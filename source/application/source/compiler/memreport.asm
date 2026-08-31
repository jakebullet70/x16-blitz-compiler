; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		memreport.asm
;		Purpose:	Report what the compiled program costs and what it has left.
;		Created:	18th August 2026
;
; ************************************************************************************************
; ************************************************************************************************
;
;		One line, printed after OK:
;
;			CODE 1234 FREE 20480 RT 12031 GP-BASIC OUT
;			CODE 1234 FREE 19200 RT SHARED
;
;		CODE	the p-code, FreeMemory..objPtr. What the program IS.
;		FREE	what is left above it for variables, strings and arrays -- workspace start up to
;				$9F00 embedded, or up to RTBASE in shared mode where the resident runtime sits on
;				top. This is the number that actually runs out, and nothing printed it before:
;				PROGRAM TOO BIG was the only feedback, and it arrives only once it is too late.
;				It EXCLUDES the 4K frame stack gap, which is reserved, not available.
;		RT		the runtime bytes carried in the object, or SHARED when there are none because
;				the program loads GPC.RT.nnn.BIN instead.
;		GP-BASIC  embedded only -- OUT if the GP.BASIC handler block was dropped (gpscan.asm),
;				IN if some keyword reached it and the whole runtime had to go in. Named for the
;				language, not abbreviated to "GP": the block it is reporting on is the GP.BASIC
;				one, and the line is read by people who know the language by that name.
;
;		All three are computed here rather than stashed by WriteObjectCode: objPtr,
;		newWorkspacePage and runtimeEndPage all survive it unchanged, and WriteMapFile touches
;		none of them, so there is nothing to preserve and no second copy to fall out of step.
;
; ************************************************************************************************

		.section code

PrintMemoryReport:
		;
		;		CODE -- the p-code length.
		;
		ldx 	#CodeText & $FF
		ldy 	#CodeText >> 8
		jsr 	PrintMessage
		sec
		lda 	objPtr
		sbc 	#FreeMemory & $FF
		sta 	reportValue
		lda 	objPtr+1
		sbc 	#FreeMemory >> 8
		sta 	reportValue+1
		jsr 	PrintDecimal
		;
		;		FREE -- workspace start up to the ceiling, which differs by mode. Both ends are
		;		page numbers, so the difference is the high byte of the answer and the low byte
		;		is always zero.
		;
		ldx 	#FreeText & $FF
		ldy 	#FreeText >> 8
		jsr 	PrintMessage
		lda 	#ObjectCeiling >> 8 		; embedded: the object grows up to the I/O page
		ldx 	ModeText
		cpx 	#'S'
		bne 	_PMRCeiling
		lda 	sharedCeilPage 				; shared: whichever runtime file this program will load --
_PMRCeiling:								; RTBASE for the core only, RTGPBASE with the handlers
		sec
		sbc 	newWorkspacePage
		sta 	reportValue+1
		stz 	reportValue
		jsr 	PrintDecimal
		;
		;		RT -- embedded runtime bytes, $0801 to the cut, or SHARED.
		;
		ldx 	#RTText & $FF
		ldy 	#RTText >> 8
		jsr 	PrintMessage
		lda 	ModeText
		cmp 	#'S'
		bne 	_PMREmbedded
		ldx 	#SharedText & $FF 			; "SHARED" then which of the two files it wants
		ldy 	#SharedText >> 8
		jsr 	PrintMessage
		ldx 	#CoreText & $FF
		ldy 	#CoreText >> 8
		lda 	gpUsed
		beq 	_PMRWhich
		ldx 	#FullText & $FF
		ldy 	#FullText >> 8
_PMRWhich:
		jsr 	PrintMessage
		bra 	_PMRDone
_PMREmbedded:
		sec
		lda 	#0 							; the runtime as written: cut - RTIMG_LOAD. The label
		sbc 	#RTIMG_LOAD & $FF 			; used to be StartBasicProgram, which lives in the
		sta 	reportValue 				; runtime image and so is no longer linked here --
		lda 	runtimeEndPage 				; genrtimage.py hands the address across instead.
		sbc 	#RTIMG_LOAD >> 8
		sta 	reportValue+1
		jsr 	PrintDecimal
		;
		;		GP -- and only here, because in shared mode the handlers are in the resident
		;		runtime whatever this program does, so there is nothing to report.
		;
		ldx 	#GPOutText & $FF
		ldy 	#GPOutText >> 8
		lda 	gpUsed
		beq 	_PMRGP
		ldx 	#GPInText & $FF
		ldy 	#GPInText >> 8
_PMRGP:
		jsr 	PrintMessage
_PMRDone:
		lda 	#13
		jmp 	$FFD2

; ************************************************************************************************
;
;		reportValue (16 bit) to the screen as decimal, leading zeros suppressed but always at
;		least one digit. Subtract each power of ten as many times as it goes; the count is the
;		digit. Same method as _WMFDecimal, which writes to the map FILE through IOWriteByte --
;		this one goes to CHROUT. They are kept apart rather than sharing an indirect output
;		vector: two tiny routines are easier to be sure of than one with a mode.
;
; ************************************************************************************************

PrintDecimal:
		stz 	reportLead 					; 0 while we are still dropping leading zeros
		ldx 	#0
_PDPow:
		ldy 	#48 						; '0' + number of subtractions = the digit
_PDSub:
		sec
		lda 	reportValue
		sbc 	_PDPow10L,x
		sta 	reportTemp
		lda 	reportValue+1
		sbc 	_PDPow10H,x
		bcc 	_PDUnder 					; borrow -> this power no longer goes
		sta 	reportValue+1
		lda 	reportTemp
		sta 	reportValue
		iny
		bra 	_PDSub
_PDUnder:
		cpy 	#48 						; a zero digit ...
		bne 	_PDEmit
		lda 	reportLead 					; ... is dropped while still leading
		beq 	_PDNext
_PDEmit:
		lda 	#1
		sta 	reportLead
		phx
		tya
		jsr 	$FFD2 						; CHROUT makes no promise about X
		plx
_PDNext:
		inx
		cpx 	#4 							; 10000, 1000, 100, 10
		bne 	_PDPow
		lda 	reportValue 				; the units digit is always written
		ora 	#48
		jmp 	$FFD2

_PDPow10L:
		.byte 	<10000, <1000, <100, <10
_PDPow10H:
		.byte 	>10000, >1000, >100, >10

;
;		Uppercase throughout: the X16 boots in PETSCII upper/graphics, where lowercase bytes
;		come out as graphics glyphs. Same reason bumpbuild.py emits 'V' not 'v'.
;
CodeText:
		.text 	"CODE ",0
FreeText:
		.text 	" FREE ",0
RTText:
		.text 	" RT ",0
SharedText:
		.text 	"SHARED",0
CoreText: 									; which resident runtime file this program will ask for
		.text 	" RC",0 					; GPC.RC.nnn.BIN -- core only, no GPB handlers
FullText:
		.text 	" RT",0 					; GPC.RT.nnn.BIN -- handlers and core
GPOutText:
		.text 	" GP-BASIC OUT",0
GPInText:
		.text 	" GP-BASIC IN",0

reportValue: 								; code section, not storage -- these belong to the
		.fill 	2 							; compiler and are thrown away when the object is
reportTemp: 								; written, so they cost a compiled program nothing.
		.fill 	2 							; See the note in file-io/read.asm.
reportLead:
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
