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
#		Build the runnable zipapp with Python's stdlib zipfile rather than shelling out
#		to zip(1), which is not present on a stock Windows box. Equivalent to "zip -j".
#
all:
	$(CCOPY) tokenise.py __main__.py
	$(PYTHON) -c "import zipfile; z = zipfile.ZipFile('tokenise.zip','w',zipfile.ZIP_DEFLATED); z.write('__main__.py','__main__.py'); z.write('../../common-scripts/c64tokens.py','c64tokens.py'); z.close()"
	$(CCOPY) tokenise.zip $(BINDIR)
	$(CDEL) __main__.py