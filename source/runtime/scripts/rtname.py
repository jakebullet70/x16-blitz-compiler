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
#		The standalone runtime ships as GPC.RT.nnn.BIN, where nnn is the ENGINE BUILD NUMBER --
#		the last component of source/application/buildnum.txt, the same stamp GPC.BLITZ.BIN
#		prints. That pins a compiled program to the exact runtime it was built against:
#		bootstrap.asm formats the identical number into the name it looks for (via BuildNumber
#		in the generated version.asm), so the two cannot disagree unless the runtime is built
#		from a different stamp than the engine.
#
#		ORDER MATTERS. The build number bumps on every "make libs", so build the engine FIRST
#		and the runtime after -- which is what release.sh and source/gpc's release target do.
#		Building gpc-rt against a stamp the engine was not built from produces a runtime no
#		compiled program asks for.
#
#		This is NOT the ABI ordinal. RT_ABI (common.inc) still carries that, in the 4-byte
#		magic at RTBASE, and answers the different question of whether an already-resident
#		runtime can be entered.
#
#		Usage:	rtname.py <built.prg> <dest-dir>	copy, named from the build number
#				rtname.py --name					print just the file name
#
# *******************************************************************************************

import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STAMP = os.path.normpath(os.path.join(HERE, "..", "..", "application", "buildnum.txt"))


def build_number():
	"""Last component of buildnum.txt, as a number. Deliberately strict: a silent default
	   here would build a runtime under a name no compiled program looks for."""
	try:
		with open(STAMP) as f:
			version = f.read().strip()
	except OSError as e:
		sys.exit("rtname.py: cannot read %s (%s)" % (STAMP, e))

	last = version.split(".")[-1]
	if not last.isdigit():
		sys.exit('rtname.py: buildnum.txt = "%s": last component is not a number' % version)
	return int(last)


def rt_filename():
	#	%03d, so 112 -> "112" and a small number still reads as GPC.RT.007.BIN. Wider
	#	build numbers simply make a wider name; bootstrap.asm formats it the same way.
	return "GPC.RT.%03d.BIN" % build_number()


def main():
	if len(sys.argv) == 2 and sys.argv[1] == "--name":
		print(rt_filename())
		return

	if len(sys.argv) != 3:
		sys.exit("usage: rtname.py <built.prg> <dest-dir>   |   rtname.py --name")

	src, dest_dir = sys.argv[1], sys.argv[2]
	if not os.path.isfile(src):
		sys.exit("rtname.py: %s was not built" % src)

	dest = os.path.join(dest_dir, rt_filename())
	shutil.copyfile(src, dest)
	print("runtime installed as %s" % rt_filename())


#	Guarded so release.sh can import rt_filename() instead of hard-coding the name a
#	fourth time -- the whole point is that nothing spells the number out.
if __name__ == "__main__":
	main()
