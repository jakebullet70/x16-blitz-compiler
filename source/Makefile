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
#		NOTHING BUMPS ANY MORE. The two version stamps -- buildnum.txt (product version, printed
#		as V1.0.0) and rtbuild.txt (runtime build number, the nnn in GPC.RT.nnn.BIN) -- are both
#		edited by hand. The runtime one had to stop moving: its number is the shared runtime's
#		FILE NAME, baked into every object by bootstrap.asm, so a bump per build meant every
#		previously compiled shared-mode program stopped finding its runtime. See
#		application/scripts/bumpbuild.py. This call only regenerates version.asm, idempotently.
#
libraries:
	$(PYTHON) application$(S)scripts$(S)bumpbuild.py
	make $(MAKEOPTS) -C tools
	make $(MAKEOPTS) -C common-source
	make $(MAKEOPTS) -C ifloat32
	make $(MAKEOPTS) -C polynomials
#
#		gp-runtime BEFORE runtime: it produces gp.library, which every one of runtime's own
#		targets links. See gp-runtime/Makefile for why the GP handlers live in their own tree.
#
	make $(MAKEOPTS) -C gp-runtime
	make $(MAKEOPTS) -C runtime
	make $(MAKEOPTS) -C compiler
	make $(MAKEOPTS) -C application

release:
	make $(MAKEOPTS) -C application release
