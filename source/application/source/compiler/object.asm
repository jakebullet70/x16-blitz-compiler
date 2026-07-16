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
;		Pages left free below the workspace for the runtime (GOSUB/FOR) stack. clr.asm puts
;		runtimeStackPtr at storeStartHigh-1:$FF and grows it DOWNWARD, so without a gap here
;		a deep call chain would walk straight back into the object code.
;
FrameStackPages = 16 						; 4K, ~250 frames

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
		jsr 	PatchOutCompile 			; makes it run the runtime on reload
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
		clc
		lda 	#ObjectBase >> 8
		adc 	zTemp1+1
		adc 	#FrameStackPages
		sta 	newWorkspacePage

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
		lda 	#ObjectBase >> 8 			; object code moves down to here
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
		lda 	zTemp0+1 					; until we reach ObjectBase (page aligned)
		cmp 	#ObjectBase >> 8
		bne 	_WOCRuntime
		lda 	zTemp0
		cmp 	#ObjectBase & $FF
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
		rts

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
