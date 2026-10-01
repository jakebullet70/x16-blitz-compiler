#
#   samplesbuild.py -- build every sample program the release ships, headlessly.
#
#   Usage:  samplesbuild.py                  build all of them
#           samplesbuild.py GPBMODS EDIT   build only the ones named
#           samplesbuild.py --list           print the table and stop
#
#   WHY IT TICKS.  build_basl.py and compile_shared.py each drive x16emu in warp and send
#   the emulator transcript to a LOG FILE, not to stdout, so a stage that is working prints
#   nothing for minutes at a time.  Streaming their output is therefore not enough on its
#   own: a heartbeat runs beside each stage and prints the elapsed time and the size of the
#   file the stage is writing, which is the one signal separating a slow compile from a
#   wedged one.
#
#   XBASE IS DELIBERATELY ABSENT.  It has a working build script, xbasebuild.py, and is
#   still built by hand; it is not part of a release because no database ships with it.
#
import os, re, shutil, subprocess, sys, threading, time

ROOT    = r"C:\dev\CmdrX16\dos_tools\x16-blitz-compiler"
GPCDIR  = os.path.join(ROOT, "source", "gpc")
GPCHOME = os.path.join(ROOT, "GPC-BASIC-TOOLS-SRC", "GPC")
ROOTABI = os.path.join(ROOT, "GPC-BASIC", "GPB.INC.BL")

#
#   One entry per program. Each builds in its src folder, which is the drive: its
#   #INCLUDEs name GPC-BASIC/, and the folder needs GPC.BIN beside the master.
#
#       src      the folder the master lives in, and its file name
#       shared   True compiles SHARED (needs GPB/GPC.RT.nnn.BIN at run time), False EMBEDDED
#       install  where the object goes and under what name -- None leaves it in the src
#                folder, which is already the drive its demo bat mounts
#       data     further files the install folder needs beside the object
#       overlay  False fails the build when the compile writes a .OVL. Default True
#
PROGRAMS = [
    #   EMBEDDED, so the object and its .OVL run with no runtime file beside them.
    dict(name="GPBMODS",
         src=("GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING", "GPBMODS.BASL"),
         shared=False, install=None, data=[]),

    dict(name="GPC.HELP",
         src=("GPC-BASIC-TOOLS-SRC/GPC-HELP", "GPC.HELP.BASL"),
         shared=True,
         install=("GPC-BASIC-TOOLS-SRC/GPC-HELP", "GPC.HELP.PRG"), data=["runtimes"]),

    #   EMBEDDED: the theme editor keeps its rows in scalars, so there is no
    #   GP.BANKEDSTR and no SHARED. It builds in the sample folder, which is the
    #   drive, and its modules are the GPC-BASIC copy sitting there.
    dict(name="COLORTST",
         src=("GPC-BASIC-TOOLS-SRC/color-test", "COLORTST.BASL"),
         shared=False,
         install=None, data=[]),

    #   EMBEDDED. The BMX images land in the sample folder, which is the drive bmx-demo.bat
    #   mounts.
    #   GPC-BASIC/BMXVIEW.EXP.BL is the downstream library copy of this master. Port a change
    #   into it by hand, with the GPC-BASIC/ include prefix dropped.
    dict(name="BMXVIEW",
         src=("GPC-BASIC-TOOLS-SRC/BMXVIEWER", "BMXVIEW.BASL"),
         shared=False,
         install=("GPC-BASIC-TOOLS-SRC/BMXVIEWER", "BMXVIEW.PRG"), data=["bmx"]),

    #   SHARED, and built in the sample folder: its #INCLUDEs name GPC-BASIC/ and the
    #   runtime and GPC.BIN are already beside it.  install=None leaves the object on
    #   that same drive, which is where its own bat mounts it from.
    dict(name="GPC.GUI",
         src=("GPC-BASIC-TOOLS-SRC/GPC-GUI-HELPER", "GPC.GUI.BASL"),
         shared=True,
         install=None, data=[]),

    #   EMBEDDED: the forked menus keep their rows in ordinary string arrays, so there is
    #   no GP.BANKEDSTR and no SHARED. It builds in the sample folder, which is the drive,
    #   and its GPB.INC.BL is the copy sitting there.
    dict(name="EDIT",
         src=("GPC-BASIC-TOOLS-SRC/edit", "EDIT.BASL"),
         shared=False,
         install=None, data=[]),

    #   SHARED, and built in the sample folder, which is the drive. The object is the
    #   helper you run beside a crashed program, so it installs into the GPC.HELP folder
    #   under the name that folder's documentation already gives it.
    #
    #   NO "runtimes": the GPC.HELP entry puts them in that folder.
    dict(name="GPC.ERR",
         src=("GPC-BASIC-TOOLS-SRC/GPC.ERR", "GPC.ERR.BASL"),
         shared=True,
         install=("GPC-BASIC-TOOLS-SRC/GPC-HELP", "GPC.ERR.PRG"), data=[]),

    #   EMBEDDED, and one PRG is the point of the sample: nothing in it may be banked.
    dict(name="GUI-LITE",
         src=("GPC-BASIC-TOOLS-SRC/GUI-LITE", "GUI-LITE.BASL"),
         shared=False,
         install=None, data=[], overlay=False),

    #   EMBEDDED, and plain X16 BASIC: MANDEL.SRC.PRG runs in ROM BASIC beside the compiled
    #   MANDEL.PRG, so the source may not use a GP keyword.
    dict(name="MANDEL",
         src=("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED", "MANDEL.BASL"),
         shared=False,
         install=None, data=[], overlay=False),

    #   EMBEDDED. The same picture with its inner loop in GP.ASM, beside MANDEL.
    dict(name="MANDELASM",
         src=("GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED", "MANDELASM.BASL"),
         shared=False,
         install=None, data=[], overlay=False),

    #   EMBEDDED, and plain X16 BASIC like MANDEL: LANDER64.SRC.PRG runs in ROM BASIC.
    dict(name="LANDER64",
         src=("GPC-BASIC-TOOLS-SRC/LANDER64", "LANDER64.BASL"),
         shared=False,
         install=None, data=[], overlay=False),

    #   EMBEDDED, and banked: the library runs from GP.BANKED regions, so the object
    #   ships with its .OVL beside it.
    dict(name="GUI-FIELD-EDIT",
         src=("GPC-BASIC-TOOLS-SRC/GUI-FIELD-EDIT", "GUI-FIELD-EDIT.BASL"),
         shared=False,
         install=None, data=[]),
]

BMX_SRC = os.path.join(ROOT, "GPC-BASIC-TOOLS-SRC", "BMXVIEWER", "SAMPLES")


class Ticker:
    #   Prints elapsed time and the size of each file the stage is writing, until stopped.
    #
    #   MORE THAN ONE FILE, because no single one moves throughout.  GPCCOMP.LOG stops at 285
    #   bytes as soon as the engine has echoed its banner and sits there for the whole compile,
    #   which reads exactly like a wedged emulator; the object is what grows after that. Size
    #   is not progress -- the banner is the finish line -- but a number that moves is the
    #   difference between a slow stage and a dead one.
    def __init__(self, tag, watch, every=10):
        self.tag = tag
        self.watch = watch if isinstance(watch, (list, tuple)) else [watch]
        self.every = every
        self.started = time.time()
        self.done = threading.Event()
        self.thread = threading.Thread(target=self._run, daemon=True)

    def _run(self):
        while not self.done.wait(self.every):
            secs = int(time.time() - self.started)
            sizes = []
            for w in self.watch:
                size = os.path.getsize(w) if os.path.exists(w) else 0
                sizes.append("%s %s" % (os.path.basename(w), format(size, ",")))
            print("   [%s] %d:%02d  %s"
                  % (self.tag, secs // 60, secs % 60, "   ".join(sizes)), flush=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.done.set()
        self.thread.join(timeout=1)
        print("   [%s] %.1fs" % (self.tag, time.time() - self.started), flush=True)


def run(cmd, tag, watch):
    #   -u so the child's prints arrive as they happen rather than in one lump at exit.
    print("   ---- " + " ".join(cmd[1:]), flush=True)
    with Ticker(tag, watch):
        p = subprocess.Popen([sys.executable, "-u"] + cmd, cwd=ROOT,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, errors="replace", bufsize=1)
        for line in p.stdout:
            line = line.rstrip()
            if line:
                print("   [%s] %s" % (tag, line), flush=True)
        return p.wait()


def check_abi(drive):
    #   GPB.INC.BL is the keyword ABI and root's copy is upstream. The build reads the
    #   sample folder's copy, and a stale one downgrades the build without an error.
    local = os.path.join(drive, "GPC-BASIC", "GPB.INC.BL")
    if not os.path.exists(local):
        return
    text = lambda path: open(path, "rb").read().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    if text(local) != text(ROOTABI):
        print("   WARNING: GPC-BASIC/GPB.INC.BL here differs from root's. Copy root's over it.",
              flush=True)


def install(prog, stem, drive):
    #   No install folder means the object already sits on the drive its demo bat mounts.
    if not prog["install"]:
        print("   stays in", prog["src"][0], flush=True)
        return

    folder, asname = prog["install"]
    dest = os.path.join(ROOT, *folder.split("/"))
    os.makedirs(dest, exist_ok=True)
    #   an in-place build compiled straight into its install folder
    same = os.path.normcase(os.path.abspath(drive)) == os.path.normcase(os.path.abspath(dest))
    if not (same and asname == stem + ".PRG"):
        shutil.copy(os.path.join(drive, stem + ".PRG"), os.path.join(dest, asname))
    print("   installed:", os.path.join(folder, asname), flush=True)

    for f in sorted(os.listdir(drive)):
        if f == stem + ".OVL":
            if not same:
                shutil.copy(os.path.join(drive, f), os.path.join(dest, f))
            print("   installed:", os.path.join(folder, f), flush=True)

    if "runtimes" in prog["data"]:
        #   The folder is its demo bat's whole drive, so /GPC/ is out of reach there.  The
        #   runtimes come from the tool home (make install) and replace any older build's.
        for old in os.listdir(dest):
            if old.endswith(".BIN") and (".RT." in old or ".RC." in old):
                os.remove(os.path.join(dest, old))
        for runtime in sorted(os.listdir(GPCHOME)):
            if runtime.endswith(".BIN") and ".RT." in runtime:
                shutil.copy(os.path.join(GPCHOME, runtime), os.path.join(dest, runtime))
                print("   installed:", os.path.join(folder, runtime), flush=True)

    if "bmx" in prog["data"]:
        count = 0
        for f in sorted(os.listdir(BMX_SRC)):
            if f.upper().endswith(".BMX"):
                shutil.copy(os.path.join(BMX_SRC, f), os.path.join(dest, f))
                count += 1
        print("   installed:", count, "BMX images into", folder, flush=True)


#   The source suffixes a master may carry, longest first so .EXP.BL wins over .BL.
SUFFIXES = (".EXP.BL", ".INC.BL", ".BASL", ".BL")


def stem_of(filename):
    #   The master's name with its source suffix removed.  NOT splitext twice: counting dots
    #   reduces GPC.HELP.BASL to GPC, the compiler is then asked for GPC.SRC.PRG, and the
    #   stage dies on an input the tokeniser never wrote.
    for suffix in SUFFIXES:
        if filename.upper().endswith(suffix):
            return filename[:-len(suffix)]
    return os.path.splitext(filename)[0]


#   A "BUILD nnn" literal anywhere in a master, and the three digits inside it.
BUILDNUM = re.compile(rb'("BUILD )(\d{3})(")')


def stamp_buildnum(prog):
    #   Bump the master's own build number, in the MASTER and not in the staged copy: a
    #   number that only ever appears on the drive leaves the source saying 001 forever,
    #   which is the confusion this is here to end.  Fixed at three digits so the string
    #   never changes length and the bank table it sits in never moves.  A master with no
    #   "BUILD nnn" literal is left alone -- this needs no entry in PROGRAMS.
    path = os.path.join(ROOT, *prog["src"][0].split("/"), prog["src"][1])
    text = open(path, "rb").read()
    if not BUILDNUM.search(text):
        return
    nextnum = [0]

    def bump(m):
        nextnum[0] = int(m.group(2)) % 999 + 1
        return m.group(1) + b"%03d" % nextnum[0] + m.group(3)

    #   read as bytes and written back as bytes, so the master's line endings survive
    open(path, "wb").write(BUILDNUM.sub(bump, text))
    print("   build number:", "%03d" % nextnum[0], flush=True)


def build(prog):
    name = prog["name"]
    stem = stem_of(prog["src"][1])
    print("=" * 70, flush=True)
    print("==", name, "(%s)" % ("SHARED" if prog["shared"] else "EMBEDDED"), flush=True)

    stamp_buildnum(prog)
    drive = os.path.join(ROOT, *prog["src"][0].split("/"))
    check_abi(drive)
    #   a changed .INC.BL is invisible to build_basl.py's up-to-date check
    junks = [stem + ".SRC.PRG", stem + ".PRG", stem + ".MAP", stem + ".SRC.SYM"]
    if not prog.get("overlay", True):
        junks.append(stem + ".OVL")
    for junk in junks:
        p = os.path.join(drive, junk)
        if os.path.exists(p):
            os.remove(p)

    started = time.time() - 2          # a small allowance for clock granularity

    src = os.path.join(drive, stem + ".SRC.PRG")
    if run([os.path.join(GPCDIR, "build_basl.py"), "--drive", drive,
            prog["src"][1], stem + ".SRC.PRG"], name, src):
        print("!! tokenise FAILED for", name, "-- nothing was compiled", flush=True)
        return False
    if not os.path.exists(src):
        print("!! tokenise produced nothing for", name, flush=True)
        return False
    print("   tokenised:", format(os.path.getsize(src), ","), "bytes", flush=True)

    #   THE EXIT STATUS IS THE ANSWER, not whether an output file turned up.  A stage that
    #   fails partway can still leave a plausible file behind; on 11th Sep 2026 one was
    #   taken for a good tokenise and handed to the compiler, which spent 420 seconds on it.
    cmd = [os.path.join(GPCDIR, "compile_shared.py"), "--drive", drive]
    if not prog["shared"]:
        cmd.append("--embedded")
    cmd += [stem + ".SRC.PRG", stem + ".PRG", stem + ".MAP"]
    rc = run(cmd, name, [os.path.join(drive, "GPCCOMP.LOG"),
                         os.path.join(drive, stem + ".PRG"),
                         os.path.join(drive, stem + ".MAP")])

    obj = os.path.join(drive, stem + ".PRG")
    if rc or not os.path.exists(obj):
        print("   -- compile FAILED; the real message is in",
              os.path.join(drive, "GPCCOMP.LOG"), flush=True)
        return False
    print("   compiled:", format(os.path.getsize(obj), ","), "bytes", flush=True)
    if not prog.get("overlay", True) and os.path.exists(os.path.join(drive, stem + ".OVL")):
        print("!!", name, "wrote", stem + ".OVL; it must be one PRG with nothing banked",
              flush=True)
        return False

    #   ONLY the overlay this build wrote.  A failed compile used to report the PREVIOUS
    #   build's overlays as if they were new.  There is one file, stem.OVL, holding every
    #   region of the program.
    for f in sorted(os.listdir(drive)):
        if f == stem + ".OVL":
            p = os.path.join(drive, f)
            fresh = os.path.getmtime(p) >= started
            print("   overlay", f, format(os.path.getsize(p), ","),
                  "" if fresh else "<-- STALE, not from this build", flush=True)

    install(prog, stem, drive)
    return True


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--list" in args:
        for p in PROGRAMS:
            print("%-10s %-42s %s" % (p["name"], "/".join(p["src"]),
                                      "SHARED" if p["shared"] else "EMBEDDED"))
        raise SystemExit(0)

    wanted = [a.upper() for a in args]
    known  = [p["name"] for p in PROGRAMS]
    unknown = [w for w in wanted if w not in known]
    if unknown:
        raise SystemExit("samplesbuild: unknown program(s): " + ", ".join(unknown))
    todo = [p for p in PROGRAMS if not wanted or p["name"] in wanted]

    began = time.time()
    failed = []
    for prog in todo:
        if not build(prog):
            failed.append(prog["name"])

    print("=" * 70, flush=True)
    print("== samples: %d built, %d failed, %.1fs total"
          % (len(todo) - len(failed), len(failed), time.time() - began))
    if failed:
        print("== FAILED:", ", ".join(failed))
        raise SystemExit(1)
