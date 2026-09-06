# -*- coding: utf-8 -*-
#
#   Build and run one BASL program headlessly, and print its RAW log.
#
#   Raw on purpose: a filtered summary has twice hidden a real result in this tree,
#   once behind a font dump and once behind a "printable runs of 4+ characters" rule
#   that ate every two-character verdict.
#
#   IT WORKS IN ITS OWN DIRECTORY, set by GPCWORK. testing/ is shared -- another
#   session rewrote GPC.INPUT between this script writing it and the emulator
#   reading it, twice, and the compile silently built THAT session's program
#   instead. The run then loaded a stale PRG and crashed with no output, which
#   reads exactly like a bug in the code under test.
#
#   It also tokenises itself rather than calling source/gpc/build_basl.py, which
#   hardcodes testing/ and is the other session's tool.
#
import os, subprocess, sys, time

ROOT = r"C:\dev\CmdrX16\dos_tools\x16-blitz-compiler"
T = os.path.join(ROOT, os.environ.get("GPCWORK", "testing"))
E = os.path.join(ROOT, "bin", "x16emu")
PY = sys.executable

env = dict(os.environ)
env["SDL_VIDEODRIVER"] = "dummy"

NAME = sys.argv[1] if len(sys.argv) > 1 else "DEVPROBE"


def emu(args, secs, stop, log):
    lp = os.path.join(T, log)
    with open(lp, "wb") as lf:
        p = subprocess.Popen([os.path.join(E, "x16emu.exe"), "-rom", os.path.join(E, "rom.bin"),
                              "-fsroot", "."] + args + ["-sound", "none", "-echo"],
                             cwd=T, stdout=lf, stderr=subprocess.STDOUT, env=env)
        dl = time.time() + secs
        while time.time() < dl:
            time.sleep(1)
            if stop in open(lp, "rb").read().decode("latin-1"):
                time.sleep(1.5)
                break
        p.kill()
        try:
            p.wait(timeout=5)
        except Exception:
            pass
    return open(lp, "rb").read().decode("latin-1")


#   Tokenise. Stop on SAVING, not on a READY. count: the banner is the proof that
#   BASLOAD actually ran, and a malformed source reaches READY. without one.
src = os.path.join(T, NAME + ".SRC.PRG")
if os.path.exists(src):
    os.remove(src)
open(os.path.join(T, "BLD.BAS"), "w", newline="\n").write('BASLOAD "%s.BASL"\n' % NAME)
t = emu(["-warp", "-pastewarp", "-bas", "BLD.BAS"], 90, "SAVING", "TOK.LOG")
if not os.path.exists(src):
    i = t.find("BASLOAD")
    sys.exit("TOKENISE FAILED: " + (t[i:i + 300] if i >= 0 else t[-300:]).replace("\r\n", " | "))
print("tokenised %s.SRC.PRG (%d bytes)" % (NAME, os.path.getsize(src)))

#   Compile. GPC.INPUT is written immediately before the run that reads it; in a
#   private directory nothing else can get between the two.
open(os.path.join(T, "GPC.INPUT"), "w", newline="\n").write(
    "%s.SRC.PRG\n%s.PRG\n%s.MAP\nSHARED\n" % (NAME, NAME, NAME))
prg = os.path.join(T, NAME + ".PRG")
if os.path.exists(prg):
    os.remove(prg)
t = emu(["-warp", "-prg", "GPC.BIN", "-run"], 120, "OK CODE", "CMP.LOG")
i = t.rfind("OUT:")
tail = (t[i:] if i >= 0 else t)
j = tail.find("OK CODE")
print("COMPILE:", tail[j:j + 60].split("\r")[0] if j >= 0 else tail[:180].replace("\r\n", " | "))
if not os.path.exists(prg):
    sys.exit("COMPILE FAILED -- read %s/CMP.LOG" % T)

t = emu(["-warp", "-prg", NAME + ".PRG", "-run"], 90, "DONE", NAME + ".RUN.LOG")
print("=" * 60)
print(t.replace("\r\n", "\n"))
