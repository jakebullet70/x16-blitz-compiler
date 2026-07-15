# ***********************************************************************************
#
#										Common Build 
#
# ***********************************************************************************
#
#	NB: Windows SDL2 is hard coded.
#
ifeq ($(OS),Windows_NT)
#
#		The recipes throughout this tree are POSIX (they use ';' chaining and forward
#		slashes), so drive them with the Git-for-Windows shell rather than cmd.exe.
#
SHELL := sh
.SHELLFLAGS := -c
CCOPY = cp
CMAKE = make
CDEL = rm -f
CDELQ =
APPSTEM = .exe
S = /
SDLDIR = C:/sdl2
CXXFLAGS = -I$(SDLDIR)$(S)include$(S)SDL2 -I . -fno-stack-protector -w -Wl,-subsystem,windows -DSDL_MAIN_HANDLED
LDFLAGS = -lmingw32
SDL_LDFLAGS = -L$(SDLDIR)$(S)lib -lSDL2 -lSDL2main -static-libstdc++ -static-libgcc
OSNAME = windows
EXTRAFILES = libwinpthread-1.dll  SDL2.dll
PYTHON ?= python
else
CCOPY = cp
CDEL = rm -f
CDELQ = 
CMAKE = make
APPSTEM =
S = /
SDL_CFLAGS = $(shell sdl2-config --cflags)
SDL_LDFLAGS = $(shell sdl2-config --libs)
CXXFLAGS = $(SDL_CFLAGS) -O2 -DLINUX  -fmax-errors=5 -I.  
LDFLAGS = 
OSNAME = linux
EXTRAFILES =
PYTHON ?= python3
endif
#
#		Directories
#
ROOTDIR =  $(dir $(realpath $(lastword $(MAKEFILE_LIST))))..$(S)
BINDIR = $(ROOTDIR)bin$(S)
RELEASEDIR = $(ROOTDIR)release$(S)
SRCDIR = $(ROOTDIR)source$(S)
CSCRIPTS = $(SRCDIR)common-scripts$(S)
CSOURCE =  $(SRCDIR)common-source$(S)
#
#		Current applications.
# 
#
#		TASS and PYTHON may be overridden per-machine in documents/local.make
#		(untracked) if they are not on the PATH.
#
TASS ?= 64tass
ASM = $(TASS) -q -c -Wall -o build$(S)code.prg -L build$(S)code.lst -l build$(S)code.lbl
#
#		Prog8, which builds GPC.PRG (source/gpc) -- the compiler's front end. It is a 5MB jar
#		and needs a JRE, so it is NOT vendored here and NOT part of "make libs": source/gpc has
#		its own target and the built GPC.PRG is committed to release/. Override either of these
#		in documents/local.make if your paths differ.
#
JAVA ?= java
PROG8C ?= C:$(S)dev$(S)CmdrX16$(S)dos_tools$(S)XFMGR2$(S)prog8c.jar
PROG8 = $(JAVA) -jar $(PROG8C) -target cx16
#
#		Two emulators, both current (r49). The r43 build that used to ship in bin/ is gone.
#		They need different SDL2 versions, so each lives in its own directory.
#
#		EMULATOR (x16emu r49)  - the automated test runner.
#		DEBUGGER (Box16)       - interactive runs; much better debugger UI.
#
#		Both quit when the CPU reaches $FFFF (the .exitemu macro), which is how the test
#		harness signals "pass" -- testing.asm loops forever on failure instead, so a hang
#		means a failed test.
#
#		Box16 is NOT used for the tests: the test .prg files are raw machine code at $0801
#		with no BASIC stub, and given "-prg x.prg,801 -run" x16emu SYSes to the load address
#		whereas Box16 issues RUN, which just yields ?SYNTAX ERROR. GPC.BLITZ.PRG does carry a
#		BASIC SYS stub, so Box16 runs it fine -- hence it drives the interactive targets.
#
EMUDIR = $(BINDIR)x16emu$(S)
BOXDIR = $(BINDIR)box16$(S)
EMULATOR = $(EMUDIR)x16emu$(APPSTEM) -rom $(EMUDIR)rom.bin -scale 2 -debug -zeroram -dump R
DEBUGGER = $(BOXDIR)Box16$(APPSTEM) -rom $(BOXDIR)rom.bin -scale 2 -zeroram
#
#		x16emu writes dump.bin; Box16 writes dump.txt. Clean up both.
#
EXECUTE = $(CDEL) dump*.bin dump*.txt ; $(EMULATOR) -prg build$(S)code.prg,801 -run
EXEBASIC = $(CDEL) dump*.bin dump*.txt ; $(DEBUGGER) -prg build$(S)code.prg -run
COMBASIC = $(DEBUGGER) -prg $(ROOTDIR)source$(S)application$(S)GPC.BLITZ.PRG -run
FAST = -warp
MAKEOPTS = --no-print-directory
#
#		Export path to the common scripts. The generator scripts under each component's
#		scripts/ directory import modules from common-scripts/, so this must be a real
#		exported environment variable on every platform.
#
export PYTHONPATH := $(CSCRIPTS)
#
#		Per-machine overrides (TASS, PYTHON, ...). Untracked; optional.
#
-include $(dir $(realpath $(lastword $(MAKEFILE_LIST))))local.make
#
#		Uncommenting .SILENT will shut the whole build up.
#
ifndef VERBOSE
#.SILENT:
endif