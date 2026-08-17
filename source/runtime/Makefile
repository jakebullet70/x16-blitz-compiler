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

build: prelim
	$(ASM) testing$(S)testing.asm $(BINDIR)runtime.library $(BINDIR)common.library $(BINDIR)ifloat32.library  $(BINDIR)polynomials.library testing$(S)testend.asm

#
#		The standalone resident runtime, GPC.RT.nnn.BIN. Same libraries as the test build, but
#		fronted by 00rt.header (magic + entry vector at RTBASE) and closed by zzrt.footer (the
#		$9F00 size guard), re-based to RTBASE via -D CodeStart (25600 = $6400 -- decimal dodges
#		Make's $; keep it in step with RTBASE in common.inc). The result is loaded once and
#		shared by every program compiled in "resident
#		runtime" mode (GPC.INPUT 4th line = SHARED). Written straight into testing/ so it sits
#		beside the compiled programs on the emulator's disk.
#
#		nnn is the ABI ordinal RT_ABI, and the name is built by rtname.py reading it back out of
#		common-source/source/common.inc -- NOT spelled out here. The same number is assembled into
#		the runtime's magic and into the name every compiled program looks for, so a copy in this
#		recipe would be the one nothing checks. Bump RT_ABI and all three move together.
#
gpc-rt: prelim
	$(ASM) -D CodeStart=25600 source$(S)main$(S)00rt.header $(BINDIR)runtime.library $(BINDIR)common.library $(BINDIR)ifloat32.library $(BINDIR)polynomials.library source$(S)main$(S)zzrt.footer
	$(PYTHON) scripts$(S)rtname.py build$(S)code.prg $(RELEASEDIR)

checkall: prelim
	$(ASM) testing$(S)testing.asm $(BINDIR)common.library $(BINDIR)ifloat32.library $(BINDIR)polynomials.library \
													$(BINDIR)compiler.library $(BINDIR)runtime.library testing$(S)testend.asm

run: build
	$(EXECUTE) 
	
variables:
	$(PYTHON) $(CSCRIPTS)variables.py
