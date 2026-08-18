# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	GP.BASIC runtime handler library makefile.
#		Date :		18th August 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		THIS IS THE SECOND HALF OF THE RUNTIME, AND IT EXISTS ONLY TO CONTROL LAYOUT.
#
#		The handlers here -- GP.DO/LOOP/EXITDO, GP.SELECT and friends, GP.CALL, the string and
#		sort commands, and the X16 drawing/menu/stash set -- used to sit in runtime/source/
#		alongside the interpreter, where build.py's leafname sort dropped them into the MIDDLE
#		of the image. That is the whole problem: the runtime is copied verbatim into every
#		compiled object, so 2,362 bytes of GP handlers are spent by a program that uses none of
#		them, and anything in the middle of the image can never be reclaimed.
#
#		Linked LAST -- after runtime/common/ifloat32/polynomials, immediately before the
#		divider or footer -- they land contiguously at the tail instead, where tier 7 can drop
#		them by lowering ObjectBase, with no relocator. See docs/blitz/GP-BASIC.TIERS.md.
#
#		That truncation is NOT built yet. This Makefile only puts the bytes where it can be.
#
#		WHY THIS IS SAFE: a handler is reachable only through its VectorTable slot -- emitted
#		p-code addresses commands by token, never by handler address -- so nothing below these
#		files ever calls into them. They call DOWN into the interpreter freely (StackOpenFrame,
#		FloatSetByte, the string heap); that direction is fine and stays fine.
#
#		THERE IS NO ASSEMBLE TARGET HERE, deliberately, and it is not an oversight. These files
#		are meaningless on their own -- every one of them references the interpreter -- so there
#		is nothing to assemble and nothing to test in isolation, unlike polynomials/ or
#		ifloat32/. The library is a text concatenation; 64tass only ever sees it linked.
#
#		BUILD ORDER: before runtime/, because runtime/'s own targets link gp.library. That is
#		set in ../Makefile and is the only ordering constraint.
#
# *******************************************************************************************

ifeq ($(OS),Windows_NT)
include ..\..\documents\common.make
else
include ../../documents/common.make
endif

#
#		PHONY, and it is load bearing. These are commands, not files -- and "build" in
#		particular is the name every other library directory here gives its output folder. The
#		first attempt at this Makefile had a build/ directory sitting beside it, so make decided
#		the target was already made and printed "Nothing to be done for 'all'". It then linked
#		on happily against a gp.library that had never been written, and the failure surfaced
#		two directories away as thirty "not defined symbol" errors.
#
.PHONY: all build

all: build

#
#		build.py sweeps source/ into _library.asm, sorted by leafname. That sort is also what
#		fixes the ORDER WITHIN this library, and the order within it is the order the bytes
#		land in -- so if the truncation ever needs the handlers in dependency order rather than
#		alphabetical, this is the single place that changes.
#
build:
	$(PYTHON) $(CSCRIPTS)build.py
	$(CCOPY) _library.asm $(BINDIR)gp.library
