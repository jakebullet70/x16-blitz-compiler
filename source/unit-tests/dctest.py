# -*- coding: utf-8 -*-
#
#   Dead-code removal: the lines a compile leaves out, against a hand analysis of each test
#   program.
#
#       dctest.py [--gpc FILE] [--only A,B]
#
#   Each test is a numbered .BAS in deadcode-tests/, tokenised with bin/tokenise.zip, a .BASL
#   tokenised with the ROM's BASLOAD, or a program generated or written byte by byte below. The
#   keep-marker tests are .BASL: tokenise.zip turns the END in REM GP.ENDKEEP into a token.
#   A NAME.SYM beside the source goes in as its symbol file. Each is
#   compiled with GPC.INPUT line 5 set, in a drive of its own under work/dctest/. The compile
#   writes the removed-line list D.NAME, and its OK line ends DEAD <lines> <bytes>.
#
#   The runtime images come from work/dcref/inputs/, the fixed copy dcref.py keeps.
#   dcstrip.py builds the same programs through make_source for the identity test.
#
import os, re, shutil, subprocess, sys, time, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TESTS = os.path.join(ROOT, "source", "unit-tests", "deadcode-tests")
WORK = os.path.join(ROOT, "work", "dctest")
INPUTS = os.path.join(ROOT, "work", "dcref", "inputs")
EMUDIR = os.path.join(ROOT, "bin", "x16emu")
EMU = os.path.join(EMUDIR, "x16emu.exe")
ROM = os.path.join(EMUDIR, "rom.bin")
TOKENISE = os.path.join(ROOT, "bin", "tokenise.zip")
TIMEOUT = 300
MISMATCH = "BLOCK MISMATCH"

FULL_NOTICE = "DEAD CODE TABLE FULL, NOTHING REMOVED"

#   name: (shared, removed lines, and either None, the notice the compile must print, or --
#   with removed None -- the error it must stop on while the option-off compile succeeds)
EXPECT = {
    #   The worked example in section 2.10 of the plan.
    "DC1": (False, [30, 50, 200, 210, 300, 310], None),
    #   An unused DEF FN, DIM retained in dead code, ON out of range, RESTORE into dead code.
    "DC2": (False, [200, 300, 310, 410, 420, 500], None),
    #   GP.DEFPROC used and unused, a GOTO into a GP.DO whose opener nothing reaches, an
    #   unreached GP.IF and GP.SELECT, and an unreached GP.ASM, listed with the body lines it
    #   reads for itself.
    "DC3": (False, [210, 220, 400, 410, 420, 430, 500, 510, 520, 530, 600, 610, 620, 630, 640],
            None),
    #   A GP.BANKEDSTR group read live, and dead lines inside a GP.BANKED region. Shared,
    #   because regions are.
    "DC4": (True, [140, 150, 530, 540], None),
    #   More than 2,048 edges: the notice, and nothing removed.
    "DC5": (False, [], FULL_NOTICE),
    #   Decision 2: a reached {VAR} naming a variable only a removed line creates.
    "DC6": (False, None, "UNKNOWN VARIABLE IN {}"),
    #   A GP.BANKED region none of whose inner lines is reached (plan 2.7).
    "DC7": (True, [510, 520], None),
    #   Keep regions through the ROM's BASLOAD: REM GP.KEEP, REM #GPC KEEP, one of each, the
    #   markers under #REM 0, REM GP.KEEPER, REM gp.keep, and a marker after a statement.
    #   BASLOAD numbers the lines from 1.
    "DC8":(False, [3, 6, 7, 10, 11, 14, 15, 18, 19, 20, 21, 22, 23, 24, 27, 28, 31], None),
    #   A KEEP inside a region, an ENDKEEP outside one, and a region open at the end.
    "DC9": (False, None, MISMATCH + " @ 4"),
    "DC10": (False, None, MISMATCH + " @ 3"),
    "DC11": (False, None, MISMATCH + " @ 4"),
    #   Marker bytes no BASLOAD run here writes: lower case, $C1-$DA, and #GPC straight after
    #   the token, which is how BASLOAD-GPC writes its directive.
    "DC12": (False, [30, 60, 70, 100, 110, 140], None),
}


def generate_dc5():
    #   1,100 lines of two GOSUBs each is 2,200 edges, and line 11020 would go if the table held.
    lines = ["%d GOSUB 20000:GOSUB 20000" % (10 * i) for i in range(1, 1101)]
    return "\n".join(lines + ["11010 END", '11020 PRINT "DEAD"', "20000 RETURN"]) + "\n"


GENERATED = {"DC5": generate_dc5}


def raw_dc12():
    def shifted(text):
        return bytes(c | 0x80 if 0x41 <= c <= 0x5A else c for c in text.encode("ascii"))
    return [(10, b'\x99"LIVE"'),
            (20, b"\x80"),
            (30, b"\x8f gp.keep"),
            (40, b'\x99"LOWER CASE"'),
            (50, b"\x8e"),
            (60, b"\x8f #gpc  endkeep"),
            (70, b"\x8f " + shifted("GP.KEEP")),
            (80, b'\x99"SHIFTED"'),
            (90, b"\x8e"),
            (100, b"\x8f " + shifted("GP.ENDKEEP")),
            (110, b"\x8f#GPC KEEP"),
            (120, b'\x99"GPC DIRECTIVE"'),
            (130, b"\x8e"),
            (140, b"\x8f#GPC ENDKEEP")]


#   name: the lines as (number, tokenised text), written as a PRG with no tokeniser
RAW = {"DC12": raw_dc12}


def write_prg(lines, path):
    out = bytearray(b"\x01\x08")
    addr = 0x0801
    for number, text in lines:
        addr += 4 + len(text) + 1
        out += bytes([addr & 0xFF, addr >> 8, number & 0xFF, number >> 8]) + text + b"\x00"
    out += b"\x00\x00"
    open(path, "wb").write(out)


def tokenise_basl(name, drive):
    """The ROM's BASLOAD, typed at the prompt with drive as the disk. None, or the problem.
    The second READY. is the finish: one follows the boot banner, one follows BASLOAD."""
    shutil.copy2(os.path.join(TESTS, name + ".BASL"), drive)
    src = os.path.join(drive, name + ".SRC.PRG")
    if os.path.exists(src):
        os.remove(src)
    open(os.path.join(drive, "BLD.BAS"), "w", newline="\n").write('BASLOAD "%s.BASL"\n' % name)
    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"
    logpath = os.path.join(drive, "BLD.LOG")
    with open(logpath, "wb") as log:
        p = subprocess.Popen([EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-pastewarp", "-sound",
                              "none", "-echo", "-bas", "BLD.BAS"],
                             cwd=drive, stdout=log, stderr=subprocess.STDOUT, env=env)
        try:
            deadline = time.time() + 60
            while time.time() < deadline:
                time.sleep(0.5)
                if open(logpath, "rb").read().count(b"READY.") >= 2:
                    time.sleep(0.5)
                    break
        finally:
            p.kill()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
    echo = open(logpath, "rb").read()
    if b"SAVING" not in echo or not os.path.exists(src):
        said = [s.strip() for s in echo.decode("latin-1").replace("\r", "\n").split("\n")
                if s.strip() and s.strip() != "READY."]
        return "TOKENISE FAILED: " + (said[-1] if said else "no output")
    return None


def make_source(name, drive):
    """Tokenise test NAME into drive as NAME.SRC.PRG, with its symbol file. None, or the problem."""
    if name in RAW:
        write_prg(RAW[name](), os.path.join(drive, name + ".SRC.PRG"))
        return None
    if os.path.exists(os.path.join(TESTS, name + ".BASL")):
        return tokenise_basl(name, drive)
    bas = os.path.join(TESTS, name + ".BAS")
    if name in GENERATED:
        bas = os.path.join(drive, name + ".BAS")
        open(bas, "w", newline="\n").write(GENERATED[name]())
    src = os.path.join(drive, name + ".SRC.PRG")
    r = subprocess.run([sys.executable, TOKENISE, bas, src], capture_output=True, text=True)
    if not os.path.exists(src):
        return "TOKENISE FAILED: " + (r.stderr.strip().splitlines() or ["?"])[-1]
    sym = os.path.join(TESTS, name + ".SYM")
    if os.path.exists(sym):
        shutil.copy2(sym, os.path.join(drive, name + ".SRC.SYM"))
    return None


def compile_one(name, gpc, shared, dead):
    drive = os.path.join(WORK, name if dead else name + "-OFF")
    shutil.rmtree(drive, ignore_errors=True)
    os.makedirs(drive)
    shutil.copy2(gpc, os.path.join(drive, "GPC.BIN"))
    for f in glob.glob(os.path.join(INPUTS, "*.BIN")):
        shutil.copy2(f, drive)
    problem = make_source(name, drive)
    if problem:
        return problem, b"", None

    lines = [name + ".SRC.PRG", name + ".PRG", name + ".MAP", "SHARED" if shared else "",
             ("D." + name) if dead else ""]
    open(os.path.join(drive, "GPC.INPUT"), "w", newline="\n").write("\n".join(lines) + "\n")

    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"
    logpath = os.path.join(drive, "CMP.LOG")
    verdict = "TIMEOUT"
    with open(logpath, "wb") as log:
        p = subprocess.Popen([EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-sound", "none",
                              "-echo", "raw", "-prg", "GPC.BIN", "-run"],
                             cwd=drive, stdout=log, stderr=subprocess.STDOUT, env=env)
        try:
            deadline = time.time() + TIMEOUT
            while time.time() < deadline:
                time.sleep(0.5)
                echo = open(logpath, "rb").read()
                ok = echo.rfind(b"OK CODE")
                if ok >= 0:
                    time.sleep(1.0)
                    echo = open(logpath, "rb").read()
                    verdict = echo[ok:].split(b"\r")[0].split(b"\n")[0].decode("latin-1").strip()
                    break
                at = echo.find(b"GPC SQUEALING")
                if at >= 0 and b"READY." in echo[at:]:
                    body = echo[at:echo.index(b"READY.", at)].decode("latin-1")
                    body = [s.strip() for s in body.replace("\r", "\n").split("\n") if s.strip()]
                    verdict = "STOPPED: " + " | ".join(body[-3:])
                    break
        finally:
            p.kill()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass

    listed = os.path.join(drive, "D." + name)
    removed = [int(n) for n in open(listed).read().split()] if os.path.exists(listed) else None
    return verdict, open(logpath, "rb").read(), removed


def check(name, gpc):
    shared, want, expect = EXPECT[name]
    verdict, log, removed = compile_one(name, gpc, shared, True)
    problems = []
    if want is None:
        if not (verdict.startswith("STOPPED") and expect in verdict):
            problems.append("should stop with " + expect)
        off, _, _ = compile_one(name, gpc, shared, False)
        if not off.startswith("OK CODE"):
            problems.append("option off: " + off)
        return verdict, problems
    m = re.search(r" DEAD ([0-9]+) ([0-9]+)$", verdict)
    if not verdict.startswith("OK CODE"):
        problems.append("did not compile")
    elif not m or removed is None or int(m.group(1)) != len(removed):
        problems.append("DEAD figures and the list disagree")
    if removed != want:
        problems.append("want %s" % want)
        problems.append("have %s" % removed)
    if expect is not None and expect.encode("latin-1") not in log:
        problems.append("no notice: " + expect)
    return verdict, problems


def main():
    args = sys.argv[1:]
    gpc = os.path.join(ROOT, "source", "application", "GPC.BIN")
    only = None
    while args:
        a = args.pop(0)
        if a == "--gpc":
            gpc = os.path.abspath(args.pop(0))
        elif a == "--only":
            only = set(args.pop(0).split(","))
        else:
            sys.exit("usage: dctest.py [--gpc FILE] [--only A,B]")

    failed = 0
    for name in EXPECT:
        if only is not None and name not in only:
            continue
        verdict, problems = check(name, gpc)
        failed += bool(problems)
        print("  %-6s %-5s %s" % (name, "FAIL" if problems else "ok", verdict[:70]))
        for p in problems:
            print("         " + p)
        sys.stdout.flush()
    print("PASS" if failed == 0 else "%d FAILED" % failed)


if __name__ == "__main__":
    main()
