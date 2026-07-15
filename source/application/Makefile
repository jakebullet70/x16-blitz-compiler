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
prelim:
	make -B -C ..$(S)common-source
	$(PYTHON) $(CSCRIPTS)build.py
	$(PYTHON) $(BINDIR)tokenise.zip $(BASICSRC) SOURCE.PRG
	printf 'SOURCE.PRG\nOBJECT.PRG\n\n' >GPC.INPUT

#
#		This order matters. 00main.header contains the BASIC header followed by the runtime components
# 		(runtime.library ... polynomials.library).
#
#		At the end, eventually, the finished compiled code will be copied over the compiler and library
#		code for this application to make more space available.
#
build: prelim
	$(ASM) 	source$(S)main$(S)00main.header \
			$(BINDIR)runtime.library $(BINDIR)common.library $(BINDIR)ifloat32.library $(BINDIR)polynomials.library \
			source$(S)main$(S)10object.divider \
			$(BINDIR)compiler.library \
			_library.asm \
			source$(S)main$(S)zzfree.footer
	$(CCOPY) build$(S)code.prg GPC.BLITZ.PRG

release:  build
	$(CDEL) OBJECT.PRG
	$(CCOPY) *.PRG $(RELEASEDIR)
	$(CCOPY) GPC.INPUT $(RELEASEDIR)
	$(CCOPY) build$(S)*.bas $(RELEASEDIR)
	$(CCOPY) $(BINDIR)tokenise.zip $(RELEASEDIR)
	#
	#		There is deliberately no CHANGES.txt here. The original author's was deleted ("Del
	#		old files from previous build") and git history is the changelog -- copying one in
	#		unconditionally only meant the release failed to package over a missing text file.
	#
	#
	#		No archive is bundled. blitz.zip -- a git-tracked binary rebuilt on every release --
	#		has been dropped: nothing in the tree ever consumed it, and its "*" glob swept
	#		whatever else lived in release/ (e.g. the XFMGR launcher) into the download. The
	#		release is simply the contents of release/.
	
run: build	
	$(CDEL) OBJECT.PRG
	$(EXEBASIC)
	$(CCOPY) GPC.BLITZ.PRG $(BINDIR)
	
x16:
	$(EMULATOR)

