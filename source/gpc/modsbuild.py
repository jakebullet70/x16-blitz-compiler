#
#   modsbuild.py -- rebuild GPBMODS and GUIFRMT headlessly from the
#   GPB-MODS-TESTING working copy.  Usage: modsbuild.py GPBMODS [GUIFRMT ...]
#
import os, shutil, subprocess, sys, time

ROOT    = r"C:\dev\CmdrX16\dos_tools\x16-blitz-compiler"
SAMPLE  = os.path.join(ROOT, "samples", "GPB-MODS-TESTING")
WORKLIB = os.path.join(SAMPLE, "GPC-BASIC")
ROOTLIB = os.path.join(ROOT, "GPC-BASIC")
TESTING = os.path.join(ROOT, "testing")
GPCDIR  = os.path.join(ROOT, "source", "gpc")

# the working copy is upstream for every module...
for f in os.listdir(WORKLIB):
    if f.endswith(".INC.BL") and f != "GPB.INC.BL":
        shutil.copy(os.path.join(WORKLIB, f), os.path.join(TESTING, f))
# ...except the keyword file, where ROOT is upstream
shutil.copy(os.path.join(ROOTLIB, "GPB.INC.BL"), os.path.join(TESTING, "GPB.INC.BL"))

def run(cmd):
    print("----", " ".join(cmd[1:]))
    r = subprocess.run([sys.executable] + cmd, cwd=ROOT,
                       capture_output=True, text=True, errors="replace")
    print(r.stdout[-2500:])
    if r.stderr.strip():
        print("STDERR:", r.stderr[-1500:])

for stem in sys.argv[1:]:
    print("=" * 60)
    print("==", stem)
    shutil.copy(os.path.join(SAMPLE, stem + ".BASL"),
                os.path.join(TESTING, stem + ".BASL"))
    # a changed .INC.BL is invisible to build_basl.py's up-to-date check
    for junk in (stem + ".SRC.PRG", stem + ".PRG", stem + ".MAP",
                 stem + ".SRC.SYM"):
        p = os.path.join(TESTING, junk)
        if os.path.exists(p):
            os.remove(p)

    started = time.time() - 2          # a small allowance for clock granularity

    run([os.path.join(GPCDIR, "build_basl.py"), stem + ".BASL", stem + ".SRC.PRG"])
    src = os.path.join(TESTING, stem + ".SRC.PRG")
    if not os.path.exists(src):
        print("!! tokenise produced nothing for", stem)
        continue
    print("   tokenised:", os.path.getsize(src), "bytes")

    run([os.path.join(GPCDIR, "compile_shared.py"),
         stem + ".SRC.PRG", stem + ".PRG", stem + ".MAP"])
    obj = os.path.join(TESTING, stem + ".PRG")
    print("   compiled:", os.path.getsize(obj) if os.path.exists(obj) else "MISSING")
    # ONLY overlays this build wrote.  The old loop printed any .B0* it found, so a
    # failed compile reported the PREVIOUS build's overlays as if they were new.
    for f in sorted(os.listdir(TESTING)):
        if f.startswith(stem + ".B0"):
            q = os.path.join(TESTING, f)
            fresh = os.path.getmtime(q) >= started
            print("   overlay", f, os.path.getsize(q), "" if fresh else "<-- STALE, not from this build")

    if not os.path.exists(obj):
        print("   -- compile failed; the real message is in", os.path.join(TESTING, "GPCCOMP.LOG"))
