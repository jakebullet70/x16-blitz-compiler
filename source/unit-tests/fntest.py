# -*- coding: utf-8 -*-
#
#   Tokenise, compile and RUN each GP.FN test.  DEFFN1 calls its routines from inside
#   expressions; DEFFN1C prints the same lines the long way, and what has to match is
#   what the two programs print -- the objects are deliberately different.
#
#   The four rejections are the messages GP.FN and RETURNS add, all of them in compiler
#   space rather than in errors.asm, so this is also what proves the scan below reaches
#   them.
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
    #   refuses a region rather than guessing. GPC/GPB.RT.121.BIN are in testing/.
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


def run_one(name, last="Z9 DONE"):
    #   Longer than the embedded runs took: a shared program LOADs its runtime first.
    #   NOT "READY." -- that is already in the log from the LOAD, so the emulator was being
    #   killed a second and a half into a program that had barely started. Each pair prints
    #   its own last line, which is why the marker is an argument rather than a constant.
    t = emu(["-warp", "-prg", name + ".PRG", "-run"], 60, last, log=name + ".RUN.LOG")
    #   x16emu -echo doubles every character in non-warp; this is warp, so it does not.
    #   Keep the lines between the RUN and the final READY.
    out = []
    for line in t.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        s = line.strip()
        if re.match(r"^[A-Z]+[0-9]", s):
            out.append(s)
    return out


#   DEFP3 is the GP.SUB regression, and it is here rather than on its own because both
#   keywords compile their arguments through ProcCompileArguments. Deferring the stores so
#   a nested GP.FN could not clobber the outer call's formals changed that routine for
#   GP.SUB as well, and nothing else would have noticed.
PAIRS = [("DEFFN1", "DEFFN1C", "Z9 DONE"),
         ("DEFP3", "DEFP3C", "D9 END")]
#   The multi-line body cases, which are what .fnsave and .fnrestore exist for: the callee
#   prints from inside the call, so every line of it emits a new.line marker that would have
#   reset the string system and emptied the caller's evaluation stack. There is no longhand
#   control to pair these against -- the point is the shape, not a byte count -- so they are
#   checked against the lines they print.
#   DEFFNS is the stack test. Twelve formals is PROC_MAXFORMALS, and its last argument is
#   four terms deep, so holding the arguments on the twelve-slot evaluation stack ran off the
#   end of it -- into NSMantissa0[0], the bottom of the same stack, with nothing checking.
#   .fnpush parks each one on the frame stack instead, so both calls come back with 1 + 10.
EXPECT = {
    "DEFFN2": ["A1 START", "A2  6"],
    "DEFFN3": ["A1 START", "B1 INBODY", "B2 SET", "A2  8",
               "B1 INBODY", "B2 SET", "A3  6"],
    "DEFFN4": ["A1 START", "A3  6"],
    "DEFFNS": ["S1 START", "S2  11", "S3  11"],
}

#   -echo writes the colour change that follows a printed number through as a literal
#   backslash-X-1-D, so a line carrying a number never equals the text it printed. Nothing
#   here tests colour, and no line these programs print contains a backslash of its own.
def clean(s):
    return s.split("\\")[0].rstrip()

BAD = [("DEFFNX", "GP.FN NEEDS A VERB DECLARED RETURNS"),
       ("DEFFNY", "GP.FN BEFORE ITS GP.DEFPROC"),
       ("DEFFNZ", "ARGUMENTS DO NOT MATCH THE GP.DEFPROC"),
       ("DEFFNW", "GP.DEFPROC RETURNS IS NOT A VARIABLE")]
BADNAMES = [b[0] for b in BAD]

results = {}
LAST = {n: p[2] for p in PAIRS for n in p[:2]}
LAST.update({n: "Z9 DONE" for n in EXPECT})
for n in list(LAST) + BADNAMES:
    ok = tokenise(n)
    kind, msg = compile_one(n) if ok else ("TOKFAIL", "")
    results[n] = (kind, msg, [])
    if kind == "OK" and n not in BADNAMES:
        results[n] = (kind, msg, run_one(n, LAST[n]))
    print("%-8s tok=%-5s %-4s %-40s %s" % (n, ok, kind, msg, " / ".join(results[n][2])))

print()
fails = 0
for a, b, _last in PAIRS:
    ka, _, oa = results[a]
    kb, _, ob = results[b]
    same = (ka == "OK" and kb == "OK" and oa == ob and len(oa) > 0)
    print("%-8s vs %-8s  %s" % (a, b, "SAME OUTPUT" if same else "*** DIFFERENT ***"))
    if not same:
        fails += 1
        print("   marked : %s" % oa)
        print("   control: %s" % ob)

for n in EXPECT:
    k, _, got = results[n]
    #   The trailing Z9 DONE is the harness's stop marker, not a result, so drop it before
    #   comparing -- every one of these programs ends with it.
    got = [clean(l) for l in got if l != "Z9 DONE"]
    good = (k == "OK" and got == EXPECT[n])
    print("%-8s %-40s %s" % (n, " / ".join(got), "AS EXPECTED" if good else "*** WRONG ***"))
    if not good:
        fails += 1
        print("   wanted : %s" % EXPECT[n])

for n, want in BAD:
    k, m, _ = results[n]
    good = (k == "ERR" and want in m)
    print("%-8s %-40s %s" % (n, m, "REJECTED" if good else "*** NOT REJECTED ***"))
    if not good:
        fails += 1

print()
print("FAILURES: %d" % fails)
sys.exit(1 if fails else 0)
