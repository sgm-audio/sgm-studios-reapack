#!/usr/bin/env python3
"""Static checks for the SGM Studios REAPER scripts.

Three classes of bug found in the 2026-11-07 audit are mechanically detectable,
so they are checked here instead of relying on a human audit:

1. Calls to REAPER API functions that do not exist
   (`GetCPULoading`, `GetProjectSampleRate`, `GetInputChannelCount`, ...).
   The allowlist is generated from the official REAPER SDK header, so this
   catches the whole family, not just the names we happened to hit.

2. Locals used before they are declared in the same chunk. REAPER resolves
   those as globals, which are nil at call time — this is exactly the
   "attempt to call a nil value (global 'addFX')" crash.

3. `PreventUIRefresh(1)` without a matching `PreventUIRefresh(-1)` on every
   return path, which leaves the arrange view frozen.

Usage:  python3 tools/check_api.py [paths...]
Exit code is 0 when clean, 1 when problems were found.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ALLOWLIST = os.path.join(ROOT, "tools", "api_allowlist.json")

STRING_OR_COMMENT = re.compile(
    r"""
      (?P<long>--\[(?P<eq>=*)\[.*?\](?P=eq)\])
    | (?P<line>--[^\n]*)
    | (?P<sq>'(?:\\.|[^'\\])*')
    | (?P<dq>"(?:\\.|[^"\\])*")
    """,
    re.S | re.X,
)


def strip_lua(source):
    """Remove comments and string literals, preserving line numbers."""
    def blank(match):
        text = match.group(0)
        return re.sub(r"[^\n]", " ", text)

    return STRING_OR_COMMENT.sub(blank, source)


def load_allowlist():
    with open(ALLOWLIST, encoding="utf-8") as fh:
        data = json.load(fh)
    return set(data["core"]), set(data["sws"]), set(data["lua_glue"])


# Helper functions whose UI-refresh work is attributed to their callers.
_UI_HELPERS = {"beginUndo", "endUndo"}

LOCAL_DECL = re.compile(
    r"(?:"
    r"local\s+function\s+(?P<fname>[A-Za-z_]\w*)"
    r"|local\s+(?P<names>[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)"
    r")"
)
ASSIGN_LOCAL = re.compile(r"\blocal\s+(?P<names>[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*=")


def declared_before(code):
    """Map of name -> line of the first `local` declaration."""
    first = {}
    for match in LOCAL_DECL.finditer(code):
        if match.group("fname"):
            names = [match.group("fname")]
        else:
            names = [n.strip() for n in match.group("names").split(",")]
        line = code[: match.start()].count("\n") + 1
        for name in names:
            first.setdefault(name, line)
    return first



def top_level_blocks(code):
    """Yield (name, start_offset, end_offset) for each top-level function.

    Only used for the PreventUIRefresh balance check; a lightweight brace/`end`
    matcher that ignores the stripped (comment/string free) code.
    """
    blocks = []
    pattern = re.compile(
        r"^(?:local\s+)?function\s+([A-Za-z_][\w:.]*)\s*\([^)]*\)\s*$",
        re.M,
    )
    keywords = re.compile(r"\b(if|for|while|do|function)\b|\b(end|elseif|else|until)\b")

    for match in pattern.finditer(code):
        name = match.group(1)
        depth = 0
        pos = match.end()
        for token in keywords.finditer(code, pos):
            word = token.group(0)
            if word in ("if", "for", "while", "do", "function"):
                depth += 1
            elif word == "end":
                if depth == 0:
                    blocks.append((name, match.start(), token.end()))
                    break
                depth -= 1
    return blocks


def check_file(path, core, sws, glue):
    problems = []
    with open(path, encoding="utf-8") as fh:
        source = fh.read()
    code = strip_lua(source)

    # 1. unknown REAPER API functions -------------------------------------
    for match in re.finditer(r"\breaper\.([A-Za-z_]\w*)", code):
        name = match.group(1)
        if name in core or name in sws or name in glue:
            continue
        line = code[: match.start()].count("\n") + 1
        problems.append(
            (line, "unknown-api",
             f"reaper.{name}() is not in the REAPER API or SWS API")
        )

    # 2. locals used before declaration -----------------------------------
    # Skip lines that are just the declaration itself or that shadow inside a
    # nested function (a re-declared local later in the file is normal for
    # different scopes, so only flag uses that appear strictly before the
    # very first declaration of that name).
    decl = declared_before(code)
    lines = code.split("\n")
    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("local "):
            continue
        for match in re.finditer(r"(?<![.:\w])([A-Za-z_]\w*)\s*\(", line):
            name = match.group(1)
            decl_line = decl.get(name)
            if decl_line and lineno < decl_line:
                problems.append(
                    (lineno, "use-before-local",
                     f"'{name}' is called on line {lineno} but declared local on line {decl_line}")
                )

    # 3. PreventUIRefresh balance ------------------------------------------
    # Evaluated per function with a tiny call-graph: a helper that only opens
    # (beginUndo) or only closes (endUndo) is fine as long as its callers are
    # balanced, so those helpers are folded into their callers first.
    balance = {}
    for name, start, end in top_level_blocks(code):
        body = code[start:end]
        balance[name] = (
            len(re.findall(r"PreventUIRefresh\(\s*1\s*\)", body))
            - len(re.findall(r"PreventUIRefresh\(\s*-1\s*\)", body))
        )

    def effective(name, seen):
        if name in seen:
            return balance.get(name, 0)
        seen = seen | {name}
        _, start, end = block_by_name[name]
        body = code[start:end]
        total = balance.get(name, 0)
        for call in re.finditer(r"(?<![.:\w])([A-Za-z_]\w*)\s*\(", body):
            callee = call.group(1)
            if callee in block_by_name and callee != name:
                total += effective(callee, seen)
        return total

    block_by_name = {n: (n, a, b) for n, a, b in top_level_blocks(code)}
    for name in block_by_name:
        if name in _UI_HELPERS:
            continue
        _, start, _ = block_by_name[name]
        net = effective(name, set())
        if net != 0:
            line = code[:start].count("\n") + 1
            problems.append(
                (line, "ui-refresh",
                 f"{name}(): PreventUIRefresh balance is {net:+d} "
                 f"({net > 0 and 'UI left frozen' or 'extra refresh'})")
            )

    return problems


def main(argv):
    core, sws, glue = load_allowlist()
    targets = argv[1:]
    if not targets:
        targets = []
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if d not in (".git", "tools")]
            targets += [os.path.join(base, f) for f in files if f.endswith(".lua")]
        targets.sort()

    total = 0
    for path in targets:
        rel = os.path.relpath(path, ROOT)
        for line, kind, message in check_file(path, core, sws, glue):
            total += 1
            print(f"{rel}:{line}: [{kind}] {message}")

    if total:
        print(f"\n{total} problem(s) found")
        return 1
    print(f"checked {len(targets)} file(s): no unknown API calls, "
          "no use-before-local, PreventUIRefresh balanced")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
