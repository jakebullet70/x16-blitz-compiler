#
#   samplesbuild.py -- build every sample program the release ships, headlessly.
#
#   Usage:  samplesbuild.py                  build all of them
#           samplesbuild.py GPBMODS EDITOR   build only the ones named
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
import os, shutil, subprocess, sys, threading, time

ROOT    = r"C:\dev\CmdrX16\dos_tools\x16-blitz-compiler"
TESTING = os.path.join(ROOT, "testing")
GPCDIR  = os.path.join(ROOT, "source", "gpc")
ROOTLIB = os.path.join(ROOT, "GPC-BASIC")

#
#   One entry per program.
#
#       src      the folder the master lives in, and its file name
#       lib      the module folder that is upstream for this program's .INC.BL files
#       extras   further sources included inline, which BASLOAD resolves off the drive
#       shared   True compiles SHARED (needs GPB/GPC.RT.nnn.BIN at run time), False EMBEDDED
#       install  where the object goes and under what name -- None leaves it in testing\,
#                which is already the drive its demo bat mounts
#       data     further files the install folder needs beside the object
#
PROGRAMS = [
    dict(name="GPBMODS",
         src=("samples/GPB-MODS-TESTING", "GPBMODS.BASL"),
         lib="samples/GPB-MODS-TESTING/GPC-BASIC",
         extras=[], shared=True, install=None, data=[]),

    dict(name="GPB.HELP",
         src=("samples/GPC-HELP", "GPB.HELP.BASL"),
         lib="samples/GPC-HELP/GPC-BASIC",
         extras=[], shared=True,
         install=("samples/GPC-HELP", "GPB.HELP.PRG"), data=["runtimes"]),

    dict(name="COLORTST",
         src=("samples/color-test", "COLORTST.BASL"),
         lib="samples/color-test/GPC-BASIC",
         extras=[], shared=True, install=None, data=[]),

    #   The GP.BASIC viewer, whose master is in the library rather than in a sample folder.
    #   EMBEDDED: bmx-demo.bat mounts demo\, which carries no runtime and never has.
    dict(name="BMXVIEW",
         src=("GPC-BASIC", "BMXVIEW.EXP.BL"),
         lib="GPC-BASIC",
         extras=[], shared=False,
         install=("demo", "C.BMXVIEW.PRG"), data=["bmx"]),

    #   EMBEDDED, per step 2 of samples\editor\readme.md -- its drive is the sample folder.
    dict(name="EDITOR",
         src=("samples/editor", "EDITOR.BASL"),
         lib="samples/editor/GPC-BASIC",
         extras=["ED-MENUS.BASL", "ED-STORE.BASL"], shared=False,
         install=("samples/editor", "C.EDITOR.PRG"), data=[]),
]

BMX_SRC = os.path.join(ROOT, "samples", "BMXVIEWER", "SAMPLES")


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


def stage_sources(prog):
    #   the program's own module folder is upstream for every .INC.BL it holds...
    lib = os.path.join(ROOT, *prog["lib"].split("/"))
    for f in os.listdir(lib):
        if f.endswith(".INC.BL"):
            shutil.copy(os.path.join(lib, f), os.path.join(TESTING, f))
    #   ...and the keyword file is ROOT's, always -- a sample copy silently downgrades it
    shutil.copy(os.path.join(ROOTLIB, "GPB.INC.BL"), os.path.join(TESTING, "GPB.INC.BL"))

    srcdir = os.path.join(ROOT, *prog["src"][0].split("/"))
    shutil.copy(os.path.join(srcdir, prog["src"][1]), os.path.join(TESTING, prog["src"][1]))
    for extra in prog["extras"]:
        shutil.copy(os.path.join(srcdir, extra), os.path.join(TESTING, extra))


def install(prog, stem):
    #   No install folder means the object already sits on the drive its demo bat mounts.
    if not prog["install"]:
        print("   stays in testing\\", flush=True)
        return

    folder, asname = prog["install"]
    dest = os.path.join(ROOT, *folder.split("/"))
    os.makedirs(dest, exist_ok=True)
    shutil.copy(os.path.join(TESTING, stem + ".PRG"), os.path.join(dest, asname))
    print("   installed:", os.path.join(folder, asname), flush=True)

    for f in sorted(os.listdir(TESTING)):
        if f.startswith(stem + ".B") and f[len(stem) + 2:].isdigit():
            shutil.copy(os.path.join(TESTING, f), os.path.join(dest, f))
            print("   installed:", os.path.join(folder, f), flush=True)

    if "runtimes" in prog["data"]:
        #   A SHARED object asks the drive ROOT for GPB.RT.nnn.BIN when it uses a GP keyword
        #   and GPC.RT.nnn.BIN when it does not (bootstrap.asm:285).  Both are copied: the
        #   choice is made at compile time and flips silently.  nnn moves whenever
        #   rtbuild.txt does, so any older one here is cleared first rather than left to be
        #   found by a program that no longer matches it.
        for old in os.listdir(dest):
            if old.endswith(".BIN") and (".RT." in old or ".RC." in old):
                os.remove(os.path.join(dest, old))
        found = 0
        for f in sorted(os.listdir(TESTING)):
            if f.endswith(".BIN") and ".RT." in f:
                shutil.copy(os.path.join(TESTING, f), os.path.join(dest, f))
                print("   installed:", os.path.join(folder, f), flush=True)
                found += 1
        if not found:
            print("   !! no GPB/GPC.RT.nnn.BIN in testing\\ -- build it with"
                  " make -C source/runtime gpc-rt", flush=True)

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
    #   reduces GPB.HELP.BASL to GPB, the compiler is then asked for GPB.SRC.PRG, and the
    #   stage dies on an input the tokeniser never wrote.
    for suffix in SUFFIXES:
        if filename.upper().endswith(suffix):
            return filename[:-len(suffix)]
    return os.path.splitext(filename)[0]


def build(prog):
    name = prog["name"]
    stem = stem_of(prog["src"][1])
    print("=" * 70, flush=True)
    print("==", name, "(%s)" % ("SHARED" if prog["shared"] else "EMBEDDED"), flush=True)

    stage_sources(prog)
    #   a changed .INC.BL is invisible to build_basl.py's up-to-date check
    for junk in (stem + ".SRC.PRG", stem + ".PRG", stem + ".MAP", stem + ".SRC.SYM"):
        p = os.path.join(TESTING, junk)
        if os.path.exists(p):
            os.remove(p)

    started = time.time() - 2          # a small allowance for clock granularity

    src = os.path.join(TESTING, stem + ".SRC.PRG")
    if run([os.path.join(GPCDIR, "build_basl.py"), prog["src"][1], stem + ".SRC.PRG"], name, src):
        print("!! tokenise FAILED for", name, "-- nothing was compiled", flush=True)
        return False
    if not os.path.exists(src):
        print("!! tokenise produced nothing for", name, flush=True)
        return False
    print("   tokenised:", format(os.path.getsize(src), ","), "bytes", flush=True)

    #   THE EXIT STATUS IS THE ANSWER, not whether an output file turned up.  A stage that
    #   fails partway can still leave a plausible file behind; on 11th Sep 2026 one was
    #   taken for a good tokenise and handed to the compiler, which spent 420 seconds on it.
    cmd = [os.path.join(GPCDIR, "compile_shared.py")]
    if not prog["shared"]:
        cmd.append("--embedded")
    cmd += [stem + ".SRC.PRG", stem + ".PRG", stem + ".MAP"]
    rc = run(cmd, name, [os.path.join(TESTING, "GPCCOMP.LOG"),
                         os.path.join(TESTING, stem + ".PRG"),
                         os.path.join(TESTING, stem + ".MAP")])

    obj = os.path.join(TESTING, stem + ".PRG")
    if rc or not os.path.exists(obj):
        print("   -- compile FAILED; the real message is in",
              os.path.join(TESTING, "GPCCOMP.LOG"), flush=True)
        return False
    print("   compiled:", format(os.path.getsize(obj), ","), "bytes", flush=True)

    #   ONLY overlays this build wrote.  A failed compile used to report the PREVIOUS build's
    #   overlays as if they were new.  The suffix is .Bnn and nn reaches 63, not .B0n.
    for f in sorted(os.listdir(TESTING)):
        if f.startswith(stem + ".B") and f[len(stem) + 2:].isdigit():
            p = os.path.join(TESTING, f)
            fresh = os.path.getmtime(p) >= started
            print("   overlay", f, format(os.path.getsize(p), ","),
                  "" if fresh else "<-- STALE, not from this build", flush=True)

    install(prog, stem)
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
