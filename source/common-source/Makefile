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

all:
	#
	#		pcode.py emits scripts/pcodeconstraw.py here. Git cannot track an empty
	#		directory, so it does not survive a clone and must be recreated.
	#
	mkdir -p scripts
	$(PYTHON) $(CSCRIPTS)pcode.py >source$(S)generated$(S)pcodetokens.inc
	$(PYTHON) $(CSCRIPTS)c64tokens.py >source$(S)generated$(S)c64tokens.inc
	$(PYTHON) $(CSCRIPTS)errors.py
	$(PYTHON) $(CSCRIPTS)build.py
	$(CCOPY) scripts$(S)pcodeconstraw.py ..$(S)common-scripts
	$(CDEL) scripts$(S)pcodeconstraw.py
	$(CCOPY) _library.asm $(BINDIR)common.library

