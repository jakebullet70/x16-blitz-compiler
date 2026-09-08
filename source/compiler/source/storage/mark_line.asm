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
;		THE TABLE IS TWO BANKS AND ONE ADDRESS SPACE. Every pointer into it -- here, in
;		GPBankRelocate and in WriteMapFile -- is a VIRTUAL address running from compilerEndHigh:$00
;		down to LineTableFloorHigh:$00, sixteen kilobytes and so 4,096 entries. STRPageLine turns
;		one into the real $A000-$BFFF address and the bank it is in, and nothing else knows the
;		table is split: the walks still start at the top, still step down four bytes an entry,
;		still stop at lineNumberTable, and the compare that ends them is a plain sixteen bit
;		compare of two virtual addresses.
;
;		SELECT THE BANK THROUGH STRPageLine, NEVER BY HAND. It sets the storage bank AND the
;		depth bank together, because the depth byte for a record sits at the same address in a
;		bank of its own and so is in the same segment by construction. Anything that opens a
;		.depth_access without having paged the record first gets whichever segment the last
;		call happened to leave selected.
;
; ************************************************************************************************

; ************************************************************************************************
;
;								Store current position, line YA
;
; ************************************************************************************************

STRMarkLine:
		pha
		sec 								; allocate 4 bytes (line #,address)
		lda 	lineNumberTable 			; and copy to the walk pointer
		sbc 	#4
		sta 	lineNumberTable
		sta 	lineWalk
		lda 	lineNumberTable+1
		sbc 	#0
		sta 	lineNumberTable+1
		sta 	lineWalk+1

		;
		;		Still inside the table? It grows DOWN from compilerEndHigh:$00 and the floor is
		;		two banks under that, and without a test it was free to walk out of the bottom
		;		in silence. (A is free here: the caller's value is on the stack until the pla
		;		below, and ExitCompiler restores SP, so raising with it still pushed is fine.)
		;
		;		THIS USED TO TEST AGAINST variableListEnd. Both tables lived in one 8K bank and
		;		grew towards each other, so the real limit was the SUM of the two -- and
		;		samples/editor had reached 7,981 of 8,192 with 1,461 lines and 356 variables.
		;		Fifty-two more lines and this test fired PROGRAM TOO BIG with a THIRD of the
		;		object budget unused. One bank each (x16_storage.inc) made the limit this table's
		;		own window, 2,048 lines; a second bank under it makes that 4,096.
		;
		lda 	lineNumberTable+1 			; the entry is 4 bytes AT the pointer and the floor is
		cmp 	#LineTableFloorHigh 		; a page boundary, so the high byte is the whole test
		bcs 	_SMLRoom 					; -- any offset within that page is inside.
		.error_toobig
_SMLRoom:
		jsr 	STRPageLine 				; lineWalk -> zTemp0, and the two banks it lives in

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
		.storage_release 					; never raise inside the window: the error handler
		.error_internal 					; prints, and that is bank 0
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
		;		zTemp0 is already paged and depthBankNow already names this record's segment,
		;		both from the STRPageLine above.
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
		sta 	lineTarget 					; the line number being searched for
		sty 	lineTarget+1

		lda 	compilerEndHigh 			; work backwards through table
		sta 	lineWalk+1
		stz 	lineWalk

_STRSearch:
		jsr 	_STRPrevLine 				; look at previous record.
		jsr 	STRPageLine 				; lineWalk -> zTemp0, in whichever bank it is in
		;
		;		THE WHOLE RECORD COMES OUT IN ONE GO, and the window closes before anything is
		;		decided about it. It used to be held open across the entire search, which worked
		;		while the table was one bank and the pointer never had to be re-paged -- and it
		;		is why both exits from inside the loop had to remember to .storage_release
		;		before raising. Four loads and four stores instead, and no way out of here with
		;		the wrong bank selected.
		;
		.storage_access
		lda 	(zTemp0)
		sta 	lineRec
		ldy 	#1
		lda 	(zTemp0),y
		sta 	lineRec+1
		iny
		lda 	(zTemp0),y
		sta 	lineRec+2
		iny
		lda 	(zTemp0),y
		sta 	lineRec+3
		.storage_release

		lda 	lineRec 					; check table line # >= target
		cmp 	lineTarget
		lda 	lineRec+1
		sbc 	lineTarget+1
		bcs 	_STRFound 					; >=

		lda 	lineRec+1 					; next table entry, until off the bottom of what was
		cmp 	#$FF 						; ever written. Should not be required !
		bne 	_STRSearch
		.error_internal

_STRFound:
		lda 	lineWalk 					; remember WHICH record matched, so STRLineDepth can
		sta 	STRFoundAt 					; read the depth byte that goes with it. This is the
		lda 	lineWalk+1 					; VIRTUAL address: STRLineDepth pages it again.
		sta 	STRFoundAt+1
		;
		;		BOTH BYTES, and it used to be the low one twice -- the second read was written
		;		`lda (zTemp1)` where it meant `(zTemp1),y`, against zTemp0 where it meant
		;		zTemp0+1. Any line whose LOW byte matched the target reported an exact match, so
		;		GOTO 300 could resolve to line 556, and the carry a caller reads to tell found
		;		from not-found was wrong with it.
		;
		lda 	lineRec 					; set A = 0 if the same, non-zero if different.
		eor 	lineTarget
		bne 	_STRDifferent
		lda 	lineRec+1
		eor 	lineTarget+1
		beq 	_STROut 					; if zero, exit with A = 0 and correct line.

_STRDifferent:
		lda 	#$FF
_STROut:
		clc  								; set carry if different, e.g. > rather than >=
		adc 	#255
		php
		lda 	lineRec+3 					; address into YA
		tay
		lda 	lineRec+2
		plp
		rts

_STRPrevLine:
		sec 								; move backwards one entry.
		lda 	lineWalk
		sbc 	#4
		sta 	lineWalk
		lda 	lineWalk+1
		sbc 	#0
		sta 	lineWalk+1
		rts

; ************************************************************************************************
;
;			Virtual line-table address in lineWalk -> real address in zTemp0, with the storage
;			bank and the depth bank selected for it. Preserves X and Y.
;
;		BIT 13 IS THE WHOLE OF IT. The virtual space is compilerEndHigh:$00 down to
;		LineTableFloorHigh:$00, sixteen kilobytes, and each bank shows eight of them at
;		$A000-$BFFF: $A000-$BFFF is the first bank at its own address, $8000-$9FFF is the second
;		bank with $2000 added back. So the segment is one bit of the high byte and the
;		translation is an ORA.
;
; ************************************************************************************************

STRPageLine:
		pha
		lda 	lineWalk
		sta 	zTemp0
		lda 	lineWalk+1
		and 	#$20 						; bit 13: set is the first bank, clear the second
		beq 	_SPLSecond
		lda 	#CompilerStorageBank
		sta 	storageBankNow
		lda 	#CompilerDepthBank
		sta 	depthBankNow
		lda 	lineWalk+1
		sta 	zTemp0+1
		pla
		rts
_SPLSecond:
		lda 	#CompilerStorageBank2
		sta 	storageBankNow
		lda 	#CompilerDepthBank2
		sta 	depthBankNow
		lda 	lineWalk+1 					; $8000-$9FFF is that bank's own $A000-$BFFF
		ora 	#$20
		sta 	zTemp0+1
		pla
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
; ************************************************************************************************

STRLineDepth:
		lda 	STRFoundAt
		sta 	lineWalk
		lda 	STRFoundAt+1
		sta 	lineWalk+1
		jsr 	STRPageLine 				; which selects the depth bank of that segment too
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
STRFoundAt: 								; the line record STRFindLine last matched (virtual)
		.fill 	2
lineWalk: 									; STRPageLine's input, and the search's walk pointer
		.fill 	2
lineTarget: 								; the line number STRFindLine is looking for
		.fill 	2
lineRec: 									; one whole record, copied out of the bank
		.fill 	4
		.send 	storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		08/09/26		A second bank under the line table, 2,048 entries to 4,096, reached
;						through STRPageLine. STRFindLine's high byte compare fixed with it.
;
; ************************************************************************************************
