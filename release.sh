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
#     make -C source/gpc release       the front end GPC.PRG (tokenises GPC.BASL via BASLOAD)
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
    echo "== make -C source/gpc release  (GPC.PRG front end, tokenised from GPC.BASL) =="
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
#   * the BASLOAD source under SRC/ -- reference only, NOT needed to run (with a note)
#   * the top-level docs
# Everything else in testing/ (samples like DIR.BASL, compiled demos, scratch) is left out.
#   GPC.PRG        the front end you launch on the X16
#   GPC.BLITZ.BIN  the compiler engine GPC.PRG chain-loads
#   GPC.RT.BIN     the shared runtime, loaded once in "shared" compile mode
#   GPC.INPUT      the control-file template
#   SRC/GPC.BASL   the BASLOAD source of the front end (NOT needed to run; see SRC/README.TXT)
RUNTIME = ("GPC.PRG", "GPC.BLITZ.BIN", "GPC.RT.BIN", "GPC.INPUT")
SRCBASL = ("GPC.BASL",)   # BASLOAD source -- goes under SRC/, not needed at run time
DOCS    = ("README.md", "LICENSE")

# The note that ships inside SRC/, explaining the folder is source and not required to run.
SRC_README = (
    "GPC -- SRC FOLDER (SOURCE, NOT NEEDED TO RUN)\n"
    "=============================================\n"
    "\n"
    "This folder holds the BASLOAD source of the GPC front end (GPC.BASL). It is\n"
    "here for reference only -- you do NOT need anything in this folder to run GPC.\n"
    "\n"
    "To run GPC, use GPC.PRG in the parent folder (with GPC.BLITZ.BIN, GPC.RT.BIN\n"
    "and GPC.INPUT beside it). GPC.BASL is never loaded at run time.\n"
    "\n"
    "GPC.BASL is human-readable BASLOAD source. To regenerate GPC.PRG from it on an\n"
    "X16 (any R49 ROM -- BASLOAD is built in), load BASLOAD and type:\n"
    "\n"
    '    BASLOAD "GPC.BASL"\n'
    "\n"
    "Its own #SAVEAS directive writes GPC.PRG back out.\n"
)

names = []
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in RUNTIME:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing required file testing/%s -- build first" % name)
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
