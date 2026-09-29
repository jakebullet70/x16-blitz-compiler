# ************************************************************************************************
# ************************************************************************************************
#
#		Name : 		runfront.py
#		Purpose :	Prove the front end (frontend/BASLOAD-GPC.BASL -> BASLOAD-GPC.PRG) actually drives
#				the engine: loads it, hands it a name, and reports what came back.
#		Date :		8th September 2026
#
# ************************************************************************************************
# ************************************************************************************************
#
#		  python BASLOAD-GPC/test/runfront.py        (build.py all first)
#
#		AN INTERACTIVE PROGRAM CANNOT BE DRIVEN HEADLESSLY. x16emu -bas types its file at the
#		READY. prompt only; once a program is running the rest of the paste is DROPPED, not
#		queued, so a GET loop never sees it. See docs/memory/paste-cannot-drive-a-running-program.
#
#		So this generates a FIXED-ANSWER VARIANT from the real source -- the three prompt lines
#		become a canned answer -- and asserts on every substitution, so the harness cannot
#		quietly test a file that no longer says what it thinks. Everything except the key reader
#		is the real front end: the LOAD guard, the poke of the name, the SYS, the bank dance on
#		return, and the message read-back. The key reader is the one lifted verbatim from GPC.BASL.
#
#		FOUR BOOTS, ONE ANSWER EACH: a missing file, a file whose #INCLUDE is missing, a good one,
#		and nothing. The front end takes one name a run, so the driver POKEs the answer's number
#		into $0401 before RUN and the variant picks its name from there. The second answer proves
#		a failed include is reported on the right line.
#
#		Five emulator runs, because the variant is BASLOAD source like any other:
#
#		  1.   tokenise it, with the ENGINE -- the same driver build.py uses
#		  2-5. LOAD the result and RUN it, once per answer
#
#		THE VERDICT IS THE SCREEN, not the output file. A run that fails partway still writes a
#		complete, valid, WRONG program, so HELLO.PRG existing proves nothing on its own. Every boot
#		has to reach BYE, the missing file has to be reported, the missing include on its line,
#		and the good file as SUCCESS.
#
#		THE RAW BYTES IN THE LOG ARE NOT ON THE SCREEN. x16emu -echo hooks CHROUT, so it also
#		catches everything the engine STREAMS to the output file. build_basl.py sees the same
#		thing with a #SYMFILE dump.
#
# ************************************************************************************************

import os
import re
import shutil
import subprocess
import sys
import time

HERE   = os.path.dirname(os.path.abspath(__file__))
GPCDIR = os.path.abspath(os.path.join(HERE, ".."))
ROOT   = os.path.abspath(os.path.join(GPCDIR, ".."))
EMUDIR = os.path.join(ROOT, "bin", "x16emu")
EMU    = os.path.join(EMUDIR, "x16emu.exe" if os.name == "nt" else "x16emu")
ROMBIN = os.path.join(EMUDIR, "rom.bin")

BUILD  = os.path.join(GPCDIR, "build")
ENGINE = os.path.join(BUILD, "BASLOAD-GPC.BIN")
SOURCE = os.path.join(GPCDIR, "frontend", "BASLOAD-GPC.BASL")
DRIVE  = os.path.join(BUILD, "fronttest")

VARIANT = "BASLOADT.BASL"           # the fixed-answer front end
VARPRG  = "BASLOADT.PRG"            # ...and what it tokenises to
MISSING = "NOSUCH.BASL"             # the first answer: a file that is deliberately not there
NOINC   = "NOINC.BASL"              # the second: its line-3 #INCLUDE is deliberately not there
SAMPLE  = "HELLO.BASL"              # the third, the one that should tokenise
OUTPUT  = "HELLO.PRG"               # ...and what HELLO.BASL's own #SAVEAS calls its output
DONE    = "BASLDONE"

#	Run 1: the engine's ABI, exactly as build.py drives it. See BASLOAD-GPC/README.md.
TOKENISE = """10 IF PEEK(1024)=42 THEN 50
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

#	Runs 2-5: the answer, then LOAD and RUN. The front end does its own LOAD of the engine.
LAUNCH = 'POKE 1025,{answer}\nLOAD"{prg}",8\nRUN\n'


def die(msg):
    sys.exit("runfront.py: FAIL -- " + msg)


def make_variant():
    """The real source with its two prompts answered in advance. Every edit is asserted."""
    src = open(SOURCE, encoding="utf-8").read()

    def swap(old, new, what):
        if old not in src:
            die("could not find the %s in %s -- the source moved, fix this harness" % (what, SOURCE))
        return src.replace(old, new, 1)

    #	Its own output name, so a test run can never overwrite the shipped front end.
    src = swap('#SAVEAS "@:BASLOAD-GPC.PRG"', '#SAVEAS "@:%s"' % VARPRG, "#SAVEAS line")

    #	The prompt itself. The driver POKEs the answer's number into $0401 before RUN; any
    #	other number is the empty answer.
    old = 'GOSUB FLUSH.KEYS\nPR$="SOURCE FILE: "\nGOSUB GETNAME\n'
    new = ('REM ---- FIXED ANSWERS, SUBSTITUTED BY test/runfront.py ----\n'
           'NM$=""\n'
           'IF PEEK(1025)=1 THEN NM$="%s"\n'
           'IF PEEK(1025)=2 THEN NM$="%s"\n'
           'IF PEEK(1025)=3 THEN NM$="%s"\n' % (MISSING, NOINC, SAMPLE))
    src = swap(old, new, "prompt block")

    with open(os.path.join(DRIVE, VARIANT), "w", newline="\n", encoding="utf-8") as f:
        f.write(src)


def emulate(driver_text, seconds, until=None):
    """Boot headless with a pasted BASIC driver. Returns the echo log. Ends early when until()
    says so, which is what keeps a passing run quick."""
    with open(os.path.join(DRIVE, "DRV.BAS"), "w", newline="\n") as f:
        f.write(driver_text)
    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"            # never steal the desktop's keyboard focus
    logpath = os.path.join(DRIVE, "RUN.LOG")
    lf = open(logpath, "wb")
    #	Killed by PID, NEVER by image name: other projects on this box run x16emu too.
    p = subprocess.Popen([EMU, "-rom", ROMBIN, "-fsroot", ".", "-warp", "-pastewarp",
                          "-sound", "none", "-echo", "-bas", "DRV.BAS"],
                         cwd=DRIVE, stdout=lf, stderr=subprocess.STDOUT, env=env)
    try:
        deadline = time.time() + seconds
        while time.time() < deadline:
            time.sleep(0.3)
            if until and until():
                time.sleep(0.5)                 # let the last write land
                break
    finally:
        p.kill()
        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        lf.close()
    return open(logpath, "rb").read().decode("latin-1", "replace")


def main():
    for need in (EMU, ROMBIN, ENGINE, SOURCE, os.path.join(HERE, NOINC), os.path.join(HERE, SAMPLE)):
        if not os.path.exists(need):
            die("missing %s%s" % (need, "  -- run build.py all first" if need == ENGINE else ""))

    if os.path.exists(DRIVE):
        shutil.rmtree(DRIVE)
    os.makedirs(DRIVE)
    shutil.copy(ENGINE, DRIVE)
    shutil.copy(os.path.join(HERE, NOINC), DRIVE)
    shutil.copy(os.path.join(HERE, SAMPLE), DRIVE)
    make_variant()

    donepath = os.path.join(DRIVE, DONE)
    outpath  = os.path.join(DRIVE, OUTPUT)

    print("  tokenising the fixed-answer front end...")
    emulate(TOKENISE.format(basl=VARIANT, done=DONE), 90,
            until=lambda: os.path.exists(donepath) and os.path.getsize(donepath) > 0)
    msg = ""
    if os.path.exists(donepath):
        msg = open(donepath, "rb").read().decode("latin-1", "replace").strip("\0 \r\n\t")
    if msg != "SUCCESS":
        die("the harness could not tokenise %s (%s)" % (VARIANT, msg or "no answer in 90s"))
    print("       %s, %d bytes" % (VARPRG, os.path.getsize(os.path.join(DRIVE, VARPRG))))

    #	Only now is a stale output dangerous, so clear it here rather than up front.
    if os.path.exists(outpath):
        os.remove(outpath)

    print("  running it once per answer -- each should LOAD the engine and reach BYE...")
    logs = []
    for answer in (1, 2, 3, 0):
        log = emulate(LAUNCH.format(answer=answer, prg=VARPRG), 90,
                      until=lambda: "BYE" in tail(DRIVE))
        if "BYE" not in log:
            die("answer %d never reached BYE -- the front end hung or crashed. Echo log tail:\n%s"
                % (answer, log[-500:]))
        logs.append(log)
    missing_log, noinc_log, sample_log, empty_log = logs

    #	The missing file has to be REPORTED, not swallowed: an error the user cannot see is the
    #	failure mode streaming has no fallback for. The engine hands back the drive's own status
    #	line for this one -- "62, FILE NOT FOUND,00,00" -- rather than one of its own messages,
    #	which is why the test looks for that and not for the word ERROR.
    if "FILE NOT FOUND" not in missing_log:
        die("%s was not reported. Echo log:\n%s" % (MISSING, missing_log[-800:]))
    #	A missing #INCLUDE is reported against the file and line that asked for it.
    lines = re.findall(r"NOINC\.BASL:(\d+)", noinc_log)
    if lines != ["3"]:
        die("%s's missing include should read NOINC.BASL:3, got %s. Echo log:\n%s"
            % (NOINC, lines or "nothing", noinc_log[-800:]))
    if "SUCCESS" not in sample_log:
        die("the front end ran but the engine did not report SUCCESS for %s. Echo log tail:\n%s"
            % (SAMPLE, sample_log[-500:]))
    if "TOKENISING" in empty_log:
        die("the empty answer tokenised something. Echo log tail:\n%s" % empty_log[-500:])
    if not os.path.exists(outpath) or os.path.getsize(outpath) == 0:
        die("SUCCESS on screen but no %s was written" % OUTPUT)
    data = open(outpath, "rb").read()
    if data[:2] != b"\x01\x08":
        die("%s does not load at $0801 (first bytes %s)" % (OUTPUT, data[:2].hex()))

    print("  PASS -- the front end loaded the engine, tokenised %s to %d bytes, and quit"
          % (SAMPLE, len(data)))


def tail(drive):
    """The echo log so far, for the early-exit test. Opened fresh each time: the writer holds it."""
    p = os.path.join(drive, "RUN.LOG")
    if not os.path.exists(p):
        return ""
    with open(p, "rb") as f:
        return f.read().decode("latin-1", "replace")


main()
