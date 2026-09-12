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
		sbc 	#ObjectOrigin & $FF
		sta 	reportValue
		lda 	objPtr+1
		sbc 	#ObjectOrigin >> 8
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
		jsr 	$FFD2
		jmp 	PrintBankReport 			; ...and a line of its own for the banks, if there are any

; ************************************************************************************************
;
;		reportValue (16 bit) to the screen as decimal, leading zeros suppressed but always at
;		least one digit. Subtract each power of ten as many times as it goes; the count is the
;		digit. Same method as _WMFDecimal, which writes to the map FILE through IOWriteByte --
;		this one goes to CHROUT. They are kept apart rather than sharing an indirect output
;		vector: two tiny routines are easier to be sure of than one with a mode.
;
; ************************************************************************************************

; ************************************************************************************************
;
;		reportValue to the screen as decimal, leading zeros suppressed but always at least one
;		digit. Subtract each power of ten as many times as it goes; the count is the digit. Same
;		method as _WMFDecimal, which writes to the map FILE through IOWriteByte -- this one goes
;		to CHROUT. They are kept apart rather than sharing an indirect output vector: two tiny
;		routines are easier to be sure of than one with a mode.
;
;		TWENTY-FOUR BITS, because the banked total does not fit in sixteen: sixty-three banks of
;		8K is 516,096 bytes. Enter at PrintDecimal with a 16 bit value in the first two bytes and
;		the third is cleared for you, which is what every caller but the bank total wants.
;
; ************************************************************************************************

; ************************************************************************************************
;
;								What went into the RAM banks
;
;		A SECOND LINE, AND ONLY WHEN THERE IS SOMETHING TO SAY. Most programs have no GP.BANKED
;		or GP.BANKEDSTR region at all and get no line, rather than a "BANKS 0" that means nothing.
;
;		The three figures are the count, the bytes held between them, and the fullest single bank.
;		The last is the one worth watching: each region loads at $A000 in a bank of its own and may
;		not exceed 32 pages, so the total can be comfortable while one region is a line away from
;		"GP.BANKED REGION OVER 8K" -- see commands/gpbank.asm.
;
;		layoutCount and layoutPages are pass one's, kept for the bootstrap's table, and neither
;		pass two nor the object writer disturbs them. Page counts, not bytes: a region is padded
;		to a page boundary and the bootstrap copies it a page at a time.
;
; ************************************************************************************************

PrintBankReport:
		lda 	layoutCount
		bne 	_PBRSome
		rts
_PBRSome:
		ldx 	#BanksText & $FF
		ldy 	#BanksText >> 8
		jsr 	PrintMessage
		lda 	layoutCount 					; how many banks
		sta 	reportValue
		stz 	reportValue+1
		jsr 	PrintDecimal
		;
		;		One walk for both totals. Pages, so the running sum needs 16 bits at 63 regions of 32
		;		pages, and the widest single one still fits a byte.
		;
		stz 	bankPages
		stz 	bankPages+1
		stz 	bankMax
		ldx 	#0
_PBRAdd:
		clc
		lda 	layoutPages,x
		adc 	bankPages
		sta 	bankPages
		bcc 	_PBRNoCarry
		inc 	bankPages+1
_PBRNoCarry:
		lda 	layoutPages,x
		cmp 	bankMax
		bcc 	_PBRNotMax
		sta 	bankMax
_PBRNotMax:
		inx
		cpx 	layoutCount
		bne 	_PBRAdd
		;
		;		PAGES TO BYTES IS A SHIFT OF EIGHT, so nothing is multiplied: the page count moves up
		;		one byte and a zero goes in underneath. That is also why the total needs 24 bits.
		;
		lda 	#' '
		jsr 	$FFD2
		stz 	reportValue
		lda 	bankPages
		sta 	reportValue+1
		lda 	bankPages+1
		sta 	reportValue+2
		jsr 	PrintDecimal24
		ldx 	#MaxText & $FF
		ldy 	#MaxText >> 8
		jsr 	PrintMessage
		stz 	reportValue
		lda 	bankMax
		sta 	reportValue+1
		jsr 	PrintDecimal
		lda 	#13
		jmp 	$FFD2


PrintDecimal:
		stz 	reportValue+2 				; the 16 bit entry: two bytes set, third assumed zero
PrintDecimal24:
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
		sta 	reportTemp+1
		lda 	reportValue+2
		sbc 	_PDPow10B,x
		bcc 	_PDUnder 					; borrow -> this power no longer goes
		sta 	reportValue+2
		lda 	reportTemp+1
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
		cpx 	#5 							; 100000, 10000, 1000, 100, 10
		bne 	_PDPow
		lda 	reportValue 				; the units digit is always written
		ora 	#48
		jmp 	$FFD2

_PDPow10L:
		.byte 	<100000, <10000, <1000, <100, <10
_PDPow10H:
		.byte 	>100000, >10000, >1000, >100, >10
_PDPow10B: 									; only 100000 reaches this far, but the loop reads it every
		.byte 	(100000 >> 16) & 255, 0, 0, 0, 0 	; time round, so all five are here

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
BanksText:
		.text 	"BANKS ",0
MaxText:
		.text 	" MAX ",0

reportValue: 								; code section, not storage -- these belong to the
		.fill 	3 							; 24 bit: the banked total passes 65,535 at eight banks
reportTemp: 								; written, so they cost a compiled program nothing.
		.fill 	2 							; See the note in file-io/read.asm.
reportLead:
		.fill 	1
bankPages: 									; pages across every region, and the widest single one
		.fill 	2
bankMax:
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
