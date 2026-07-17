# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		shared_test.py
#		Purpose:	Regression test for SHARED (resident-runtime) mode.
#		Created:	17th July 2026
#
# ************************************************************************************************
# ************************************************************************************************
#
#		The other unit-tests drive the compiler NATIVELY (StartCompiler + the test API, quitting
#		at $FFFF for a RAM-dump compare). SHARED mode is a DISK-FLOW feature -- GPC.BLITZ.BIN reads
#		GPC.INPUT, streams a bootstrap + p-code, and the bootstrap loads GPC.RT.BIN at run time --
#		so it needs a different harness. This one compiles a program in SHARED mode, checks the
#		object's byte layout, then runs it twice in the emulator to prove both paths:
#
#			COLD  a fresh machine (-zeroram, no magic at $7300) must LOAD GPC.RT.BIN, then run.
#			WARM  with the runtime already resident AND its disk file scratched, the program must
#			      still run -- proving it reused the resident copy instead of reloading (a reload
#			      would ?RT-fail on the now-missing file).
#
#		Prerequisites (build them first -- see the Makefile's "build" target):
#			testing/GPC.BLITZ.BIN   the compiler engine      (make libs)
#			testing/GPC.RT.BIN      the resident runtime      (make -C source/runtime gpc-rt)
#
#		The emulator is launched with SDL_VIDEODRIVER=dummy so it never steals the desktop's
#		keyboard focus, and each run is terminated by PID -- never by image name, because other
#		projects on this box run x16emu too. (CPython on Windows makes Popen.pid a real Windows
#		PID, so proc.kill() is a TerminateProcess of exactly this emulator.)
#
# ************************************************************************************************

import os, sys, time, subprocess

ROOT     = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TESTING  = os.path.join(ROOT, "testing")
EMU      = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM      = os.path.join(ROOT, "bin", "x16emu", "rom.bin")
TOKENISE = os.path.join(ROOT, "bin", "tokenise.zip")

# ABI constants -- must match common-source (RTBASE, PCODE_PAGE, MIN_WS_PAGES) and the runtime's
# FrameStackPages. Kept here as literals so the test fails loudly if the ABI moves under it.
RTBASE            = 0x7300
PCODE_PAGE        = 0x09
FRAME_STACK_PAGES = 16
MIN_WS_PAGES      = 16

# Files this test creates in testing/ (the emulator's drive). All prefixed RT_ and cleaned up.
SRC_BAS   = "RT_SRC.BAS"
SRC_PRG   = "RT_SRC.PRG"
OBJ_PRG   = "RT_OBJ.PRG"
WARM_DRV  = "RT_WARM.TXT"
RT_BACKUP = os.path.join(TESTING, "RT_RTBAK.BIN")
GPC_INPUT = os.path.join(TESTING, "GPC.INPUT")
SCRATCH   = [SRC_BAS, SRC_PRG, OBJ_PRG, WARM_DRV, "RT_COMPILE.LOG", "RT_COLD.LOG", "RT_WARM.LOG"]

# GPC.INPUT is a tracked working file; the compile step rewrites it, so snapshot and restore it so
# the test leaves the tree exactly as it found it.
_gpc_input_saved = None

COLD_MARK = b"COLDOK"
WARM_MARK = b"WARMOK"


def die(msg):
    print("  FAIL: " + msg)
    cleanup()
    sys.exit(1)


def cleanup():
    for f in SCRATCH:
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            try: os.remove(p)
            except OSError: pass
    if os.path.exists(RT_BACKUP):
        try: os.remove(RT_BACKUP)
        except OSError: pass
    if _gpc_input_saved is not None:
        with open(GPC_INPUT, "wb") as f:
            f.write(_gpc_input_saved)


def tokenise(bas_text, bas_name, prg_name):
    with open(os.path.join(TESTING, bas_name), "w", newline="\n") as f:
        f.write(bas_text)
    r = subprocess.run([sys.executable, TOKENISE,
                        os.path.join(TESTING, bas_name),
                        os.path.join(TESTING, prg_name)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        die("tokenise failed: " + r.stdout + r.stderr)


def run_emu(extra_args, logname, timeout, until_file=None):
    """Launch x16emu headless. If until_file is given, poll for it to appear and stabilise (the
    compile writes its object); otherwise run for the full timeout (a program run). Always kill by
    PID and return the raw echo log bytes."""
    logpath = os.path.join(TESTING, logname)
    env = dict(os.environ); env["SDL_VIDEODRIVER"] = "dummy"
    args = [EMU, "-rom", ROM, "-fsroot", ".", "-warp"] + extra_args
    lf = open(logpath, "wb")
    p = subprocess.Popen(args, cwd=TESTING, stdout=lf, stderr=subprocess.STDOUT, env=env)
    try:
        if until_file:
            target = os.path.join(TESTING, until_file)
            deadline = time.time() + timeout
            while time.time() < deadline:
                time.sleep(0.4)
                if os.path.exists(target) and os.path.getsize(target) > 0:
                    s1 = os.path.getsize(target); time.sleep(0.4)
                    if os.path.getsize(target) == s1:
                        break
        else:
            time.sleep(timeout)
    finally:
        p.kill()
        try: p.wait(timeout=5)
        except subprocess.TimeoutExpired: pass
        lf.close()
    with open(logpath, "rb") as f:
        return f.read()


# ------------------------------------------------------------------------------------------------
#		Step 1 -- compile in SHARED mode and verify the object's byte layout.
# ------------------------------------------------------------------------------------------------

def compile_shared(marker):
    tokenise('100 print "%s"\n110 stop\n' % marker.decode(), SRC_BAS, SRC_PRG)
    with open(os.path.join(TESTING, "GPC.INPUT"), "w", newline="\n") as f:
        f.write("%s\n%s\n\nSHARED\n" % (SRC_PRG, OBJ_PRG))
    obj = os.path.join(TESTING, OBJ_PRG)
    if os.path.exists(obj): os.remove(obj)
    run_emu(["-prg", "GPC.BLITZ.BIN", "-run"], "RT_COMPILE.LOG", timeout=30, until_file=OBJ_PRG)
    if not os.path.exists(obj):
        die("SHARED compile produced no object (%s)" % OBJ_PRG)
    verify_layout(obj, marker)


def verify_layout(path, marker):
    data = open(path, "rb").read()
    load = data[0] | (data[1] << 8)
    if load != 0x0801:
        die("object load address $%04X, expected $0801" % load)
    body  = data[2:]
    boot  = body[:255]
    pcode = body[255:]
    if len(boot) != 255:
        die("bootstrap is %d bytes, expected 255" % len(boot))
    if (0x0801 + 255) != 0x0900:
        die("p-code does not start at $0900")
    for magic in (b"GPC1", b"GPC.RT.BIN", b"?RT"):
        if magic not in boot:
            die("bootstrap missing %r" % magic)
    # the A/X/Y handoff: LDA #$09 / LDX #WS / LDY #$73 / JMP $7304
    m = boot.find(bytes([0xA9, PCODE_PAGE]))
    if m < 0:
        die("no LDA #PCODE_PAGE in bootstrap")
    seg = boot[m:m + 9]
    a, x, y = seg[1], seg[3], seg[5]
    jmp = seg[7] | (seg[8] << 8)
    if seg[0] != 0xA9 or seg[2] != 0xA2 or seg[4] != 0xA0 or seg[6] != 0x4C:
        die("handoff opcodes wrong: %s" % seg.hex(" "))
    if a != PCODE_PAGE:                 die("handoff A=$%02X, expected $%02X" % (a, PCODE_PAGE))
    if y != (RTBASE >> 8):              die("handoff Y=$%02X, expected $%02X" % (y, RTBASE >> 8))
    if jmp != RTBASE + 4:              die("handoff JMP $%04X, expected $%04X" % (jmp, RTBASE + 4))
    pages = (len(pcode) + 255) // 256
    ws_expected = PCODE_PAGE + pages + FRAME_STACK_PAGES
    if x != ws_expected:
        die("WS_START=$%02X, expected $%02X (9 + %d p-code pages + %d)"
            % (x, ws_expected, pages, FRAME_STACK_PAGES))
    if ws_expected > (RTBASE >> 8) - MIN_WS_PAGES:
        die("WS_START=$%02X should have been rejected as PROGRAM TOO BIG" % ws_expected)
    if marker not in pcode:
        die("p-code does not contain the marker %r" % marker)
    print("  ok: layout -- load $0801, 255-byte bootstrap, p-code @ $0900, "
          "WS_START=$%02X (A=$%02X Y=$%02X JMP $%04X)" % (x, a, y, jmp))


# ------------------------------------------------------------------------------------------------
#		Step 2 -- COLD path: fresh RAM, the bootstrap must load GPC.RT.BIN itself.
# ------------------------------------------------------------------------------------------------

def cold_run(marker):
    log = run_emu(["-zeroram", "-echo", "-prg", OBJ_PRG, "-run"], "RT_COLD.LOG", timeout=6)
    if marker not in log:
        die("COLD: program marker %r never printed (runtime did not come up)" % marker)
    if b"?RT" in log:
        die("COLD: ?RT -- GPC.RT.BIN failed to load")
    print("  ok: COLD -- fresh machine loaded GPC.RT.BIN and ran (%s)" % marker.decode())


# ------------------------------------------------------------------------------------------------
#		Step 3 -- WARM path: make the runtime resident, DELETE it from disk, then run. Success
#		proves the resident copy was reused; a reload would ?RT-fail on the missing file.
# ------------------------------------------------------------------------------------------------

def warm_run(marker):
    rt = os.path.join(TESTING, "GPC.RT.BIN")
    if not os.path.exists(rt):
        die("WARM: GPC.RT.BIN missing before test")
    import shutil
    shutil.copyfile(rt, RT_BACKUP)
    drv = ('LOAD"GPC.RT.BIN",8,1\n'          # make the runtime resident at $7300 (magic set)
           'OPEN15,8,15,"S:GPC.RT.BIN"\n'    # scratch it from the disk...
           'CLOSE15\n'
           'LOAD"%s"\n'                       # ...load the shared program...
           'RUN\n' % OBJ_PRG)                 # ...and run it: it MUST use the resident runtime
    with open(os.path.join(TESTING, WARM_DRV), "w", newline="\n") as f:
        f.write(drv)
    try:
        log = run_emu(["-pastewarp", "-echo", "-bas", WARM_DRV], "RT_WARM.LOG", timeout=9)
        deleted = not os.path.exists(rt)
    finally:
        if not os.path.exists(rt) and os.path.exists(RT_BACKUP):
            shutil.copyfile(RT_BACKUP, rt)     # always restore the runtime
    if not deleted:
        die("WARM: DOS scratch did not remove GPC.RT.BIN -- test would be inconclusive")
    if marker not in log:
        die("WARM: program marker %r never printed" % marker)
    if b"?RT" in log:
        die("WARM: ?RT -- it tried to reload the (deleted) runtime instead of reusing the resident copy")
    print("  ok: WARM -- runtime file scratched, program still ran from the resident copy (%s)"
          % marker.decode())


def main():
    for f, what in ((EMU, "x16emu"), (ROM, "rom.bin"), (TOKENISE, "tokenise.zip"),
                    (os.path.join(TESTING, "GPC.BLITZ.BIN"), "GPC.BLITZ.BIN"),
                    (os.path.join(TESTING, "GPC.RT.BIN"), "GPC.RT.BIN")):
        if not os.path.exists(f):
            die("prerequisite not found: %s (%s) -- build it first (see the Makefile)" % (what, f))
    global _gpc_input_saved
    if os.path.exists(GPC_INPUT):
        _gpc_input_saved = open(GPC_INPUT, "rb").read()
    print("SHARED (resident-runtime) mode regression test")
    compile_shared(COLD_MARK)
    cold_run(COLD_MARK)
    compile_shared(WARM_MARK)
    warm_run(WARM_MARK)
    cleanup()
    print("PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
