# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		rtname.py
#		Purpose :	Install the built resident runtime under its build-numbered name.
#		Date :		31st July 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		The standalone runtime ships as GPB/GPC.RT.nnn.BIN, where nnn is the RUNTIME BUILD NUMBER --
#		source/application/rtbuild.txt. bootstrap.asm formats the identical number into the name
#		every compiled program looks for (via BuildNumber in the generated version.asm), so the
#		two cannot disagree unless the runtime is built from a different stamp than the engine.
#
#		THE NUMBER IS PINNED AND DOES NOT BUMP. It used to be the last component of
#		buildnum.txt and incremented on every "make libs", which meant a differently-named
#		runtime file after every rebuild and a shared-mode program that could no longer find its
#		runtime. A consumer compiling in shared mode needs the name to hold still, so it now
#		moves only when someone edits rtbuild.txt -- and every shared-mode program must be
#		recompiled when it does, because the name is baked into each object.
#
#		This is NOT the product version (buildnum.txt, e.g. 1.0.0, what GPC.BIN prints),
#		and it is NOT the ABI ordinal. RT_ABI (common.inc) carries that, in the 4-byte magic at
#		RTBASE, and answers the different question of whether an already-resident runtime can
#		be entered. The file name says WHICH runtime; the magic says whether it FITS.
#
#		Usage:	rtname.py <built.prg> <dest-dir>	copy, named from the build number
#				rtname.py --name					print just the file name
#
# *******************************************************************************************

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STAMP = os.path.normpath(os.path.join(HERE, "..", "..", "application", "rtbuild.txt"))


def build_number():
	"""rtbuild.txt, as a number. Deliberately strict: a silent default here would build a
	   runtime under a name no compiled program looks for."""
	try:
		with open(STAMP) as f:
			build = f.read().strip()
	except OSError as e:
		sys.exit("rtname.py: cannot read %s (%s)" % (STAMP, e))

	if not build.isdigit():
		sys.exit('rtname.py: rtbuild.txt = "%s": not a number' % build)
	return int(build)


def rt_filename():
	"""The FULL runtime: the GPB handlers AND the core, loading at RTGPBASE.

	   GPB, not GPC, because that is what the extra half of it IS -- the GPB keyword handlers.
	   The plain GPC name below is the plain runtime. %03d, so 112 -> "112" and a small build
	   number still reads as GPB.RT.007.BIN; bootstrap.asm formats it the same way, and both
	   names are the same width so its length bytes do not care which is which."""
	return "GPB.RT.%03d.BIN" % build_number()


def rc_filename():
	"""The CORE-ONLY runtime, for a shared program that uses no GPB keyword. Same width as the
	   GPB name above, and the two sort together in a directory."""
	return "GPC.RT.%03d.BIN" % build_number()


#	RTGPBASE and RTBASE are read out of common.inc rather than repeated here. Getting either
#	wrong would produce a file that loads to the wrong address -- which is not a build failure,
#	it is a program that jumps into the middle of something at run time.
COMMON_INC = os.path.normpath(os.path.join(HERE, "..", "..", "common-source", "source", "common.inc"))


def base(name):
	try:
		text = open(COMMON_INC).read()
	except OSError as e:
		sys.exit("rtname.py: cannot read %s (%s)" % (COMMON_INC, e))
	m = re.search(r"^%s\s*=\s*\$([0-9A-Fa-f]+)" % name, text, re.M)
	if m is None:
		sys.exit("rtname.py: %s is not defined in common.inc" % name)
	return int(m.group(1), 16)


def main():
	if len(sys.argv) == 2 and sys.argv[1] == "--name":
		print(rt_filename())
		return

	if len(sys.argv) != 3:
		sys.exit("usage: rtname.py <built.prg> <dest-dir>   |   rtname.py --name")

	src, dest_dir = sys.argv[1], sys.argv[2]
	if not os.path.isfile(src):
		sys.exit("rtname.py: %s was not built" % src)

	#
	#	TWO FILES, SLICED FROM THE ONE IMAGE -- not two builds. The image assembles from
	#	RTGPBASE with the GPB handlers at the bottom and the core at RTBASE, so the core-only
	#	file is literally the tail of the full one with its own load address in front. That is
	#	why the core bytes cannot differ between the two: there is only one copy of them.
	#
	#	A PRG starts with a 2-byte little-endian load address, which is what we re-write.
	#
	gpbase, rtbase = base("RTGPBASE"), base("RTBASE")
	image = open(src, "rb").read()[2:]			# drop the assembler's load address
	cut = rtbase - gpbase
	if cut <= 0 or cut >= len(image):
		sys.exit("rtname.py: RTBASE-RTGPBASE = %d is outside the %d byte image" % (cut, len(image)))

	for name, addr, body in ((rt_filename(), gpbase, image),
	                         (rc_filename(), rtbase, image[cut:])):
		with open(os.path.join(dest_dir, name), "wb") as h:
			h.write(bytes((addr & 0xFF, addr >> 8)))
			h.write(body)
		print("runtime installed as %s ($%04X, %d bytes)" % (name, addr, len(body)))


#	Guarded so release.sh can import rt_filename() instead of hard-coding the name a
#	fourth time -- the whole point is that nothing spells the number out.
if __name__ == "__main__":
	main()
