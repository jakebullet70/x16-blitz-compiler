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
#		Which leaves the compiler needing four facts about an image it can no longer see:
#
#			GPBase / ObjectBase		the two possible cut points. ScanGPUsage decides which,
#									and both are LINK-DERIVED in the image -- GPBase is a label
#									in gp-runtime, ObjectBase is 10object.divider's .align.
#
#			the two patch offsets	RunCodePage+1 and RunWorkspacePage+1, as offsets from
#									$0801, because the streamer patches them by position in the
#									file rather than by address in RAM.
#
#			GPUsageBits				32 bytes: one bit per opcode, set if that opcode's handler
#									lives at or above GPBase.
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
#		Usage:	genrtimage.py <image.lbl> <image.prg> <out.asm> [dest-dir]
#
# *******************************************************************************************

import os
import re
import sys

LOAD = 0x0801									# where the image is linked, and loads, and runs


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


def main():
	if len(sys.argv) not in (4, 5):
		die("usage: genrtimage.py <image.lbl> <image.prg> <out.asm> [dest-dir]")
	lblPath, prgPath, outPath = sys.argv[1:4]

	labels = readLabels(lblPath)
	image = readImage(prgPath)

	gpbase = need(labels, "GPBase")
	objectbase = need(labels, "ObjectBase")
	vec = need(labels, "VectorTable")
	shiftvec = need(labels, "ShiftVectorTable")
	codepage = need(labels, "RunCodePage") + 1				# the operand, not the opcode
	wspage = need(labels, "RunWorkspacePage") + 1

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
	for name, ofs in (("RunCodePage+1", codepage), ("RunWorkspacePage+1", wspage)):
		if not LOAD <= ofs < gpbase:
			die("%s at $%04x is outside the part of the image that is always written" % (name, ofs))

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
		h.write("\n\t\t.section code\n")
		h.write(";\n;\tOne bit per opcode, set when that opcode's handler is at or above\n")
		h.write(";\tGPBase. Bytes 0-15 are VectorTable, 16-31 ShiftVectorTable.\n;\n")
		h.write("GPUsageBits:\n")
		h.write(asmBytes(bits) + "\n")
		h.write("\t\t.send code\n")

	installed = ""
	if len(sys.argv) == 5:
		dest = os.path.join(sys.argv[4], imageName())
		os.makedirs(sys.argv[4], exist_ok=True)
		with open(dest, "wb") as h:					# the load address goes WITH it: the streamer
			h.write(open(prgPath, "rb").read())		# reads and checks those two bytes
		installed = " -> " + imageName()

	print("  genrtimage: image %d bytes, GPBase $%04x, ObjectBase $%04x, %d/%d GP vectors%s"
		  % (len(image), gpbase, objectbase,
			 sum(bin(b).count("1") for b in bits), plainCount + shiftCount, installed))


main()
