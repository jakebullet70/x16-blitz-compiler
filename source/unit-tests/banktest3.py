# -*- coding: utf-8 -*-
#
#   Tokenise, compile and RUN each GP.BANKED test, then compare the marked program's
#   output against its unmarked control.  Increment 2 moves code, so a byte compare of
#   the objects is no longer the test -- what has to match is what the program prints.
#
import os, re, subprocess, time, sys

ROOT = r"C:\dev\CmdrX16\dos_tools\x16-blitz-compiler"
T = os.path.join(ROOT, "testing")
E = os.path.join(ROOT, "bin", "x16emu")
PY = r"C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe"
#   GPC's OWN error vocabulary, read out of the generator's output so it cannot drift.
#   Guessing at it ("the line ends with ERROR") missed BAD VALUE completely and then
#   matched a stray line from BASIC instead, which read like a compiler crash and was not.
GPC_ERRORS = re.findall(
    r'\.text\s+"([^"]+)"',
    open(os.path.join(ROOT, "source", "common-source", "source", "generated",
                      "errors.asm"), encoding="latin-1").read())

env = dict(os.environ)
env["SDL_VIDEODRIVER"] = "dummy"


def emu(args, secs, stop=None, log="BT.LOG"):
    lp = os.path.join(T, log)
    with open(lp, "wb") as lf:
        p = subprocess.Popen([os.path.join(E, "x16emu.exe"), "-rom", os.path.join(E, "rom.bin"),
                              "-fsroot", "."] + args + ["-sound", "none", "-echo"],
                             cwd=T, stdout=lf, stderr=subprocess.STDOUT, env=env)
        dl = time.time() + secs
        while time.time() < dl:
            time.sleep(1)
            t = open(lp, "rb").read().decode("latin-1")
            if stop and stop in t:
                time.sleep(1.5)
                break
        p.kill()
        try:
            p.wait(timeout=5)
        except Exception:
            pass
    return open(lp, "rb").read().decode("latin-1")


def tokenise(name):
    src = os.path.join(T, name + ".SRC.PRG")
    if os.path.exists(src):
        os.remove(src)
    subprocess.run([PY, os.path.join(ROOT, "source", "gpc", "build_basl.py"),
                    name + ".BASL", name + ".SRC.PRG"],
                   cwd=ROOT, capture_output=True, text=True)
    return os.path.exists(src)


def compile_one(name, mode="SHARED"):
    #   SHARED, not embedded: GP.BANKED only works there. The bootstrap is what moves the
    #   region into the bank, and an embedded program has no bootstrap -- gpbank.asm
    #   refuses a region rather than guessing. GPC/GPB.RT.120.BIN are in testing/.
    open(os.path.join(T, "GPC.INPUT"), "w", newline="\n").write(
        "%s.SRC.PRG\n%s.PRG\n%s.MAP\n%s\n" % (name, name, name, mode))
    p = os.path.join(T, name + ".PRG")
    if os.path.exists(p):
        os.remove(p)
    t = emu(["-warp", "-prg", "GPC.BIN", "-run"], 90, "OK CODE")
    #   The error TABLE is echoed right after the banner, so nothing before the "OUT:"
    #   line is a result.  Only look after it.
    i = t.rfind("OUT:")
    tail = t[i:] if i >= 0 else t
    j = tail.find("OK CODE")
    if j >= 0:
        return "OK", tail[j:j + 30].split("\r")[0].strip()
    for line in tail.split("\r\n"):
        s = line.strip()
        for e in GPC_ERRORS:
            if s.startswith(e):
                return "ERR", s
    return "???", tail[:100].replace("\r\n", " | ")


def run_one(name):
    #   Longer than the embedded runs took: a shared program LOADs its runtime first.
    t = emu(["-warp", "-prg", name + ".PRG", "-run"], 60, "READY.", log=name + ".RUN.LOG")
    #   x16emu -echo doubles every character in non-warp; this is warp, so it does not.
    #   Keep the lines between the RUN and the final READY.
    out = []
    for line in t.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        s = line.strip()
        if re.match(r"^[A-Z]+[0-9]", s):
            out.append(s)
    return out


PAIRS = [("BANKA", "BANKE"), ("BANKB", "BANKF"), ("BANKH", "BANKI"), ("BANKJ", "BANKK"),
         ("BANKN", "BANKO")]
BAD = [("BANKC", "BLOCK MISMATCH"), ("BANKD", "BLOCK MISMATCH"),
       ("BANKG", "BLOCK MISMATCH"), ("BANKL", "VALUE"), ("BANKM", "VALUE"),
       ("BANKX", "BAD VALUE"), ("BANKY", "NOT IMPLEMENTED")]
BADNAMES = [b[0] for b in BAD]

results = {}
for n in [x for p in PAIRS for x in p] + BADNAMES:
    ok = tokenise(n)
    kind, msg = compile_one(n) if ok else ("TOKFAIL", "")
    results[n] = (kind, msg, [])
    if kind == "OK" and n not in BADNAMES:
        results[n] = (kind, msg, run_one(n))
    print("%-6s tok=%-5s %-4s %-28s %s" % (n, ok, kind, msg, " / ".join(results[n][2])))

print()
fails = 0
for a, b in PAIRS:
    ka, _, oa = results[a]
    kb, _, ob = results[b]
    same = (ka == "OK" and kb == "OK" and oa == ob and len(oa) > 0)
    print("%-6s vs %-6s  %s" % (a, b, "SAME OUTPUT" if same else "*** DIFFERENT ***"))
    if not same:
        fails += 1
        print("       marked  :", oa)
        print("       control :", ob)

for n, want in BAD:
    k, m, _ = results[n]
    good = (k == "ERR" and want in m)
    print("%-6s rejected     %s   (%s)" % (n, "YES" if good else "*** NO ***", m))
    if not good:
        fails += 1

print()
print("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails)
sys.exit(1 if fails else 0)
