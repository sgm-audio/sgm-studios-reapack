#!/usr/bin/env python3
"""Run the Lua regression tests with whatever Lua 5.4 interpreter is available."""
import shutil
import subprocess
import sys

CANDIDATES = ["lua5.4", "lua54", "lua5.3", "lua"]

def find_lua():
    for name in CANDIDATES:
        path = shutil.which(name)
        if path:
            return path
    return None

def main():
    lua = find_lua()
    if not lua:
        print("no Lua interpreter found (install lua5.4)")
        return 1
    print(f"using {lua}")
    return subprocess.call([lua, "tests/run_tests.lua"])

if __name__ == "__main__":
    sys.exit(main())
