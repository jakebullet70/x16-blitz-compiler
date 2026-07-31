# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		rtname.py
#		Purpose :	Install the built resident runtime under its ABI-versioned name.
#		Date :		31st July 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		The standalone runtime ships as GPC.RT.nnn.BIN, where nnn is the ABI ordinal RT_ABI.
#		RT_ABI is defined once, in common-source/source/common.inc, and read back here rather
#		than repeated in the makefile -- three things have to agree on that number (the magic
#		at RTBASE, the name the runtime is BUILT as, and the name a compiled program LOOKS
#		FOR), and a copy in a makefile is the one the assembler could never catch drifting.
#
#		Usage:	rtname.py <built.prg> <dest-dir>	copy, named from RT_ABI
#				rtname.py --name					print just the file name
#
# *******************************************************************************************

import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
INC = os.path.normpath(os.path.join(HERE, "..", "..", "common-source", "source", "common.inc"))


def rt_abi():
	"""Pull RT_ABI out of common.inc. Deliberately strict: a silent default here would
	   build a runtime under a name no program looks for."""
	try:
		with open(INC) as f:
			text = f.read()
	except OSError as e:
		sys.exit("rtname.py: cannot read %s (%s)" % (INC, e))

	m = re.search(r"^\s*RT_ABI\s*=\s*(\d+)", text, re.MULTILINE)
	if not m:
		sys.exit("rtname.py: no 'RT_ABI = <n>' line in %s" % INC)
	value = int(m.group(1))
	if value > 999:
		sys.exit("rtname.py: RT_ABI = %d does not fit the three digits of GPC.RT.nnn.BIN" % value)
	return value


def rt_filename():
	return "GPC.RT.%03d.BIN" % rt_abi()


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


main()
