# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	GPC.PRG -- the compiler's front end, tokenised from BASLOAD source GPC.BASL.
#
# *******************************************************************************************
# *******************************************************************************************
#
#		The front end is written in BASLOAD source (GPC.BASL). BASLOAD is an X16 ROM utility, so
#		there is no host tokeniser: build_basl.py boots the bundled emulator, runs BASLOAD on
#		GPC.BASL, and the source's own  #SAVEAS "@:GPC.PRG"  writes the tokenised program straight
#		into testing/. This replaced the old Prog8/Java build (kept in old-archive/) -- no Java,
#		no prog8c.jar. build_basl.py bumps the build number (VERSION$ in GPC.BASL) on every build.
#
#			make -C source/gpc			build testing/GPC.PRG from GPC.BASL
#			make -C source/gpc release	same -- GPC.BASL and GPC.PRG both land in testing/
#			make -C source/gpc run		build, then launch the front end in the emulator
#
# *******************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\documents\common.make
else
include ../../documents/common.make
endif

#
#		All targets are commands, not files -- mark phony so they always run.
#
.PHONY: all build release run clean

all: build

#
#		Tokenise GPC.BASL -> testing/GPC.PRG headlessly. build_basl.py also stages GPC.BASL into
#		testing/ (the emulator drive), so both the source and the PRG ship from there.
#
build:
	$(PYTHON) build_basl.py

#
#		Everything already lands in testing/ (RELEASEDIR) during build, so release == build.
#
release: build

#
#		Launch the freshly built front end. It chain-loads GPC.BLITZ.BIN, which must sit beside
#		it on the drive -- so point the emulator's filesystem root at testing/.
#
run: build
	$(EMULATOR) -fsroot $(RELEASEDIR) -prg $(RELEASEDIR)GPC.PRG -run

clean:
	$(CDEL) $(RELEASEDIR)GPCBLD.BAS $(RELEASEDIR)GPCBLD.LOG
