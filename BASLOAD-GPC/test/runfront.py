# ************************************************************************************************
# ************************************************************************************************
#
#		Name : 		runfront.py
#		Purpose :	Prove the front end (frontend/BASLOAD.BASL -> BASLOAD.PRG) actually drives
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
#		become three canned answers -- and asserts on every substitution, so the harness cannot
#		quietly test a file that no longer says what it thinks. Everything except the key reader
#		is the real front end: the LOAD guard, the poke of the name, the SYS, the bank dance on
#		return, the message read-back, and the loop that comes round for the next file. The key
#		reader is the one lifted verbatim from GPC.BASL.
#
#		THE ANSWERS ARE A MISSING FILE, THEN A GOOD ONE, THEN NOTHING. The engine replies in the
#		buffer it was asked in -- the message at $bf00 overwrites the name -- so a front end that
#		poked the name once would hand its own error text to the engine as the next file name.
#		Only a bad file followed by a good one can catch that, and it costs one extra pass.
#
#		Two emulator runs, because the variant is BASLOAD source like any other:
#
#		  1. tokenise it, with the ENGINE -- the same driver build.py uses
#		  2. LOAD the result and RUN it, and let it tokenise test/HELLO.BASL through the front
#		     end's own path
#
#		THE VERDICT IS THE SCREEN, not the output file. A run that fails partway still writes a
#		complete, valid, WRONG program, so HELLO.PRG existing proves nothing on its own. Three
#		things have to be on it, in order: an ERROR for the file that is not there, SUCCESS for
#		the one that is, and BYE -- which says the loop came round a third time, took the empty
#		answer and left, rather than hanging in a GET.
#
#		THE RAW BYTES IN THE LOG ARE NOT ON THE SCREEN. x16emu -echo hooks CHROUT, so it also
#		catches everything the engine STREAMS to the output file. build_basl.py sees the same
#		thing with a #SYMFILE dump.
#
# ************************************************************************************************

import os
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
ENGINE = os.path.join(BUILD, "BASLOAD.BIN")
SOURCE = os.path.join(GPCDIR, "frontend", "BASLOAD.BASL")
DRIVE  = os.path.join(BUILD, "fronttest")

VARIANT = "BASLOADT.BASL"           # the fixed-answer front end
VARPRG  = "BASLOADT.PRG"            # ...and what it tokenises to
MISSING = "NOSUCH.BASL"             # the first answer: a file that is deliberately not there
SAMPLE  = "HELLO.BASL"              # the second, the one that should tokenise
OUTPUT  = "HELLO.PRG"               # ...and what HELLO.BASL's own #SAVEAS calls its output
DONE    = "BASLDONE"

#	Run 1: the engine's ABI, exactly as build.py drives it. See BASLOAD-GPC/README.md.
TOKENISE = """10 IF PEEK(1024)=42 THEN 50
20 POKE 1024,42
30 LOAD"BASLOAD.BIN",8,1
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

#	Run 2: nothing but LOAD and RUN. The front end does its own LOAD of the engine from there.
LAUNCH = 'LOAD"{prg}",8\nRUN\n'


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
    src = swap('#SAVEAS "@:BASLOAD.PRG"', '#SAVEAS "@:%s"' % VARPRG, "#SAVEAS line")

    #	The prompt itself. NF is the pass counter, and the three answers are the whole test:
    #	a name that is not there, a name that is, and an empty one to quit.
    #
    #	THE MISSING FILE GOES FIRST ON PURPOSE. The engine answers in the buffer it was asked in
    #	-- the message at $bf00 overwrites the name -- so a front end that poked the name once
    #	would hand its own error text to the engine as the second file name. Asking for a bad
    #	file and then a good one is the only arrangement that can catch that.
    old = 'GOSUB FLUSH.KEYS\nPR$="SOURCE FILE: "\nGOSUB GETNAME\n'
    new = ('REM ---- FIXED ANSWERS, SUBSTITUTED BY test/runfront.py ----\n'
           'NM$=""\n'
           'IF NF=0 THEN NM$="%s"\n'
           'IF NF=1 THEN NM$="%s"\n'
           'NF=NF+1\n' % (MISSING, SAMPLE))
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
    for need in (EMU, ROMBIN, ENGINE, SOURCE, os.path.join(HERE, SAMPLE)):
        if not os.path.exists(need):
            die("missing %s%s" % (need, "  -- run build.py all first" if need == ENGINE else ""))

    if os.path.exists(DRIVE):
        shutil.rmtree(DRIVE)
    os.makedirs(DRIVE)
    shutil.copy(ENGINE, DRIVE)
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

    print("  running it -- it should LOAD the engine and tokenise %s..." % SAMPLE)
    log = emulate(LAUNCH.format(prg=VARPRG), 90, until=lambda: "BYE" in tail(DRIVE))

    if "BYE" not in log:
        die("the front end never reached BYE -- it hung, crashed, or never took the empty\n"
            "               answer. Echo log tail:\n%s" % log[-500:])
    #	The missing file has to be REPORTED, not swallowed: an error the user cannot see is the
    #	failure mode streaming has no fallback for. The engine hands back the drive's own status
    #	line for this one -- "62, FILE NOT FOUND,00,00" -- rather than one of its own messages,
    #	which is why the test looks for that and not for the word ERROR.
    if "FILE NOT FOUND" not in log.split("SUCCESS")[0]:
        die("%s was not reported before the good file. Echo log:\n%s"
            % (MISSING, log[-800:]))
    if "SUCCESS" not in log:
        die("the front end ran but the engine did not report SUCCESS -- so the name was not\n"
            "               re-poked, and the second file was never tokenised. Echo log tail:\n%s"
            % log[-500:])
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
