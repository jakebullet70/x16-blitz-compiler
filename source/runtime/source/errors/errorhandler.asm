; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		errorhandler.asm
;		Purpose:	Error handler
;		Created:	12th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

Unimplemented:
		jmp 	ErrorV_unimplemented
		
RuntimeErrorHandler:
		;
		;		Bank 1 (HANDLER_BANK) at an error means a handler in bank 1 was running. Select the
		;		program's bank, saved by BankEnter, so READY does not leave the handler code selected.
		;
		lda 	SelectRAMBank
		cmp 	#HANDLER_BANK
		bne 	_EHProgramBank
		lda 	handlerBank
		sta 	SelectRAMBank
_EHProgramBank:
		tya
		clc
		adc 	codePtr
		sta 	codePtr
		bcc 	_EHNoCarry
		inc 	codePtr+1
_EHNoCarry:
		;
		;		Step back one byte, onto the opcode that failed rather than the one after it.
		;		NXCommand consumes the opcode (iny) BEFORE it jumps through VectorTable, so a
		;		handler that raises during its own execution -- rather than while its arguments
		;		are being evaluated -- reports a codePtr+Y already past its own instruction. When
		;		that instruction is the LAST on its line (a one-statement line, which is how most
		;		BASIC is written) the address lands on the first byte of the NEXT line, and
		;		GPC.ERR then names that line as an exact hit. Measured: a bare RETURN raising
		;		STRUCTURE IMBALANCE, and a failing BLOAD, both reported the following line.
		;		Every other raise site is at least one byte into its statement too -- operand
		;		fetches iny past the byte they read -- so -1 never leaves the failing statement.
		;
		lda 	codePtr
		bne 	_EHNoBorrow
		dec 	codePtr+1
_EHNoBorrow:
		dec 	codePtr
		pla
		ply
		sta 	zTemp0
		sty 	zTemp0+1
		ldx 	#0 							; output to channel #0 
		ldy 	#1
_EHDisplayMsg:
		lda 	(zTemp0),y
		jsr 	XPrintCharacterToChannel
		iny
		lda 	(zTemp0),y
		bne 	_EHDisplayMsg
		ldy 	#3 							; " @ $", printed from the last byte of _EHAtText down
_EHDisplayAt:
		lda 	_EHAtText,y
		jsr 	XPrintCharacterToChannel
		dey
		bpl 	_EHDisplayAt
		;
		;		Where the error is, in the form the map file and GPC.ERR use. Low p-code is an
		;		offset from the p-code base, "$0143". P-code at $A000 up is in a GP.BANKED region,
		;		which runs from $A000 in its own bank, so it is the bank and the run address,
		;		"$14:A043". The compiler puts one region in a bank, so the pair names one byte.
		;		SelectRAMBank is the region's bank: bank 1 was put back above.
		;
		lda 	codePtr+1
		cmp 	#$A0
		bcc 	_EHLowCode
		lda 	SelectRAMBank
		jsr 	_EHDisplayHex
		lda 	#':'
		jsr 	XPrintCharacterToChannel
		lda 	codePtr+1
		bra 	_EHDisplayPage
_EHLowCode:
		sec
		sbc 	runtimeHigh
_EHDisplayPage:
		jsr 	_EHDisplayHex
		lda 	codePtr
		jsr 	_EHDisplayHex
		sec 								; report error.
		jmp 	EndRuntime

_EHAtText:
		.text 	"$ @ "

_EHDisplayHex:
		pha
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		jsr 	_EHDisplayNibble
		pla		
_EHDisplayNibble:
		and 	#15
		cmp 	#10
		bcc 	_EHNotHex
		adc 	#6
_EHNotHex:
		adc 	#48
		jmp 	XPrintCharacterToChannel
						
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
