; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		object.asm
;		Purpose:	Write object code out.
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;									Write object code out.
;
; ************************************************************************************************

;
;		FrameStackPages -- the gap left below the workspace for the runtime (GOSUB/FOR) stack --
;		was defined here. It now lives in common-source/source/common.inc, because the runtime
;		needs the same number to know where the bottom of that gap is (StackOpenFrame).
;

; ************************************************************************************************
;
;		Write object code out.
;
;		In memory the layout is
;
;			$0801 [ runtime ] ObjectBase [ compiler ] FreeMemory [ object code ] objPtr
;
;		but a saved program never compiles anything, so the compiler is dead weight. The
;		file is therefore written in two pieces -- the runtime, then the object code -- so
;		that on reload the object code lands at ObjectBase, on top of where the compiler was.
;
;		That reclaims (FreeMemory-ObjectBase) bytes from every compiled program, and, more
;		importantly, lets the workspace start just above the object code instead of at a
;		hardcoded $8000 -- which is most of the useable memory a compiled program gets.
;
;		The two immediates in StartCode are patched as they stream past, rather than in RAM,
;		so the copy still in memory (RUN a second time) keeps running from FreeMemory.
;
; ************************************************************************************************

WriteObjectCode:
		lda 	ModeText 					; GPC.INPUT line 4 -- 'S' (SHARED) selects resident-runtime
		cmp 	#'S' 						; mode: emit a bootstrap + p-code, no embedded runtime
		bne 	_WOCEmbedded 				; (see the shared branch below and compiler/bootstrap.asm).
		jmp 	_WOCShared 					; jmp, not a branch -- the embedded path is >127 bytes
_WOCEmbedded:
		jsr 	PatchOutCompile 			; makes it run the runtime on reload
		jsr 	ScanGPUsage 				; does anything reach a handler above GPBase ?
		;
		;		The cut. A program using no GP.BASIC keyword takes the runtime as $0801..GPBase
		;		and puts its object code there; one that uses any takes the whole thing,
		;		$0801..ObjectBase, exactly as before. Both labels are page aligned, so a single
		;		page number says which -- and it is used THREE times below (the copy terminator,
		;		the RunCodePage patch and the workspace base), so it is settled once, here.
		;
		lda 	#GPBase >> 8
		ldx 	gpUsed
		beq 	_WOCCutSet
		lda 	#ObjectBase >> 8
_WOCCutSet:
		sta 	runtimeEndPage
		sec 								; page delta: where it will run, less where it sits now
		sbc 	#FreeMemory >> 8
		jsr 	AsmPatchBlobs 				; resolve every GP.ASM .word operand now that the
											; run base is finally known
		;
		;		zTemp1 = length of the object code.
		;
		sec
		lda 	objPtr
		sbc 	#FreeMemory & $FF
		sta 	zTemp1
		lda 	objPtr+1
		sbc 	#FreeMemory >> 8
		sta 	zTemp1+1
		;
		;		Round that up to whole pages.
		;
		lda 	zTemp1 						; any part page ?
		beq 	_WOCWholePages
		inc 	zTemp1+1 					; then it needs one more
_WOCWholePages:
		;
		;		newWorkspacePage = ObjectBase + pages(object code) + the frame stack gap.
		;
		;		...and then check the program can actually RUN, which the embedded path never
		;		did -- only the SHARED path had the equivalent test. That was survivable while
		;		the compiler itself capped p-code at 12,032 bytes; with the object buffer now
		;		reaching $9EFF it is not, because a program can be compiled successfully and
		;		still leave no room above itself for variables, arrays and strings. It would
		;		load, start, and then fail in some unrelated-looking way at run time.
		;
		;		The workspace runs from newWorkspacePage to $9F00, so require MIN_WS_PAGES (4K)
		;		of it, and reject a page count that overflowed a byte on the way -- the same two
		;		tests, in the same order, as _WOCShared.
		;
		clc
		lda 	runtimeEndPage 				; where the object code will actually land
		adc 	zTemp1+1
		bcs 	_WOCTooBig
		adc 	#FrameStackPages
		bcs 	_WOCTooBig
		sta 	newWorkspacePage
		cmp 	#(ObjectCeiling >> 8) - MIN_WS_PAGES + 1
		bcc 	_WOCFits
_WOCTooBig:
		jmp 	_WOCSBig 					; shared with the SHARED path: prints PROGRAM TOO BIG,
_WOCFits: 									; returns carry set, caller skips the map file and OK

		ldy 	#ObjectFile >> 8
		ldx 	#ObjectFile & $FF
		jsr 	IOOpenWrite 				; open write

		lda 	#1 							; write out the load address $0801
		jsr 	IOWriteByte
		lda 	#8
		jsr 	IOWriteByte
		;
		;		Part one : the runtime, $0801 up to ObjectBase, patching the two immediates
		;		in StartCode on the way past.
		;
		.set16 	zTemp0,StartBasicProgram
_WOCRuntime:
		lda 	zTemp0+1 					; the code page operand ?
		cmp 	#(RunCodePage+1) >> 8
		bne 	_WOCNotCodePage
		lda 	zTemp0
		cmp 	#(RunCodePage+1) & $FF
		bne 	_WOCNotCodePage
		lda 	runtimeEndPage 				; object code moves down to here
		bra 	_WOCEmit
_WOCNotCodePage:
		lda 	zTemp0+1 					; the workspace page operand ?
		cmp 	#(RunWorkspacePage+1) >> 8
		bne 	_WOCPlain
		lda 	zTemp0
		cmp 	#(RunWorkspacePage+1) & $FF
		bne 	_WOCPlain
		lda 	newWorkspacePage 			; so the workspace can start much lower
		bra 	_WOCEmit
_WOCPlain:
		lda 	(zTemp0)
_WOCEmit:
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCSkip1
		inc 	zTemp0+1
_WOCSkip1:
		lda 	zTemp0+1 					; until we reach the cut (both candidates are page
		cmp 	runtimeEndPage 				; aligned, so the low byte is always zero there)
		bne 	_WOCRuntime
		lda 	zTemp0
		bne 	_WOCRuntime
		;
		;		Part two : the object code itself, which lands at ObjectBase on reload.
		;
		.set16 	zTemp0,FreeMemory
_WOCCode:
		lda 	zTemp0 						; done ?
		cmp 	objPtr
		bne 	_WOCCodeByte
		lda 	zTemp0+1
		cmp 	objPtr+1
		beq 	_WOCDone
_WOCCodeByte:
		lda 	(zTemp0)
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCCode
		inc 	zTemp0+1
		bra 	_WOCCode
_WOCDone:
		jsr 	IOWriteClose 				; close the file.
		clc 								; success -- CompileCode reads the carry (set = rejected)
		rts

; ************************************************************************************************
;
;		Shared (resident-runtime) output: [$0801 bootstrap][$0900 p-code], no embedded runtime.
;		The bootstrap (compiler/bootstrap.asm) is streamed as the first 255 bytes with WS_START
;		patched in; the p-code follows and lands at $0900 on reload. A program whose p-code +
;		frame-stack gap + minimum workspace would not fit below RTBASE is rejected (carry set).
;
; ************************************************************************************************

_WOCShared:
		;
		;		p-code length -> whole pages (same as the embedded path)
		;
		sec
		lda 	objPtr
		sbc 	#FreeMemory & $FF
		sta 	zTemp1
		lda 	objPtr+1
		sbc 	#FreeMemory >> 8
		sta 	zTemp1+1
		lda 	zTemp1
		beq 	_WOCSWhole
		inc 	zTemp1+1
_WOCSWhole:
		;
		;		WS_START = PCODE_PAGE + pages(p-code) + the frame-stack gap. Reject if that leaves
		;		fewer than MIN_WS_PAGES below RTBASE, or if the page count itself overflowed a byte.
		;
		jsr 	ScanGPUsage 				; the shared runtime is two files now -- see below
		lda 	#(PCODE_PAGE - (FreeMemory >> 8)) & $FF	; shared p-code always lands at $0900
		jsr 	AsmPatchBlobs
		;
		;		The workspace ends where the resident runtime starts, and that is no longer one
		;		address: a program using no GPB keyword loads the CORE-ONLY file at RTBASE and keeps
		;		everything below it, one using GPB loads the full file at RTGPBASE and stops there.
		;		2,560 bytes between them, so it is worth knowing which.
		;
		lda 	#RTBASE >> 8
		ldx 	gpUsed
		beq 	_WOCSCeiling
		lda 	#RTGPBASE >> 8
_WOCSCeiling:
		sta 	sharedCeilPage
		clc
		lda 	#PCODE_PAGE
		adc 	zTemp1+1
		bcs 	_WOCSBigFar
		adc 	#FrameStackPages
		bcs 	_WOCSBigFar
		sta 	newWorkspacePage 			; reuse this byte to carry WS_START
		;
		;		Reject unless MIN_WS_PAGES still fit below the ceiling. Computed as a THRESHOLD and
		;		compared, rather than subtracting the ceiling from the start page: the subtraction
		;		underflows when the p-code has already run past the ceiling, and an underflow reads as
		;		a small positive gap -- i.e. it accepts exactly the programs it exists to reject.
		;
		lda 	sharedCeilPage
		sec
		sbc 	#MIN_WS_PAGES - 1 			; the highest start page that still leaves a workspace
		sta 	zTemp1 						; (the low byte is spent -- only zTemp1+1 is still live)
		lda 	newWorkspacePage
		cmp 	zTemp1
		bcs 	_WOCSBigFar
		bra 	_WOCSFits
;
;		_WOCSBig is at the far end of this file, out of branch range from here -- the same
;		trampoline FixBranches needs for its GP.EXITDO handler, for the same reason.
;
_WOCSBigFar:
		jmp 	_WOCSBig
_WOCSFits:
		;
		;		Header: a normal PRG loading at $0801 -- the bootstrap sits there.
		;
		ldy 	#ObjectFile >> 8
		ldx 	#ObjectFile & $FF
		jsr 	IOOpenWrite
		lda 	#1
		jsr 	IOWriteByte
		lda 	#8
		jsr 	IOWriteByte
		;
		;		Part one: the bootstrap, ProgramBootstrap..ProgramBootstrapEnd, patching three operand
		;		bytes as they stream past. Build the table first -- the addresses are constants but all
		;		three VALUES are per-program, so it cannot be static data.
		;
		.set16 	BootPatchTable, ProgramBootstrap+BootWSPatchOffset
		lda 	newWorkspacePage 			; where this program's workspace starts
		sta 	BootPatchTable+2
		.set16 	BootPatchTable+3, ProgramBootstrap+BootWSEndPatchOffset
		lda 	sharedCeilPage 				; ... and where it ends: RTBASE or RTGPBASE
		sta 	BootPatchTable+5
		.set16 	BootPatchTable+6, ProgramBootstrap+BootGPPatchOffset
		lda 	gpUsed 						; ... and whether the handlers have to come with it
		beq 	_WOCSFlag
		lda 	#1 							; normalise: the bootstrap tests it with BEQ
_WOCSFlag:
		sta 	BootPatchTable+8
		.set16 	zTemp0,ProgramBootstrap
_WOCSBoot:
		;
		;		THREE patched bytes now, not one, so the loop asks a table rather than growing a third
		;		copy of the same compare. Each entry is (address lo, hi, value): workspace START page,
		;		workspace END page -- which is the runtime base this program will use -- and the flag
		;		saying whether it needs the GPB handlers at all.
		;
		ldx 	#0
_WOCSBootPatch:
		lda 	zTemp0
		cmp 	BootPatchTable,x
		bne 	_WOCSBootNext
		lda 	zTemp0+1
		cmp 	BootPatchTable+1,x
		bne 	_WOCSBootNext
		lda 	BootPatchTable+2,x 			; the byte to substitute
		bra 	_WOCSBootEmit
_WOCSBootNext:
		inx
		inx
		inx
		cpx 	#BootPatchEnd-BootPatchTable
		bne 	_WOCSBootPatch
		lda 	(zTemp0)
_WOCSBootEmit:
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCSBootNoHi
		inc 	zTemp0+1
_WOCSBootNoHi:
		lda 	zTemp0
		cmp 	#<ProgramBootstrapEnd
		bne 	_WOCSBoot
		lda 	zTemp0+1
		cmp 	#>ProgramBootstrapEnd
		bne 	_WOCSBoot
		;
		;		Part two: the p-code from FreeMemory..objPtr, which lands at $0900 on reload.
		;
		.set16 	zTemp0,FreeMemory
_WOCSCode:
		lda 	zTemp0
		cmp 	objPtr
		bne 	_WOCSCodeByte
		lda 	zTemp0+1
		cmp 	objPtr+1
		beq 	_WOCSCodeDone
_WOCSCodeByte:
		lda 	(zTemp0)
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCSCode
		inc 	zTemp0+1
		bra 	_WOCSCode
_WOCSCodeDone:
		jsr 	IOWriteClose
		clc 								; success
		rts
_WOCSBig:
		ldx 	#ProgramTooBigText & $FF
		ldy 	#ProgramTooBigText >> 8
		jsr 	PrintMessage
		sec 								; rejected -- CompileCode skips the map file and the OK
		rts

ProgramTooBigText:
		.text 	"PROGRAM TOO BIG", 13, 0

; ************************************************************************************************
;
;		Write the debug MAP file, if GPC.INPUT gave a third line (its name). The map turns a
;		runtime error's "@ $XXXX" back into a source line, which is otherwise a hand decode of
;		the p-code. One text line per source line, in ascending code order:
;
;			0030 12
;
;		the 4-digit hex P-CODE OFFSET -- exactly what the runtime prints as "@ $0030" -- then a
;		space and the DECIMAL BASIC line number that begins there. To place an error, find the
;		largest offset that is <= the one reported.
;
;		It is built straight from the compiler's line-number table (STRMarkLine): 4-byte entries
;		[line# lo, line# hi, addr lo, addr hi], growing DOWNWARD from compilerEndHigh:$00 to
;		lineNumberTable, walked here from the top down so the file comes out in code order. The
;		stored addr is the compile-time position in the object buffer (based at FreeMemory), so
;		offset = addr - FreeMemory -- the same number the runtime reports, because the object is
;		copied verbatim from FreeMemory to its run address. The two synthetic lines the implicit
;		-DIM prologue adds show up as line 65024 ($FE00, the end marker) and 65535 ($FFFF, the
;		prologue); they are real code positions, just not the user's.
;
; ************************************************************************************************

WriteMapFile:
		lda 	OptionsText 				; no third line -> no map asked for.
		bne 	_WMFStart
		rts
_WMFStart:
		ldy 	#OptionsText >> 8 			; open the map file for write (logical file 3, as the
		ldx 	#OptionsText & $FF 			; object write already closed).
		jsr 	IOOpenWrite
		lda 	compilerEndHigh 			; walk from the top of the table ...
		sta 	mapWalk+1
		stz 	mapWalk
_WMFLoop:
		sec 								; ... down one 4-byte entry at a time.
		lda 	mapWalk
		sbc 	#4
		sta 	mapWalk
		lda 	mapWalk+1
		sbc 	#0
		sta 	mapWalk+1
		lda 	mapWalk+1 					; stop once below the last (lowest) entry.
		cmp 	lineNumberTable+1
		bcc 	_WMFDone
		bne 	_WMFEntry
		lda 	mapWalk
		cmp 	lineNumberTable
		bcc 	_WMFDone
_WMFEntry:
		jsr 	_WMFWriteEntry
		bra 	_WMFLoop
_WMFDone:
		jmp 	IOWriteClose

;
;		Write one entry: "<hhhh> <ddddd>",CR. Everything the line needs is pulled out through
;		zTemp0 up front, before any IOWriteByte -- CHROUT to a file is free to trash zero page,
;		but mapValue/mapOff are plain RAM and survive it.
;
_WMFWriteEntry:
		lda 	mapWalk 					; point zTemp0 at the entry.
		sta 	zTemp0
		lda 	mapWalk+1
		sta 	zTemp0+1
		;
		;		The table is in banked RAM now, so page it in for the four reads and page it back
		;		out again before any file I/O -- the KERNAL owns bank 0. That the entry is fully
		;		unpacked into mapValue/mapOff before the first IOWriteByte was already true (see
		;		the note above); it is now load-bearing rather than merely tidy.
		;
		.storage_access
		ldy 	#0 							; line number -> mapValue (consumed by the decimal print)
		lda 	(zTemp0),y
		sta 	mapValue
		ldy 	#1
		lda 	(zTemp0),y
		sta 	mapValue+1
		ldy 	#2 							; offset = stored address - FreeMemory (page aligned)
		lda 	(zTemp0),y
		sec
		sbc 	#FreeMemory & $FF
		sta 	mapOff
		ldy 	#3
		lda 	(zTemp0),y
		sbc 	#FreeMemory >> 8
		sta 	mapOff+1
		.storage_release
		lda 	mapOff+1 					; hex offset, high byte then low.
		jsr 	_WMFHexByte
		lda 	mapOff
		jsr 	_WMFHexByte
		lda 	#' '
		jsr 	IOWriteByte
		jsr 	_WMFDecimal 				; decimal line number.
		lda 	#10 						; LF ends the line -- this file is read on the host (grep,
		jmp 	IOWriteByte 				; VS Code), not the X16, so a Unix newline suits it best.

;
;		A (0..255) as two hex digits. Same trick as the runtime error handler.
;
_WMFHexByte:
		pha
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		jsr 	_WMFNibble
		pla
_WMFNibble:
		and 	#15
		cmp 	#10
		bcc 	_WMFDigit
		adc 	#6 							; carry set here: 10 -> +6+1 = 'A'
_WMFDigit:
		adc 	#48
		jmp 	IOWriteByte

;
;		mapValue (16 bit) as decimal, leading zeros suppressed but always at least one digit.
;		Subtract each power of ten as many times as it goes; the count is the digit.
;
_WMFDecimal:
		stz 	mapLead 					; 0 while we are still dropping leading zeros
		ldx 	#0
_WMFDPow:
		ldy 	#48 						; '0' + number of subtractions = the digit
_WMFDSub:
		sec
		lda 	mapValue
		sbc 	_WMFPow10L,x
		sta 	mapTemp
		lda 	mapValue+1
		sbc 	_WMFPow10H,x
		bcc 	_WMFDUnder 					; borrow -> this power no longer goes
		sta 	mapValue+1
		lda 	mapTemp
		sta 	mapValue
		iny
		bra 	_WMFDSub
_WMFDUnder:
		cpy 	#48 						; a zero digit ...
		bne 	_WMFDEmit
		lda 	mapLead 					; ... is dropped while still leading
		beq 	_WMFDNext
_WMFDEmit:
		lda 	#1
		sta 	mapLead
		tya
		jsr 	IOWriteByte
_WMFDNext:
		inx
		cpx 	#4 							; 10000, 1000, 100, 10
		bne 	_WMFDPow
		lda 	mapValue 					; the units digit is always written
		ora 	#48
		jmp 	IOWriteByte

_WMFPow10L:
		.byte 	<10000, <1000, <100, <10
_WMFPow10H:
		.byte 	>10000, >1000, >100, >10

BootPatchTable: 							; three (addr lo, addr hi, value) triples, built per program
		.fill 	9 							; by the shared path just above -- see the note there.
BootPatchEnd:
sharedCeilPage: 							; page the shared workspace stops at: RTBASE normally,
		.fill 	1 							; RTGPBASE when the GPB handlers sit below it.
runtimeEndPage: 							; first page ABOVE the runtime as written out: GPBase if the
		.fill 	1 							; GP block was dropped, ObjectBase if it was kept.
newWorkspacePage: 							; first page of workspace in the saved file. In the code
		.fill 	1 							; section, not storage -- see the note in
											; file-io/read.asm.
mapWalk: 									; these too live in the code section, not storage -- they
		.fill 	2 							; belong to the compiler and are thrown away when the
mapValue: 									; object is written, so they cost a compiled program
		.fill 	2 							; nothing. See the note in file-io/read.asm.
mapOff:
		.fill 	2
mapTemp:
		.fill 	2
mapLead:
		.fill 	1
		.send code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;
; ************************************************************************************************
