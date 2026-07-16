# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	GPC.PRG -- the front end for the compiler
#		Date :		14th July 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		This is deliberately NOT part of "make libs". Prog8 is a 5MB jar and needs a JRE, and
#		nothing else in this tree does -- making the whole build depend on both, to produce one
#		1K program that changes about once a year, would be a poor trade. So GPC.PRG is built
#		here on demand and the result is committed to testing/.
#
#			make -C source/gpc			build GPC.PRG
#			make -C source/gpc release	build it and put it in testing/
#			make -C source/gpc run		build it and run it in the emulator
#
#		Set PROG8C (and JAVA) in documents/local.make if the jar is not where common.make
#		expects it.
#
# *******************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\documents\common.make
else
include ../../documents/common.make
endif

all: build

#
#		Every target here is a command, not a file -- and one, "build", collides with the build/
#		directory prog8 writes into. Without this, make sees that directory, decides "build" is
#		already made, and silently skips recompiling. Mark them all phony so they always run.
#
.PHONY: all build release run clean

#
#		Every build first stamps a fresh number into GPC.P8 -- the "V0.9.N" GPC prints at startup --
#		so each built GPC.PRG is identifiable on sight. In place, in PowerShell; this is a Windows box.
#		release and run both depend on build, so all three routes bump it.
#
BUMP = powershell -NoProfile -ExecutionPolicy Bypass -File bump-build.ps1

#
#		Prog8 names its output after the source, in lowercase -- GPC.prg. The X16 wants GPC.PRG,
#		and on a case sensitive host those are two different files. It has to be renamed, and it
#		cannot be renamed in place: on Windows GPC.prg and GPC.PRG ARE the same file and cp
#		refuses to copy one onto itself. Hence the build/ directory.
#
build:
	$(BUMP)
	$(PROG8) -out build GPC.P8
	$(CCOPY) build$(S)GPC.prg GPC.PRG

release: build
	$(CCOPY) GPC.PRG $(RELEASEDIR)

#
#		GPC chain-loads GPC.BLITZ.BIN by name, so the compiler has to be sitting next to it.
#
run: build
	$(CCOPY) ..$(S)application$(S)GPC.BLITZ.BIN .
	$(CDEL) dump*.bin dump*.txt
	$(EMULATOR) -prg GPC.PRG -run

clean:
	$(CDEL) GPC.PRG GPC.BLITZ.BIN build$(S)GPC.*
