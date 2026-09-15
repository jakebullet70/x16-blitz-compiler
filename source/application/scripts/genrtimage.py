# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		genrtimage.py
#		Purpose :	Hand the runtime-image link's addresses across to the compiler link.
#		Date :		30th August 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		THE COMPILER AND THE RUNTIME ARE NOW TWO SEPARATE LINKS, and this is the only thing
#		that crosses between them.
#
#		They used to be one image: $0801 runtime, ObjectBase compiler, FreeMemory object
#		buffer. That put 14,079 bytes of runtime in low RAM throughout every compile purely so
#		WriteObjectCode could copy them into the output file -- and every one of those bytes
#		came straight off the largest program the compiler could build. The runtime is a file
#		now (GPC.IMG.nnn.BIN), streamed from disk at write time, and the compiler links on its
#		own at $0801.
#
#		Which leaves the compiler needing five facts about an image it can no longer see:
#
#			GPBase / ObjectBase		the two possible cut points. ScanGPUsage decides which,
#									and both are LINK-DERIVED in the image -- GPBase is a label
#									in gp-runtime, ObjectBase is 10object.divider's .align.
#
#			the three patch offsets	RunCodePage+1, RunWorkspacePage+1 and RunBankPage+1, as
#									offsets from $0801, because the streamer patches them by
#									position in the file rather than by address in RAM.
#
#			GPUsageBits				32 bytes: one bit per opcode, set if that opcode's handler
#									lives at or above GPBase.
#
#			RTIMG_BANKLEN			the bytes of bank code in bank.prg, less its load address.
#									An embedded object carries them after the p-code, where they
#									sit in the workspace until StartCode copies them to bank 1,
#									so a .cerror keeps them within MIN_WS_PAGES. StartCode
#									copies up to the image's RTImgBankEnd, which must agree.
#
#		THE BITMAP IS WHY THIS SCRIPT EXISTS AT ALL. ScanGPUsage used to read the runtime's
#		VectorTable directly and compare each handler address against GPBase -- fine when the
#		table was in RAM, impossible now. But it never needed the addresses: it only ever asked
#		"is this handler in the block I am about to discard?", which is one bit. So the answer
#		is computed here, from the image's own linked table, and the question the scan asks is
#		unchanged -- still by address, still following a handler that moves into or out of
#		gp-runtime/ with no list to maintain.
#
#		It also installs the image under its build-numbered name, GPC.IMG.nnn.BIN, from the same
#		rtbuild.txt stamp the shared runtime uses. A fixed name would still be FOUND when stale,
#		and a stale image produces a program that loads and then misbehaves; a numbered one is
#		simply absent, and WriteObjectCode says NO RUNTIME IMAGE instead of writing the object.
#
#		The bank code goes beside it as GP1.IMG.nnn.BIN, whole, with its $A000 load address. It
#		jumps into this image at fixed addresses, so the two install from the one link, and both
#		are checked before either is written. Its name is the image's with the third character
#		changed, as GP1.RT.nnn.BIN is to GPC.RT.nnn.BIN.
#
#		Usage:	genrtimage.py <image.lbl> <image.prg> <bank.prg> <out.asm> [dest-dir]
#
# *******************************************************************************************

import os
import re
import sys

LOAD = 0x0801									# where the image is linked, and loads, and runs
BANK = 0xA000									# where the bank code is linked, in bank 1


def die(msg):
	sys.exit("  genrtimage: FAIL -- " + msg)


def readLabels(path):
	"""64tass .lbl -- NAME = $HHHH, one per line."""
	if not os.path.isfile(path):
		die("%s is missing -- the runtime-image link must run first" % path)
	out = {}
	for line in open(path, encoding="latin-1"):
		m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\$([0-9a-fA-F]+)\s*$", line.strip())
		if m:
			out[m.group(1)] = int(m.group(2), 16)
	return out


def need(labels, name):
	if name not in labels:
		die("the runtime image defines no %s -- link order changed?" % name)
	return labels[name]


def readImage(path):
	"""The linked .prg, minus its two byte load address."""
	if not os.path.isfile(path):
		die("%s is missing -- the runtime-image link must run first" % path)
	data = open(path, "rb").read()
	if len(data) < 3:
		die("%s is empty" % path)
	load = data[0] | (data[1] << 8)
	if load != LOAD:
		die("%s loads at $%04x, not $%04x" % (path, load, LOAD))
	return data[2:]


def readBank(path):
	"""The linked banked section, minus its load address. It opens with the embedded magic,
	   "GE" and RT_ABI, which the shared bootstrap tells from its own "GP"."""
	if not os.path.isfile(path):
		die("%s is missing -- the runtime-image link must run first" % path)
	data = open(path, "rb").read()
	if len(data) < 6 or data[0] | (data[1] << 8) != BANK:
		die("%s does not load at $%04x" % (path, BANK))
	if data[2:4] != b"GE":
		die("%s opens with %r, not the embedded magic GE" % (path, data[2:4]))
	if len(data) - 2 > 0x2000:
		die("%s is %d bytes, more than a bank holds" % (path, len(data) - 2))
	return data[2:]


def usageBits(image, base, count, gpbase):
	"""One bit per vector slot, set when the handler is at or above gpbase.

	   16 bytes covers 128 opcodes; a table shorter than that leaves the tail clear. That
	   matters for exactly one opcode: ScanGPUsage accepts up to PCD_ENDSYSTEM inclusive,
	   which is one slot past the end of VectorTable, and read the first ShiftVectorTable
	   entry when it got there. Below the cut either way, so the answer is the same -- but
	   the read is now in bounds rather than accidentally harmless."""
	bits = bytearray(16)
	for i in range(count):
		off = base - LOAD + i * 2
		if off + 1 >= len(image):
			die("vector table runs past the end of the image")
		handler = image[off] | (image[off + 1] << 8)
		if handler >= gpbase:
			bits[i >> 3] |= 1 << (i & 7)
	return bits


def asmBytes(bits):
	return "\n".join(
		"\t\t.byte\t" + ",".join("$%02x" % b for b in bits[i:i + 8])
		for i in range(0, len(bits), 8))


def imageName():
	stamp = os.path.normpath(os.path.join(
		os.path.dirname(os.path.abspath(__file__)), "..", "rtbuild.txt"))
	if not os.path.isfile(stamp):
		die("%s is missing -- it holds the runtime build number" % stamp)
	build = open(stamp, encoding="utf-8").read().strip()
	if not build.isdigit() or not 0 <= int(build) <= 999:
		die('rtbuild.txt = "%s": must be 0..999, it names GPC.IMG.nnn.BIN' % build)
	return "GPC.IMG.%03d.BIN" % int(build)


def bankImageName():
	"""The embedded bank code, installed beside the image. The same width, with the third
	   character changed, as GP1.RT.nnn.BIN is to GPC.RT.nnn.BIN."""
	return "GP1" + imageName()[3:]


def main():
	if len(sys.argv) not in (5, 6):
		die("usage: genrtimage.py <image.lbl> <image.prg> <bank.prg> <out.asm> [dest-dir]")
	lblPath, prgPath, bankPath, outPath = sys.argv[1:5]

	labels = readLabels(lblPath)
	image = readImage(prgPath)
	bank = readBank(bankPath)

	gpbase = need(labels, "GPBase")
	objectbase = need(labels, "ObjectBase")
	vec = need(labels, "VectorTable")
	shiftvec = need(labels, "ShiftVectorTable")
	codepage = need(labels, "RunCodePage") + 1				# the operand, not the opcode
	wspage = need(labels, "RunWorkspacePage") + 1
	bankpage = need(labels, "RunBankPage") + 1
	bankend = need(labels, "RTImgBankEnd")

	#
	#		Sanity, because every one of these being wrong produces a program that loads and
	#		then misbehaves rather than a build that fails.
	#
	if gpbase & 0xFF or objectbase & 0xFF:
		die("GPBase $%04x / ObjectBase $%04x must both be page aligned" % (gpbase, objectbase))
	if not LOAD < gpbase <= objectbase:
		die("expected $%04x < GPBase $%04x <= ObjectBase $%04x" % (LOAD, gpbase, objectbase))
	if len(image) != objectbase - LOAD:
		die("image is %d bytes, ObjectBase says it should be %d"
			% (len(image), objectbase - LOAD))
	for name, ofs in (("RunCodePage+1", codepage), ("RunWorkspacePage+1", wspage), ("RunBankPage+1", bankpage)):
		if not LOAD <= ofs < gpbase:
			die("%s at $%04x is outside the part of the image that is always written" % (name, ofs))
	if bankend - BANK != len(bank):
		die("RTImgBankEnd is $%04x, but %s holds %d bytes of bank code" % (bankend, bankPath, len(bank)))

	#
	#		The tables are contiguous in vectors.asm, so ShiftVectorTable's start is
	#		VectorTable's end. The shift table's own end is the first thing after it, which is
	#		not knowable from labels alone -- 128 slots is the most the opcode space allows and
	#		usageBits stops at the image end, so ask for what the file actually holds.
	#
	plainCount = min(128, (shiftvec - vec) // 2)
	shiftCount = min(128, (objectbase - shiftvec) // 2)

	bits = usageBits(image, vec, plainCount, gpbase) + \
		   usageBits(image, shiftvec, shiftCount, gpbase)

	with open(outPath, "w", encoding="utf-8", newline="\n") as h:
		h.write(";\n;\tGenerated by scripts/genrtimage.py from the runtime-image link.\n")
		h.write(";\tDo not edit: rebuild the image and this follows it.\n;\n")
		h.write("GPBase          = $%04x\n" % gpbase)
		h.write("ObjectBase      = $%04x\n" % objectbase)
		h.write("RTIMG_LOAD      = $%04x\n" % LOAD)
		h.write("RTIMG_LENGTH    = $%04x\n" % (objectbase - LOAD))
		h.write("RTIMG_CODEPOFS  = $%04x\n" % (codepage - LOAD))
		h.write("RTIMG_WSPAGEOFS = $%04x\n" % (wspage - LOAD))
		h.write("RTIMG_BANKPOFS  = $%04x\n" % (bankpage - LOAD))
		h.write("RTIMG_BANKLEN   = $%04x\n" % len(bank))
		h.write("\t\t.cerror RTIMG_BANKLEN > (MIN_WS_PAGES << 8), "
				"\"embedded bank code over MIN_WS_PAGES pages - its copy above the p-code has no room\"\n")
		h.write("\n\t\t.section code\n")
		h.write(";\n;\tOne bit per opcode, set when that opcode's handler is at or above\n")
		h.write(";\tGPBase. Bytes 0-15 are VectorTable, 16-31 ShiftVectorTable.\n;\n")
		h.write("GPUsageBits:\n")
		h.write(asmBytes(bits) + "\n")
		h.write("\t\t.send code\n")

	installed = ""
	if len(sys.argv) == 6:
		os.makedirs(sys.argv[5], exist_ok=True)
		#	Both go whole, load address and all: the streamer reads and checks the image's two bytes.
		for name, path in ((imageName(), prgPath), (bankImageName(), bankPath)):
			with open(os.path.join(sys.argv[5], name), "wb") as h:
				h.write(open(path, "rb").read())
		installed = " -> %s, %s" % (imageName(), bankImageName())

	print("  genrtimage: image %d bytes, bank code %d, GPBase $%04x, ObjectBase $%04x, %d/%d GP vectors%s"
		  % (len(image), len(bank), gpbase, objectbase,
			 sum(bin(b).count("1") for b in bits), plainCount + shiftCount, installed))


#	Guarded so release.sh can import imageName() and bankImageName() instead of spelling the
#	build number out a third time -- the same reason rtname.py is guarded.
if __name__ == "__main__":
	main()
