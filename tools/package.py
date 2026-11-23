"""Make the release zip: python tools/package.py

The zip holds only the add-on's folder, as the game wants it in Interface/AddOns, with the
repository's LICENSE inside it. It's named after the folder and the toc's version, and goes
in dist/ (git ignores it):

    python tools/package.py              -> dist/<folder>-<version>.zip, say dist/VoltUI-1.102.0.zip
    python tools/package.py --list       what would go in, without writing anything
    python tools/package.py --version v1.102.0   stop unless the toc says this version (for a tag)

Files go in when git would commit them: tracked, or new and not ignored. So the data files made
on your PC from ForeverDB's data, which .gitignore lists, stay out. Two checks back that up and
stop the build: no file .gitignore names under the add-on's folder may be in the list, and no
file may start with the "not for redistribution" lines those generated files carry. It also
stops if the toc lists a file that isn't there, other than those generated ones (the game
skips a missing file, so they're listed for whoever makes them).
"""
# The same file is in other add-on repositories too: change one copy, then copy it to the others.
import argparse
import os
import re
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# The first lines of a file made from ForeverDB's or RestedXP's data say one of these.
NOT_OURS = ("Not for redistribution", "Don't share it", "Reuse requires this credit")


def find_addon(root):
    """The one folder at the top that holds <folder>/<folder>.toc."""
    found = [d for d in sorted(os.listdir(root))
             if os.path.isfile(os.path.join(root, d, d + ".toc"))]
    if len(found) != 1:
        raise SystemExit("expected one add-on folder with its own toc in %s, found %s" % (root, found or "none"))
    return found[0]


def read_toc(text):
    """(version, files the toc loads) from a toc's text."""
    version, files = None, []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("##"):
            m = re.match(r"##\s*Version\s*:\s*(\S+)", line)
            if m:
                version = m.group(1)
        elif not line.startswith("#"):
            files.append(line.replace("\\", "/"))
    return version, files


def generated(gitignore_text, addon):
    """Paths inside the add-on's folder, relative to it, that .gitignore names one by one."""
    out = set()
    prefix = addon + "/"
    for line in gitignore_text.splitlines():
        line = line.strip().lstrip("/")
        if line.startswith(prefix) and not line.startswith("#"):
            out.add(line[len(prefix):])
    return out


def git_files(root, addon):
    """The add-on's files git would commit, relative to the add-on's folder."""
    done = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "--", addon],
                          cwd=root, capture_output=True, text=True, check=True)
    prefix = addon + "/"
    files = []
    for line in done.stdout.splitlines():
        line = line.strip()
        if line.startswith(prefix) and os.path.isfile(os.path.join(root, line)):
            files.append(line[len(prefix):])
    return sorted(set(files))


def problems(root, addon, files, made_here):
    """Reasons not to ship this list; empty when it's fine."""
    bad = []
    folder = os.path.join(root, addon)
    have = set(files)
    for f in sorted(have & made_here):
        bad.append("%s/%s is made on your PC from data that isn't ours to share" % (addon, f))
    for f in files:
        if os.path.basename(f).lower() in ("key.txt",):
            bad.append("%s/%s looks like an API key" % (addon, f))
        if f.endswith((".lua", ".xml", ".toc", ".txt", ".md")):
            with open(os.path.join(folder, f), "r", encoding="utf-8", errors="replace") as h:
                head = h.read(2000)
            for words in NOT_OURS:
                if words in head:
                    bad.append("%s/%s says \"%s\" at the top" % (addon, f, words))
                    break
    with open(os.path.join(folder, addon + ".toc"), "r", encoding="utf-8", errors="replace") as h:
        version, listed = read_toc(h.read())
    if not version:
        bad.append("%s.toc has no ## Version line" % addon)
    for f in listed:
        if f not in have and f not in made_here:
            bad.append("%s.toc loads %s, which isn't in the zip" % (addon, f))
    return bad


def build(root, addon, files, out_dir, version):
    """Write the zip and return its path."""
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "%s-%s.zip" % (addon, version))
    tmp = path + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for f in files:
            z.write(os.path.join(root, addon, f), "%s/%s" % (addon, f))
        licence = os.path.join(root, "LICENSE")
        if os.path.isfile(licence) and "LICENSE" not in files and "LICENSE.txt" not in files:
            z.write(licence, "%s/LICENSE.txt" % addon)
    os.replace(tmp, path)
    return path


def main(argv=None):
    p = argparse.ArgumentParser(description="Make the release zip of this repository's add-on.")
    p.add_argument("--list", action="store_true", help="show what would go in, write nothing")
    p.add_argument("--version", help="stop unless the toc's version is this (a leading v is dropped)")
    p.add_argument("--out", default=os.path.join(ROOT, "dist"), help="folder for the zip (default dist/)")
    args = p.parse_args(argv)

    addon = find_addon(ROOT)
    with open(os.path.join(ROOT, ".gitignore"), "r", encoding="utf-8") as h:
        made_here = generated(h.read(), addon)
    with open(os.path.join(ROOT, addon, addon + ".toc"), "r", encoding="utf-8", errors="replace") as h:
        version, _ = read_toc(h.read())
    files = git_files(ROOT, addon)

    bad = problems(ROOT, addon, files, made_here)
    if args.version and version and args.version.lstrip("vV") != version:
        bad.append("asked for version %s but %s.toc says %s" % (args.version, addon, version))
    if args.list:
        for f in files:
            print("%s/%s" % (addon, f))
        print("%d files, %s %s" % (len(files), addon, version))
    if bad:
        for b in bad:
            print("STOP:", b)
        return 1
    if args.list:
        return 0
    path = build(ROOT, addon, files, args.out, version)
    print("%s: %d files, %d KB" % (os.path.relpath(path, ROOT), len(files), (os.path.getsize(path) + 1023) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
