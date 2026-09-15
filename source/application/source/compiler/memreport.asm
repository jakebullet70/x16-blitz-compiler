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
;		Printed after OK, a line at a time:
;
;			OK LOW CODE 11776, SHARED GPBASIC
;			RUNTIME 13567 									embedded only
;			LOW FREE 9728, FRAME STACK 2048
;			LINES 2744
;			DEAD CODE:  202 LINES REMOVED, 1413 BYTES SAVED 		only with removal on
;			BANK   7 CODE  3328 USED  4864 FREE 				a line a bank, only if any
;			BANK  12 TEXT  3840 USED  4352 FREE
;			TOTAL BANKS 2, 7168 USED
;
;		LOW CODE  the p-code that stays in low memory: FreeMemory up to objPtr, or up to
;				gpBankStart once a GP.BANKED region or GP.BANKEDSTR text has gone into a bank,
;				because those bytes load into their banks. It is the length PrepareObjectCode
;				rounds up to pages (compiler/object.asm), so where the p-code lands, plus those
;				pages, plus the frame stack, is where the workspace starts.
;		SHARED	the program loads a resident runtime file; EMBEDDED, it carries its own.
;		GPBASIC	the GP.BASIC handlers are in: shared, the program asks for GPB.RT.nnn.BIN;
;				embedded, some keyword reached the handler block and the whole runtime went in.
;				CORE when they are not: GPC.RT.nnn.BIN, or the block dropped (gpscan.asm).
;		RUNTIME	the runtime bytes an embedded object carries.
;		LOW FREE  what is left for variables, strings and arrays -- workspace start up to $9F00
;				embedded, or up to the resident runtime in shared mode. This is the number that
;				actually runs out.
;		FRAME STACK  the gap between the p-code and the workspace, for GOSUB and FOR frames.
;				Reserved, so LOW FREE does not include it.
;		LINES	the source lines the last pass read, whichever reader read them -- the main loop,
;				or GP.ASM and GP.BANKEDSTR pulling in their own bodies -- less the ones dead-code
;				removal left out, which were read past and not compiled.
;		DEAD CODE  only when GPC.INPUT line 5 turned removal on: the lines left out, then the
;				bytes that saved -- pass zero's length less pass one's. Four wide each.
;		BANK	one line per GP.BANKED region and GP.BANKEDSTR text bank -- see PrintBankReport.
;
;		All of it is computed here rather than stashed by WriteObjectCode: objPtr, gpBankStart,
;		newWorkspacePage and runtimeEndPage all survive it unchanged, and WriteMapFile touches
;		none of them, so there is nothing to preserve and no second copy to fall out of step.
;
; ************************************************************************************************

		.section code

PrintMemoryReport:
		;
		;		LOW CODE -- the p-code length, less anything that went into a bank.
		;
		ldx 	#CodeText & $FF
		ldy 	#CodeText >> 8
		jsr 	PrintMessage
		lda 	objPtr
		ldy 	objPtr+1
		ldx 	gpBankActive
		beq 	_PMRLowEnd
		lda 	gpBankStart 				; the lowest banked byte, page aligned
		ldy 	gpBankStart+1
_PMRLowEnd:
		sec
		sbc 	#ObjectOrigin & $FF
		sta 	reportValue
		tya
		sbc 	#ObjectOrigin >> 8
		sta 	reportValue+1
		jsr 	PrintDecimal
		;
		;		SHARED or EMBEDDED, then whether the GP.BASIC handlers are in.
		;
		ldx 	#EmbeddedText & $FF
		ldy 	#EmbeddedText >> 8
		lda 	ModeText
		cmp 	#'S'
		bne 	_PMRMode
		ldx 	#SharedText & $FF
		ldy 	#SharedText >> 8
_PMRMode:
		jsr 	PrintMessage
		ldx 	#CoreText & $FF
		ldy 	#CoreText >> 8
		lda 	gpUsed
		beq 	_PMRHandlers
		ldx 	#GPBasicText & $FF
		ldy 	#GPBasicText >> 8
_PMRHandlers:
		jsr 	PrintMessage
		lda 	#13
		jsr 	$FFD2
		;
		;		RUNTIME -- embedded only. A shared program carries none.
		;
		lda 	ModeText
		cmp 	#'S'
		beq 	_PMRFree
		ldx 	#RuntimeText & $FF
		ldy 	#RuntimeText >> 8
		jsr 	PrintMessage
		sec
		lda 	#0 							; the runtime as written: cut - RTIMG_LOAD. The label
		sbc 	#RTIMG_LOAD & $FF 			; used to be StartBasicProgram, which lives in the
		sta 	reportValue 				; runtime image and so is no longer linked here --
		lda 	runtimeEndPage 				; genrtimage.py hands the address across instead.
		sbc 	#RTIMG_LOAD >> 8
		sta 	reportValue+1
		jsr 	PrintDecimal
		lda 	#13
		jsr 	$FFD2
		;
		;		LOW FREE -- workspace start up to the ceiling, which differs by mode. Both ends are
		;		page numbers, so the difference is the high byte of the answer and the low byte
		;		is always zero. The frame stack is pages too.
		;
_PMRFree:
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
		ldx 	#FrameText & $FF
		ldy 	#FrameText >> 8
		jsr 	PrintMessage
		lda 	#FrameStackPages
		sta 	reportValue+1
		stz 	reportValue
		jsr 	PrintDecimal
		lda 	#13
		jsr 	$FFD2
		;
		;		LINES -- every line this pass read, less the lines removal left out.
		;
		ldx 	#LinesText & $FF
		ldy 	#LinesText >> 8
		jsr 	PrintMessage
		lda 	dcReads
		sta 	reportValue
		lda 	dcReads+1
		sta 	reportValue+1
		lda 	dcEnabled 					; only pass zero clears the list count, so with removal
		beq 	_PMRLinesOut 				; off it is not this compile's
		sec
		lda 	reportValue
		sbc 	dcListCount
		sta 	reportValue
		lda 	reportValue+1
		sbc 	dcListCount+1
		sta 	reportValue+1
_PMRLinesOut:
		jsr 	PrintDecimal
		lda 	#13
		jsr 	$FFD2
		;
		;		DEAD CODE -- only when dead code was being removed.
		;
		lda 	dcEnabled
		beq 	_PMREnd
		ldx 	#DeadText & $FF
		ldy 	#DeadText >> 8
		jsr 	PrintMessage
		lda 	dcListCount 				; the lines left out
		sta 	reportValue
		lda 	dcListCount+1
		sta 	reportValue+1
		lda 	#4
		jsr 	PrintDecimalField
		ldx 	#LinesRemovedText & $FF
		ldy 	#LinesRemovedText >> 8
		jsr 	PrintMessage
		lda 	dcRemovedBytes 				; ...and the bytes that saved
		sta 	reportValue
		lda 	dcRemovedBytes+1
		sta 	reportValue+1
		lda 	#4
		jsr 	PrintDecimalField
		ldx 	#BytesSavedText & $FF
		ldy 	#BytesSavedText >> 8
		jsr 	PrintMessage
		lda 	#13
		jsr 	$FFD2
_PMREnd:
		jmp 	PrintBankReport

; ************************************************************************************************
;
;								What went into the RAM banks
;
;		A LINE A BANK, AND ONLY WHEN THERE IS ONE. Most programs have no GP.BANKED or
;		GP.BANKEDSTR at all and get no bank lines, rather than a "TOTAL BANKS 0" that means
;		nothing.
;
;		ONE LAYOUT ENTRY IS ONE BANK. GPBankCheckBankFree refuses a second GP.BANKED on a bank,
;		BStrRegister refuses text on a bank a GP.BANKED owns, and BStrSelectBank keeps the text
;		banks distinct. BStrRegister enters each text bank's number in gpBankBanks too, so that
;		one table names every bank, as it names every .nnn file. The text entries are the last
;		bstrBankCount of the layout, in slot order (commands/gpbstrflush.asm).
;
;		USED IS WHOLE PAGES. A region is padded to a page boundary, layoutPages is what the
;		bootstrap copies, and the page count is what the two OVER 8K checks hold to 32 -- so FREE
;		is room that is certainly there, and the part page at the top of USED may hold a little
;		more.
;
;		layoutCount and layoutPages are pass one's, kept for the bootstrap's table, and neither
;		pass two nor the object writer disturbs them. bstrBankCount is pass two's, which found
;		the same banks in the same order.
;
; ************************************************************************************************

PrintBankReport:
		lda 	layoutCount
		bne 	_PBRSome
		rts
_PBRSome:
		sec 								; the first text entry: GP.BANKEDSTR from here on,
		sbc 	bstrBankCount 				; GP.BANKED below it
		sta 	bankFirstText
		stz 	bankPages
		stz 	bankPages+1
		stz 	bankIndex
		;
		;		BANK nnn, and CODE or TEXT.
		;
_PBRLine:
		ldx 	#BankText & $FF
		ldy 	#BankText >> 8
		jsr 	PrintMessage
		ldx 	bankIndex
		lda 	gpBankBanks,x
		sta 	reportValue
		stz 	reportValue+1
		lda 	#3
		jsr 	PrintDecimalField
		ldx 	#BankCodeText & $FF
		ldy 	#BankCodeText >> 8
		lda 	bankIndex
		cmp 	bankFirstText
		bcc 	_PBRKind
		ldx 	#BankTextText & $FF
		ldy 	#BankTextText >> 8
_PBRKind:
		jsr 	PrintMessage
		;
		;		USED and FREE. PAGES TO BYTES IS A SHIFT OF EIGHT, so nothing is multiplied: the
		;		page count is the high byte and the low byte is zero. A bank is 32 pages.
		;
		ldx 	bankIndex
		lda 	layoutPages,x
		sta 	reportValue+1
		stz 	reportValue
		lda 	#5
		jsr 	PrintDecimalField
		ldx 	#BankUsedText & $FF
		ldy 	#BankUsedText >> 8
		jsr 	PrintMessage
		ldx 	bankIndex
		sec
		lda 	#32
		sbc 	layoutPages,x
		sta 	reportValue+1
		stz 	reportValue
		lda 	#6
		jsr 	PrintDecimalField
		ldx 	#BankFreeText & $FF
		ldy 	#BankFreeText >> 8
		jsr 	PrintMessage
		lda 	#13
		jsr 	$FFD2
		;
		;		...into the total, and on to the next entry.
		;
		ldx 	bankIndex
		clc
		lda 	layoutPages,x
		adc 	bankPages
		sta 	bankPages
		bcc 	_PBRNoCarry
		inc 	bankPages+1
_PBRNoCarry:
		inc 	bankIndex
		lda 	bankIndex
		cmp 	layoutCount
		bne 	_PBRLine
		;
		;		TOTAL BANKS -- the count of the lines above, then the bytes between them. The
		;		page sum moves up a byte as before, which is why it needs 24 bits: 127
		;		banks of 8K is 1,040,384 bytes.
		;
		ldx 	#TotalBanksText & $FF
		ldy 	#TotalBanksText >> 8
		jsr 	PrintMessage
		lda 	layoutCount
		sta 	reportValue
		stz 	reportValue+1
		jsr 	PrintDecimal
		ldx 	#BankCommaText & $FF
		ldy 	#BankCommaText >> 8
		jsr 	PrintMessage
		stz 	reportValue
		lda 	bankPages
		sta 	reportValue+1
		lda 	bankPages+1
		sta 	reportValue+2
		jsr 	PrintDecimal24
		ldx 	#BankUsedText & $FF
		ldy 	#BankUsedText >> 8
		jsr 	PrintMessage
		lda 	#13
		jmp 	$FFD2

; ************************************************************************************************
;
;		reportValue to the screen as decimal, leading zeros suppressed but always at least one
;		digit. Subtract each power of ten as many times as it goes; the count is the digit. Same
;		method as _WMFDecimal, which writes to the map FILE through IOWriteByte -- this one goes
;		to CHROUT. They are kept apart rather than sharing an indirect output vector: two tiny
;		routines are easier to be sure of than one with a mode.
;
;		PrintDecimalField takes a field width in A, up to 7, and right-aligns the number in
;		spaces. PrintDecimal is the same with no field.
;
;		TWENTY-FOUR BITS, because the banked total does not fit in sixteen: 127 banks of 8K
;		is 1,040,384 bytes. Enter at PrintDecimal with a 16 bit value in the first two bytes and
;		the third is cleared for you, which is what every caller but the bank total wants.
;
; ************************************************************************************************

PrintDecimal:
		lda 	#1 							; no field: one digit wide pads nothing
PrintDecimalField: 							; A = field width, the number right-aligned in spaces
		stz 	reportValue+2 				; the 16 bit entries: two bytes set, third assumed zero
		bra 	PrintDecimalWidth
PrintDecimal24:
		lda 	#1
PrintDecimalWidth:
		sta 	reportTemp 					; seven digit positions, so a leading zero is a space from
		lda 	#7 							; power 7 - width on. reportTemp only holds the width
		sec 								; here; the subtraction loop writes over it
		sbc 	reportTemp
		sta 	reportPadFrom
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
		lda 	reportLead
		bne 	_PDEmit
		cpx 	reportPadFrom 				; ... is dropped while still leading, or written as a
		bcc 	_PDNext 					; space once it is inside the field
		ldy 	#' '
		bra 	_PDWrite
_PDEmit:
		lda 	#1
		sta 	reportLead
_PDWrite:
		phx
		tya
		jsr 	$FFD2 						; CHROUT makes no promise about X
		plx
_PDNext:
		inx
		cpx 	#6 							; 1000000, 100000, 10000, 1000, 100, 10
		bne 	_PDPow
		lda 	reportValue 				; the units digit is always written
		ora 	#48
		jmp 	$FFD2

_PDPow10L:
		.byte 	<1000000, <100000, <10000, <1000, <100, <10
_PDPow10H:
		.byte 	>1000000, >100000, >10000, >1000, >100, >10
_PDPow10B: 									; only the top two reach this far, but the loop reads it every
		.byte 	(1000000 >> 16) & 255, (100000 >> 16) & 255, 0, 0, 0, 0 	; time round, so all six are here

;
;		Uppercase throughout: the X16 boots in PETSCII upper/graphics, where lowercase bytes
;		come out as graphics glyphs. Same reason bumpbuild.py emits 'V' not 'v'.
;
CodeText:
		.text 	"LOW CODE ",0
FreeText:
		.text 	"LOW FREE ",0
FrameText:
		.text 	", FRAME STACK ",0
SharedText: 								; the program loads a resident runtime file
		.text 	", SHARED",0
EmbeddedText: 								; ...or carries its own
		.text 	", EMBEDDED",0
GPBasicText: 								; the GP.BASIC handlers are in: GPB.RT.nnn.BIN, or embedded whole
		.text 	" GPBASIC",0
CoreText: 									; they are not: GPC.RT.nnn.BIN, or the handler block dropped
		.text 	" CORE",0
RuntimeText:
		.text 	"RUNTIME ",0
LinesText:
		.text 	"LINES ",0
DeadText:
		.text 	"DEAD CODE: ",0
LinesRemovedText:
		.text 	" LINES REMOVED, ",0
BytesSavedText:
		.text 	" BYTES SAVED",0
BankText:
		.text 	"BANK ",0
BankCodeText:
		.text 	" CODE ",0
BankTextText:
		.text 	" TEXT ",0
BankUsedText:
		.text 	" USED",0
BankFreeText:
		.text 	" FREE",0
TotalBanksText:
		.text 	"TOTAL BANKS ",0
BankCommaText:
		.text 	", ",0

reportValue: 								; code section, not storage -- these belong to the
		.fill 	3 							; 24 bit: the banked total passes 65,535 at eight banks
reportTemp: 								; written, so they cost a compiled program nothing.
		.fill 	2 							; See the note in file-io/read.asm.
reportLead:
		.fill 	1
reportPadFrom: 								; the first power whose leading zero is a space, not dropped
		.fill 	1
bankPages: 									; pages across every bank, for the total
		.fill 	2
bankIndex: 									; the layout entry being reported
		.fill 	1
bankFirstText: 								; the first entry that is GP.BANKEDSTR text
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
