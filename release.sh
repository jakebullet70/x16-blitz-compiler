#!/bin/sh
# ***************************************************************************
#  release.sh -- full build + package a versioned release zip. POSIX; run from Git Bash.
#  Invoked by release.bat, or directly:  ./release.sh [zip]
#
#     release.sh          build everything, then package into release/gpc-release-<n>.zip
#     release.sh zip      package only -- zip the CURRENT testing/ build, no rebuild
#
#  The full build runs:
#     make libs                        the libraries + the compiler engine GPC.BIN
#     make release                     stage the engine + samples into testing/
#     make -C source/runtime gpc-rt    both shared runtimes, GPB/GPC.RT.nnn.BIN (into testing/)
#     make -C source/gpc release       GPC.PRG + GPC.ERR (tokenised, then compiled SHARED)
#
#  The zip lands in release/ -- the release drop folder, kept apart from the daily testing/
#  build cycle -- named gpc-release-<n>.zip (n = the engine build number, last part of
#  source/application/buildnum.txt). It is a git-ignored build artifact, the way the old
#  testing/blitz.zip was -- do not commit it.
# ***************************************************************************
set -e
cd "$(dirname "$0")"

if [ "$1" != "zip" ]; then
    echo "== make libs =="
    make libs
    echo "== make release =="
    make release
    echo "== make -C source/runtime gpc-rt  (GPB/GPC.RT.nnn.BIN shared runtimes) =="
    make -C source/runtime gpc-rt
    echo "== make -C source/gpc release  (GPC.PRG + GPC.ERR, tokenised and compiled) =="
    make -C source/gpc release
fi

echo "== packaging release zip =="
# zip(1) is not on a stock Windows box, so package through Python's stdlib -- the
# same reason the rest of this tree's zipping goes through Python (see mkzip history).
python - <<'PY'
import os, sys, zipfile

root    = os.getcwd()
testing = os.path.join(root, "testing")

# The PRODUCT VERSION lives in ONE place: source/application/buildnum.txt, e.g. "1.0.0". It is
# what GPC.BIN prints (as V1.0.0) and what names this zip, and it is edited by hand when a
# release is cut -- nothing bumps it. It used to be VERSION$ in testing/GPC.BASL, which tracked
# the front end instead and so never moved when the compiler changed.
#
# The zip is named from the WHOLE version (gpc-release-1.0.0.zip), not from its last component.
# It used to be the last component alone, back when that component was an ever-increasing build
# number and unique on its own. It no longer is: 1.0.0 and 2.0.0 would both have produced
# "gpc-release-0.zip" and the second would have silently overwritten the first.
#
# The runtime build number is a DIFFERENT stamp (rtbuild.txt) and appears only in the
# GPB.RT.nnn.BIN file name, via rt_filename() below.
stamp = os.path.join(root, "source", "application", "buildnum.txt")
if not os.path.isfile(stamp):
    raise SystemExit("release: cannot find source/application/buildnum.txt -- no engine version")
version = open(stamp, encoding="utf-8").read().strip()   # e.g. "1.0.0"
if not version:
    raise SystemExit("release: buildnum.txt is empty -- no engine version")
num     = version                 # e.g. "1.0.0" -- the whole version, for the zip name
ver     = "v" + version           # e.g. "v1.0.0"

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
#   GPC.BIN        the compiler engine GPC.PRG chain-loads
#   GPC.IMG.nnn.BIN the runtime every self-contained object carries, streamed into it as the
#                  object is written. GPC.BIN CANNOT COMPILE WITHOUT IT -- the runtime used to
#                  live inside the engine and moved out so that the object buffer could have
#                  the low RAM. Build-numbered like the shared runtimes, and for the same
#                  reason: a stale one under a fixed name would still be found.
#   GPB.RT.nnn.BIN the shared runtime WITH the GPB handlers, and
#   GPC.RT.nnn.BIN the same runtime WITHOUT them -- a program compiled in "shared" mode asks
#                  for whichever it needs, and BOTH must ship: which one a given program wants
#                  is decided at compile time, so a release carrying only one silently works
#                  for half the programs built against it. nnn is the RUNTIME
#                  BUILD NUMBER, read from rtname.py rather than spelled out -- a hard-coded
#                  name here is exactly what broke this script when the runtime was versioned.
#   GPC.ERR.PRG    the error-address-to-line helper -- the COMPILED build. In the tree it is
#                  C.GPC.ERR.PRG (the "C." prefix distinguishes compiler output from the
#                  GPC.ERR.PRG that is its input); the release drops the prefix, because a
#                  user should not have to know which of two spellings is the fast one. The
#                  interpreted build is NOT shipped -- it exists in the tree only as the
#                  compile input, and SRC/GPC.ERR.BASL regenerates it if it is ever needed.
#   SRC/*.BASL     the BASLOAD sources (NOT needed to run; see SRC/README.TXT)
#   GPC-BASIC/     the GP.BASIC library -- the .INC.BL includes every BASL source using GP
#                  keywords needs, the .EXP.BL examples, and its manual (GP-BASIC.md) and
#                  global-name register (GP-BASIC.GLOBALS.md) alongside them
# GPC.INPUT (the control-file template) is deliberately NOT shipped: GPC.PRG drives
# the compile interactively, and the file is per-user state (git-ignored in testing/).
# The runtime's file name carries the engine build number; import the one definition of it.
sys.path.insert(0, os.path.join(root, "source", "runtime", "scripts"))
from rtname import rt_filename, rc_filename         # noqa: E402

# ...and the runtime IMAGE's name likewise, from the script that builds it.
sys.path.insert(0, os.path.join(root, "source", "application", "scripts"))
from genrtimage import imageName                    # noqa: E402

RUNTIME = ("GPC.PRG", "GPC.BIN", imageName(), rt_filename(), rc_filename())
# Companion tools, shipped at the root as (name in testing/, name in the zip). The compiled
# helper is built as C.GPC.ERR.PRG and ships as plain GPC.ERR.PRG -- so it must NOT be listed
# with an interpreted GPC.ERR.PRG as well, or the two collide on one name in the archive.
TOOLS   = (("C.GPC.ERR.PRG", "GPC.ERR.PRG"),)
SRCBASL = ("GPC.BASL", "GPC.ERR.BASL")     # ALL BASLOAD source -- goes under SRC/
DOCS    = ("README.md", "LICENSE")

# The GP.BASIC library ships whole, under GPC-BASIC/, straight from the repo master rather than
# from testing/ -- testing/ holds only the staged copies of whatever was last built there, and
# they are git-ignored precisely so they cannot be mistaken for the masters.
#
# Its two reference docs LIVE in GPC-BASIC/ rather than in a docs folder of their own, so the repo
# and the zip have the same shape and a relative link works in both. They used to be copied in from
# docs/blitz/ here, which meant README.md's own links were correct in the repo and broken for every
# release user -- and the release user is the one who cannot go and find the file. Someone who
# extracts this zip to write a program needs the manual beside the includes it describes, and a
# doc one directory away from the thing it documents is a doc nobody opens. The build-plan docs
# (GP-BASIC.TIERS.md, GP-BASIC.PLAN.md) are deliberately NOT shipped -- they are the argument
# for how the library was built, not instructions for using it.
GPBASIC_DIR  = os.path.join(root, "GPC-BASIC")

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
    "To compile, run GPC.PRG (with GPC.BIN and the GPC.RT.nnn.BIN runtime\n"
    "beside it). To turn a runtime error's \"@ $XXXX\" into a source line, run\n"
    "GPC.ERR.PRG.\n"
    "The .BASL sources are never loaded at run time.\n"
    "\n"
    "BASLOAD is built into every R49 X16 ROM. To rebuild a PRG from its source,\n"
    "load the source with BASLOAD -- its own #SAVEAS writes the PRG back out:\n"
    "\n"
    '    BASLOAD "GPC.BASL"        (writes GPC.PRG)\n'
    '    BASLOAD "GPC.ERR.BASL"    (writes GPC.ERR.PRG)\n'
    "\n"
    "CAREFUL with the second one. The shipped GPC.ERR.PRG is the COMPILED helper;\n"
    "BASLOAD writes the plain interpreted version over that same name, so you would\n"
    "silently swap the fast tool for a slow one. It still works -- and it is in fact\n"
    "the version to use if the runtime is missing, since the compiled\n"
    "one needs it -- but re-extract from the zip to get the compiled helper back.\n"
)

names = []
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in RUNTIME:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing required file testing/%s -- build first" % name)
        z.write(full, name)
        names.append(name)
    for built, shipped in TOOLS:
        full = os.path.join(testing, built)
        if not os.path.isfile(full):
            raise SystemExit("release: missing tool testing/%s -- build first" % built)
        z.write(full, shipped)
        names.append(shipped)
    for name in SRCBASL:
        full = os.path.join(testing, name)
        if not os.path.isfile(full):
            raise SystemExit("release: missing source file testing/%s -- build first" % name)
        z.write(full, "SRC/" + name)
        names.append("SRC/" + name)
    z.writestr("SRC/README.TXT", SRC_README.replace("\n", "\r\n"))
    names.append("SRC/README.TXT")

    # The GP.BASIC library, whole. Sorted so the archive listing is stable between builds, and
    # a hard failure if the folder is missing -- a release quietly shipping without the library
    # would look complete and leave every #INCLUDE unresolvable.
    if not os.path.isdir(GPBASIC_DIR):
        raise SystemExit("release: GPC-BASIC/ is missing -- the GP.BASIC library ships with the release")
    for name in sorted(os.listdir(GPBASIC_DIR)):
        full = os.path.join(GPBASIC_DIR, name)
        if os.path.isfile(full):
            z.write(full, "GPC-BASIC/" + name)
            names.append("GPC-BASIC/" + name)

    # The manual and the global register are files in GPC-BASIC/ like any other, so the loop above
    # already took them -- but check, because shipping the library with no documentation is the
    # kind of omission that looks like a complete release.
    for must in ("GPC-BASIC/GP-BASIC.md", "GPC-BASIC/GP-BASIC.GLOBALS.md", "GPC-BASIC/README.md"):
        if must not in names:
            raise SystemExit("release: %s is missing -- the library ships with its documentation" % must)

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
