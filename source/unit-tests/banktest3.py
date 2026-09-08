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

#   ...AND THE MESSAGES THAT ARE NOT IN THAT TABLE. errors.asm links below GPBase and is
#   copied into every compiled program, so a diagnostic only the compiler can ever print
#   goes in compiler space instead -- "jsr CallErrorHandler" followed by inline .text.
#   Eight of them exist now and the number is growing.  Miss them and a rejection test that
#   is working perfectly reports "???" and counts as a FAILURE, because the check below is
#   kind == "ERR": the message is right there in the tail and the harness cannot see it.
for _d in ("compiler", "application"):
    for _root, _dirs, _files in os.walk(os.path.join(ROOT, "source", _d, "source")):
        for _f in _files:
            if _f.endswith(".asm"):
                GPC_ERRORS += re.findall(
                    r'CallErrorHandler\s*\.text\s+"([^"]+)"',
                    open(os.path.join(_root, _f), encoding="latin-1").read())

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
    #   NOT line by line.  -echo streams the object bytes through CHROUT as they are
    #   written, so the message can be glued to the tail of them with no CR in between --
    #   BANKY reported "???" for exactly that reason while the compiler had printed
    #   NOT IMPLEMENTED @ 6 perfectly well.  Match the message and its " @ line" instead,
    #   which is a shape nothing in a p-code stream produces.
    for e in GPC_ERRORS:
        m = re.search(re.escape(e) + r" @ *[0-9]+", tail)
        if m:
            return "ERR", m.group(0)
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
       ("BANKX", "BAD VALUE"), ("BANKY", "NOT IMPLEMENTED"),
       #   The region COUNT is a checked limit, not a crash.  BNK64 is sixty-four trivial
       #   regions in banks 1 up -- one more than a 512K X16 has -- and the message names the
       #   sixty-fourth GP.BANKED.  It is a compiler-space message, so this test is also what
       #   proves the scan above reaches them.  It was BNK17 until the tables left the 1K
       #   storage hole and the count became the machine's.
       ("BNK64", "TOO MANY GP.BANKED REGIONS")]
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
