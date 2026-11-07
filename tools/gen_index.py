#!/usr/bin/env python3
"""Regenerate the parts of index.xml that are derived from the script headers.

`reapack-index` (the official tool) does this itself, but it needs Ruby +
nokogiri + pandoc, so the index in this repository is maintained by hand. This
script automates the error-prone half of that job:

  * <version name=... author=... time=...>   <- @version / @author / @changelog date
  * <changelog>                              <- @changelog
  * <source ...>...</source>                 <- @provides, pinned to a commit

Everything else (package descriptions, the RTF "about" text, categories) is
left byte-for-byte untouched, because rewriting it would mean re-running pandoc
over the READMEs and would churn the whole file.

Sources are pinned to a commit SHA, matching what reapack-index emits: its URL
template is `<repo>/raw/$commit/$path`. A tag or branch name would let the
content behind an unchanged version number drift, which ReaPack cannot detect.

Usage:
    python3 tools/gen_index.py            # pin to HEAD
    python3 tools/gen_index.py --check    # verify only, non-zero exit on drift
"""

import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "index.xml")
REPO_URL = "https://github.com/sgm-audio/sgm-studios-reapack"
SCREENSHOT_DIR = os.path.join(ROOT, "docs", "screenshots")

# ReaPack shows <link rel="screenshot"> images in the package browser and turns
# <link rel="donation"> into a button. Only real, reachable URLs belong here:
#   * screenshots come from docs/screenshots/<package>.png when that file exists
#     (capture them in REAPER — a generated mock-up would be a lie);
#   * the donation link is only emitted when a URL is configured below.
DONATION_URL = None

HEADER = re.compile(r"^--\s*@(description|author|version|metapackage|provides|changelog)\b(.*)$")


def parse_header(path):
    """Parse the metaheader block of a ReaScript (see reapack-index metaheader)."""
    info = {"provides": [], "changelog": []}
    key = None
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            if not raw.startswith("--"):
                if key and not raw.strip():
                    break
                continue
            line = raw.rstrip("\n")[2:]
            stripped = line.lstrip(" ")
            match = HEADER.match("--" + stripped) if False else None  # unused
            if re.match(r"^\s*@\w+", stripped):
                name, _, rest = stripped.strip().partition(" ")
                key = name[1:]
                if key == "metapackage":
                    info["metapackage"] = True
                elif key in ("version", "author", "description"):
                    info[key] = rest.strip()
                continue
            if key == "provides":
                entry = stripped.strip()
                if entry:
                    info["provides"].append(entry)
            elif key == "changelog":
                # keep the author's indentation: one space after "--" is the
                # separator, the rest is the layout of the changelog
                info["changelog"].append(line[1:].rstrip())
    return info


def parse_provides(entries):
    """'[main] foo.lua' -> (sections, path). Mirrors ReaPack's provides grammar."""
    out = []
    for entry in entries:
        sections = []
        path = entry
        m = re.match(r"^\[([^\]]*)\]\s*(.+)$", entry)
        if m:
            names = [s.strip() for s in m.group(1).split("+") if s.strip()]
            sections = [] if "nomain" in names else names
            path = m.group(2).strip()
        if "=>" in path:                      # [main] src.lua=>target.lua
            path = path.split("=>", 1)[1].strip()
        out.append((sections, path))
    return out


def dedent_changelog(lines):
    """Strip the block's common leading indent, the way MetaHeader does."""
    lines = list(lines)
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    indent = len(lines[0]) - len(lines[0].lstrip(" ")) if lines else 0
    return "\n".join(ln[indent:] if ln[:indent].strip() == "" else ln for ln in lines)


def changelog_date(lines):
    for line in lines:
        m = re.match(r"^\s*(\d[^\s(]*)\s*\((\d{4}-\d\d-\d\d)\)", line)
        if m:
            return m.group(2)
    return None


def cdata(text):
    return "<![CDATA[" + text + "]]>"


def block_bounds(text, name):
    """Byte range of <reapack name="name" ...> ... </reapack>."""
    start = text.find('<reapack name="%s"' % name)
    if start < 0:
        raise SystemExit("package %r not found in index.xml" % name)
    end = text.index("</reapack>", start) + len("</reapack>")
    return start, end


def build_sources(pkg_path, info, commit):
    """Return (path, main_attr, file_attr) tuples for one package."""
    category = os.path.dirname(pkg_path)
    sources = []

    def add(path, sections, file_attr=None):
        sources.append((path, sections, file_attr))

    if not info.get("metapackage"):
        add(pkg_path, ["main"] if True else [], None)

    seen = {pkg_path} if not info.get("metapackage") else set()
    for sections, rel in parse_provides(info["provides"]):
        # A bare "." in @provides means "this file" (reapack-index rewrites it to
        # the package name); resolve it the same way.
        if rel in (".", ""):
            rel = os.path.basename(pkg_path)
        path = os.path.normpath(os.path.join(category, rel))
        if path in seen:
            continue
        seen.add(path)
        # Child files of a package that are not runnable scripts carry no `main`
        # (main means "register in this Action List section"), and a source that
        # renames the file needs a `file=` attribute.
        file_attr = None
        if os.path.basename(path) != os.path.basename(rel):
            file_attr = rel
        add(path, sections, file_attr)

    # Child files that belong to the package but are not in @provides are
    # deliberately not guessed at: reapack-index only ships @provides files.
    return sources


def render_sources(sources, commit):
    lines = []
    for path, sections, file_attr in sources:
        if not os.path.isfile(os.path.join(ROOT, path)):
            raise SystemExit("source file does not exist: %s" % path)
        attrs = ""
        if sections:
            attrs += ' main="%s"' % " ".join(sections)
        if file_attr:
            attrs += ' file="%s"' % file_attr
        lines.append("        <source%s>%s/raw/%s/%s</source>"
                     % (attrs, REPO_URL, commit, path))
    return "\n".join(lines)


def desired_links(pkg, info):
    """(rel, href) pairs a package should advertise, in ReaPack's display order."""
    category = os.path.dirname(pkg)
    links = [("website", "%s/tree/main/%s" % (REPO_URL, category))]

    shot = os.path.join(SCREENSHOT_DIR, os.path.basename(pkg) + ".png")
    if os.path.isfile(shot):
        links.append(("screenshot",
                      "%s/raw/main/docs/screenshots/%s.png"
                      % (REPO_URL, os.path.basename(pkg))))

    if DONATION_URL:
        links.append(("donation", DONATION_URL))
    return links


def root_links():
    """Links for the repository entry itself."""
    links = [("website", REPO_URL)]
    if DONATION_URL:
        links.append(("donation", DONATION_URL))
    return links


def sync_links(block, links):
    """Add/replace the <link> elements of one package's <metadata>."""
    # Drop the rels this script owns, keep anything else the author added.
    owned = {"website", "screenshot", "donation"}
    existing = re.findall(r'[ \t]*<link\b[^>]*/>\n?', block)
    for tag in existing:
        rel_match = re.search(r'rel="([^"]*)"', tag)
        if rel_match and rel_match.group(1) in owned:
            block = block.replace(tag, "", 1)

    wanted = "".join('        <link rel="%s" href="%s"/>\n' % (rel, href)
                     for rel, href in links)
    if "<metadata>" in block:
        return block.replace("<metadata>\n", "<metadata>\n" + wanted, 1)
    # A package without <metadata> needs one created.
    return re.sub(r"(<reapack\b[^>]*>)\n",
                  r"\1\n      <metadata>\n" + wanted + "      </metadata>\n",
                  block, count=1)


def rewrite(path, commit, check):
    text = open(path, encoding="utf-8").read()
    original = text
    changed = []

    # Discover packages from the file itself, so a new script needs a manual
    # block first (the RTF description cannot be invented here).
    names = re.findall(r'<reapack name="([^"]+)"', text)
    for name in names:
        start, end = block_bounds(text, name)
        block = text[start:end]

        # Which file defines this package?
        pkg = None
        for category in sorted(os.listdir(ROOT)):
            if category.startswith("."):
                continue
            candidate = os.path.join(category, name)
            if os.path.isfile(os.path.join(ROOT, candidate)):
                pkg = candidate
                break
        if not pkg:
            raise SystemExit("cannot find the script for package %r" % name)

        info = parse_header(os.path.join(ROOT, pkg))

        # 1. version attributes
        old_ver = re.search(r'<version name="([^"]*)" author="([^"]*)" time="([^"]*)"', block)
        if not old_ver:
            raise SystemExit("%s: no <version> in index.xml" % name)
        version = info.get("version") or old_ver.group(1)
        author = info.get("author") or old_ver.group(2)
        date = changelog_date(info["changelog"]) or old_ver.group(3)[:10]
        block = block[:old_ver.start()] + (
            '<version name="%s" author="%s" time="%sT12:00:00Z"' % (version, author, date)
        ) + block[old_ver.end():]

        # 2. changelog
        cl = dedent_changelog(info["changelog"])
        block = re.sub(r"<changelog>.*?</changelog>",
                       "<changelog>" + cdata(cl) + "</changelog>",
                       block, count=1, flags=re.S)

        # 3. metadata links (website / screenshot / donation)
        block = sync_links(block, desired_links(pkg, info))

        # 4. sources
        sources = build_sources(pkg, info, commit)
        rendered = render_sources(sources, commit)
        block = re.sub(r"(?:^|\n)(?:        <source[^>]*>[^<]*</source>\n?)+",
                       "\n" + rendered + "\n", block, count=1)

        text = text[:start] + block + text[end:]

    # Index-wide metadata (the "about" text shown for the repository itself).
    root_at = text.rfind("<metadata>")
    if root_at > text.rfind("</reapack>"):
        start, end = root_at, text.index("</metadata>", root_at) + len("</metadata>")
        # the root block is indented by two spaces, not eight
        text = text[:start] + sync_links(text[start:end], root_links()).replace(
            "        <link", "    <link") + text[end:]

    try:
        ET.fromstring(text)
    except ET.ParseError as exc:
        raise SystemExit("generated index.xml is not valid XML: %s" % exc)

    if text != original:
        changed.append("index.xml")
        if not check:
            open(path, "w", encoding="utf-8").write(text)

    return changed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="fail if index.xml is out of date")
    parser.add_argument("--commit", default=None,
                        help="commit SHA to pin sources to (default: HEAD)")
    args = parser.parse_args()

    if args.commit:
        commit = args.commit
    elif args.check:
        # Keep whatever is already pinned, and only verify everything else.
        existing = re.search(r"/raw/([0-9a-f]{7,40})/", open(INDEX, encoding="utf-8").read())
        commit = existing.group(1) if existing else "HEAD"
    else:
        commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()

    changed = rewrite(INDEX, commit, args.check)
    if args.check:
        if changed:
            print("index.xml is out of date — run: python3 tools/gen_index.py")
            return 1
        print("index.xml is up to date")
        return 0
    print("index.xml rewritten, sources pinned to %s" % commit[:10])
    return 0


if __name__ == "__main__":
    sys.exit(main())
