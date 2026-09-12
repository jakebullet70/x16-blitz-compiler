# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		compile_shared.py
#		Purpose :	Compile a tokenised PRG with GPC.BIN, headlessly. SHARED by
#				default, EMBEDDED with --embedded.
#		Date :		31st July 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		The build ships GPC.ERR as a COMPILED program rather than an interpreted one, so the
#		helper you reach for after a crash runs at compiled speed. It is built in SHARED mode:
#		it carries no embedded runtime and uses the resident GPC.RT.nnn.BIN, which is already
#		on the drive for compiled programs -- so the tool costs ~1.6K instead of ~12K.
#
#		There is no host-side compiler: GPC is a native X16 program. So, like build_basl.py,
#		this boots the bundled emulator and drives the real thing. GPC.PRG (the front end) is
#		INTERACTIVE, so it is the wrong thing to script -- run the ENGINE, GPC.BIN, which
#		reads its four-line GPC.INPUT (source, object, map, mode) straight off the drive.
#
#		GPC.INPUT is a tracked working file, so it is snapshotted and restored: a build must not
#		leave the tree different from how it found it.
#
#			compile_shared.py [--embedded] <source.prg> <object.prg> [map]
#
#		Both programs the build compiles -- GPC.PRG and GPC.ERR -- are SHARED, so they use
#		the resident runtime rather than carrying a ~12K copy each. GPC.PRG needs the GPB
#		one (GP.DO and GP.LOOP have handlers); source/gpc/Makefile builds gpc-rt before it
#		compiles either. --embedded is here for a program that has to stand alone.
#
# *******************************************************************************************

import os
import subprocess
import sys
import time

HERE      = os.path.dirname(os.path.abspath(__file__))
ROOT      = os.path.abspath(os.path.join(HERE, "..", ".."))
TESTING   = os.path.join(ROOT, "testing")
EMUDIR    = os.path.join(ROOT, "bin", "x16emu")
EMU       = os.path.join(EMUDIR, "x16emu.exe" if os.name == "nt" else "x16emu")
ROM       = os.path.join(EMUDIR, "rom.bin")
GPC_INPUT = os.path.join(TESTING, "GPC.INPUT")
ENGINE    = "GPC.BIN"

TIMEOUT = 900			# generous: the engine compiles on an emulated 8 MHz 65C02.
						# GPBMODS at 2,200 lines and two GP.BANKED regions took about
						# 200 s, so 180 was under the biggest thing in the tree.  It has
						# seven regions now, and 26 KB of overlay files are written one
						# after the other at the end of pass two: on 11th Sep 2026 that
						# run needed about 450 s, and 420 killed it mid-overlay, leaving
						# the same 513 byte object a warp-mode lull used to leave.


BANNER = b"GPC SQUEALING"	# the engine's first line of output, above its error table
READY  = b"READY."			# BASIC's prompt: one at boot, one more if the engine stops


def die(msg):
	sys.exit("compile_shared.py: " + msg)


#
#		The compiler's account of a failure, taken from the log between its banner and the
#		READY. that follows it. The banner line and the two file names are dropped -- the
#		build printed those itself -- and what is left is the message that matters.
#
def report(raw):
	text = raw.decode("latin-1").replace("\r", "\n")
	lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
	kept = [ln for ln in lines if not ln.startswith("GPC SQUEALING")
			and not ln.startswith("IN:") and not ln.startswith("OUT:")]
	return "\n".join("    " + ln for ln in kept[-8:]) or "    (no message)"


def compile_one(source, obj, mapfile="", shared=True):
	for need in (EMU, ROM, os.path.join(TESTING, ENGINE), os.path.join(TESTING, source)):
		if not os.path.exists(need):
			die("missing %s" % need)

	objpath = os.path.join(TESTING, obj)
	saved = None
	if os.path.exists(GPC_INPUT):
		with open(GPC_INPUT, "rb") as f:
			saved = f.read()

	try:
		#
		#		Four CR-terminated lines -- source, object, map, mode -- and an EMBEDDED build
		#		writes only THREE. That is not a shortcut: GPC.BASL omits the line rather than
		#		writing an empty one ("GP.IF SH=1 THEN PRINT#1,SHARED"), so a three-line file
		#		is exactly what the engine is handed in the interactive case.
		#
		control = "%s\n%s\n%s\n" % (source, obj, mapfile)
		if shared:
			control += "SHARED\n"
		with open(GPC_INPUT, "w", newline="\n") as f:
			f.write(control)
		for stale in (obj, mapfile):
			if stale:
				p = os.path.join(TESTING, stale)
				if os.path.exists(p):
					os.remove(p)

		#
		#		SDL_VIDEODRIVER=dummy so a build never pops a window or steals keyboard focus.
		#		Kill by PID (Popen.kill), never by image name -- other emulators may be running.
		#
		env = dict(os.environ)
		env["SDL_VIDEODRIVER"] = "dummy"
		logpath = os.path.join(TESTING, "GPCCOMP.LOG")
		with open(logpath, "wb") as log:
			p = subprocess.Popen([EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-sound", "none",
								  "-echo", "raw", "-prg", ENGINE, "-run"],
								 cwd=TESTING, stdout=log, stderr=subprocess.STDOUT, env=env)
			try:
				#
				#		STOP ON "OK CODE" AND NOTHING ELSE.
				#
				#		The old stop condition was "the object exists and has not grown for 0.6s",
				#		and the TWO-PASS COMPILER retired it: pass two writes the object AS it
				#		compiles, so the file appears early and grows in bursts. A lull in warp
				#		mode killed the emulator mid-compile, leaving a 513 byte object, NO MAP,
				#		and a cheerful "compiled" line. Size is not progress; the banner is.
				#
				#		Do not widen this to match an error word. GPC echoes its whole
				#		error-message TABLE just after its banner -- OUT OF RANGE, SYNTAX ERROR,
				#		TYPE MISMATCH are all in the log of a perfect build -- so anything
				#		looser fires on success.
				#
				#		FAILING FAST IS THE OTHER HALF. A compile that cannot go on prints its
				#		message and drops BASIC back to READY., and nothing further is ever
				#		written: waiting out TIMEOUT there costs seven minutes and tells you
				#		nothing the log did not already say. So the second stop condition is a
				#		READY. AFTER THE BANNER -- the one BASIC prints at boot sits above it,
				#		and a successful run is claimed by "OK CODE" in the test above before
				#		this one is reached. The lines between the banner and that READY. are
				#		the compiler's own account of the failure, so they go in the message.
				#
				finished = False
				stopped = None
				deadline = time.time() + TIMEOUT
				while time.time() < deadline:
					time.sleep(0.5)
					try:
						with open(logpath, "rb") as r:
							echo = r.read()
					except OSError:
						continue
					if b"OK CODE" in echo:
						finished = True
						time.sleep(1.5)			# let the last write and the map land
						break
					at = echo.find(BANNER)
					if at >= 0 and READY in echo[at:]:
						stopped = echo[at:echo.index(READY, at)]
						break
			finally:
				p.kill()
				try:
					p.wait(timeout=5)
				except subprocess.TimeoutExpired:
					pass
	finally:
		if saved is not None:
			with open(GPC_INPUT, "wb") as f:
				f.write(saved)

	#
	#		THE OBJECT EXISTING IS NOT THE TEST. Pass two writes it as it compiles, so a run
	#		killed at TIMEOUT leaves a short one -- 513 bytes, the bootstrap and nothing else --
	#		and this used to print "compiled" over it. The banner is what says the compile ran
	#		to the end, and the map is what says the object was finished; a build asking for a
	#		map and not getting one did not succeed, whatever is sitting in the object file.
	#
	if stopped is not None:
		die("%s stopped compiling %s -- see testing/GPCCOMP.LOG\n%s"
			% (ENGINE, source, report(stopped)))
	if not finished:
		die("%s did not finish %s within %ds -- see testing/GPCCOMP.LOG"
			% (ENGINE, source, TIMEOUT))
	if not os.path.exists(objpath):
		die("%s did not compile %s -- see testing/GPCCOMP.LOG" % (ENGINE, source))
	if mapfile and not os.path.exists(os.path.join(TESTING, mapfile)):
		die("%s wrote no map for %s -- see testing/GPCCOMP.LOG" % (ENGINE, source))
	print("  compiled %s -> %s (%d bytes, %s)"
		  % (source, obj, os.path.getsize(objpath), "SHARED" if shared else "EMBEDDED"))
	os.remove(os.path.join(TESTING, "GPCCOMP.LOG"))


def main():
	args = sys.argv[1:]
	shared = True
	if args and args[0] == "--embedded":
		shared = False
		args = args[1:]
	if len(args) not in (2, 3):
		die("usage: compile_shared.py [--embedded] <source.prg> <object.prg> [map]")
	compile_one(args[0], args[1], args[2] if len(args) == 3 else "", shared)


main()
