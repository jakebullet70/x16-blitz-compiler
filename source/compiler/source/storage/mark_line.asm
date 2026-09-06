; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		mark_line.asm
;		Purpose:	Line Number Tracking
;		Created:	15th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Store current position, line YA
;
; ************************************************************************************************

STRMarkLine:
		pha
		sec 								; allocate 4 bytes (line #,address)
		lda 	lineNumberTable 			; and copy to zTemp0
		sbc 	#4
		sta 	lineNumberTable
		sta 	zTemp0
		lda 	lineNumberTable+1
		sbc 	#0
		sta 	lineNumberTable+1
		sta 	zTemp0+1

		;
		;		Still inside the window? This table grows DOWN from CompilerWorkspaceEnd, and
		;		without a test it was free to walk out of the bottom of the bank in silence.
		;		(A is free here: the caller's value is on the stack until the pla below, and
		;		ExitCompiler restores SP, so raising with it still pushed is fine.)
		;
		;		THIS USED TO TEST AGAINST variableListEnd. Both tables lived in one 8K bank and
		;		grew towards each other, so the real limit was the SUM of the two -- and
		;		samples/editor had reached 7,981 of 8,192 with 1,461 lines and 356 variables.
		;		Fifty-two more lines and this test fired PROGRAM TOO BIG with a THIRD of the
		;		object budget unused. One bank each (x16_storage.inc) makes the limit this
		;		table's own window, which is 2,048 lines.
		;
		lda 	lineNumberTable+1 			; the entry is 4 bytes AT the pointer and the window
		cmp 	compilerStartHigh 			; starts on a page boundary, so the high byte is the
		bcs 	_SMLRoom 					; whole test -- any offset within that page is inside.
		.error_toobig
_SMLRoom:

		.storage_access
		;
		;		PASS TWO MUST FIND ITS OWN ANSWER ALREADY IN THE RECORD. Everything the second
		;		pass resolves -- every branch, every .unwind, every block end -- is read out of
		;		this table, so a line that lands somewhere else this time round is the one
		;		failure that cannot be allowed to reach an object. Nothing has been written yet
		;		and nothing will be.
		;
		;		THIS IS THE CHECK, once pass one has no buffer to lay an object out in. The
		;		checksum compares two finished objects and there will only be one; what the two
		;		passes still both produce is this table, and it is what the object is built from.
		;
		lda 	passNumber
		beq 	_SMLWrite
		phy 								; THE LINE NUMBER IS STILL IN YA -- A is on the stack
		ldy 	#2 							; already, and the high byte stays in Y until the tya
		lda 	(zTemp0),y 					; below writes it
		cmp 	objPtr
		bne 	_SMLDiverged
		iny
		lda 	(zTemp0),y
		cmp 	objPtr+1
		bne 	_SMLDiverged
		ply
		bra 	_SMLWrite
_SMLDiverged:
		.storage_release 					; as _STRNext: never raise inside the window, the
		.error_internal 					; error handler prints and that is bank 0
_SMLWrite:
		pla
		sta 	(zTemp0) 					; line # save it in +0,+1
		tya
		ldy 	#1
		sta 	(zTemp0),y
		;
		lda 	objPtr 						; save current address in +2,+3
		iny
		sta 	(zTemp0),y
		lda 	objPtr+1
		iny
		sta 	(zTemp0),y

		.storage_release
		;
		;		...and how many GP.DO blocks are open at the start of this line, in a bank of its
		;		own at the same address. A GOTO out of a block needs the depth where it LANDS,
		;		which is a fact about a line that may not have been compiled yet -- so pass one
		;		writes it here and pass two reads it back with STRLineDepth. See x16_storage.inc
		;		for why it is a separate bank and not a fifth byte on the record.
		;
		.depth_access
		lda 	blockDepth
		sta 	(zTemp0)
		.depth_release
		rts

; ************************************************************************************************
;
;				Line number YA - find in table, return address YA 
;				
;				If FOUND: of the matching line, with Carry Clear.
;				If NOT FOUND : of the previous line (e.g. next code line), with Carry Set.
;
; ************************************************************************************************

STRFindLine:
		.storage_access

		sta 	zTemp0 						; zTemp0 line number being searched
		sty 	zTemp0+1
		
		lda 	compilerEndHigh 			; work backwards through table
		sta 	zTemp1+1
		stz 	zTemp1

_STRSearch:
		jsr 	_STRPrevLine 				; look at previous record.

		ldy 	#1
		lda 	(zTemp1) 					; check table line # >= target
		cmp 	zTemp0
		lda 	(zTemp1),y
		sbc 	zTemp0+1
		bcs 	_STRFound 					; >=
_STRNext: 									; next table entry.
		ldy 	#1 							; should not be required !
		lda 	(zTemp1),y
		cmp 	#$FF
		bne 	_STRSearch
		.storage_release 					; the only escape from inside a storage window -- close
		.error_internal 					; it, or the error handler runs with the wrong RAM bank

_STRFound:
		lda 	zTemp1 						; remember WHICH record matched, so STRLineDepth can
		sta 	STRFoundAt 				; read the depth byte that goes with it. A is dead
		lda 	zTemp1+1 					; here -- the compare below reloads it.
		sta 	STRFoundAt+1
		lda 	(zTemp1) 					; set A = 0 if the same, 0 if different.
		eor 	zTemp0
		bne 	_STRDifferent
		lda 	(zTemp1)
		eor 	zTemp0
		beq 	_STROut 					; if zero, exit with A = 0 and correct line.

_STRDifferent:
		lda 	#$FF 						
_STROut:
		clc  								; set carry if different, e.g. > rather than >=
		adc 	#255 				
		php
		iny 								; address into YA
		lda 	(zTemp1),y
		pha
		iny
		lda 	(zTemp1),y
		tay
		pla	
		.storage_release
		plp	
		rts

_STRPrevLine:
		sec 								; move backwards one entry.
		lda 	zTemp1
		sbc 	#4
		sta 	zTemp1
		lda 	zTemp1+1
		sbc 	#0
		sta 	zTemp1+1
		rts
; ************************************************************************************************
;
;					The block depth of the line STRFindLine last matched, in A
;
;		Two calls rather than one because the answer is wanted in exactly one place -- the
;		.unwind in front of a GOTO -- and every other caller of STRFindLine wants only the
;		address. Call it straight after STRFindLine: the record it read is remembered in
;		STRFoundAt, and the next STRFindLine overwrites that.
;
;		zTemp0 IS FREE HERE. STRFindLine has finished with it -- it held the line number being
;		searched for -- and it is the only zero page pointer this can reach the bank through.
;
; ************************************************************************************************

STRLineDepth:
		lda 	STRFoundAt
		sta 	zTemp0
		lda 	STRFoundAt+1
		sta 	zTemp0+1
		.depth_access
		lda 	(zTemp0)
		.depth_release
		rts

; ************************************************************************************************
;
;								Make position X:YA to Offset X:YA
;
; ************************************************************************************************

STRMakeOffset:
		clc 								; borrow 1
		sbc 	objPtr
		pha
		tya
		sbc 	objPtr+1
		tay
		pla
		rts
		
		.send code

		.section storage
STRFoundAt: 								; the line record STRFindLine last matched
		.fill 	2
		.send 	storage

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
