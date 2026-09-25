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
#		GPC.BASL, and the source's own  #SAVEAS "@:GPC.SRC.PRG"  writes the tokenised program
#		into drive/. This replaced the old Prog8/Java build (kept in old-archive/) -- no Java,
#		no prog8c.jar. There is no build number here: it belongs to the engine, which prints its
#		own (source/application/buildnum.txt).
#
#			make -C source/gpc			GPC.BASL -> GPC.SRC.PRG -> drive/GPC.PRG
#			make -C source/gpc release	build, then tokenise and compile the GPC.ERR helper
#										in samples/GPC.ERR/
#			make -C source/gpc run		build, then launch the front end in the emulator
#
# *******************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\common.make
else
include ../common.make
endif

#
#		GPC.ERR builds in its own sample folder, which is the emulator drive for it.
#
GPCERRDIR = $(ROOTDIR)samples$(S)GPC.ERR

#
#		All targets are commands, not files -- mark phony so they always run.
#
.PHONY: all build release run clean

all: build

#
#		The front end is a TWO STEP build, because GPC.BASL is written in GP.BASIC:
#		BASLOAD tokenises it to GPC.SRC.PRG, which the ROM cannot RUN (nothing in BASIC
#		is behind $CE7x), and GPC.BIN compiles that into GPC.PRG, which is the front end
#		you launch. GPC.PRG therefore still means what it always meant.
#
#		SHARED, like GPC.ERR: the front end carries no runtime of its own and uses the
#		resident GPB.RT.nnn.BIN -- the GPB one, WITH the handlers, because GP.DO/GP.LOOP
#		need them. So gpc-rt is built HERE, before the compile: a shared front end that
#		cannot find its runtime does not start, and `make run` would hit that first.
#
#		GPB.INC.BL is staged FIRST. BASLOAD resolves an #INCLUDE off the DRIVE, so the
#		copy GPC.BASL includes has to be sitting in drive/ before the tokenise, not
#		just in GPC-BASIC/. GPC-BASIC/ is the master and the staged copy is git-ignored.
#		build_basl.py also stages GPC.BASL into drive/, so the source ships from there.
#
build:
	$(CCOPY) ..$(S)..$(S)GPC-BASIC$(S)GPB.INC.BL $(RELEASEDIR)GPB.INC.BL
	$(PYTHON) build_basl.py
	make $(MAKEOPTS) -C ../runtime gpc-rt
	$(PYTHON) compile_shared.py GPC.SRC.PRG GPC.PRG

#
#		release = the front-end build, then the GPC.ERR helper: tokenised to
#		GPC.ERR.SRC.PRG, then compiled to GPC.ERR.PRG, both in GPCERRDIR. That folder is
#		the emulator drive for the helper and holds its own GPC-BASIC/, GPC.BIN and
#		runtimes, so nothing of GPC.ERR's is staged into drive/. build_basl.py with two
#		args just tokenises, and skips when the source is absent or no newer than the PRG.
#
#		The helper is compiled SHARED, against the GPB.RT.nnn.BIN in that folder: the
#		GPB runtime, the one with the GP handlers. A standalone build of it is the wrong
#		artifact.
#
#		The compile also writes GPC.ERR.OVL, the region overlay, and the program will not
#		run without it. release.sh ships both files. The object name and the overlay name
#		have to agree: the compiler bakes the object's own name into the object and the
#		bootstrap reads <name>.OVL back out of it, so renaming the object renames the
#		overlay everywhere it ships.
#
#		gpc-rt is built by `build` above, because the front end is shared too. A release
#		that ships shared-mode programs must ship the runtime they need.
#
release: build
	$(PYTHON) build_basl.py --drive $(GPCERRDIR) GPC.ERR.BASL GPC.ERR.SRC.PRG
	$(PYTHON) compile_shared.py --drive $(GPCERRDIR) GPC.ERR.SRC.PRG GPC.ERR.PRG GPC.ERR.MAP

#
#		Launch the freshly built front end. It chain-loads GPC.BIN, which must sit beside
#		it on the drive -- so point the emulator's filesystem root at drive/.
#
run: build
	$(EMULATOR) -fsroot $(RELEASEDIR) -prg $(RELEASEDIR)GPC.PRG -run

clean:
	$(CDEL) $(RELEASEDIR)GPCBLD.BAS $(RELEASEDIR)GPCBLD.LOG
