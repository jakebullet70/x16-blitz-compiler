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
#		into testing/. This replaced the old Prog8/Java build (kept in old-archive/) -- no Java,
#		no prog8c.jar. There is no build number here: it belongs to the engine, which prints its
#		own (source/application/buildnum.txt).
#
#			make -C source/gpc			GPC.BASL -> GPC.SRC.PRG -> testing/GPC.PRG
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
#		GPB.INC.BL is staged FIRST. BASLOAD resolves an #INCLUDE off the DRIVE, and both
#		GPC.BASL and GPC.ERR.BASL now include it, so it has to be sitting in testing/
#		before either tokenise -- not just in GPC-BASIC/. Copied rather than duplicated:
#		GPC-BASIC/ is the master, this is a build artifact, and .gitignore says so.
#		build_basl.py also stages GPC.BASL into testing/, so the source ships from there.
#
build:
	$(CCOPY) ..$(S)..$(S)GPC-BASIC$(S)GPB.INC.BL $(RELEASEDIR)GPB.INC.BL
	$(PYTHON) build_basl.py
	make $(MAKEOPTS) -C ../runtime gpc-rt
	$(PYTHON) compile_shared.py GPC.SRC.PRG GPC.PRG

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
#		The runtime is built by `build` above now, because the FRONT END is shared too.
#		Nothing else in the tree builds gpc-rt, which is how its $9F00 size guard managed
#		to fail unnoticed for weeks; a release that ships shared-mode programs must ship
#		the runtime they need.
#
#
#		GPB.INC.BL is already staged by `build` above, which both sources now need.
#
release: build
	$(PYTHON) build_basl.py GPC.ERR.BASL GPC.ERR.PRG
	$(PYTHON) compile_shared.py GPC.ERR.PRG C.GPC.ERR.PRG M.GPC.ERR

#
#		Launch the freshly built front end. It chain-loads GPC.BIN, which must sit beside
#		it on the drive -- so point the emulator's filesystem root at testing/.
#
run: build
	$(EMULATOR) -fsroot $(RELEASEDIR) -prg $(RELEASEDIR)GPC.PRG -run

clean:
	$(CDEL) $(RELEASEDIR)GPCBLD.BAS $(RELEASEDIR)GPCBLD.LOG
