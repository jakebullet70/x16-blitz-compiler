# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	Outer makefile
#		Date :		5th October 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\..\documents\common.make
else
include ../../../documents/common.make
endif

#
#		Build the runnable zipapp (python tokenise.zip <in.bas> <out.prg>). mkzip.py stands
#		in for zip(1), which is not present on a stock Windows box, and writes the archive
#		reproducibly -- a plain zipfile.write() stamps mtimes, so this rebuilt byte-different
#		on every make and showed up as a spurious modification in git.
#
all:
	$(CCOPY) tokenise.py __main__.py
	$(PYTHON) $(CSCRIPTS)mkzip.py tokenise.zip __main__.py ..$(S)..$(S)common-scripts$(S)c64tokens.py
	$(CCOPY) tokenise.zip $(BINDIR)
	$(CDEL) __main__.py