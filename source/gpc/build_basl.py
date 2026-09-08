# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		build_basl.py
#		Purpose:	Tokenise testing/GPC.BASL to testing/GPC.SRC.PRG by running BASLOAD
#				headless. GPC.SRC.PRG is then COMPILED into GPC.PRG -- see the Makefile.
#				With args "BASL PRG" it instead tokenises that one extra tool the same way
#				(no source mirror) -- used to freshen GPC.ERR.PRG on a release.
#
# ************************************************************************************************
# ************************************************************************************************
#
#		The GPC front end is written in BASLOAD source (GPC.BASL). BASLOAD is an X16 ROM utility,
#		so there is no host-side tokeniser for it: we tokenise by booting the bundled emulator and
#		letting the source's own  #SAVEAS "@:GPC.PRG"  option write the tokenised program to the
#		drive. This replaces the old Prog8/Java build of GPC.PRG (now in source/gpc/old-archive/).
#
#		NOT THE ROM BASLOAD ANY MORE. The ROM build assembles the tokenised program in BASIC RAM,
#		which capped a .BASL plus every #INCLUDE it pulls in at 38,655 bytes -- and it truncated
#		SILENTLY, printing SAVING and writing a short file before reporting the error. BASLOAD-GPC
#		is the same source built as a RAM-resident PRG that streams each line to the output file as
#		it finishes it, so the ceiling is the disk. See BASLOAD-GPC/README.md.
#
#		That costs one thing: the ROM's  BASLOAD "X"  command printed its own result, and a PRG
#		cannot. BASLOAD leaves a NUL-terminated message at $bf00 in bank 0 and the CALLER reports
#		it, so the driver below writes that message to a sentinel file and this script reads it.
#		The sentinel is also how we know the run finished -- see tokenise().
#
#		DIRECTION: the MASTER copy is testing/GPC.BASL -- that is where the front end is edited
#		and interactively BASLOAD-tested (testing/ is the emulator's drive). This build tokenises
#		it IN PLACE and, on success, mirrors it back into the source tree (source/gpc/GPC.BASL)
#		so the committed copy always matches what was last built. On a fresh checkout with no
#		testing/GPC.BASL, the committed mirror is used to seed it.
#
#		BUILD NUMBER: none here. It belongs to the ENGINE now -- source/application/buildnum.txt,
#		bumped by source/application/scripts/bumpbuild.py on every engine build and printed by
#		GPC.BIN next to "GPC SQUEALING...". A front-end counter could not answer the only
#		question a build number is read for ("which compiler am I running?"), because it moved
#		when the front end was rebuilt and stood still when the compiler changed.
#
#		EXTRA TOOLS: run  build_basl.py GPC.ERR.BASL GPC.ERR.PRG  to tokenise a companion tool the
#		same headless way. These live only in testing/ (no source/ mirror), so this mode just
#		tokenises -- no mirror. It skips when the source is absent, and when the PRG is already up
#		to date, which is now an optimisation rather than a necessity: the ROM build wrote two
#		nondeterministic bytes past the program's end marker, so re-tokenising an unchanged source
#		churned them. The streaming build stops at the end marker and its output is byte for byte
#		the same every time. The Makefile's "release" target uses it to freshen GPC.ERR.PRG.
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

MASTER = os.path.join(TESTING, "GPC.BASL")  # the master you edit + interactively BASLOAD-test
MIRROR = os.path.join(HERE, "GPC.BASL")     # committed mirror in the source tree, kept in sync
BASL   = "GPC.BASL"                          # its name on the emulator drive (= testing/)
PRG    = "GPC.SRC.PRG"                       # #SAVEAS "@:GPC.SRC.PRG" writes this
SYM    = "GPC.SRC.SYM"                       # #SYMFILE "@:GPC.SRC.SYM" writes this
DRIVER = "GPCBLD.BAS"                        # scratch: the BASIC driver we "type" at the prompt
LOG    = "GPCBLD.LOG"                        # scratch: the emulator echo log
DONE   = "BASLDONE"                          # scratch: the driver writes BASLOAD's message here

#	The streaming tokeniser. BASLOAD-GPC/build/ is the dev copy, rebuilt by BASLOAD-GPC/build.py;
#	testing/ carries the shipped one beside GPC.BIN, so a fresh checkout with no cc65 still builds.
#	The dev copy wins when it exists, which is what keeps an edit to the fork from being ignored.
#
#	TWO FILES, not one. BASLOAD-GPC.BIN is the engine and the only thing this script calls -- it pokes
#	the name and SYSes, the same as any other caller. BASLOAD-GPC.PRG is the FRONT END, which does
#	that from a prompt instead; nothing here needs it, but testing/ is the emulator's drive and the
#	release directory, so the tool a person runs belongs next to the one the build runs.
BASLOAD_FILES = ("BASLOAD-GPC.BIN", "BASLOAD-GPC.PRG")
BASLOAD_BUILT = os.path.join(ROOT, "BASLOAD-GPC", "build", "BASLOAD-GPC.BIN")
BASLOAD_DRIVE = os.path.join(TESTING, "BASLOAD-GPC.BIN")

#
#	The API is three inputs and one output, all in RAM bank 0 -- see BASLOAD-GPC/README.md.
#
#	  $bf00  the source file name, and afterwards the NUL-terminated result message
#	  r0L/$02  name length     r0H/$03  device     SYS $6000  go
#
#	BANK 0, NOT POKE 0,0. X16 BASIC saves and restores the RAM bank around every PEEK and POKE, so
#	POKE 0,0 selects nothing and the name lands in whichever bank was live. The symptom is silent:
#	SYS returns cleanly, no file is written, and $bf00 still reads back what you poked. BASLOAD
#	also leaves bank 1 selected on return, so line 90 selects bank 0 again before reading $bf00.
#
#	LOAD inside a BASIC program restarts it AND clears variables, so the re-entry guard is a POKEd
#	byte in golden RAM rather than a variable.
#
DRIVER_TEXT = """10 IF PEEK(1024)=42 THEN 50
20 POKE 1024,42
30 LOAD"BASLOAD-GPC.BIN",8,1
50 B$="{basl}"
60 BANK 0
70 FOR I=1 TO LEN(B$):POKE 48896+I-1,ASC(MID$(B$,I,1)):NEXT
80 POKE 2,LEN(B$):POKE 3,8:SYS 24576
90 BANK 0:R$=""
100 FOR I=0 TO 79:C=PEEK(48896+I):IF C=0 THEN 120
110 R$=R$+CHR$(C):NEXT
120 OPEN 13,8,13,"@:{done},S,W":PRINT#13,R$:CLOSE 13
130 PRINT"BASLOAD:";R$
RUN
"""


def die(msg):
    print("  build_basl: FAIL -- " + msg)
    sys.exit(1)


#
#   There is deliberately no bump_version() here any more. The build number moved to the ENGINE
#   (source/application/buildnum.txt, printed by GPC.BIN and bumped by its own
#   scripts/bumpbuild.py). Bumping it here was actively misleading: it moved when the front end
#   was rebuilt, which is almost never, and stayed put when the compiler changed -- so it could
#   not answer "which engine am I running?", the only thing anyone reads a build number for.
#


#
#   A FILE THAT EXISTS AND LOADS AT $0801 IS NOT EVIDENCE OF A GOOD TOKENISE, and it never was.
#   The ROM BASLOAD printed SAVING and wrote a TRUNCATED program before reporting BASIC RAM FULL;
#   the streaming build has no such ceiling, but a run that fails partway has still written every
#   line up to the failure and closed the file with a valid end marker. GPC compiles that happily.
#   BASLOAD's own message is the only thing that distinguishes the two, so it is what gets checked.
#
#   THE CHECK IS POSITIVE, not the absence of the word ERROR. The driver writes BASLOAD's result
#   message to a sentinel file, and only the literal "SUCCESS" lets the build continue. That also
#   makes the sentinel the completion signal: an emulator that crashed, hung or never reached the
#   SYS leaves no sentinel, which used to be indistinguishable from a slow save.
#
#   Reading a file rather than the echo log is deliberate. The log carries the #SYMFILE dump --
#   the user's own symbol names, which could contain anything -- and wraps at 80 columns, which
#   would split a long message across lines. BASLOAD's nineteen return codes are listed in
#   testing/MSEDIT/BASLOAD.MD.
#
def read_response(path):
    """BASLOAD's result message from the sentinel, or "" if the run never got that far."""
    if not os.path.exists(path):
        return ""
    return open(path, "rb").read().decode("latin-1", "replace").strip("\0 \r\n\t")


def stage_basload():
    """Put the streaming BASLOAD on the emulator's drive, preferring the dev build over the
    shipped one so an edit to BASLOAD-GPC/src/ cannot be silently ignored. The front end rides
    along when it has been built; only the engine is required."""
    devdir = os.path.dirname(BASLOAD_BUILT)
    for name in BASLOAD_FILES:
        src = os.path.join(devdir, name)
        dst = os.path.join(TESTING, name)
        if not os.path.exists(src):
            continue
        built = open(src, "rb").read()
        drive = open(dst, "rb").read() if os.path.exists(dst) else None
        if built != drive:
            with open(dst, "wb") as f:
                f.write(built)
            print("  build_basl: staged BASLOAD-GPC/build/%s -> testing/ (%d bytes)"
                  % (name, len(built)))
    if not os.path.exists(BASLOAD_DRIVE):
        die("no BASLOAD-GPC.BIN in testing/ or BASLOAD-GPC/build/ -- run:\n"
            "               python BASLOAD-GPC/build.py prg")


def tokenise(basl_name, prg_name, also_clean=()):
    """Boot the emulator headless, load BASLOAD-GPC.BIN and SYS it at <basl_name>, so the source's own
    #SAVEAS writes testing/<prg_name>. Returns the tokenised PRG's bytes; dies on failure.
    also_clean lists extra outputs (e.g. a #SYMFILE) to remove up front so a stale one can't fake
    success."""
    stage_basload()

    with open(os.path.join(TESTING, DRIVER), "w", newline="\n") as f:
        f.write(DRIVER_TEXT.format(basl=basl_name, done=DONE))

    #   Start from a clean slate. #SAVEAS overwrites, but a stale PRG from an earlier run must not
    #   be able to stand in for a new one -- and the sentinel especially, since it IS the verdict.
    for f in (prg_name, DONE) + tuple(also_clean):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            os.remove(p)

    env = dict(os.environ); env["SDL_VIDEODRIVER"] = "dummy"
    args = [EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-pastewarp", "-echo", "-bas", DRIVER]
    logpath  = os.path.join(TESTING, LOG)
    donepath = os.path.join(TESTING, DONE)
    target   = os.path.join(TESTING, prg_name)

    #
    #   WAIT FOR THE SENTINEL, NOT FOR THE OUTPUT FILE. The old wait watched <prg_name> for a
    #   stable size, which worked when BASLOAD SAVEd in one go. Streaming writes it a line at a
    #   time over several seconds, so any pause -- an #INCLUDE being opened, say -- looks exactly
    #   like a finished save. The sentinel is written once, after BASLOAD has returned.
    #
    #   The budget is generous because it is not a polling cost: the wait ends the moment the
    #   sentinel appears, so a two-second tokenise still takes two seconds.
    #
    lf = open(logpath, "wb")
    proc = subprocess.Popen(args, cwd=TESTING, stdout=lf, stderr=subprocess.STDOUT, env=env)
    try:
        deadline = time.time() + 180
        while time.time() < deadline:
            time.sleep(0.4)
            if os.path.exists(donepath) and os.path.getsize(donepath) > 0:
                time.sleep(0.4)                        # let the CLOSE land
                break
    finally:
        proc.kill()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: pass
        lf.close()

    log      = open(logpath, "rb").read()
    response = read_response(donepath)

    for f in (DRIVER, LOG, DONE):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            try: os.remove(p)
            except OSError: pass

    #   Checked BEFORE the "did a file appear" test, because on a failure partway through one did,
    #   and it is a complete, valid, WRONG program.
    if not response:
        die("BASLOAD never reported back within 180s -- it crashed, hung, or never reached the\n"
            "               SYS. No %s was produced. Echo log tail:\n%s"
            % (prg_name, log[-400:].decode("latin-1", "replace")))
    if response != "SUCCESS":
        die("BASLOAD said %s -- %s stops where the error did, do not compile it"
            % (response, prg_name))

    if not os.path.exists(target) or os.path.getsize(target) == 0:
        die("BASLOAD reported SUCCESS but wrote no %s -- check the #SAVEAS name" % prg_name)

    data = open(target, "rb").read()
    if len(data) < 3 or data[0] != 0x01 or data[1] != 0x08:
        die("%s does not load at $0801 (first bytes %s)" % (prg_name, data[:2].hex()))
    return data


def build_front_end():
    """The GPC.BASL flow: seed the master from the mirror if missing, tokenise to GPC.SRC.PRG, then
    mirror the master back to source/gpc/GPC.BASL. The build number is the engine's job now --
    see source/application/scripts/bumpbuild.py."""
    if not os.path.exists(MASTER):
        if not os.path.exists(MIRROR):
            die("no GPC.BASL in testing/ or source/gpc/ -- nothing to build")
        with open(MIRROR, "rb") as a, open(MASTER, "wb") as b:
            b.write(a.read())
        print("  build_basl: seeded testing/GPC.BASL from source/gpc/GPC.BASL")

    data = tokenise(BASL, PRG, also_clean=(SYM,))

    # Mirror the master back into the source tree so the committed source/gpc/GPC.BASL always
    # matches what was last built. Only write when it actually changed (avoid mtime/git churn).
    master_bytes = open(MASTER, "rb").read()
    mirror_bytes = open(MIRROR, "rb").read() if os.path.exists(MIRROR) else None
    mirrored = master_bytes != mirror_bytes
    if mirrored:
        with open(MIRROR, "wb") as b:
            b.write(master_bytes)

    print("  build_basl: OK -- testing/%s (%d bytes, loads $0801) tokenised from testing/GPC.BASL"
          % (PRG, len(data)))
    if mirrored:
        print("             mirrored testing/GPC.BASL -> source/gpc/GPC.BASL")


def build_tool(basl_name, prg_name):
    """Tokenise a companion tool (e.g. GPC.ERR.BASL -> GPC.ERR.PRG) that lives only in testing/.
    No version bump, no source mirror. "If needed": skip when the source is absent, or when the
    PRG is already at least as new as its source -- an emulator boot saved, nothing more, now that
    the streaming build's output is byte for byte identical run to run."""
    basl = os.path.join(TESTING, basl_name)
    prg  = os.path.join(TESTING, prg_name)
    if not os.path.exists(basl):
        print("  build_basl: skip -- no testing/%s (nothing to tokenise for %s)" % (basl_name, prg_name))
        return
    if os.path.exists(prg) and os.path.getmtime(prg) >= os.path.getmtime(basl):
        print("  build_basl: skip -- testing/%s is up to date (source no newer)" % prg_name)
        return
    sym = os.path.splitext(prg_name)[0] + ".SYM"    # a #SYMFILE, if any, sits beside the PRG
    data = tokenise(basl_name, prg_name, also_clean=(sym,))
    print("  build_basl: OK -- testing/%s (%d bytes, loads $0801) tokenised from testing/%s"
          % (prg_name, len(data), basl_name))


def main():
    for f, what in ((EMU, "x16emu.exe"), (ROM, "rom.bin")):
        if not os.path.exists(f):
            die("missing %s (%s)" % (what, f))
    if len(sys.argv) >= 3:
        build_tool(sys.argv[1], sys.argv[2])
    else:
        build_front_end()
    sys.exit(0)


if __name__ == "__main__":
    main()
