#!/bin/sh
# ***************************************************************************
#  release.sh -- full build + package a versioned release zip. POSIX; run from Git Bash.
#  Invoked by release.bat, or directly:  ./release.sh [zip]
#
#     release.sh          build everything, then package into release/gpc-release-<n>.zip
#     release.sh zip      package only -- zip the CURRENT testing/ build, no rebuild
#
#  The full build runs:
#     make libs                        the libraries + the compiler engine GPC.BLITZ.BIN
#     make release                     stage the engine + samples into testing/
#     make -C source/runtime gpc-rt    the shared runtime GPC.RT.BIN (into testing/)
#     make -C source/gpc release       GPC.PRG + the GPC.ERR helper, tokenised via BASLOAD
#
#  The zip lands in release/ -- the release drop folder, kept apart from the daily testing/
#  build cycle -- named gpc-release-<n>.zip (n = the build number, last part of VERSION$). It is a
#  git-ignored build artifact, the way the old testing/blitz.zip was -- do not commit it.
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
    echo "== make -C source/gpc release  (GPC.PRG + GPC.ERR, tokenised via BASLOAD) =="
    make -C source/gpc release
fi

echo "== packaging release zip =="
# zip(1) is not on a stock Windows box, so package through Python's stdlib -- the
# same reason the rest of this tree's zipping goes through Python (see mkzip history).
python - <<'PY'
import os, re, zipfile

root    = os.getcwd()
testing = os.path.join(root, "testing")

# The version lives in ONE place: the VERSION$ variable in GPC.BASL, e.g.  VERSION$ = "0.9.110".
# Read it from the testing/ copy -- that is the master, and the exact GPC.BASL that goes into the
# zip (see source/gpc/GPC.BASL.README.TXT). Show it whole ("v0.9.110"); the last dotted component
# is the build number used in the zip name (gpc-release-110.zip -- the established naming).
basl = open(os.path.join(testing, "GPC.BASL"), encoding="utf-8").read()
m    = re.search(r'VERSION\$\s*=\s*"([0-9.]+)"', basl)
if not m:
    raise SystemExit('release: cannot find  VERSION$ = "..."  in testing/GPC.BASL')
version = m.group(1)              # e.g. "0.9.110"
num     = version.split(".")[-1]  # e.g. "110" -- the build number, for the zip name
ver     = "v" + version           # e.g. "v0.9.110"

# Output goes into the release/ drop folder (separate from the daily testing/ build cycle),
# named with the current gpc-release-<n>.zip convention. Create the folder if missing.
release_dir = os.path.join(root, "release")
os.makedirs(release_dir, exist_ok=True)
out = os.path.join(release_dir, "gpc-release-%s.zip" % num)

# The release layout:
#   * the files needed to RUN the compiler, at the zip root
#   * the companion tools, also at the root
#   * ALL BASLOAD source under SRC/ -- reference only, NOT needed to run (with a note)
#   * the top-level docs
# Everything else in testing/ (samples like DIR.BASL, compiled demos, scratch) is left out.
#   GPC.PRG        the front end you launch on the X16
#   GPC.BLITZ.BIN  the compiler engine GPC.PRG chain-loads
#   GPC.RT.BIN     the shared runtime, loaded once in "shared" compile mode
#   GPC.ERR.PRG    the error-address-to-line helper (companion tool)
#   SRC/*.BASL     the BASLOAD sources (NOT needed to run; see SRC/README.TXT)
# GPC.INPUT (the control-file template) is deliberately NOT shipped: GPC.PRG drives
# the compile interactively, and the file is per-user state (git-ignored in testing/).
RUNTIME = ("GPC.PRG", "GPC.BLITZ.BIN", "GPC.RT.BIN")
TOOLS   = ("GPC.ERR.PRG",)                 # companion tools -- also shipped at the root
SRCBASL = ("GPC.BASL", "GPC.ERR.BASL")     # ALL BASLOAD source -- goes under SRC/
DOCS    = ("README.md", "LICENSE")

# The note that ships inside SRC/, explaining the folder is source and not required to run.
SRC_README = (
    "GPC -- SRC FOLDER (SOURCE, NOT NEEDED TO RUN)\n"
    "=============================================\n"
    "\n"
    "This folder holds the BASLOAD source of the GPC tools:\n"
    "\n"
    "    GPC.BASL       the compiler front end  ->  GPC.PRG\n"
    "    GPC.ERR.BASL   the error-line helper   ->  GPC.ERR.PRG\n"
    "\n"
    "It is here for reference only -- you do NOT need anything in this folder to\n"
    "run GPC. The ready-to-run programs are in the parent folder.\n"
    "\n"
    "To compile, run GPC.PRG (with GPC.BLITZ.BIN and GPC.RT.BIN beside it). To\n"
    "turn a runtime error's \"@ $XXXX\" into a source line, run GPC.ERR.PRG.\n"
    "The .BASL sources are never loaded at run time.\n"
    "\n"
    "BASLOAD is built into every R49 X16 ROM. To rebuild a PRG from its source,\n"
    "load the source with BASLOAD -- its own #SAVEAS writes the PRG back out:\n"
    "\n"
    '    BASLOAD "GPC.BASL"        (writes GPC.PRG)\n'
    '    BASLOAD "GPC.ERR.BASL"    (writes GPC.ERR.PRG)\n'
)

names = []
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in RUNTIME:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing required file testing/%s -- build first" % name)
        z.write(full, name)
        names.append(name)
    for name in TOOLS:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing tool testing/%s -- build first" % name)
        z.write(full, name)
        names.append(name)
    for name in SRCBASL:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing source file testing/%s -- build first" % name)
        z.write(full, "SRC/" + name)
        names.append("SRC/" + name)
    z.writestr("SRC/README.TXT", SRC_README.replace("\n", "\r\n"))
    names.append("SRC/README.TXT")
    for doc in DOCS:
        full = os.path.join(root, doc)
        if os.path.isfile(full):
            z.write(full, doc)
            names.append(doc)

print("release/%s  %s  (%d files, %d bytes)" % (os.path.basename(out), ver, len(names), os.path.getsize(out)))
for n in names:
    print("   ", n)
PY

echo
echo "== RELEASE OK =="
