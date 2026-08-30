# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		md5_test.py
#		Purpose:	Regression test -- compiled MD5 must agree with interpreted MD5.
#		Created:	30th July 2026
#
# ************************************************************************************************
# ************************************************************************************************
#
#		testing/MD5 is the Commodore BASIC MD5 from Rosetta Code (line 1100's GOTO retargeted --
#		the published listing jumps to a line that does not exist). It is here because it is a
#		brutal end-to-end test of the compiler: 32-bit integer arithmetic built out of floats,
#		hex literals, DEF FN, arrays, string handling, GOSUB depth and file I/O, and a single
#		wrong bit anywhere changes the digest completely. It found four real bugs:
#
#			the sign packed into mantissa bit 31 of the .float operand, the math constants and
#			the polynomial coefficients;  hex literals truncated to 16 bits, so $10000 was 0;
#			LINPUT not waiting for input;  and LINPUT not ending the typed line.
#
#		WHAT IS ASSERTED: that COMPILED and INTERPRETED agree. That is the property that matters --
#		the compiler must do what the ROM does. The digest is checked against hashlib too, since
#		it is free, but a disagreement between the two X16 runs is the real failure.
#
#		HOW THE INPUT IS FED: the program prompts with LINPUT and there is no stdin into the
#		emulator. x16emu's -bas does not merely load a listing -- it types the file in as
#		keystrokes, and it KEEPS FEEDING THEM AFTER THE PROGRAM STARTS. So a driver of
#		LOAD / RUN / <filename> / N drives the whole interactive path with nobody at the keyboard,
#		which means this exercises LINPUT for real rather than patching the prompt out.
#
#		The emulator is launched with SDL_VIDEODRIVER=dummy so it never steals the desktop's
#		keyboard focus, and each run is killed by PID -- never by image name, because other
#		projects on this box run x16emu too.
#
# ************************************************************************************************

import os, re, sys, time, hashlib, subprocess

ROOT    = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TESTING = os.path.join(ROOT, "testing")
EMU     = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM     = os.path.join(ROOT, "bin", "x16emu", "rom.bin")

SOURCE  = "MD5"                     # the BASIC program, tracked in testing/
OBJECT  = "C.MD5"                   # what GPC compiles it to (regenerated here)
MAPFILE = "M.MD5"
FIXTURE = "MD5FIX.DAT"              # the bytes we hash

#	43 bytes, fixed, no line ending -- the digest must not depend on the host's newline style.
FIXTURE_BYTES = b"The quick brown fox jumps over the lazy dog"

SCRATCH = [OBJECT, MAPFILE, FIXTURE, "MD5DRV.TXT", "MD5C.LOG", "MD5I.LOG", "MD5B.LOG"]
DIGEST  = re.compile(rb"[0-9A-F]{32}")

_gpc_input_saved = None


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
    if _gpc_input_saved is not None:
        with open(os.path.join(TESTING, "GPC.INPUT"), "wb") as f:
            f.write(_gpc_input_saved)


def run_emu(extra_args, logname, timeout, until=None):
    """Launch x16emu headless and return the raw echo log. If `until` is given, stop as soon as it
    appears in the log; otherwise run the full timeout."""
    logpath = os.path.join(TESTING, logname)
    env = dict(os.environ); env["SDL_VIDEODRIVER"] = "dummy"
    args = [EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-sound", "none",
            "-echo", "raw"] + extra_args
    lf = open(logpath, "wb")
    p = subprocess.Popen(args, cwd=TESTING, stdout=lf, stderr=subprocess.STDOUT, env=env)
    try:
        deadline = time.time() + timeout
        while time.time() < deadline:
            time.sleep(0.5)
            if until:
                try:
                    with open(logpath, "rb") as f:
                        if until in f.read():
                            time.sleep(1.0)        # let the last line land
                            break
                except OSError:
                    pass
    finally:
        p.kill()
        try: p.wait(timeout=5)
        except subprocess.TimeoutExpired: pass
        lf.close()
    with open(logpath, "rb") as f:
        return f.read()


def compile_md5():
    """GPC.BIN reads GPC.INPUT: source, object, map, mode."""
    global _gpc_input_saved
    gi = os.path.join(TESTING, "GPC.INPUT")
    if os.path.exists(gi) and _gpc_input_saved is None:
        with open(gi, "rb") as f:
            _gpc_input_saved = f.read()
    with open(gi, "w", newline="\n") as f:
        f.write("%s\n%s\n%s\n\n" % (SOURCE, OBJECT, MAPFILE))
    for f in (OBJECT, MAPFILE):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            os.remove(p)
    run_emu(["-prg", "GPC.BIN", "-run"], "MDB.LOG".replace("MDB", "MD5B"), 90, until=b"OK")
    if not os.path.exists(os.path.join(TESTING, OBJECT)):
        die("compile produced no " + OBJECT)


def hash_with(program, logname):
    """Drive one run of `program` through the prompt and return the digest it printed.

    The driver is typed in as keystrokes: LOAD, RUN, the filename the program asks for, then N to
    decline "ANOTHER FILE?". -bas keeps feeding while the program runs, which is what lets this
    answer a LINPUT prompt."""
    with open(os.path.join(TESTING, "MD5DRV.TXT"), "w", newline="\n") as f:
        f.write('LOAD "%s"\nRUN\n%s\nN\n' % (program, FIXTURE))
    log = run_emu(["-bas", "MD5DRV.TXT", "-pastewarp"], logname, 240, until=b"JIFFIES")
    found = DIGEST.findall(log)
    if not found:
        die("%s printed no digest (see testing/%s)" % (program, logname))
    return found[0].decode()


def main():
    for f, what in ((EMU, "emulator"), (ROM, "ROM"),
                    (os.path.join(TESTING, SOURCE), "testing/" + SOURCE),
                    (os.path.join(TESTING, "GPC.BIN"), "testing/GPC.BIN")):
        if not os.path.exists(f):
            die("missing %s: %s" % (what, f))

    with open(os.path.join(TESTING, FIXTURE), "wb") as f:
        f.write(FIXTURE_BYTES)
    expected = hashlib.md5(FIXTURE_BYTES).hexdigest().upper()

    print("  md5: compiling %s ..." % SOURCE)
    compile_md5()
    print("  md5: running compiled ...")
    compiled = hash_with(OBJECT, "MD5C.LOG")
    print("  md5: running interpreted ...")
    interpreted = hash_with(SOURCE, "MD5I.LOG")

    print("    compiled    %s" % compiled)
    print("    interpreted %s" % interpreted)
    print("    hashlib     %s" % expected)

    if compiled != interpreted:
        die("compiled and interpreted DISAGREE -- the compiler does not match the ROM")
    if compiled != expected:
        die("both X16 runs agree but the digest is wrong (expected %s)" % expected)

    cleanup()
    print("  md5: PASS")


main()
