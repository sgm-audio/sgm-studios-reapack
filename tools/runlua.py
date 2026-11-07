#!/usr/bin/env python3
"""Run one of the Lua test suites without REAPER or a system Lua interpreter.

The suites are plain Lua and normally run as:

    lua5.4 tests/run_tests.lua

That needs a Lua binary installed. This script embeds Lua 5.5 through lupa
instead, so the suites can run anywhere Python is available:

    pip install lupa
    python3 tools/runlua.py tests/run_tests.lua

Two details matter:

* os.exit() must not kill the Python process. The suites call it to set their
  exit status, so it is replaced with a function that records the code and the
  script is allowed to finish normally.
* The real exit status is propagated, so CI and `&&` chains behave the same way
  as with a native Lua binary.

This file lives in tools/ rather than /tmp on purpose: it was previously kept
outside the repository and lost between sessions, which made the suites
unrunnable.
"""

import sys

try:
    import lupa
except ImportError:  # pragma: no cover - the message is the point
    sys.stderr.write(
        "lupa is not installed. Either install a Lua interpreter and run the "
        "suite directly (lua5.4 tests/run_tests.lua), or install lupa:\n"
        "    pip install lupa\n"
    )
    sys.exit(2)


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: runlua.py <suite.lua>\n")
        return 2

    runtime = lupa.LuaRuntime(unpack_returned_tuples=True)
    exit_code = 0

    def fake_exit(n=0):
        nonlocal exit_code
        exit_code = int(n or 0)

    runtime.globals().os.exit = fake_exit

    loader = runtime.eval("function(p) return assert(loadfile(p)) end")
    try:
        loader(argv[1])()
    finally:
        # Flush through Lua's own handles so output interleaves correctly when
        # stdout is redirected.
        runtime.execute("io.stdout:flush(); io.stderr:flush()")
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
