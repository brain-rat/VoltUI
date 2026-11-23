"""Tests for tools/package.py: python tests/package_test.py"""
# The same file is in other add-on repositories too: change one copy, then copy it to the others.
import os
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import package  # noqa: E402

passed, failed = 0, 0


def check(name, ok):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print("FAIL", name)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as h:
        h.write(text)


TOC = "## Interface: 16001\n## Title: Demo\n## Version: 1.2.3\n\nCore.lua\n# a comment\nMade.lua\nSub\\Part.lua\n"

# read_toc
version, files = package.read_toc(TOC)
check("toc version", version == "1.2.3")
check("toc files, comments skipped, slashes turned", files == ["Core.lua", "Made.lua", "Sub/Part.lua"])
check("toc with no version", package.read_toc("## Title: x\nA.lua\n")[0] is None)

# generated
gi = "key.txt\n# made on your PC\nDemo/Made.lua\n/Demo/Other.lua\nOtherAddon/X.lua\n*.report.json\n"
check("generated names under the add-on only", package.generated(gi, "Demo") == {"Made.lua", "Other.lua"})

with tempfile.TemporaryDirectory() as root:
    write(os.path.join(root, "Demo", "Demo.toc"), TOC)
    write(os.path.join(root, "Demo", "Core.lua"), "local _, ns = ...\n")
    write(os.path.join(root, "Demo", "Sub", "Part.lua"), "-- part\n")
    write(os.path.join(root, "LICENSE"), "GPL\n")
    os.makedirs(os.path.join(root, "tools"))
    made = {"Made.lua", "Other.lua"}
    good = ["Core.lua", "Demo.toc", "Sub/Part.lua"]

    check("find_addon", package.find_addon(root) == "Demo")
    check("clean list passes", package.problems(root, "Demo", good, made) == [])

    # A generated file that got into the list stops the build.
    write(os.path.join(root, "Demo", "Made.lua"), "-- ours\n")
    bad = package.problems(root, "Demo", good + ["Made.lua"], made)
    check("generated file stops it", any("Made.lua" in b for b in bad))

    # So does a file that carries a generated file's header, whatever its name.
    write(os.path.join(root, "Demo", "Copy.lua"), "-- Data: ForeverDB.net. Reuse requires this credit: see NOTICE.txt\n")
    bad = package.problems(root, "Demo", good + ["Copy.lua"], made)
    check("ForeverDB header stops it", any("Copy.lua" in b for b in bad))
    write(os.path.join(root, "Demo", "Guide.lua"), "-- made on this PC. Don't share it: it's worked out from others' data\n")
    check("don't-share header stops it", any("Guide.lua" in b for b in package.problems(root, "Demo", good + ["Guide.lua"], made)))
    write(os.path.join(root, "Demo", "key.txt"), "secret\n")
    check("key file stops it", any("key.txt" in b for b in package.problems(root, "Demo", good + ["key.txt"], made)))

    # The toc loading a file that isn't there stops it, unless it's one made on your PC.
    bad = package.problems(root, "Demo", ["Core.lua", "Demo.toc"], made)
    check("missing toc file stops it", any("Sub/Part.lua" in b for b in bad))
    check("missing generated file is fine", not any("Made.lua" in b for b in bad))

    write(os.path.join(root, "Demo", "Demo.toc"), "## Title: Demo\nCore.lua\n")
    check("no version stops it", any("Version" in b for b in package.problems(root, "Demo", ["Core.lua", "Demo.toc"], made)))
    write(os.path.join(root, "Demo", "Demo.toc"), TOC)

    # build: the add-on's folder at the top of the zip, with the licence inside it.
    out = os.path.join(root, "dist")
    path = package.build(root, "Demo", good, out, "1.2.3")
    check("zip name", os.path.basename(path) == "Demo-1.2.3.zip")
    with zipfile.ZipFile(path) as z:
        names = sorted(z.namelist())
        check("zip holds the folder and licence", names == ["Demo/Core.lua", "Demo/Demo.toc", "Demo/LICENSE.txt", "Demo/Sub/Part.lua"])
        check("zip contents", z.read("Demo/Core.lua") == b"local _, ns = ...\n")
    check("no temp file left", os.listdir(out) == ["Demo-1.2.3.zip"])

    # Two add-on folders is a mistake, not a guess.
    write(os.path.join(root, "Two", "Two.toc"), TOC)
    try:
        package.find_addon(root)
        check("two add-ons refused", False)
    except SystemExit:
        check("two add-ons refused", True)

print("%d passed, %d failed" % (passed, failed))
sys.exit(1 if failed else 0)
