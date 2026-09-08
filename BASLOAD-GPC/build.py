# ************************************************************************************************
# ************************************************************************************************
#
#		Name : 		build.py
#		Purpose :	Build BASLOAD from the vendored upstream source -- as the ROM bank it
#				normally is, and as an ordinary RAM-resident PRG.
#		Date :		6th September 2026
#
# ************************************************************************************************
# ************************************************************************************************
#
#		Three targets out of ONE source tree, plus the launcher that drives them:
#
#		  rom    conf/basload-rom.cfg   16,384 bytes, loads at $c000 in ROM bank 15
#		  prg    conf/basload-prg.cfg   BASLOAD.BIN -- the engine, loads and runs at $6000
#		  front  frontend/BASLOAD.BASL  BASLOAD.PRG -- the front end you actually launch
#
#		The prg target is the whole point of this folder -- see README.md. There is no source
#		diff between it and the rom target and there is not meant to be one: everything
#		ROM-specific in BASLOAD is already RAM-resident (the bridge copies itself to golden
#		RAM), so the difference is a linker config and nothing else.
#
#		BASLOAD.BIN, NOT BASLOAD.PRG. The engine's only interface is an ABI -- name at $bf00,
#		length in r0L, device in r0H, SYS $6000 -- so the name a person types has to belong to
#		the front end, exactly as GPC.PRG and GPC.BIN divide it. The front target tokenises
#		that front end WITH THE ENGINE IT JUST BUILT, which also exercises the fork end to end.
#
#		  python BASLOAD-GPC/build.py [rom|prg|front|all]      default: all
#
#		THE FORK IS AN OVERLAY, NOT A PATCH SET. upstream/ stays exactly as it was vendored and
#		src/ holds a whole copy of each file we changed, so
#
#		  diff BASLOAD-GPC/upstream/line.inc BASLOAD-GPC/src/line.inc
#
#		is the fork, in full, with no tooling. Each build copies upstream/ to build/work/, drops
#		src/ over it and assembles there, which also means a half-finished edit can never leave
#		the vendored tree dirty. Every changed hunk sits inside a ;=== GPC begin/end === banner.
#
#		VERIFY is the reason the rom target exists at all. It rebuilds the bank and diffs it
#		against bank 15 of bin/x16emu/rom.bin, which answers "is the vendored source actually
#		what is running?" -- and on 6th Sep 2026 the answer was yes, to within seven bytes of
#		signature string. Re-run it after every upstream pull.
#
#		cc65, NOT 64tass. BASLOAD is a cc65 project and the rest of this repo is not, so the
#		toolchain is found here rather than assumed to be on PATH -- like 64tass and python,
#		it lives off-PATH in C:\8bitProgramming.
#
# ************************************************************************************************

import os
import shutil
import subprocess
import sys
import time

HERE     = os.path.dirname(os.path.abspath(__file__))
ROOT     = os.path.abspath(os.path.join(HERE, ".."))
UPSTREAM = os.path.join(HERE, "upstream")
SRC      = os.path.join(HERE, "src")
BUILD    = os.path.join(HERE, "build")
WORK     = os.path.join(BUILD, "work")      # upstream + src: the fork, and what ships
STOCK    = os.path.join(BUILD, "stock")     # upstream alone: what the rom target checks
ROM      = os.path.join(ROOT, "bin", "x16emu", "rom.bin")

#	The bank BASLOAD occupies. conf/basload-rom.cfg says bank=$0f, and grepping rom.bin for
#	"BASIC RAM FULL" lands at offset 252,527 -- inside bank 15. Both agree, so this is not a guess.
BANK      = 15
BANK_SIZE = 16384

#	Where the PRG is linked. NOT $0801: BASLOAD builds its output upward from there, so a
#	RAM-resident build has to stand clear of the program it is writing. $6000 leaves ~22K of
#	output space, which is LESS than the 38,655 the ROM build gets -- the RAM build only stops
#	costing headroom once the output streams to a file instead of accumulating in BASIC RAM.
#	See RESEARCH.md, "What this does not fix on its own".
PRG_ADDR = 0x6000

CC65 = os.environ.get("CC65_HOME", r"C:\8bitProgramming\cc65")
CL65 = os.path.join(CC65, "bin", "cl65.exe" if os.name == "nt" else "cl65")

#	The front end. Its source is BASLOAD source, so tokenising it needs a running X16 -- the same
#	bundled emulator every other BASL step in this tree drives (source/gpc/build_basl.py).
FRONTEND  = os.path.join(HERE, "frontend")
FRONT_DIR = os.path.join(BUILD, "frontdrive")	# the emulator's drive for that one run
EMU       = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe" if os.name == "nt" else "x16emu")
ENGINE    = "BASLOAD.BIN"
FRONT_SRC = "BASLOAD.BASL"
FRONT_PRG = "BASLOAD.PRG"						# frontend/BASLOAD.BASL says #SAVEAS "@:BASLOAD.PRG"
DONE      = "BASLDONE"							# the driver writes BASLOAD's own message here


def die(msg):
	sys.exit("build.py: " + msg)


def overlay(tree, with_src):
	"""Lay out a tree to assemble in. Rebuilt from scratch every time, so a file removed from src/
	goes back to being upstream's on the very next build, with nothing to undo.

	THE ROM TARGET TAKES with_src=False ON PURPOSE. Its job is to answer "is the vendored source
	actually what the ROM runs", and it can only answer that about a tree we have not touched."""
	if os.path.exists(tree):
		shutil.rmtree(tree)
	shutil.copytree(UPSTREAM, tree)
	if not with_src:
		return
	forked = []
	for name in sorted(os.listdir(SRC)) if os.path.isdir(SRC) else []:
		path = os.path.join(SRC, name)
		if not os.path.isfile(path):
			continue
		#	A src/ file that overlays nothing is a typo, not a new feature: main.asm includes a
		#	fixed list, so a misspelt name would be copied in and then silently never assembled.
		if not os.path.exists(os.path.join(UPSTREAM, name)):
			die("src/%s overlays nothing -- upstream has no file by that name" % name)
		shutil.copy(path, os.path.join(tree, name))
		forked.append(name)
	print("  fork %s" % (", ".join(forked) if forked else "(none -- building stock upstream)"))


def run(tree, cfg, out, mapfile):
	"""cl65 over main.asm with the given linker config. Every include is pulled in by main.asm,
	so there is exactly one translation unit and no link order to get wrong."""
	if not os.path.exists(CL65):
		die("no cl65 at %s -- set CC65_HOME, or install the cc65 Windows snapshot" % CL65)
	args = [CL65, "-o", out, "--cpu", "65C02", "-t", "none",
			"-C", cfg, "-m", mapfile, "main.asm"]
	r = subprocess.run(args, cwd=tree, capture_output=True, text=True)
	if r.returncode != 0:
		die("cl65 failed:\n" + (r.stdout or "") + (r.stderr or ""))
	#	cl65 leaves the object beside the source; the Makefile deletes it and so do we.
	stray = os.path.join(tree, "main.o")
	if os.path.exists(stray):
		os.remove(stray)


def build_rom():
	overlay(STOCK, with_src=False)
	out = os.path.join(BUILD, "basload-rom.bin")
	run(STOCK, os.path.join(STOCK, "conf", "basload-rom.cfg"), out,
		os.path.join(BUILD, "basload-rom.map"))
	print("  rom  %s (%d bytes)" % (os.path.basename(out), os.path.getsize(out)))
	verify(out)


def verify(built):
	"""Diff the rebuilt bank against the one in the emulator's ROM."""
	if not os.path.exists(ROM):
		print("       (no bin/x16emu/rom.bin -- skipped the compare)")
		return
	with open(ROM, "rb") as f:
		f.seek(BANK * BANK_SIZE)
		shipped = f.read(BANK_SIZE)
	with open(built, "rb") as f:
		ours = f.read()
	diff = [i for i in range(min(len(shipped), len(ours))) if shipped[i] != ours[i]]
	if not diff:
		print("       identical to rom.bin bank %d" % BANK)
		return
	#
	#	SEVEN BYTES AT $fff0-$fff6 IS THE EXPECTED ANSWER, and it is not a version skew: it is
	#	the signature string, lowercase "basload" in the shipped ROM and upper case in the
	#	source. Anything else means the vendored source is not what is running.
	#
	lo, hi = 0xC000 + diff[0], 0xC000 + diff[-1]
	expected = (len(diff) == 7 and lo == 0xFFF0 and hi == 0xFFF6)
	print("       %d bytes differ, $%04X..$%04X%s"
		  % (len(diff), lo, hi, "  (the signature string's case -- expected)" if expected
			 else "  *** UNEXPECTED -- the vendored source is not what rom.bin runs ***"))


def build_prg():
	raw = os.path.join(BUILD, "basload-prg.raw")
	overlay(WORK, with_src=True)
	run(WORK, os.path.join(HERE, "conf", "basload-prg.cfg"), raw,
		os.path.join(BUILD, "basload-prg.map"))
	#	A PRG is the load address little-endian, then the image. cl65 emits the image alone.
	#	.BIN, not .PRG: this is the engine, called through an ABI. BASLOAD.PRG is the front end.
	out = os.path.join(BUILD, ENGINE)
	with open(out, "wb") as f:
		f.write(bytes([PRG_ADDR & 0xFF, PRG_ADDR >> 8]))
		with open(raw, "rb") as g:
			f.write(g.read())
	os.remove(raw)
	print("  prg  %s (%d bytes, loads $%04X, SYS %d)"
		  % (os.path.basename(out), os.path.getsize(out), PRG_ADDR, PRG_ADDR))


#
#	THE DRIVER. Typed at the READY. prompt, it is the engine's ABI written out in BASIC: name to
#	$bf00 in bank 0, length to r0L, device to r0H, SYS $6000. The front end being built does the
#	same thing from a prompt -- see frontend/BASLOAD.BASL.
#
#	BANK 0, NOT POKE 0,0. X16 BASIC saves and restores the RAM bank around every PEEK and POKE, so
#	POKE 0,0 selects nothing and the name lands in whichever bank was live; the symptom is silent.
#	LOAD inside a running program restarts it AND clears variables, so the re-entry guard is a
#	POKEd byte. Line 90 re-selects bank 0 because BASLOAD returns with bank 1 live.
#
DRIVER_TEXT = """10 IF PEEK(1024)=42 THEN 50
20 POKE 1024,42
30 LOAD"{engine}",8,1
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


def build_front():
	"""Tokenise frontend/BASLOAD.BASL into build/BASLOAD.PRG, the launcher a person runs.

	IT IS TOKENISED BY THE ENGINE THIS SCRIPT JUST BUILT, not by the ROM's BASLOAD. Two reasons.
	The ROM command prints its result and a script would have to scrape the screen for it, whereas
	the PRG leaves a message at $bf00 that the driver can write to a sentinel file -- and that
	sentinel is also how we know the run finished, rather than guessing at a sleep. And a front end
	built by the engine it fronts is one more end-to-end exercise of the fork on every build."""
	engine = os.path.join(BUILD, ENGINE)
	src    = os.path.join(FRONTEND, FRONT_SRC)
	for need in (engine, src, EMU, ROM):
		if not os.path.exists(need):
			die("missing %s%s" % (need, "  -- run build.py prg first" if need == engine else ""))

	if os.path.exists(FRONT_DIR):
		shutil.rmtree(FRONT_DIR)
	os.makedirs(FRONT_DIR)
	shutil.copy(engine, FRONT_DIR)
	shutil.copy(src, FRONT_DIR)
	with open(os.path.join(FRONT_DIR, "DRV.BAS"), "w", newline="\n") as f:
		f.write(DRIVER_TEXT.format(engine=ENGINE, basl=FRONT_SRC, done=DONE))

	env = dict(os.environ)
	env["SDL_VIDEODRIVER"] = "dummy"		# never steal the desktop's keyboard focus
	args = [EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-pastewarp", "-sound", "none",
			"-echo", "-bas", "DRV.BAS"]
	done = os.path.join(FRONT_DIR, DONE)
	log  = open(os.path.join(FRONT_DIR, "RUN.LOG"), "wb")
	#	Killed by PID, NEVER by image name: other projects on this box run x16emu too.
	proc = subprocess.Popen(args, cwd=FRONT_DIR, stdout=log, stderr=subprocess.STDOUT, env=env)
	try:
		deadline = time.time() + 90
		while time.time() < deadline:
			time.sleep(0.3)
			if os.path.exists(done) and os.path.getsize(done) > 0:
				time.sleep(0.3)						# let the CLOSE land
				break
	finally:
		proc.kill()
		try:
			proc.wait(timeout=5)
		except subprocess.TimeoutExpired:
			pass
		log.close()

	#	THE CHECK IS POSITIVE, and it comes before "did a file appear". A run that fails partway
	#	has still written every line up to the failure and closed the file with a valid end marker,
	#	so an output file is not evidence of anything. Only the literal SUCCESS is.
	msg = ""
	if os.path.exists(done):
		msg = open(done, "rb").read().decode("latin-1", "replace").strip("\0 \r\n\t")
	if not msg:
		die("BASLOAD never reported back within 90s tokenising %s -- see %s"
			% (FRONT_SRC, os.path.join(FRONT_DIR, "RUN.LOG")))
	if msg != "SUCCESS":
		die("BASLOAD said %s tokenising %s" % (msg, FRONT_SRC))

	built = os.path.join(FRONT_DIR, FRONT_PRG)
	if not os.path.exists(built) or os.path.getsize(built) == 0:
		die("BASLOAD reported SUCCESS but wrote no %s -- check the #SAVEAS name" % FRONT_PRG)
	out = os.path.join(BUILD, FRONT_PRG)
	shutil.copy(built, out)
	print("  front %s (%d bytes, RUN it -- it LOADs %s itself)"
		  % (FRONT_PRG, os.path.getsize(out), ENGINE))


def main():
	what = sys.argv[1] if len(sys.argv) > 1 else "all"
	if what not in ("rom", "prg", "front", "all"):
		die("usage: build.py [rom|prg|front|all]")
	os.makedirs(BUILD, exist_ok=True)
	if what in ("rom", "all"):
		build_rom()
	if what in ("prg", "all"):
		build_prg()
	#	After prg, always: the front end is tokenised by the engine, so it has to be the fresh one.
	if what in ("front", "all"):
		build_front()


main()
