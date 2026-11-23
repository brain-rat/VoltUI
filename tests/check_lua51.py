"""Check every add-on file compiles on Lua 5.1, the version the game runs.

Newer Lua accepts things 5.1 refuses, such as a block that starts with ";" or goto. A file
that doesn't compile never loads in the game, so its whole feature silently goes missing.

Needs lupa (pip install lupa). Run from the repo root: python tests/check_lua51.py
"""
import os
import sys

from lupa import lua51

# Other folders can be given instead, such as the installed add-ons with their generated data files:
#   python tests/check_lua51.py "<AddOns>/VoltUI"
ADDONS = tuple(sys.argv[1:]) or ("VoltUI",)

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(src, name) local f, e = loadstring(src, name); return f ~= nil, e end")

bad = checked = 0
for addon in ADDONS:
    for folder, _, files in os.walk(addon):
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(folder, name)
            with open(path, encoding="utf-8", newline="") as f:
                source = f.read().lstrip("﻿")
            ok, err = compile_lua(source, "@" + path)
            checked += 1
            if not ok:
                bad += 1
                print("FAIL:", err)

print(f"{checked - bad} of {checked} files compile on Lua 5.1")
sys.exit(1 if bad else 0)
