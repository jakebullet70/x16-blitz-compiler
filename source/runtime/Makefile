# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	runtime library makefile.
#		Date :		5th October 2023
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

prelim: 
	make -B -C ../common-source
	$(PYTHON) scripts$(S)genmapping.py >source$(S)generated$(S)links.asm
	$(PYTHON) scripts$(S)vectors.py >source$(S)generated$(S)vectors.asm

	$(PYTHON) $(CSCRIPTS)build.py
	$(CCOPY) _library.asm $(BINDIR)runtime.library

#
#		gp.library is LAST in every link below, which is the whole reason it is a separate
#		library: the GP handlers then sit contiguously at the tail of the image instead of
#		scattered through it. ../gp-runtime/Makefile has the argument in full. It must already
#		be built -- ../Makefile enters gp-runtime before this directory.
#
build: prelim
	$(ASM) testing$(S)testing.asm $(BINDIR)runtime.library $(BINDIR)common.library $(BINDIR)ifloat32.library  $(BINDIR)polynomials.library $(BINDIR)gp.library testing$(S)testend.asm

#
#		The standalone resident runtime. TWO FILES, sliced by rtname.py from this ONE image:
#
#			GPB.RT.nnn.BIN	loads at RTGPBASE ($6600) -- GPB handlers AND core
#			GPC.RT.nnn.BIN	loads at RTBASE   ($6E00) -- core only, for a program using no GPB
#
#		Hence the link ORDER, which is the whole point of this recipe: gp.library goes FIRST
#		here, at the bottom -- the opposite of every other link line in the tree, where it goes
#		last. The core has to sit at one fixed address whichever file was loaded, so the
#		optional half must be the low one. See common.inc.
#
#		-D CodeStart is RTGPBASE, not RTBASE (26112 = $6600 -- decimal dodges Make's $; keep
#		it in step with RTGPBASE in common.inc). 05rtcore.divider pads the gap and stamps
#		RTGPMAGIC; zzrt.footer still guards the top against $9F00. Written straight into
#		testing/ so both sit beside the compiled programs on the emulator's disk.
#
#		nnn is the RUNTIME BUILD NUMBER, source/application/rtbuild.txt, and the name is built by
#		rtname.py reading that file -- NOT spelled out here. The same number reaches bootstrap.asm
#		as BuildNumber (via the generated version.asm) and so becomes the name every compiled
#		program looks for; a copy in this recipe would be the one nothing checks. It is pinned and
#		edited by hand, because moving it orphans every already-compiled shared-mode program.
#
#		This is NOT the ABI ordinal. RT_ABI (common.inc) is that, in the magic 00rt.header lays
#		down at RTBASE; the file name says WHICH runtime, the magic says whether it FITS.
#
gpc-rt: prelim
	$(ASM) -D CodeStart=26112 source$(S)main$(S)00rtgp.header $(BINDIR)gp.library \
		source$(S)main$(S)05rtcore.divider source$(S)main$(S)00rt.header \
		$(BINDIR)runtime.library $(BINDIR)common.library $(BINDIR)ifloat32.library $(BINDIR)polynomials.library \
		source$(S)main$(S)zzrt.footer
	$(PYTHON) scripts$(S)rtname.py build$(S)code.prg $(RELEASEDIR)

checkall: prelim
	$(ASM) testing$(S)testing.asm $(BINDIR)common.library $(BINDIR)ifloat32.library $(BINDIR)polynomials.library \
													$(BINDIR)compiler.library $(BINDIR)runtime.library $(BINDIR)gp.library testing$(S)testend.asm

run: build
	$(EXECUTE) 
	
variables:
	$(PYTHON) $(CSCRIPTS)variables.py
