# -*- coding: utf-8 -*-
#
#   One compile, timed from its own transcript (docs/blitz/COMPILER-TESTS.PLAN.md, section 5).
#
#       gpcprobe.py [NAME [INPUTS [DRIVE]]]
#
#   Compiles NAME, GPBMODS by default, SHARED with the option off, with
#   source/application/GPC.BIN. The inputs come from INPUTS, scratch/dcref/inputs/ by default, and
#   the compile runs in DRIVE, scratch/gpcprobe/NAME/ by default.
#
#   CMP.LOG is polled every 0.1 s. The probe records each growth of the file, the time each
#   pass-1 progress dot first appears, and when PASS 1, PASS 2 and OK LOW CODE are seen.
#   DRIVE/probe.json keeps the record for gpcspans.py. The last line compares the outputs with
#   scratch/gpctest/ref/off/NAME/.
#
#   Run no other emulator alongside it: the times are the point.
#
import os, sys, time, json, re, shutil, subprocess

import dcref

NAME = sys.argv[1] if len(sys.argv) > 1 else "GPBMODS"
gpc = os.path.join(dcref.ROOT, "source", "application", "GPC.BIN")
inputs = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(dcref.WORK, "inputs")
drive = os.path.abspath(sys.argv[3]) if len(sys.argv) > 3 else os.path.join(dcref.ROOT, "scratch", "gpcprobe", NAME)
shutil.rmtree(drive, ignore_errors=True)
os.makedirs(drive)
shutil.copy2(gpc, os.path.join(drive, "GPC.BIN"))
for f in os.listdir(inputs):
    if f.endswith(".BIN") or f.startswith(NAME + ".SRC."):
        shutil.copy2(os.path.join(inputs, f), drive)
lines = [NAME + ".SRC.PRG", NAME + ".PRG", NAME + ".MAP", "SHARED", ""]
open(os.path.join(drive, "GPC.INPUT"), "w", newline="\n").write("\n".join(lines) + "\n")

env = dict(os.environ)
env["SDL_VIDEODRIVER"] = "dummy"
logpath = os.path.join(drive, "CMP.LOG")
growth, dots1, marks = [], [], {}
size = 0
with open(logpath, "wb") as log:
    p = subprocess.Popen([dcref.EMU, "-rom", dcref.ROM, "-fsroot", ".", "-warp", "-sound", "none",
                          "-echo", "raw", "-prg", "GPC.BIN", "-run"],
                         cwd=drive, stdout=log, stderr=subprocess.STDOUT, env=env)
    t0 = time.time()
    try:
        while time.time() - t0 < 1500:
            time.sleep(0.1)
            n = os.path.getsize(logpath)
            if n == size:
                continue
            t = time.time() - t0
            growth.append((round(t, 2), n))
            size = n
            b = open(logpath, "rb").read()
            for key, pat in (("pass1", b"PASS 1 "), ("pass2", b"PASS 2 "), ("ok", b"OK LOW CODE"),
                             ("ready_after_ok", None)):
                if key in marks:
                    continue
                if pat is not None and pat in b:
                    marks[key] = round(t, 2)
                elif key == "ready_after_ok" and "ok" in marks and b"READY." in b[b.rfind(b"OK LOW CODE"):]:
                    marks[key] = round(t, 2)
            at = b.find(b"PASS 1 ")
            if at >= 0:
                run = len(re.match(rb"\.*", b[at + 7:]).group(0))
                while len(dots1) < run:
                    dots1.append(round(t, 2))
            if "ready_after_ok" in marks:
                break
    finally:
        p.kill()
        p.wait(timeout=5)

b = open(logpath, "rb").read()
ok = b.rfind(b"OK LOW CODE")
verdict = b[ok:].split(b"\r")[0].decode("latin-1") if ok >= 0 else "NO OK"
steps = [growth[i][1] - (growth[i - 1][1] if i else 0) for i in range(len(growth))]
out = dict(name=NAME, verdict=verdict, marks=marks, dots1=dots1, growth=growth)
json.dump(out, open(os.path.join(drive, "probe.json"), "w"), indent=1)
print("verdict:", verdict)
print("marks:", marks)
print("growth events:", len(growth), " distinct step sizes:", sorted(set(steps))[:20])
print("pass-1 dots:", len(dots1), " distinct dot times:", len(set(dots1)))
import gpctest
print("against ref/off:", gpctest.against("off", NAME, verdict, drive))
