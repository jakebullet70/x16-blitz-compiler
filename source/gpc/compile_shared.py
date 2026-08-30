# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		compile_shared.py
#		Purpose :	Compile a tokenised PRG with GPC.BIN, headlessly, in SHARED mode.
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
#			compile_shared.py <source.prg> <object.prg> [map]
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

TIMEOUT = 180			# generous: the engine compiles on an emulated 8 MHz 65C02


def die(msg):
	sys.exit("compile_shared.py: " + msg)


def compile_one(source, obj, mapfile=""):
	for need in (EMU, ROM, os.path.join(TESTING, ENGINE), os.path.join(TESTING, source)):
		if not os.path.exists(need):
			die("missing %s" % need)

	objpath = os.path.join(TESTING, obj)
	saved = None
	if os.path.exists(GPC_INPUT):
		with open(GPC_INPUT, "rb") as f:
			saved = f.read()

	try:
		with open(GPC_INPUT, "w", newline="\n") as f:
			f.write("%s\n%s\n%s\nSHARED\n" % (source, obj, mapfile))
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
								  "-prg", ENGINE, "-run"],
								 cwd=TESTING, stdout=log, stderr=subprocess.STDOUT, env=env)
			try:
				deadline = time.time() + TIMEOUT
				while time.time() < deadline:
					time.sleep(0.5)
					#	wait for the object to appear AND stop growing
					if os.path.exists(objpath) and os.path.getsize(objpath) > 0:
						size = os.path.getsize(objpath)
						time.sleep(0.6)
						if os.path.getsize(objpath) == size:
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

	if not os.path.exists(objpath):
		die("%s did not compile %s -- see testing/GPCCOMP.LOG" % (ENGINE, source))
	print("  compiled %s -> %s (%d bytes, SHARED)" % (source, obj, os.path.getsize(objpath)))
	os.remove(os.path.join(TESTING, "GPCCOMP.LOG"))


def main():
	if len(sys.argv) not in (3, 4):
		die("usage: compile_shared.py <source.prg> <object.prg> [map]")
	compile_one(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else "")


main()
