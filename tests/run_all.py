"""Run every check there is, on the Lua the game runs: python tests/run_all.py

1. every add-on file compiles on Lua 5.1 (check_lua51.py)
2. VoltUI's tests, on Lua 5.1
3. every tests/*_test.py, for the tools

Needs lupa (pip install lupa), which carries a real Lua 5.1. Run from the repo root. Ends with a
line for each, and exits 1 if any failed.
"""
import glob, re
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

LUA_TESTS = (("tests/voltui_test.lua", "VoltUI"),)


def run_lua(script, *args):
    """A Lua test file on real Lua 5.1, with arg[] as the lua program would give it."""
    from lupa import lua51

    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    arg = lua.table()
    arg[0] = script
    for i, a in enumerate(args, 1):
        arg[i] = a
    lua.globals().arg = arg
    # The tests end with os.exit: taken as the result, without ending this program.
    lua.execute("os.exit = function(code) error({ exit = (code == true or code == nil) and 0 or (code == false and 1) or code }, 0) end")
    load = lua.eval("""function(path)
      local f, e = loadfile(path)
      if not f then return 1, e end
      local ok, err = pcall(f)
      if ok then return 0 end
      if type(err) == "table" and err.exit then return err.exit end
      return 1, tostring(err)
    end""")
    code, err = load(script), None
    if isinstance(code, tuple):
        code, err = code
    if err:
        print("LUA ERROR:", err)
    return int(code or 0)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--lua":
        return run_lua(*sys.argv[2:])
    os.chdir(ROOT)
    steps = [("Lua 5.1 compile check", [sys.executable, "tests/check_lua51.py"])]
    for script, addon in LUA_TESTS:
        steps.append((script, [sys.executable, os.path.join("tests", "run_all.py"), "--lua", script, addon]))
    for path in sorted(glob.glob(os.path.join("tests", "*_test.py"))):
        steps.append((path.replace("\\", "/"), [sys.executable, path]))
    results = []
    for name, cmd in steps:
        done = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        out = (done.stdout or "").strip().splitlines()
        # The tests' own "N passed, M failed" line; a failure's lines are shown in full.
        last = next((l.strip() for l in reversed(out) if "passed" in l or "compile" in l or l.strip() == "ok"), out[-1].strip() if out else "")
        bad = (done.returncode != 0 or any(l.startswith("LUA ERROR") or l.strip().startswith("FAIL") for l in out)
               or re.search(r"\b[1-9]\d* failed", last) is not None)
        if bad:
            for l in out:
                if "FAIL" in l or "ERROR" in l or "Traceback" in l:
                    print("   ", l.strip())
            if done.stderr:
                print(done.stderr.strip())
        results.append((name, bad, last))
    print()
    for name, bad, last in results:
        print("%-4s %-34s %s" % ("FAIL" if bad else "ok", name, last))
    return 1 if any(bad for _, bad, _ in results) else 0


if __name__ == "__main__":
    sys.exit(main())
