#!/bin/sh
# ***************************************************************************
#  release.sh -- build, stage and package a versioned release. POSIX; run from
#  Git Bash. Invoked by USER-RUNS/release.bat, or directly.
#
#     release.sh          build everything, stage release/TMP, then zip it
#     release.sh stage    stage release/TMP from the CURRENT build -- no rebuild,
#                         no zip. WIPES release/TMP and fills it again.
#     release.sh zip      zip release/TMP EXACTLY AS IT STANDS -- no rebuild, no
#                         restage. Hand edits in TMP survive and go in the zip.
#
#  THE STAGING FOLDER IS THE POINT. release/TMP holds the release unpacked, in the
#  shape the zip will have, so the layout can be read and corrected before anything
#  is packaged. Stage it, look at it, fix it, then zip from it. There is one build
#  file -- this one -- and the layout is defined once, in LAYOUT below.
#
#  The full build runs:
#     make libs                        the libraries + the compiler engine GPC.BIN
#     make release                     stage the engine + samples into source/drive/
#     make -C source/runtime gpc-rt    both shared runtimes and their bank code, GPB/GPC/GP1.RT.nnn.BIN
#     make -C source/gpc release       GPC.PRG + GPC.ERR (tokenised, then compiled)
#     source/gpc/samplesbuild.py       the sample programs, each tokenised then
#                                      compiled
#
#  THE SAMPLE BUILD COMES LAST because GPC.HELP and the others are compiled SHARED and
#  want the runtime that gpc-rt has just written. It is also the slow half: each program
#  drives the emulator twice, so samplesbuild.py streams its output and ticks every ten
#  seconds with the size of the file the running stage is writing. A stage that is
#  thinking and a stage that is wedged look different.
#
#  STAGING NEVER COMPILES. It takes whatever the last build left behind, and a program
#  with no compiled object gets a PLACEHOLDER PRG -- a two-line BASIC stub that prints
#  its own name and ends, so it cannot be mistaken for a build. MANIFEST.TXT in the
#  staged tree names every placeholder, and the zip step warns about any it ships.
#
#  The zip lands in release/ -- the release drop folder, kept apart from the daily
#  source/drive/ build cycle -- named gpc-release-<n>.zip. It is a git-ignored artifact, the
#  way the old source/drive/blitz.zip was; release/TMP is git-ignored too, and release/ itself
#  is tracked so the folder exists in a fresh clone.
# ***************************************************************************
set -e
cd "$(dirname "$0")"

MODE="${1:-full}"
case "$MODE" in
    full) DO_BUILD=1; DO_STAGE=1; DO_ZIP=1 ;;
    stage) DO_BUILD=0; DO_STAGE=1; DO_ZIP=0 ;;
    zip)  DO_BUILD=0; DO_STAGE=0; DO_ZIP=1 ;;
    *)    echo "release.sh: unknown mode '$MODE' -- use nothing, 'stage' or 'zip'"; exit 1 ;;
esac

if [ "$DO_BUILD" = 1 ]; then
    echo "== make libs =="
    make libs
    echo "== make release =="
    make release
    echo "== make -C source/runtime gpc-rt  (GPB/GPC/GP1.RT.nnn.BIN shared runtimes) =="
    make -C source/runtime gpc-rt
    echo "== make -C source/gpc release  (GPC.PRG + GPC.ERR, tokenised and compiled) =="
    make -C source/gpc release
    echo "== samplesbuild.py  (GPBMODS, GPC.HELP, COLORTST, BMXVIEW, GPC.GUI, EDIT, GPC.ERR, GUI-LITE, MANDEL, MANDELASM) =="
    python source/gpc/samplesbuild.py
fi

# zip(1) is not on a stock Windows box, so packaging goes through Python's stdlib --
# the same reason the rest of this tree's zipping does (see mkzip history).
DO_STAGE=$DO_STAGE DO_ZIP=$DO_ZIP python - <<'PY'
import os, shutil, struct, sys, zipfile

root    = os.getcwd()
drive = os.path.join(root, "source", "drive")
TMP     = os.path.join(root, "release", "TMP")

do_stage = os.environ.get("DO_STAGE") == "1"
do_zip   = os.environ.get("DO_ZIP")   == "1"

# The PRODUCT VERSION lives in ONE place: source/application/buildnum.txt, e.g. "1.0.0". It is
# what GPC.BIN prints (as V1.0.0) and what names the zip, and it is edited by hand when a
# release is cut -- nothing bumps it. It used to be VERSION$ in source/drive/GPC.BASL, which tracked
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

# The runtime's file name carries the runtime build number; import the one definition of it.
sys.path.insert(0, os.path.join(root, "source", "runtime", "scripts"))
from rtname import rt_filename, rc_filename, bank_filename  # noqa: E402
# ...and the runtime IMAGE's two names likewise, from the script that installs them.
sys.path.insert(0, os.path.join(root, "source", "application", "scripts"))
from genrtimage import imageName, bankImageName     # noqa: E402

# ===========================================================================
#  THE LAYOUT -- what a release is, in one place
# ===========================================================================
#
#  release/TMP/
#     GPC.PRG GPC.BIN GPC/GP1.IMG.nnn.BIN  the compiler
#     GPB/GPC/GP1.RT.nnn.BIN               both shared runtimes and their bank code
#     GPC.ERR.PRG  GPC.HELP.PRG            the two companion programs
#     BASLOAD-GPC.PRG BASLOAD-GPC.BIN      the streaming tokeniser
#     README.md LICENSE MANIFEST.TXT
#     HELP-TXT/       the help viewer's index and topics
#     GPC-BASIC/      the GP.BASIC library, whole, with its manual
#     SRC/            source. Nothing under it is needed to run GPC.
#        GPC/           GPC.BASL and the one module it includes
#        GPC-ERROR/     GPC.ERR.BASL and the 22 modules it includes
#        GPC-HELP/      GPC.HELP.BASL, the 13 modules it includes and its help content
#        GPC-BASLOAD/   the tokeniser, its documents and its source as one zip
#     SAMPLES/<PROG>/ one folder per sample program
#
#  WARNING: one folder a tool under SRC/, and each carries its own copy of every module
#  its source #INCLUDEs. BASLOAD resolves an #INCLUDE against the folder it runs in, so
#  GPC-BASIC/ at the release root is out of reach from inside SRC/. A source folder
#  without its modules looks complete and cannot be rebuilt. The copies are the ones the
#  shipped object was built from, not the library masters.
#
#  Every sample is EMBEDDED, so a sample folder needs nothing from the drive root. A region
#  overlay (NAME.OVL) is LOADed from BESIDE THE PROGRAM. A SHARED object fetches its runtime
#  from the DRIVE ROOT with a LEADING SLASH (bootstrap.asm:285), which works from any
#  depth. SHARED vs EMBEDDED is not a preference: a SHARED object carries no runtime and
#  asks for GPB.RT.nnn.BIN when it uses a GP keyword and GPC.RT.nnn.BIN when it does not.
#  The choice is made at compile time and flips silently, so BOTH runtimes ship, and either
#  one loads GP1.RT.nnn.BIN, the bank code, from the same place.
#
#  The help content folder keeps the name HELP-TXT. The viewer opens its files as
#  //HELP-TXT/:NAME (GPC.HELP.BASL:218), so the name is not ours to choose here.
#
#  GPC.INPUT (the control-file template) is deliberately NOT shipped: GPC.PRG drives the
#  compile interactively, and the file is per-user state (git-ignored in source/drive/).

# The root. GPC.PRG and GPC.HELP.PRG are both compiled SHARED, so they want
# GPB.RT.nnn.BIN beside them -- which is this same root, two lines up.
#
#   GPC.PRG         the front end you launch on the X16 -- a COMPILED program, because
#                   GPC.BASL is written in GP.BASIC. BASLOAD tokenises it to GPC.SRC.PRG
#                   (compile-only, not shipped) and GPC.BIN compiles that into this.
#   GPC.BIN         the compiler engine GPC.PRG chain-loads
#   GPC.IMG.nnn.BIN the runtime every self-contained object carries, streamed into it as
#                   the object is written. GPC.BIN CANNOT COMPILE WITHOUT IT -- the runtime
#                   used to live inside the engine and moved out so that the object buffer
#                   could have the low RAM. Build-numbered like the shared runtimes, and
#                   for the same reason: a stale one under a fixed name would still be found.
#   GP1.IMG.nnn.BIN the bank code built with that image, which a self-contained object carries
#                   after its p-code and copies to bank 1 as it starts. It jumps into the
#                   image at fixed addresses, so the two install together from one link.
#   GPC.ERR.PRG     the error-address-to-line helper. Built in GPC-BASIC-TOOLS-SRC/GPC.ERR/, which is
#                   its own emulator drive, and compiled SHARED, so it wants the same
#                   runtime beside it as any other compiled program. The tokenised source
#                   is NOT shipped -- it is compile input, and could not be run in any case.
#   GPC.ERR.OVL     the banked half of that helper, its region overlay. It is not optional:
#                   GPC.ERR.PRG reads it by name as it starts and stops without it.
#   GPC.HELP.PRG    the on-machine reference -- the manual, the globals register and the
#                   file list, readable on the X16. Compiled SHARED. It reads
#                   HELP-TXT/GPC.HELP.IDX beside it.
#   GPC.HELP.OVL    the banked half of the reference, its region overlay. It is not
#                   optional: the program reads it as it starts and stops without it.
#                   WARNING: the overlay name is compiled into GPC.HELP.PRG, so neither
#                   file can be renamed here.
#   BASLOAD-GPC.PRG the streaming tokeniser, the same pair SRC/GPC-BASLOAD/ ships with its
#   BASLOAD-GPC.BIN source. It writes as it reads, so a source is not bounded by BASIC RAM
#                   the way the ROM's BASLOAD is.
ROOTFILES = [
    ("source/drive/GPC.PRG",                     "GPC.PRG"),
    ("source/drive/GPC.BIN",                     "GPC.BIN"),
    ("source/drive/" + imageName(),              imageName()),
    ("source/drive/" + bankImageName(),          bankImageName()),
    ("source/drive/" + rt_filename(),            rt_filename()),
    ("source/drive/" + rc_filename(),            rc_filename()),
    ("source/drive/" + bank_filename(),          bank_filename()),
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/GPC.ERR.PRG",         "GPC.ERR.PRG"),
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/GPC.ERR.OVL",         "GPC.ERR.OVL"),
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/GPC.HELP.PRG",       "GPC.HELP.PRG"),
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/GPC.HELP.OVL",       "GPC.HELP.OVL"),
    ("BASLOAD-GPC/build/BASLOAD-GPC.PRG",       "BASLOAD-GPC.PRG"),
    ("BASLOAD-GPC/build/BASLOAD-GPC.BIN",       "BASLOAD-GPC.BIN"),
    ("README.md",                           "README.md"),
    ("LICENSE",                             "LICENSE"),
]

# A shipped readme serves the repo and the release. Everything from this line on is for the
# source tree, and the staged copy stops above it. The root README.md and the MANDELBROT-SPEED
# readme carry one.
README_CUT = "<!-- release: the rest is for the source tree -->"

# The GP.BASIC library ships whole, straight from the repo master rather than from source/drive/ --
# source/drive/ holds only the staged copies of whatever was last built there, and they are
# git-ignored precisely so they cannot be mistaken for the masters.
#
# Its two reference docs LIVE in GPC-BASIC/ rather than in a docs folder of their own, so the
# repo and the zip have the same shape and a relative link works in both. They used to be copied
# in from docs/blitz/, which meant README.md's own links were correct in the repo and broken for
# every release user -- and the release user is the one who cannot go and find the file. The
# build-plan docs (GP-BASIC.TIERS.md, GP-BASIC.PLAN.md) are deliberately NOT shipped: they are
# the argument for how the library was built, not instructions for using it.
TREES = [
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/HELP-TXT",   "HELP-TXT"),
    ("GPC-BASIC",                   "GPC-BASIC"),
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/GPC-BASIC",   "SRC/GPC-ERROR/GPC-BASIC"),
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/GPC-BASIC",  "SRC/GPC-HELP/GPC-BASIC"),
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/HELP-TXT",   "SRC/GPC-HELP/HELP-TXT"),
]

# GPC.ERR's source, whole and rebuildable. Its #INCLUDE lines name GPC-BASIC/ for the 20
# library modules, so they sit in a folder of that name beside the source. They are the sample
# folder's copies rather than the library masters: those are what the shipped object was built
# from. ERRTOKEN and ERRSRC are GPC.ERR's own and sit beside the source.
GPCERR_SRC = [
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/GPC.ERR.BASL",    "SRC/GPC-ERROR/GPC.ERR.BASL"),
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/ERRTOKEN.INC.BL", "SRC/GPC-ERROR/ERRTOKEN.INC.BL"),
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/ERRSRC.INC.BL",   "SRC/GPC-ERROR/ERRSRC.INC.BL"),
    ("GPC-BASIC-TOOLS-SRC/GPC.ERR/readme.md",       "SRC/GPC-ERROR/README.md"),
]

# GPC.HELP's source, the same shape as GPC-ERROR, with the help content it was built beside.
# GPC-HELP.md is the whole reference as one document, rendered from the same source.
GPCHELP_SRC = [
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/GPC.HELP.BASL", "SRC/GPC-HELP/GPC.HELP.BASL"),
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/GPC-HELP.md",   "SRC/GPC-HELP/GPC-HELP.md"),
    ("GPC-BASIC-TOOLS-SRC/GPC-HELP/readme.md",     "SRC/GPC-HELP/README.md"),
]

# The tokeniser: the runnable pair, the ROM image for anyone flashing it in, and its two
# documents. Its assembly source goes in as ONE zip rather than a loose tree -- it is
# reference material, and four .inc files at this level would read like something the
# release needs.
BASLOAD_FILES = [
    ("BASLOAD-GPC/build/BASLOAD-GPC.BIN",   "SRC/GPC-BASLOAD/BASLOAD-GPC.BIN"),
    ("BASLOAD-GPC/build/BASLOAD-GPC.PRG",   "SRC/GPC-BASLOAD/BASLOAD-GPC.PRG"),
    ("BASLOAD-GPC/build/basload-rom.bin",   "SRC/GPC-BASLOAD/basload-rom.bin"),
    ("BASLOAD-GPC/README.md",               "SRC/GPC-BASLOAD/README.md"),
    ("BASLOAD-GPC/RESEARCH.md",             "SRC/GPC-BASLOAD/RESEARCH.md"),
]
BASLOAD_SRC_DIR = "BASLOAD-GPC/src"
BASLOAD_SRC_ZIP = "SRC/GPC-BASLOAD/BASLOAD-SRC.ZIP"

# The front end's source folder, the same shape as GPC-ERROR. GPC.BASL #INCLUDEs one
# module by bare name, so GPB.INC.BL sits beside it. Both come from source/drive/, which
# is where the front end is edited and where the shipped GPC.PRG was compiled.
SRCBASL = [("source/drive/GPC.BASL",        "GPC/GPC.BASL"),
           ("source/drive/GPB.INC.BL",      "GPC/GPB.INC.BL")]

# One folder per sample. "fake" names the one file worth stubbing when it is not there --
# the program itself. The one glob is the BMX images, whose count follows the source.
#
# WARNING: a region overlay is named NAME.OVL and the program reads that literal as it
# starts. It is not optional and it cannot be renamed.
SAMPLES = [
    {
        "dir":   "GPBMODS",
        "files": [("GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.PRG",   "GPBMODS.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.OVL",   "GPBMODS.OVL"),
                  ("GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.BASL",  "GPBMODS.BASL"),
                  ("GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPB-MENUS.BASL", "GPB-MENUS.BASL")],
        "globs": [],
        "fake":  "GPBMODS.PRG",
    },
    {
        "dir":   "BMXVIEW",
        "files": [("GPC-BASIC-TOOLS-SRC/BMXVIEWER/BMXVIEW.PRG",      "BMXVIEW.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/BMXVIEWER/BMXVIEW.BASL",    "BMXVIEW.BASL")],
        "globs": [("GPC-BASIC-TOOLS-SRC/BMXVIEWER/SAMPLES", lambda n: n.upper().endswith(".BMX"))],
        "fake":  "BMXVIEW.PRG",
    },
    {
        "dir":   "COLORTST",
        "files": [("GPC-BASIC-TOOLS-SRC/color-test/COLORTST.PRG",        "COLORTST.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/color-test/COLORTST.BASL",       "COLORTST.BASL")],
        "globs": [],
        "fake":  "COLORTST.PRG",
    },
    {
        "dir":   "GUI-LITE",
        "files": [("GPC-BASIC-TOOLS-SRC/GUI-LITE/GUI-LITE.PRG",          "GUI-LITE.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/GUI-LITE/GUI-LITE.BASL",         "GUI-LITE.BASL")],
        "globs": [],
        "fake":  "GUI-LITE.PRG",
    },
    {
        "dir":   "MANDELBROT-SPEED",
        "files": [("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/MANDEL.SRC.PRG",  "MANDEL.SRC.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/MANDEL.PRG",      "MANDEL.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/MANDELASM.PRG",   "MANDELASM.PRG"),
                  ("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/MANDEL.BASL",     "MANDEL.BASL"),
                  ("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/MANDELASM.BASL",  "MANDELASM.BASL"),
                  ("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/readme.md",       "README.md")],
        "globs": [],
        "fake":  "MANDELASM.PRG",
    },
]

# THE DEVELOPER'S OWN FILES -- STAGED, NEVER SHIPPED.
# XFMGR is the file manager the staged drive is navigated with, and XT is the 28-byte BASIC
# shim that LOADs it ("/XFMGR/XFMGR.PRG"). tmp-emu.bat boots release/TMP and wants them there.
# The zip step SKIPS every path under these names -- see DEV_PREFIXES below, which is what
# actually enforces it, so the rule cannot be lost by being remembered wrongly.
DEV_ONLY = [
    ("source/drive/XT",    "XT"),         # a file
    ("source/drive/XFMGR", "XFMGR"),      # a folder, staged whole
]
DEV_PREFIXES = ("XT", "XFMGR/")

# MANIFEST.TXT is a record of the STAGING, not of the release: it names where every file
# came from, and it lists the dev-only files that the zip does not contain. Shipping it
# would hand a release user an index to things that are not in their download. It stays
# in release/TMP and is left out of the zip along with the dev-only files.
NOT_SHIPPED = DEV_PREFIXES + ("MANIFEST.TXT",)

SRC_README = (
    "GPC SRC folder (source, not needed to run)\n"
    "==========================================\n"
    "\n"
    "This folder holds the GP.BASIC source of the GPC tools, one folder per tool.\n"
    "It is here for reference only. Nothing in this folder is needed to run GPC.\n"
    "The ready-to-run programs are in the parent folder.\n"
    "\n"
    "    SRC/\n"
    "      README.TXT            this file\n"
    "      GPC/\n"
    "        GPC.BASL            the compiler front end\n"
    "        GPB.INC.BL          the one module it includes\n"
    "      GPC-ERROR/\n"
    "        GPC.ERR.BASL        the error-line helper\n"
    "        ERRTOKEN.INC.BL     its keyword text\n"
    "        ERRSRC.INC.BL       its source reader\n"
    "        README.md           its own notes\n"
    "        GPC-BASIC/          the 20 library modules it includes\n"
    "      GPC-HELP/\n"
    "        GPC.HELP.BASL       the on-machine reference viewer\n"
    "        README.md           its own notes\n"
    "        GPC-BASIC/          the 13 modules it includes\n"
    "        HELP-TXT/           the help content it reads\n"
    "        GPC-HELP.md         the same reference as one document\n"
    "      GPC-BASLOAD/\n"
    "        BASLOAD-GPC.PRG     the tokeniser front end\n"
    "        BASLOAD-GPC.BIN     the tokeniser engine\n"
    "        basload-rom.bin     the ROM image, for anyone flashing it in\n"
    "        README.md\n"
    "        RESEARCH.md\n"
    "        BASLOAD-SRC.ZIP     the tokeniser's own 64tass source\n"
    "\n"
    "BASLOAD resolves an #INCLUDE against the folder it runs in. GPC-BASIC/ at the\n"
    "release root is out of reach from inside SRC/, so each source folder carries\n"
    "its own copies of the modules. Go into the tool's folder first, then run\n"
    "BASLOAD there.\n"
    "\n"
    "GPC.BASL has one include line, #INCLUDE \"GPB.INC.BL\", a bare name with no\n"
    "folder. GPC.ERR.BASL has 22 and GPC.HELP.BASL has 13, each naming a module\n"
    "in GPC-BASIC/, as in #INCLUDE \"GPC-BASIC/GPB.INC.BL\".\n"
    "The module copies here are the ones the shipped objects were compiled from,\n"
    "not the library masters.\n"
    "\n"
    "All three tools are written in GP.BASIC. Rebuilding one takes two steps, and\n"
    "BASLOAD does only the first. BASLOAD is built into every R49 ROM. The parent\n"
    "folder also ships BASLOAD-GPC.PRG, which writes its output as it reads, so a\n"
    "source is not bounded by BASIC RAM. Its own source is in SRC/GPC-BASLOAD/.\n"
    "Each source carries its own #SAVEAS, so BASLOAD names the output itself:\n"
    "\n"
    "    in SRC/GPC/         BASLOAD \"GPC.BASL\"       writes GPC.SRC.PRG\n"
    "    in SRC/GPC-ERROR/   BASLOAD \"GPC.ERR.BASL\"   writes GPC.ERR.SRC.PRG\n"
    "    in SRC/GPC-HELP/    BASLOAD \"GPC.HELP.BASL\"  writes GPC.HELP.SRC.PRG\n"
    "\n"
    "The @: in each #SAVEAS means overwrite. Each output is written into its own\n"
    "folder, beside its source. None of the three can overwrite a shipped program\n"
    "in the parent folder.\n"
    "\n"
    "What BASLOAD writes cannot be run. No BASIC code sits behind the GP tokens,\n"
    "so the ROM can neither LIST nor RUN those files. They are input for the\n"
    "compiler. The second step is to compile that output with GPC. The shipped\n"
    "GPC.PRG, GPC.ERR.PRG and GPC.HELP.PRG are already compiled.\n"
    "\n"
    "To compile, run GPC.PRG. It needs GPC.BIN, the GPC.IMG.nnn.BIN and\n"
    "GP1.IMG.nnn.BIN images, and the GPB.RT.nnn.BIN, GPC.RT.nnn.BIN and\n"
    "GP1.RT.nnn.BIN runtime files beside it. All of those are in the parent folder.\n"
    "\n"
    "GPC.ERR.PRG turns the \"@ $XXXX\" of a runtime error into a source line. It\n"
    "needs GPC.ERR.OVL beside it. GPC.HELP.PRG needs GPC.HELP.OVL and the HELP-TXT/\n"
    "folder beside it. The .BASL sources are never loaded at run time.\n"
    "\n"
    "GPC.BIN compiles without a front end, so a broken GPC.PRG does not stop a\n"
    "compile. GPC.BIN reads a file called GPC.INPUT straight off the drive. Write\n"
    "the source name, the object name and a blank line into it with any editor,\n"
    "then RUN GPC.BIN. Driving the compiler is all the front end does.\n"
)

# ===========================================================================
#  STAGE
# ===========================================================================
staged       = []      # (path in TMP, where it came from)
placeholders = []      # paths in TMP that are stubs, not builds
missing      = []      # absent, and no stub made


def fake_prg(name):
    """A runnable BASIC stub, not an empty file.

    A zero-byte PRG under a real program's name cannot be told apart from a build that
    half worked. This one LOADs and RUNs and says what it is, so nobody spends an
    afternoon on it. Two lines: the message, then END."""
    load  = 0x0801
    text  = '"' + name + " NOT BUILT -- PLACEHOLDER" + '"'
    lines = [(10, bytes([0x99]) + text.encode("ascii")),        # PRINT "..."
             (20, bytes([0x80]))]                               # END
    out, addr = b"", load
    for num, toks in lines:
        rec   = toks + b"\x00"
        addr  = addr + 4 + len(rec)
        out  += struct.pack("<HH", addr, num) + rec
    return struct.pack("<H", load) + out + b"\x00\x00"


def put(src_rel, dst_rel):
    """Copy one file in. True if a real file landed."""
    src = os.path.join(root, *src_rel.split("/"))
    dst = os.path.join(TMP, *dst_rel.split("/"))
    if not os.path.isfile(src):
        return False
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    staged.append((dst_rel, src_rel))
    return True


def stub(dst_rel):
    dst = os.path.join(TMP, *dst_rel.split("/"))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "wb") as f:
        f.write(fake_prg(os.path.basename(dst_rel)))
    staged.append((dst_rel, "(placeholder)"))
    placeholders.append(dst_rel)


def put_tree(src_dir_rel, dst_dir_rel):
    """Copy a folder in, recursively. Returns the file count."""
    src_dir = os.path.join(root, *src_dir_rel.split("/"))
    if not os.path.isdir(src_dir):
        missing.append(src_dir_rel + "/  (whole folder)")
        return 0
    n = 0
    for name in sorted(os.listdir(src_dir)):
        full = os.path.join(src_dir, name)
        if os.path.isfile(full):
            put(src_dir_rel + "/" + name, dst_dir_rel + "/" + name)
            n += 1
        elif os.path.isdir(full):
            n += put_tree(src_dir_rel + "/" + name, dst_dir_rel + "/" + name)
    return n


def cut_readme(dst_rel):
    """Stop a staged readme at README_CUT. False if it has no cut line."""
    readme = os.path.join(TMP, *dst_rel.split("/"))
    with open(readme, encoding="utf-8", newline="") as f:
        text = f.read()
    cut = text.find(README_CUT)
    if cut < 0:
        return False
    with open(readme, "w", encoding="utf-8", newline="") as f:
        f.write(text[:cut].rstrip() + ("\r\n" if "\r\n" in text else "\n"))
    return True


if do_stage:
    if os.path.isdir(TMP):
        print("release: wiping release/TMP")
        shutil.rmtree(TMP)
    os.makedirs(TMP)

    for src_rel, dst_rel in ROOTFILES:
        if not put(src_rel, dst_rel):
            if dst_rel.upper().endswith(".PRG"):
                stub(dst_rel)
            else:
                missing.append(src_rel)

    if os.path.isfile(os.path.join(TMP, "README.md")) and not cut_readme("README.md"):
        print("release: WARNING -- README.md has no cut line, so it ships whole")

    for src_dir_rel, dst_dir_rel in TREES:
        print("release: %-12s -- %d files" % (dst_dir_rel + "/", put_tree(src_dir_rel, dst_dir_rel)))

    # The library must be there, and it must have its documentation. A release quietly
    # shipping without the library would look complete and leave every #INCLUDE dangling.
    have = set(d for d, _ in staged)
    for must in ("GPC-BASIC/GP-BASIC.md", "GPC-BASIC/GP-BASIC.GLOBALS.md", "GPC-BASIC/README.md"):
        if must not in have:
            raise SystemExit("release: %s is missing -- the library ships with its documentation" % must)

    for src_rel, dst_rel in BASLOAD_FILES:
        if not put(src_rel, dst_rel):
            missing.append(src_rel)

    src_dir = os.path.join(root, *BASLOAD_SRC_DIR.split("/"))
    if os.path.isdir(src_dir):
        zpath = os.path.join(TMP, *BASLOAD_SRC_ZIP.split("/"))
        os.makedirs(os.path.dirname(zpath), exist_ok=True)
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for name in sorted(os.listdir(src_dir)):
                full = os.path.join(src_dir, name)
                if os.path.isfile(full):
                    z.write(full, "src/" + name)
        staged.append((BASLOAD_SRC_ZIP, BASLOAD_SRC_DIR + "/*"))
    else:
        missing.append(BASLOAD_SRC_DIR)

    for src_rel, dst_rel in GPCERR_SRC + GPCHELP_SRC:
        if not put(src_rel, dst_rel):
            missing.append(src_rel)

    for src_rel, name in SRCBASL:
        if not put(src_rel, "SRC/" + name):
            missing.append(src_rel)
    os.makedirs(os.path.join(TMP, "SRC"), exist_ok=True)
    with open(os.path.join(TMP, "SRC", "README.TXT"), "w", newline="") as f:
        f.write(SRC_README.replace("\n", "\r\n"))
    staged.append(("SRC/README.TXT", "(generated)"))

    for prog in SAMPLES:
        base = "SAMPLES/" + prog["dir"]
        for src_rel, name in prog["files"]:
            if not put(src_rel, base + "/" + name):
                if name == prog["fake"]:
                    stub(base + "/" + name)
                else:
                    missing.append(src_rel)
            elif name == "README.md":
                cut_readme(base + "/" + name)
        for folder, keep in prog["globs"]:
            full_dir = os.path.join(root, *folder.split("/"))
            if not os.path.isdir(full_dir):
                missing.append(folder + "/  (glob source)")
                continue
            for name in sorted(os.listdir(full_dir)):
                if keep(name) and os.path.isfile(os.path.join(full_dir, name)):
                    put(folder + "/" + name, base + "/" + name)

    dev = []
    for src_rel, dst_rel in DEV_ONLY:
        src = os.path.join(root, *src_rel.split("/"))
        if os.path.isdir(src):
            n = put_tree(src_rel, dst_rel)
            dev.append("%s/ (%d files)" % (dst_rel, n))
        elif put(src_rel, dst_rel):
            dev.append(dst_rel)
        else:
            missing.append(src_rel + "  (dev only)")
    if dev:
        print("release: DEV ONLY, staged but never zipped -- %s" % ", ".join(dev))

    # MANIFEST.TXT -- every file, and where it came from. It is the record that survives
    # someone opening the folder a week later with no memory of this run.
    lines = ["GPC RELEASE STAGING -- release/TMP", "=" * 34, "",
             "Every file in this tree, and where it came from. A source of (placeholder)",
             "is a BASIC stub, NOT a compiled program -- it prints its own name and ends.",
             "A file marked DEV ONLY is staged for local use and is NOT put in the zip.",
             ""]
    for dst_rel, src_rel in sorted(staged):
        full = os.path.join(TMP, *dst_rel.split("/"))
        tag  = "   DEV ONLY" if dst_rel.startswith(DEV_PREFIXES) else ""
        lines.append("%-44s %9d  %s%s" % (dst_rel, os.path.getsize(full), src_rel, tag))
    if placeholders:
        lines += ["", "PLACEHOLDERS -- NOT BUILT (%d):" % len(placeholders)]
        lines += ["    " + p for p in placeholders]
    if missing:
        lines += ["", "MISSING, no stub made (%d):" % len(missing)]
        lines += ["    " + m for m in missing]
    with open(os.path.join(TMP, "MANIFEST.TXT"), "w", newline="") as f:
        f.write("\r\n".join(lines) + "\r\n")

    total = sum(os.path.getsize(os.path.join(TMP, *d.split("/"))) for d, _ in staged)
    print("release: staged %d files, %d bytes into release/TMP" % (len(staged) + 1, total))
    if placeholders:
        print("release: %d PLACEHOLDER(S): %s" % (len(placeholders), ", ".join(placeholders)))
    if missing:
        print("release: %d MISSING: %s" % (len(missing), ", ".join(missing)))

# ===========================================================================
#  ZIP -- release/TMP exactly as it stands, minus the developer's own files
# ===========================================================================
if do_zip:
    if not os.path.isdir(TMP):
        raise SystemExit("release: release/TMP does not exist -- run ./release.sh stage first")

    out   = os.path.join(root, "release", "gpc-release-%s.zip" % version)
    names = []
    skipped = []
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, dirnames, filenames in os.walk(TMP):
            dirnames.sort()
            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                rel  = os.path.relpath(full, TMP).replace(os.sep, "/")
                if rel.startswith(NOT_SHIPPED):
                    skipped.append(rel)
                    continue
                z.write(full, rel)
                names.append(rel)

    # A placeholder in a shipped zip is not fatal -- staging deliberately allows one so the
    # layout can be worked on before everything is built -- but it must never be quiet.
    # Stubs are found by READING THE FILE, not from the staging run: "release.sh zip" is
    # the mode most likely to ship one, and it is the mode that did no staging.
    shipped_stubs = []
    for n in names:
        if not n.upper().endswith(".PRG"):
            continue
        with open(os.path.join(TMP, *n.split("/")), "rb") as f:
            if b"NOT BUILT -- PLACEHOLDER" in f.read(128):
                shipped_stubs.append(n)
    print("release/%s  v%s  (%d files, %d bytes)"
          % (os.path.basename(out), version, len(names), os.path.getsize(out)))
    for n in names:
        print("   ", n)
    if skipped:
        print("release: %d file(s) left out of the zip: %s"
              % (len(skipped), ", ".join(sorted(set(p.split("/")[0] for p in skipped)))))
    if shipped_stubs:
        print("release: WARNING -- this zip ships %d PLACEHOLDER(S), not real builds:"
              % len(shipped_stubs))
        for n in shipped_stubs:
            print("   ", n)
PY

echo
echo "== RELEASE OK =="
