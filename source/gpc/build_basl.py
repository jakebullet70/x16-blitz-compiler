# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		build_basl.py
#		Purpose:	Build testing/GPC.PRG from source/gpc/GPC.BASL by running BASLOAD headless.
#
# ************************************************************************************************
# ************************************************************************************************
#
#		The GPC front end is written in BASLOAD source (GPC.BASL). BASLOAD is an X16 ROM utility,
#		so there is no host-side tokeniser for it: we tokenise by booting the bundled emulator,
#		"typing"  BASLOAD "GPC.BASL"  at the BASIC prompt, and letting the source's own
#		  #SAVEAS "@:GPC.PRG"  option write the tokenised program to the drive. This replaces the
#		old Prog8/Java build of GPC.PRG (now in source/gpc/old-archive/).
#
#		Headless, exactly like the other emulator-driven steps in this tree (see
#		source/unit-tests/shared-runtime/shared_test.py): SDL_VIDEODRIVER=dummy so the emulator
#		never steals the desktop's keyboard focus, and it is killed by PID -- NEVER by image name,
#		because other projects on this box run x16emu too.
#
# ************************************************************************************************

import os, sys, time, subprocess

HERE    = os.path.dirname(os.path.abspath(__file__))
ROOT    = os.path.abspath(os.path.join(HERE, "..", ".."))
TESTING = os.path.join(ROOT, "testing")
EMU     = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM     = os.path.join(ROOT, "bin", "x16emu", "rom.bin")

SRC    = os.path.join(HERE, "GPC.BASL")   # the canonical source
BASL   = "GPC.BASL"                        # its name on the emulator drive (= testing/)
PRG    = "GPC.PRG"                         # #SAVEAS "@:GPC.PRG" writes this
SYM    = "GPC.SYM"                         # #SYMFILE "@:GPC.SYM" writes this
DRIVER = "GPCBLD.BAS"                      # scratch: the one line we "type" at BASIC
LOG    = "GPCBLD.LOG"                      # scratch: the emulator echo log


def die(msg):
    print("  build_basl: FAIL -- " + msg)
    sys.exit(1)


def main():
    for f, what in ((EMU, "x16emu.exe"), (ROM, "rom.bin"), (SRC, "source/gpc/GPC.BASL")):
        if not os.path.exists(f):
            die("missing %s (%s)" % (what, f))

    # Stage the source onto the emulator drive, and drop a one-line driver that tokenises it.
    with open(SRC, "rb") as a, open(os.path.join(TESTING, BASL), "wb") as b:
        b.write(a.read())
    with open(os.path.join(TESTING, DRIVER), "w", newline="\n") as f:
        f.write('BASLOAD "%s"\n' % BASL)

    # Start from a clean slate so we can poll for the freshly written file (#SAVEAS overwrites,
    # but we want to detect a NEW GPC.PRG, not mistake a stale one for success).
    for f in (PRG, SYM):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            os.remove(p)

    env = dict(os.environ); env["SDL_VIDEODRIVER"] = "dummy"
    args = [EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-pastewarp", "-echo", "-bas", DRIVER]
    logpath = os.path.join(TESTING, LOG)
    target  = os.path.join(TESTING, PRG)

    lf = open(logpath, "wb")
    proc = subprocess.Popen(args, cwd=TESTING, stdout=lf, stderr=subprocess.STDOUT, env=env)
    ok = False
    try:
        deadline = time.time() + 30
        while time.time() < deadline:
            time.sleep(0.4)
            if os.path.exists(target) and os.path.getsize(target) > 0:
                s1 = os.path.getsize(target); time.sleep(0.4)
                if os.path.getsize(target) == s1:      # size stable -> save finished
                    ok = True
                    break
    finally:
        proc.kill()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: pass
        lf.close()

    log = open(logpath, "rb").read()

    # Remove the scratch (keep GPC.BASL / GPC.PRG / GPC.SYM in testing/).
    for f in (DRIVER, LOG):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            try: os.remove(p)
            except OSError: pass

    if not ok:
        die("BASLOAD wrote no %s within 30s -- echo log tail:\n%s"
            % (PRG, log[-400:].decode("latin-1", "replace")))

    data = open(target, "rb").read()
    if len(data) < 3 or data[0] != 0x01 or data[1] != 0x08:
        die("%s does not load at $0801 (first bytes %s)" % (PRG, data[:2].hex()))

    print("  build_basl: OK -- testing/%s (%d bytes, loads $0801) tokenised from GPC.BASL" % (PRG, len(data)))
    sys.exit(0)


if __name__ == "__main__":
    main()
