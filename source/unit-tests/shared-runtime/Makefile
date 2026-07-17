# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		Makefile
#		Purpose:	SHARED (resident-runtime) mode regression test
#		Created:	17th July 2026
#
# ************************************************************************************************
# ************************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\..\documents\common.make
else
include ../../../documents/common.make
endif

all: shared

#
#		Run the test. It needs testing/GPC.BLITZ.BIN (make libs) and testing/GPC.RT.BIN
#		(make -C source/runtime gpc-rt) -- "make build" makes both, or use "make rebuild"
#		to build then test in one step.
#
shared:
	$(PYTHON) shared_test.py

build:
	$(CMAKE) $(MAKEOPTS) -C ..$(S)..$(S).. libs
	$(CMAKE) $(MAKEOPTS) -C ..$(S)..$(S)runtime gpc-rt

rebuild: build shared
