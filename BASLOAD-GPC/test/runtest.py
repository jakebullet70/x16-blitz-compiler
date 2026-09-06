# ************************************************************************************************
# ************************************************************************************************
#
#		Name : 		runtest.py
#		Purpose :	Prove the RAM-resident BASLOAD works, by tokenising the same source twice --
#				once through the ROM and once through the PRG -- and comparing the output.
#		Date :		6th September 2026
#
# ************************************************************************************************
# ************************************************************************************************
#
#		  python BASLOAD-GPC/test/runtest.py
#
#		PASS means the two tokenised programs are identical. It is the only claim worth
#		testing here: a RAM build that runs but tokenises differently is worse than one that
#		does not run at all.
#
#		THE LAST TWO BYTES ARE EXCLUDED FROM THE COMPARE, and that is not slack. BASLOAD writes
#		two bytes past the end of the program that differ run to run -- source/gpc/build_basl.py
#		documents the same thing and skips its up-to-date check because of it.
#
#		Build first:  python BASLOAD-GPC/build.py prg
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

DRIVE  = os.path.join(GPCDIR, "build", "testdrive")
SOURCE = "HELLO.BASL"
OUTPUT = "HELLO.PRG"
PRG    = os.path.join(GPCDIR, "build", "BASLOAD.PRG")

#	Where build.py links the PRG, and the API's three inputs. $bf00 = 48896, r0L = 2, r0H = 3.
SYS_ADDR  = 0x6000
NAME_ADDR = 0xBF00

#
#	BANK 0, NOT POKE 0,0. Stock X16 BASIC saves and restores the RAM bank around every PEEK and
#	POKE, so POKE 0,0 selects nothing and the file name lands in whichever bank happened to be
#	live. The symptom is silent -- SYS returns cleanly, no output file is written, and $bf00
#	still reads back what you poked. It cost five emulator runs on 6th Sep 2026.
#
#	LOAD inside a BASIC program restarts it AND clears variables, so the re-entry guard is a
#	POKEd byte in golden RAM rather than a variable.
#
DRIVER = """10 IF PEEK(1024)=42 THEN 50
20 POKE 1024,42
30 LOAD"BASLOAD.PRG",8,1
50 B$="{source}"
60 BANK 0
70 FOR I=1 TO LEN(B$):POKE {name}+I-1,ASC(MID$(B$,I,1)):NEXT
80 POKE 2,LEN(B$):POKE 3,8:SYS {sys}
RUN
"""


def die(msg):
	sys.exit("runtest.py: FAIL -- " + msg)


def emulate(driver_text, seconds):
	"""Boot the emulator headless with a pasted BASIC driver. -prg and -bas are alternatives in
	x16emu, not a pair, which is why the driver LOADs the PRG itself."""
	with open(os.path.join(DRIVE, "DRV.BAS"), "w", newline="\n") as f:
		f.write(driver_text)
	out = os.path.join(DRIVE, OUTPUT)
	if os.path.exists(out):
		os.remove(out)
	env = dict(os.environ)
	env["SDL_VIDEODRIVER"] = "dummy"			# never steal the desktop's keyboard focus
	log = os.path.join(DRIVE, "RUN.LOG")
	with open(log, "wb") as lf:
		p = subprocess.Popen([EMU, "-rom", ROMBIN, "-fsroot", ".", "-warp", "-pastewarp",
							  "-sound", "none", "-echo", "-bas", "DRV.BAS"],
							 cwd=DRIVE, stdout=lf, stderr=subprocess.STDOUT, env=env)
		try:
			time.sleep(seconds)
		finally:
			p.kill()								# by PID: other projects run x16emu too
			try:
				p.wait(timeout=5)
			except subprocess.TimeoutExpired:
				pass
	return open(out, "rb").read() if os.path.exists(out) else None


def main():
	for need in (EMU, ROMBIN, PRG, os.path.join(HERE, SOURCE)):
		if not os.path.exists(need):
			die("missing %s%s" % (need, "  -- run build.py prg first" if need == PRG else ""))

	if os.path.exists(DRIVE):
		shutil.rmtree(DRIVE)
	os.makedirs(DRIVE)
	shutil.copy(os.path.join(HERE, SOURCE), DRIVE)
	shutil.copy(PRG, DRIVE)

	print("  tokenising %s through the ROM BASLOAD..." % SOURCE)
	from_rom = emulate('BASLOAD "%s"\n' % SOURCE, 25)
	if from_rom is None:
		die("the ROM BASLOAD wrote no %s -- the fixture is broken, not the PRG" % OUTPUT)
	print("       %d bytes" % len(from_rom))

	print("  tokenising %s through the RAM-resident PRG..." % SOURCE)
	from_prg = emulate(DRIVER.format(source=SOURCE, name=NAME_ADDR, sys=SYS_ADDR), 25)
	if from_prg is None:
		die("the RAM-resident BASLOAD wrote no %s" % OUTPUT)
	print("       %d bytes" % len(from_prg))

	#	Trailing two bytes dropped -- see the header.
	a, b = from_rom[:-2], from_prg[:-2]
	if a != b:
		bad = next(i for i in range(min(len(a), len(b))) if a[i] != b[i]) if len(a) == len(b) \
			else "length %d vs %d" % (len(a), len(b))
		die("the two tokenised programs differ (%s)" % bad)

	print("  PASS -- %d bytes identical, ROM and RAM builds agree" % len(a))


main()
