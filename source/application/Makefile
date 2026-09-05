# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	Application makefile
#		Date :		9th October 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\documents\common.make
else
include ../../documents/common.make
endif

all: build	

BASICSRC = build$(S)balls.bas

libraries:
	make -C ..

#
#		GPC.INPUT is the compiler's control file: source, object, options, one per line. The
#		compiler falls back to SOURCE.PRG and OBJECT.PRG without it, so this only spells out
#		what it would have done anyway -- but it is also the template a caller copies, so it
#		is worth having one sitting next to the compiler.
#
#
#		bumpbuild.py must run BEFORE build.py: it generates source/generated/version.asm, and
#		build.py is what sweeps source/ into _library.asm. The other way round and the engine
#		links the previous version.asm. It reads both stamps -- buildnum.txt for the printed
#		version, rtbuild.txt for the GPC.RT.nnn.BIN name -- and increments neither, so running
#		it several times per build (which this tree does) is harmless.
#
prelim:
	make -B -C ..$(S)common-source
	$(PYTHON) scripts$(S)bumpbuild.py
	$(PYTHON) $(CSCRIPTS)build.py
	$(PYTHON) $(BINDIR)tokenise.zip $(BASICSRC) SOURCE.PRG
	printf 'SOURCE.PRG\nOBJECT.PRG\n\n' >GPC.INPUT

#
#		TWO LINKS, and they are two because the runtime is no longer resident while compiling.
#
#		It used to be one image -- $0801 runtime, ObjectBase compiler, FreeMemory object buffer
#		-- which kept 14,079 bytes of runtime in low RAM for the whole compile purely so that
#		WriteObjectCode could copy them into the output file. Every one of those bytes came off
#		the object buffer, i.e. off the largest program the compiler could build: 12,800, when
#		the run side would happily take 18,432. Now the runtime is GPC.IMG.nnn.BIN, streamed
#		from disk at write time, and the compiler has low RAM largely to itself.
#
#		LINK ONE is that image, and its order is the old one: 00rtimage.header, the runtime
#		components, then 10object.divider. gp.library stays LAST of the components -- the GP
#		handlers are then the tail of the image, which is the only place they can ever be
#		truncated out of an object that uses none of them (../gp-runtime/Makefile explains).
#
#		genrtimage.py then hands four facts across to link two: GPBase, ObjectBase, the two
#		patch offsets, and the GP-usage bitmap that replaced ScanGPUsage's VectorTable read. It
#		also installs the image under its build-numbered name.
#
#		LINK TWO is the compiler. It takes common.library and ifloat32.library because the
#		compiler calls into both (errors, MoveObjectForward, constant folding) -- and NOT
#		runtime.library, polynomials.library or gp.library, into which it makes no call at all.
#		source/unit-tests/compiler-runtime has linked exactly this subset for as long as it has
#		existed, so the shape is not new.
#
#		$(ASM) always writes build/code.*, so link one's outputs are copied aside before link
#		two overwrites them.
#
build: prelim
	$(ASM) 	source$(S)main$(S)00rtimage.header \
			$(BINDIR)runtime.library $(BINDIR)common.library $(BINDIR)ifloat32.library $(BINDIR)polynomials.library \
			$(BINDIR)gp.library \
			source$(S)main$(S)10object.divider
	$(CCOPY) build$(S)code.prg build$(S)rtimage.prg
	$(CCOPY) build$(S)code.lbl build$(S)rtimage.lbl
	$(PYTHON) scripts$(S)genrtimage.py build$(S)rtimage.lbl build$(S)rtimage.prg rtimage.gen.asm $(RELEASEDIR)
	$(ASM) 	source$(S)main$(S)00main.header \
			$(BINDIR)common.library $(BINDIR)ifloat32.library \
			$(SRCDIR)runtime$(S)source$(S)system-specific$(S)x16$(S)addresses$(S)x16_include.inc \
			rtimage.gen.asm \
			$(BINDIR)compiler.library \
			_library.asm \
			source$(S)main$(S)zzfree.footer
	$(CCOPY) build$(S)code.prg GPC.BIN

release:  build
	$(CDEL) OBJECT.PRG
	$(CCOPY) *.PRG $(RELEASEDIR)
	$(CCOPY) GPC.BIN $(RELEASEDIR)
	$(CCOPY) GPC.INPUT $(RELEASEDIR)
	$(CCOPY) build$(S)*.bas $(RELEASEDIR)
	$(CCOPY) $(BINDIR)tokenise.zip $(RELEASEDIR)
	#
	#		The on-machine reference, so a staged drive can run GPB.HELP beside the
	#		compiler. The PRG is checked in already built (EMBEDDED, so it needs no
	#		runtime beside it); HELP-TXT holds the index and the topics, and the viewer
	#		opens both as //HELP-TXT/:NAME -- so the folder has to arrive as a folder.
	#
	$(CCOPY) $(ROOTDIR)samples$(S)GPC-HELP$(S)GPB.HELP.PRG $(RELEASEDIR)
	$(CCOPY) -r $(ROOTDIR)samples$(S)GPC-HELP$(S)HELP-TXT $(RELEASEDIR)
	#
	#		There is deliberately no CHANGES.txt here. The original author's was deleted ("Del
	#		old files from previous build") and git history is the changelog -- copying one in
	#		unconditionally only meant the release failed to package over a missing text file.
	#
	#
	#		No archive is bundled. blitz.zip -- a git-tracked binary rebuilt on every release --
	#		has been dropped: nothing in the tree ever consumed it, and its "*" glob swept
	#		whatever else lived in testing/ (e.g. the XFMGR launcher) into the download. The
	#		release is simply the contents of testing/.
	
run: build	
	$(CDEL) OBJECT.PRG
	$(EXEBASIC)
	$(CCOPY) GPC.BIN $(BINDIR)
	
x16:
	$(EMULATOR)

