# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	Outer makefile
#		Date :		0th October 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

#
#		Bl**dy Windows.
#
ifeq ($(OS),Windows_NT)
include ..\documents\common.make
else
include ../documents/common.make
endif


all: libraries release

#
#		The engine's build number is bumped HERE, once, and nowhere else. application/ is built
#		twice by this file alone (`libraries` below, then `release`), and build.sh runs `make
#		release` again after `make libs`, so bumping inside the application's own prelim counted
#		a single build as three. Every other entry just regenerates version.asm from this number.
#
libraries:
	$(PYTHON) application$(S)scripts$(S)bumpbuild.py --bump
	make $(MAKEOPTS) -C tools
	make $(MAKEOPTS) -C common-source
	make $(MAKEOPTS) -C ifloat32
	make $(MAKEOPTS) -C polynomials
	make $(MAKEOPTS) -C runtime
	make $(MAKEOPTS) -C compiler
	make $(MAKEOPTS) -C application

release:
	make $(MAKEOPTS) -C application release
