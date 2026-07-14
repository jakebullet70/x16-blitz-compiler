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

prelim: 
	make -B -C ..$(S)common-source
	$(PYTHON) $(CSCRIPTS)build.py
	$(PYTHON) $(BINDIR)tokenise.zip $(BASICSRC) SOURCE.PRG

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
	$(CCOPY) build$(S)code.prg BLITZ.PRG

release:  build
	$(CDEL) OBJECT.PRG
	$(CCOPY) *.PRG $(RELEASEDIR)
	$(CCOPY) build$(S)*.bas $(RELEASEDIR)
	$(CCOPY) $(BINDIR)tokenise.zip $(RELEASEDIR)
	#
	#		CHANGES.txt was the original author's 2023 changelog and is gone ("Del old files
	#		from previous build"). Ship it only if it is actually there: a release should not
	#		fail to build over an optional text file the repo no longer carries.
	#
	if [ -f $(ROOTDIR)CHANGES.txt ] ; then $(CCOPY) $(ROOTDIR)CHANGES.txt $(RELEASEDIR) ; fi
	#
	#		Bundle the release. mkzip.py replaces zip(1) (absent on a stock Windows box) and
	#		writes reproducibly, so an unchanged release no longer produces a new blitz.zip.
	#		It skips the archive it is writing, so the * glob cannot swallow a stale one.
	#
	cd $(RELEASEDIR) ; $(CDEL) blitz.zip ; $(PYTHON) $(CSCRIPTS)mkzip.py blitz.zip *
	
run: build	
	$(CDEL) OBJECT.PRG
	$(EXEBASIC)
	$(CCOPY) BLITZ.PRG $(BINDIR)	
	
x16:
	$(EMULATOR)

