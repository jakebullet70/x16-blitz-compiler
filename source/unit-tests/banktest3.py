# -*- coding: utf-8 -*-
#
#   Tokenise, compile and RUN each GP.BANKED test, then compare the marked program's
#   output against its unmarked control.  Increment 2 moves code, so a byte compare of
#   the objects is no longer the test -- what has to match is what the program prints.
#
import glob, os, re, shutil, subprocess, time, sys

ROOT = r"C:\dev\CmdrX16\dos_tools\x16-blitz-compiler"
T = os.path.join(ROOT, "scratch", "banktest3")
E = os.path.join(ROOT, "bin", "x16emu")
#   The interpreter running this, not a path off one machine: the hard-coded one went
#   stale and the suite could not tokenise anything at all.
PY = sys.executable
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

#   Any of those messages with its " @ line", which is how a compile ends when it is refused.
ERR_RE = re.compile("(?:" + "|".join(re.escape(e) for e in GPC_ERRORS) + r") @ *[0-9]+")

env = dict(os.environ)
env["SDL_VIDEODRIVER"] = "dummy"


#   ram is the machine's banked RAM in K: 512 is a stock X16 and bank 63 its highest,
#   2048 has every bank to 255.
def emu(args, secs, stop=None, log="BT.LOG", ram=512):
    lp = os.path.join(T, log)
    with open(lp, "wb") as lf:
        p = subprocess.Popen([os.path.join(E, "x16emu.exe"), "-rom", os.path.join(E, "rom.bin"),
                              "-fsroot", ".", "-ram", str(ram)] + args + ["-sound", "none", "-echo"],
                             cwd=T, stdout=lf, stderr=subprocess.STDOUT, env=env)
        dl = time.time() + secs
        while time.time() < dl:
            time.sleep(1)
            t = open(lp, "rb").read().decode("latin-1")
            if stop and stop in t:
                time.sleep(1.5)
                break
            #   A refused compile never prints the stop text, so every refusal test used to wait
            #   out the whole timeout, 90 s each. A compiler error after the "OUT:" line ends the
            #   wait too. A program run prints no "OUT:", so this never cuts one short.
            i = t.rfind("OUT:")
            if i >= 0 and ERR_RE.search(t, i):
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
                    "--drive", T, name + ".BASL", name + ".SRC.PRG"],
                   cwd=ROOT, capture_output=True, text=True)
    return os.path.exists(src)


#   The banks inside NAME.OVL, as three-digit strings. The file introduces every region
#   with its bank and its page count and ends on one marker byte, so walking it is the whole
#   of reading it -- and a file that does not end on the marker reports SHORT rather than
#   passing the check.
OVL_END = 1


def overlays(name):
    p = os.path.join(T, name + ".OVL")
    if not os.path.exists(p):
        return []
    b, i, banks = open(p, "rb").read(), 0, []
    while i + 2 <= len(b) and b[i] != OVL_END:
        banks.append(b[i])
        i += 2 + b[i + 1] * 256
    got = sorted("%03d" % x for x in banks)
    whole = i == len(b) - 1 and b[i] == OVL_END
    return got if whole else got + ["SHORT"]

#   An EMBEDDED object no longer carries its regions. It opens the same .OVL a shared one
#   does, by a name the compiler patches into the runtime image, so overlays() above reads
#   both builds and the only extra thing to check is that the image asks for the right file.
RTIMG = {}
for _line in open(os.path.join(ROOT, "source", "application", "rtimage.gen.asm")):
    if "=" in _line and _line.split()[0].startswith("RTIMG_"):
        _k, _v = _line.split("=", 1)
        RTIMG[_k.strip()] = int(_v.strip().lstrip("$"), 16)


def image_overlay_name(name):
    #   The length byte and the name itself, out of the object's own runtime image. Zero
    #   length is a program with no region, which opens nothing and ships as one file.
    b = open(os.path.join(T, name + ".PRG"), "rb").read()[2:]
    n = b[RTIMG["RTIMG_OVLLENOFS"]]
    if n == 0:
        return ""
    o = RTIMG["RTIMG_OVLNAMOFS"]
    return b[o:o + n].decode("latin-1")



def compile_one(name, mode="SHARED"):
    #   SHARED by default, because every test above it is shared and that is what says the
    #   shared path has not moved. The embedded block at the foot of the file is what asks
    #   for the other mode.
    open(os.path.join(T, "GPC.INPUT"), "w", newline="\n").write(
        "%s.SRC.PRG\n%s.PRG\n%s.MAP\n%s\n" % (name, name, name, mode))
    p = os.path.join(T, name + ".PRG")
    if os.path.exists(p):
        os.remove(p)
    #   The overlay goes too, or a failed compile leaves the last run's for the checks to find.
    ovl = os.path.join(T, name + ".OVL")
    if os.path.exists(ovl):
        os.remove(ovl)
    t = emu(["-warp", "-prg", "GPC.BIN", "-run"], 90, "OK LOW CODE")
    #   The error TABLE is echoed right after the banner, so nothing before the "OUT:"
    #   line is a result.  Only look after it.
    i = t.rfind("OUT:")
    tail = t[i:] if i >= 0 else t
    j = tail.find("OK LOW CODE")
    if j >= 0:
        return "OK", tail[j:j + 40].split("\r")[0].strip()
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


def run_one(name, ram=512):
    #   Longer than the embedded runs took: a shared program LOADs its runtime first.
    t = emu(["-warp", "-prg", name + ".PRG", "-run"], 60, "READY.",
            log="%s.RUN%d.LOG" % (name, ram), ram=ram)
    #   x16emu -echo doubles every character in non-warp; this is warp, so it does not.
    #   Keep the lines between the RUN and the final READY.
    out = []
    for line in t.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        s = line.strip()
        if re.match(r"^[A-Z]+[0-9]", s):
            out.append(s)
        #   The bootstrap's own two messages, which stop a program before it prints anything.
        elif re.search(r"\?(?:RAM|OVL)$", s):
            out.append(s[-4:])
    return out


#   BNKGC is a GOTO and an IF .. GOTO inside one region and a GOTO out of it, against its
#   control BNKGD.  BANKH, a GOTO into a region from low memory, was a pair with BANKI until
#   the compiler refused it; it ran only because the bootstrap leaves the last region it
#   loaded selected.
PAIRS = [("BANKA", "BANKE"), ("BANKB", "BANKF"), ("BANKJ", "BANKK"),
         ("BANKN", "BANKO"), ("BNKGC", "BNKGD"), ("BGA", "BGB")]
PAIRNAMES = [x for p in PAIRS for x in p]
BAD = [("BANKC", "BLOCK MISMATCH"), ("BANKD", "BLOCK MISMATCH"),
       ("BANKG", "BLOCK MISMATCH"), ("BANKL", "VALUE"), ("BANKM", "VALUE"),
       ("BANKX", "BAD VALUE"),
       #   A GOTO selects no bank, so every form of one into a region from outside it is
       #   refused: GOTO (BANKH), IF .. GOTO (BNKGA), ON .. GOTO (BNKGB), IF .. THEN <line>
       #   (BNKGE), and a GOTO from one region into another (BGD).
       ("BANKH", "NOT IMPLEMENTED"), ("BNKGA", "NOT IMPLEMENTED"),
       ("BNKGB", "NOT IMPLEMENTED"), ("BNKGE", "NOT IMPLEMENTED"),
       ("BGD", "NOT IMPLEMENTED"),
       #   ON .. GOSUB into a region: an ON entry is 3 bytes and a .bgosub 4.  BGA/BGB above
       #   call into a region by GOSUB, GP.SUB, GP.FN and FN with no BANK statement.
       ("BGC", "ON GOSUB IN OR OUT OF GP.BANKED"),
       #   Bank 1 holds the runtime's rarely used handlers: a region there (BNK1) and text
       #   there (BSTR1) are refused.  Both read the bank through GPBankReadNumber.  This and
       #   BGC's are compiler-space messages, so these tests also prove the scan above reaches
       #   them.
       ("BNK1", "BANK 1 IS RESERVED"), ("BSTR1", "BANK 1 IS RESERVED")]
BADNAMES = [b[0] for b in BAD]
#   No control: what the program prints is the test. BANKY calls from one region into
#   another, which the compiler refused until .bgosub.
#
#   BNK255 has code in banks 255, 100 and 2 and text in 254, so the bootstrap page takes four
#   regions out of one file, into banks that are neither contiguous nor in order. At 2048K it
#   prints all four; at 512K the page stops with ?RAM before the program starts. BNKOVL is
#   BNK255 with the last 100 bytes cut off its .OVL: it must stop with ?OVL rather than run a
#   region it only half read.
RUNS = [("BANKY", 512, ["Q1", "Q2", "Q3"]),
        ("BNK255", 2048, ["H254", "H255", "H100", "H2"]),
        ("BNK255", 512, ["?RAM"]),
        ("BNKOVL", 2048, ["?OVL"])]
RUNNAMES = list(dict.fromkeys(r[0] for r in RUNS))
#   The banks a compile must leave in the overlay, checked before it is cut short.
OVERLAYS = [("BNK255", ["002", "100", "254", "255"]), ("BNKOVL", ["002", "100", "254", "255"])]
TRUNCATE = [("BNKOVL", 100)]

#   EVERY TEST ABOVE IS SHARED. These four are compiled a second time --embedded and run again,
#   and must print exactly what the shared build printed. An embedded object keeps its .OVL
#   beside it now and reads it at startup, so what is checked is that contract -- the file is
#   still there, the image asks for it by name, and it carries the same regions.
#
#   NOT A BYTE COMPARE against the shared .OVL. A branch that crosses into a region is
#   corrected by where the p-code RUNS, which is $0A00 shared and $3600 embedded, so the two
#   overlays differ in every region that is ever entered. They are not meant to be the same
#   bytes; they are meant to do the same thing.
EMBEDDED = [("BANKY", 512), ("BANKZ", 512), ("BANKN", 512), ("BNK64", 2048),
#   BNKEMB (a copy of BNK255) is here because GP.BANKEDSTR is no longer shared-only. Its text bank travels
#   in the .OVL like any other region, and the sixteen bytes saying which
#   bank each text slot went to ride in the runtime image, which StartCode copies to
#   GPBSTRBANKS. So the embedded run has to print the same four lines the shared one does.
            ("BNKEMB", 2048)]
#   ...and the limit that is gone. A hundred one-page regions used to be refused EMBEDDED --
#   they were appended to the object and ran past $9F00 into the I/O page. They travel in the
#   .OVL now, which the loader never reads, so the build has to take them.
BIGEMB = [("BNKBIG", 100)]

#   The drive keeps its own compiler and runtime, and they went stale once. Copy the
#   current ones over them first.
shutil.copy2(os.path.join(ROOT, "source", "application", "GPC.BIN"), T)
for pattern in ("GPC.IMG.*.BIN", "GP1.IMG.*.BIN",
                "GPB.RT.*.BIN", "GPC.RT.*.BIN", "GP1.RT.*.BIN"):
    for f in glob.glob(os.path.join(ROOT, "drive", pattern)):
        shutil.copy2(f, T)

#   BNKOVL is BNK255 under another name, made fresh each run so the two cannot drift.
open(os.path.join(T, "BNKOVL.BASL"), "w", newline="").write(
    open(os.path.join(T, "BNK255.BASL"), newline="").read().replace("BNK255", "BNKOVL"))
#   BNKEMB is BNK255 under a third name, for the embedded pass at the foot of this file. That
#   pass overwrites the object it compiles and takes its .OVL away -- which is right for an
#   embedded build and wrong to leave behind, because the shared rows above run first next time
#   and would find an embedded object where they left a shared one. A name of its own keeps the
#   two apart, exactly as BNKOVL does.
open(os.path.join(T, "BNKEMB.BASL"), "w", newline="").write(
    open(os.path.join(T, "BNK255.BASL"), newline="").read().replace("BNK255", "BNKEMB"))

#   BNKBIG is generated too: a hundred one-page regions, which no embedded object has room for.
#   None of them is ever called -- the test is the refusal, and calling them would only make the
#   low code large enough to change which limit it hits first.
open(os.path.join(T, "BNKBIG.BASL"), "w", newline="").write(
    '#SAVEAS "@:BNKBIG.SRC.PRG"\n#REM 0\n#INCLUDE "GPB.INC.BL"\n\nPRINT "B1"\nEND\n\n' +
    "".join('GP.BANKED %d\nBB%d:\n    PRINT "X"\n    RETURN\nGP.ENDBANKED\n\n' % (b, b)
            for b in range(2, 102)))


results = {}
for n in PAIRNAMES + RUNNAMES + BADNAMES:
    ok = tokenise(n)
    kind, msg = compile_one(n) if ok else ("TOKFAIL", "")
    out = run_one(n) if kind == "OK" and n in PAIRNAMES else []
    results[n] = (kind, msg, out)
    print("%-6s tok=%-5s %-4s %-28s %s" % (n, ok, kind, msg, " / ".join(out)))

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

for n, want in OVERLAYS:
    got = overlays(n)
    good = (results[n][0] == "OK" and got == want)
    print("%-6s overlays     %s   (%s)" % (n, "YES" if good else "*** NO ***", " ".join(got)))
    if not good:
        fails += 1

for n, cut in TRUNCATE:
    p = os.path.join(T, n + ".OVL")
    if os.path.exists(p):
        with open(p, "r+b") as f:
            f.truncate(max(0, os.path.getsize(p) - cut))

for n, ram, want in RUNS:
    k, m, _ = results[n]
    out = run_one(n, ram) if k == "OK" else []
    good = (out == want)
    print("%-6s runs %4dK   %s   (%s)" % (n, ram, "YES" if good else "*** NO ***", " / ".join(out) or m))
    if not good:
        fails += 1

#   The embedded half, last: it compiles these names again and overwrites their objects.
for n, ram in EMBEDDED:
    tokenise(n)
    ks, ms = compile_one(n, "SHARED")
    want_ovl = overlays(n)
    want_out = run_one(n, ram) if ks == "OK" else []
    ke, me = compile_one(n, "EMBEDDED")
    got = overlays(n) if ke == "OK" else ["COMPILE " + me]
    out = run_one(n, ram) if ke == "OK" else []
    named = image_overlay_name(n) if ke == "OK" else ""
    #   THE .OVL HAS TO STILL BE THERE, and the image has to be asking for it by name. Those
    #   two are the whole of the pairing: nothing else ties the second file to the first.
    left = os.path.exists(os.path.join(T, n + ".OVL"))
    good = (got == want_ovl and out == want_out and len(out) > 0
            and left and named == n + ".OVL")
    print("%-6s embedded %4dK %s   (%s)"
          % (n, ram, "YES" if good else "*** NO ***", " / ".join(out) or me))
    if not good:
        fails += 1
        print("       shared   :", want_ovl, want_out)
        print("       embedded :", got, out, named, "" if left else "NO OVL")

for n, want in BIGEMB:
    ok = tokenise(n)
    k, m = compile_one(n, "EMBEDDED") if ok else ("TOKFAIL", "")
    got = overlays(n) if k == "OK" else []
    good = (k == "OK" and len(got) == want and "SHORT" not in got)
    print("%-6s embedded %d regions %s   (%s)"
          % (n, want, "YES" if good else "*** NO ***", m or "%d in the .OVL" % len(got)))
    if not good:
        fails += 1

print()
print("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails)
sys.exit(1 if fails else 0)
