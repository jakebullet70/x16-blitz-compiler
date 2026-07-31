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
#		no prog8c.jar. There is no build number here: it belongs to the engine, which prints its
#		own (source/application/buildnum.txt).
#
#			make -C source/gpc			build testing/GPC.PRG from GPC.BASL
#			make -C source/gpc release	build, re-tokenise the GPC.ERR helper, build the shared
#										runtime, and compile GPC.ERR against it (C.GPC.ERR.PRG,
#										which release.sh ships as plain GPC.ERR.PRG)
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
#		release = the front-end build, plus a fresh tokenise of the GPC.ERR companion tool
#		(GPC.ERR.BASL -> GPC.ERR.PRG) so the shipped helper matches its source. build_basl.py with
#		two args just tokenises (no mirror), and skips if the source is absent.
#		Everything lands in testing/ (RELEASEDIR).
#
#		GPC.ERR is then COMPILED, in SHARED mode, to C.GPC.ERR.PRG -- the helper you reach for
#		after a crash should not itself be the slowest thing on the disk. SHARED because the
#		resident runtime is already there for compiled programs, so the tool costs ~1.6K rather
#		than carrying its own ~12K copy. Both names exist HERE because one is the compiler's
#		input and the other its output; the release ships only the compiled one, renamed to
#		plain GPC.ERR.PRG (see release.sh) so a user has one name to remember, not two.
#		If the runtime is missing, SRC/GPC.ERR.BASL rebuilds the interpreted version.
#
#		The runtime is built here too. Nothing else in the tree builds gpc-rt, which is how its
#		$9F00 size guard managed to fail unnoticed for weeks; a release that ships a shared-mode
#		tool must ship the runtime that tool needs.
#
release: build
	$(PYTHON) build_basl.py GPC.ERR.BASL GPC.ERR.PRG
	make $(MAKEOPTS) -C ../runtime gpc-rt
	$(PYTHON) compile_shared.py GPC.ERR.PRG C.GPC.ERR.PRG M.GPC.ERR

#
#		Launch the freshly built front end. It chain-loads GPC.BLITZ.BIN, which must sit beside
#		it on the drive -- so point the emulator's filesystem root at testing/.
#
run: build
	$(EMULATOR) -fsroot $(RELEASEDIR) -prg $(RELEASEDIR)GPC.PRG -run

clean:
	$(CDEL) $(RELEASEDIR)GPCBLD.BAS $(RELEASEDIR)GPCBLD.LOG
