# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		Makefile
#		Purpose:	MD5 end-to-end regression test (compiled must agree with interpreted)
#		Created:	30th July 2026
#
# ************************************************************************************************
# ************************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\..\documents\common.make
else
include ../../../documents/common.make
endif

all: md5

#
#		Run the test. It needs testing/GPC.BLITZ.BIN (make libs) and testing/MD5, which is
#		tracked. Everything else it makes and removes itself.
#
#		This one is slower than the other unit tests -- it runs a real BASIC program twice, once
#		interpreted -- so it is not in the default build. Run it after anything that touches
#		iFloat32, the number parser or the runtime's file I/O.
#
md5:
	$(PYTHON) md5_test.py
