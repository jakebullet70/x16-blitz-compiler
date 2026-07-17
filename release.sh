#!/bin/sh
# ***************************************************************************
#  release.sh -- full build + package release.zip. POSIX; run from Git Bash.
#  Invoked by release.bat, or directly:  ./release.sh [zip]
#
#     release.sh          build everything, then package testing/ into release.zip
#     release.sh zip      package only -- zip the CURRENT testing/ build, no rebuild
#
#  The full build runs:
#     make libs                        the libraries + the compiler engine GPC.BLITZ.BIN
#     make release                     stage the engine + samples into testing/
#     make -C source/runtime gpc-rt    the shared runtime GPC.RT.BIN (into testing/)
#     make -C source/gpc release       the front end GPC.PRG (bumps the build number)
#
#  release.zip is a build artifact (git-ignored), the way the old testing/blitz.zip
#  was -- do not commit it.
# ***************************************************************************
set -e
cd "$(dirname "$0")"

if [ "$1" != "zip" ]; then
    echo "== make libs =="
    make libs
    echo "== make release =="
    make release
    echo "== make -C source/runtime gpc-rt  (GPC.RT.BIN shared runtime) =="
    make -C source/runtime gpc-rt
    echo "== make -C source/gpc release  (GPC.PRG front end -- bumps build number) =="
    make -C source/gpc release
fi

echo "== packaging release.zip =="
# zip(1) is not on a stock Windows box, so package through Python's stdlib -- the
# same reason the rest of this tree's zipping goes through Python (see mkzip history).
python - <<'PY'
import os, re, zipfile

root    = os.getcwd()
testing = os.path.join(root, "testing")
out     = os.path.join(root, "release.zip")

# The release is ONLY the files needed to run the compiler, plus the README.
# Everything else in testing/ (samples, compiled demos, the host tokeniser, scratch)
# is deliberately left out.
#   GPC.PRG        the front end you launch on the X16
#   GPC.BLITZ.BIN  the compiler engine GPC.PRG chain-loads
#   GPC.RT.BIN     the shared runtime, loaded once in "shared" compile mode
#   GPC.INPUT      the control-file template
GPC  = ("GPC.PRG", "GPC.BLITZ.BIN", "GPC.RT.BIN", "GPC.INPUT")
DOCS = ("README.md", "LICENSE")

# Version string GPC prints at startup: "v0.9.<build_num>", from GPC.P8.
p8  = open(os.path.join(root, "source", "gpc", "GPC.P8"), encoding="utf-8").read()
m   = re.search(r"build_num\s*=\s*(\d+)", p8)
ver = "v0.9." + (m.group(1) if m else "?")

names = []
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in GPC:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing required file testing/%s -- build first" % name)
        z.write(full, name)
        names.append(name)
    for doc in DOCS:
        full = os.path.join(root, doc)
        if os.path.isfile(full):
            z.write(full, doc)
            names.append(doc)

print("release.zip  %s  (%d files, %d bytes)" % (ver, len(names), os.path.getsize(out)))
for n in names:
    print("   ", n)
PY

echo
echo "== RELEASE OK =="
