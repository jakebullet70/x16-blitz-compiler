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
#		Two targets out of ONE unmodified source tree:
#
#		  rom   upstream/conf/basload-rom.cfg   16,384 bytes, loads at $c000 in ROM bank 15
#		  prg   conf/basload-prg.cfg            a PRG that loads and runs anywhere in RAM
#
#		The prg target is the whole point of this folder -- see README.md. There is no source
#		diff between them and there is not meant to be one: everything ROM-specific in BASLOAD
#		is already RAM-resident (the bridge copies itself to golden RAM), so the difference is
#		a linker config and nothing else.
#
#		  python BASLOAD-GPC/build.py [rom|prg|both]      default: both
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
import subprocess
import sys

HERE     = os.path.dirname(os.path.abspath(__file__))
ROOT     = os.path.abspath(os.path.join(HERE, ".."))
UPSTREAM = os.path.join(HERE, "upstream")
BUILD    = os.path.join(HERE, "build")
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


def die(msg):
	sys.exit("build.py: " + msg)


def run(cfg, out, mapfile):
	"""cl65 over main.asm with the given linker config. Every include is pulled in by main.asm,
	so there is exactly one translation unit and no link order to get wrong."""
	if not os.path.exists(CL65):
		die("no cl65 at %s -- set CC65_HOME, or install the cc65 Windows snapshot" % CL65)
	args = [CL65, "-o", out, "--cpu", "65C02", "-t", "none",
			"-C", cfg, "-m", mapfile, "main.asm"]
	r = subprocess.run(args, cwd=UPSTREAM, capture_output=True, text=True)
	if r.returncode != 0:
		die("cl65 failed:\n" + (r.stdout or "") + (r.stderr or ""))
	#	cl65 leaves the object beside the source; the Makefile deletes it and so do we.
	stray = os.path.join(UPSTREAM, "main.o")
	if os.path.exists(stray):
		os.remove(stray)


def build_rom():
	out = os.path.join(BUILD, "basload-rom.bin")
	run(os.path.join(UPSTREAM, "conf", "basload-rom.cfg"), out,
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
	run(os.path.join(HERE, "conf", "basload-prg.cfg"), raw,
		os.path.join(BUILD, "basload-prg.map"))
	#	A PRG is the load address little-endian, then the image. cl65 emits the image alone.
	out = os.path.join(BUILD, "BASLOAD.PRG")
	with open(out, "wb") as f:
		f.write(bytes([PRG_ADDR & 0xFF, PRG_ADDR >> 8]))
		with open(raw, "rb") as g:
			f.write(g.read())
	os.remove(raw)
	print("  prg  %s (%d bytes, loads $%04X, SYS %d)"
		  % (os.path.basename(out), os.path.getsize(out), PRG_ADDR, PRG_ADDR))


def main():
	what = sys.argv[1] if len(sys.argv) > 1 else "both"
	if what not in ("rom", "prg", "both"):
		die("usage: build.py [rom|prg|both]")
	os.makedirs(BUILD, exist_ok=True)
	if what in ("rom", "both"):
		build_rom()
	if what in ("prg", "both"):
		build_prg()


main()
