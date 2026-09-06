; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		goto.asm
;		Purpose:	Goto command
;		Created:	18th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;											GO TO
;
; ************************************************************************************************

CommandGOAlt:
		lda 	#C64_TO 					; GO TO alternative
		jsr 	CheckNextA
		bra 	CommandGOTO

; ************************************************************************************************
;
;											GOTO
;
; ************************************************************************************************

CommandGOTO: 
		;
		;		A GOTO that is lexically inside a GP.DO has to close those blocks' stack frames on
		;		its way out, because GP.LOOP -- the thing that normally releases them -- is exactly
		;		what it is jumping past. So it is prefixed with an .unwind saying how many: the
		;		block depth here, minus the block depth where it lands.
		;
		;		ONLY WHEN THE DEPTH IS NON-ZERO, and that matters more than it looks. The .unwind
		;		handler lives above GPBase, so emitting one unconditionally would mark EVERY
		;		program as using the GP block -- 2,048 bytes onto a program that never wrote a
		;		GP keyword. A program that is inside a GP.DO already carries it.
		;
		;		THE TARGET IS READ BEFORE ANYTHING IS WRITTEN, because the .unwind goes in front
		;		of the GOTO and its count depends on where the GOTO goes. That is the only reason
		;		this does not simply call CompileBranchCommand, which writes its opcode first and
		;		reads the line number afterwards.
		;
		jsr 	GetNextNonSpace
		jsr 	ParseConstant 				; the target line, into YA
		bcc 	_CGSyntax
		sta 	branchTarget
		sty 	branchTarget+1
		;
		lda 	blockDepth
		beq 	_CGNoUnwind
		jsr 	UnwindCount
		pha
		lda 	#PCD_CMD_UNWIND
		jsr 	WriteCodeByte
		lda 	#1 							; the count is pass two's answer -- see EmitBranch
		ldy 	#0
		jsr 	SumSkipYA
		pla
		jsr 	WriteCodeByte
_CGNoUnwind:
		lda 	#PCD_CMD_GOTO
		jsr 	WriteBranchTo
		rts

_CGSyntax:
		.error_syntax

; ************************************************************************************************
;
;		How many block frames the GOTO to branchTarget closes, in A.
;
;		PASS ONE CANNOT ANSWER. The target line may not have been compiled yet, and the depth
;		there is exactly what is being asked for -- which is why this used to be done after the
;		whole object was laid out, by walking it. Pass one writes a zero and counts the byte;
;		pass two has pass one's table and answers here.
;
;		A jump SIDEWAYS -- out of one block into another at the same depth -- computes zero and
;		closes nothing. That is not worth code to detect: the frame it lands in belongs to a
;		block whose own GP.LOOP will release it.
;
; ************************************************************************************************

UnwindCount:
		lda 	passNumber
		beq 	_UCNone 					; pass one: the byte goes past with nothing in it
		lda 	branchTarget
		ldy 	branchTarget+1
		jsr 	STRFindLine 				; the record for the line it lands on
		bcs 	_UCNone 					; no such line -- the GOTO itself reports it
		jsr 	STRLineDepth 				; ...and how deep in blocks that line is
		sta 	unwindTarget
		sec
		lda 	blockDepth
		sbc 	unwindTarget
		bcs 	_UCDone 					; the target is DEEPER than we are: nothing to close
_UCNone:
		lda 	#0
_UCDone:
		rts

; ************************************************************************************************
;
;		Block nesting, counted at compile time so that CommandGOTO above can ask "am I inside
;		one?" and .unwind can ask "how far inside?". GP.IF is NOT counted: it opens no stack
;		frame (its four opcodes are markers and reused goto handlers), so there is nothing to
;		unwind out of it.
;
;		EACH LOOP ALSO GETS AN ORDINAL, and where it ends is written down under that ordinal as
;		the GP.LOOP goes past. Only pass one writes; pass two reads, and that is what lets a
;		GP.EXITDO -- a branch to a place the compiler has not reached -- be resolved where it is
;		written rather than by walking the finished object afterwards.
;
;		Underflow is not guarded here. A stray GP.LOOP is caught structurally -- BlockDepthDown
;		raises BLOCK MISMATCH -- and a depth that went briefly negative would only make a GOTO
;		emit an .unwind it did not need, whose count comes out as zero anyway.
;
; ************************************************************************************************

BlockDepthUp: 								;; called from commands.def for GP.DO
		lda 	blockDepth
		cmp 	#BLOCK_MAX_NEST
		bcs 	BlockFailNest
		asl 	a
		tax
		jsr 	BlockOpen 					; this loop's ordinal, in blockIndex
		lda 	blockIndex
		sta 	blockOrdinals,x
		lda 	blockIndex+1
		sta 	blockOrdinals+1,x
		inc 	blockDepth
		clc 								; .def helpers MUST return carry clear
		rts

BlockDepthDown: 							;; and for GP.LOOP
		lda 	blockDepth
		beq 	_BDDFloor
		dec 	blockDepth
		lda 	passNumber
		bne 	_BDDFloor 					; pass two READS this table; it does not write it
		;
		;		Where a GP.EXITDO in this loop lands: one past the GP.LOOP just written. What is
		;		STORED is one less than that -- the GP.LOOP's own address -- and the reader adds
		;		the one back. Stored that way the address always falls strictly INSIDE its own
		;		stretch of object, which is what matters when the loop is inside a GP.BANKED
		;		region: GPBankAdjust puts the byte at the region's end on the LOW side of the
		;		move, and one past the last GP.LOOP of a region is exactly that byte.
		;
		lda 	blockDepth
		asl 	a
		tax
		lda 	blockOrdinals,x
		sta 	blockIndex
		lda 	blockOrdinals+1,x
		sta 	blockIndex+1
		jsr 	BlockEndHere
_BDDFloor:
		clc
		rts

; ************************************************************************************************
;
;		Where the innermost open GP.DO ends, into branchTarget. Pass two only -- in pass one the
;		answer does not exist yet, which is the whole reason there are two passes.
;
; ************************************************************************************************

BlockEnclosingDo:
		lda 	blockDepth
		beq 	BlockFailStructure 			; a GP.EXITDO that is not inside a loop at all
		dec 	a
		asl 	a
		tax
		lda 	blockOrdinals,x
		sta 	blockIndex
		lda 	blockOrdinals+1,x
		sta 	blockIndex+1
		jmp 	BlockEndTarget

;
;		The three ways a block can be refused, HERE rather than at the foot of the file: the
;		tests that reach them are spread over the routines below, and a relative branch does not
;		span them.
;
BlockFailNest:
		.error_memory 						; more nesting than BLOCK_MAX_NEST allows
BlockFailCount:
		.error_toobig 						; more blocks than the table holds
BlockFailStructure:
		.error_structure

; ************************************************************************************************
;
;		The two things EVERY block does, whichever keyword opened it.
;
;		BlockOpen 		take the next block ordinal, into blockIndex. Both passes count them out
;						in the same order, over the same source, and so agree on every one.
;		BlockEndHere 	the block whose ordinal is in blockIndex ends where the write cursor
;						stands. Pass one only -- pass two is reading what this wrote.
;		BlockEndTarget 	...and reading it back, into branchTarget.
;
; ************************************************************************************************

BlockOpen:
		lda 	blockCount
		sta 	blockIndex
		lda 	blockCount+1
		sta 	blockIndex+1
		inc 	blockCount
		bne 	_BOPCounted
		inc 	blockCount+1
_BOPCounted:
		lda 	blockCount+1 				; the table holds BLOCK_MAX of them
		cmp 	#BLOCK_MAX >> 8
		bcs 	BlockFailCount
		rts

BlockEndHere:
		sec 								; one short, and the reader adds it back
		lda 	objPtr
		sbc 	#1
		sta 	blockValue
		lda 	objPtr+1
		sbc 	#0
		sta 	blockValue+1
		lda 	passNumber
		beq 	BlockEndWrite 				; pass one writes it down
		jmp 	BlockEndCheck 				; pass two makes sure it is what it read

BlockEndTarget:
		jsr 	BlockEndRead
BlockPlusOne:
		clc 								; the stored address is one short -- see BlockDepthDown
		lda 	blockValue
		adc 	#1
		sta 	branchTarget
		lda 	blockValue+1
		adc 	#0
		sta 	branchTarget+1
		rts

; ************************************************************************************************
;
;		Entry blockIndex of the block-end table, to and from blockValue. The window is opened and
;		closed around the two bytes rather than held, for the reason x16_storage.inc gives.
;
; ************************************************************************************************

BlockEndWrite:
		jsr 	BlockEndPointer
		.block_access
		lda 	blockValue
		sta 	(zTemp0)
		ldy 	#1
		lda 	blockValue+1
		sta 	(zTemp0),y
		.block_release
		rts

;
;		AND THE SAME ENTRY, COMPARED. Pass two recomputes every block end where pass one wrote
;		it down, and a disagreement is the same failure STRMarkLine guards against: pass two
;		resolved a GP.EXITDO or a GP.ELSE out of a table that no longer describes the object it
;		is writing. See the note in storage/mark_line.asm.
;
BlockEndCheck:
		lda 	blockValue 					; the answer this pass just worked out
		sta 	blockCheck
		lda 	blockValue+1
		sta 	blockCheck+1
		jsr 	BlockEndRead 				; ...against the one pass one left here
BlockEndCompare:
		lda 	blockValue
		cmp 	blockCheck
		bne 	_BECDiverged
		lda 	blockValue+1
		cmp 	blockCheck+1
		beq 	_BECAgreed
_BECDiverged:
		.error_internal
_BECAgreed:
		rts

BlockEndRead:
		jsr 	BlockEndPointer
		.block_access
		lda 	(zTemp0)
		sta 	blockValue
		ldy 	#1
		lda 	(zTemp0),y
		sta 	blockValue+1
		.block_release
		rts

;
;		zTemp0 = BlockEndTable + blockIndex*2. The table base is page aligned and the index is
;		under 2,048, so the doubled index cannot leave the table's own 4K.
;
BlockEndPointer:
		lda 	blockIndex
		asl 	a
		sta 	zTemp0
		lda 	blockIndex+1
		rol 	a
		clc
		adc 	#BlockEndTable >> 8
		sta 	zTemp0+1
		rts

; ************************************************************************************************
;
;		THE ALTERNATIVES. A GP.IF or a GP.CASE that comes out false branches to the NEXT
;		alternative, which is a different place for each one -- so each gets an ordinal of its
;		own, and the target is written down by whatever alternative follows it.
;
;		BlockAltOpen 	take the next ordinal, into blockAlt. The caller remembers it as its
;						block's PENDING alternative.
;		BlockAltHere 	blockAlt's target is where the write cursor stands. Pass one only.
;		BlockAltRead 	...and reading it back, into branchTarget.
;
;		ONE PENDING ALTERNATIVE PER OPEN BLOCK IS ENOUGH, which is what makes this a slot rather
;		than a chain: a GP.IF's test is resolved by the next GP.ELSEIF, GP.ELSE or GP.ENDIF, and
;		by then the next test has not been written.
;
; ************************************************************************************************

BlockAltOpen:
		lda 	altCount
		sta 	blockAlt
		lda 	altCount+1
		sta 	blockAlt+1
		inc 	altCount
		bne 	_BAOCounted
		inc 	altCount+1
_BAOCounted:
		lda 	altCount+1
		cmp 	#BLOCK_MAX >> 8
		bcc 	_BAORoom
		jmp 	BlockFailCount 				; a jmp: the error exits sit above the table routines
_BAORoom:
		rts

BlockAltHere:
		lda 	blockAlt+1 					; $FFFF -- nothing is waiting for a target
		and 	blockAlt
		cmp 	#$FF
		beq 	_BAHDone
		lda 	blockAlt
		sta 	blockIndex
		lda 	blockAlt+1
		sta 	blockIndex+1
		sec 								; one short, and the reader adds it back -- see
		lda 	objPtr 						; BlockDepthDown for why
		sbc 	#1
		sta 	blockValue
		lda 	objPtr+1
		sbc 	#0
		sta 	blockValue+1
		lda 	passNumber
		bne 	_BAHCheck 					; pass two makes sure it is what it read
		jmp 	BlockAltWrite
_BAHCheck:
		lda 	blockValue 					; as BlockEndCheck, over the other table
		sta 	blockCheck
		lda 	blockValue+1
		sta 	blockCheck+1
		jsr 	BlockAltFetch
		jmp 	BlockEndCompare
_BAHDone:
		rts

BlockAltRead:
		lda 	blockAlt
		sta 	blockIndex
		lda 	blockAlt+1
		sta 	blockIndex+1
		jsr 	BlockAltFetch
		jmp 	BlockPlusOne 				; the stored address is one short, as always

; ************************************************************************************************
;
;		Entry blockIndex of the ALTERNATIVE table, to and from blockValue. The same two routines
;		as the block-end table, over the other half of the bank.
;
; ************************************************************************************************

BlockAltWrite:
		jsr 	BlockAltPointer
		.block_access
		lda 	blockValue
		sta 	(zTemp0)
		ldy 	#1
		lda 	blockValue+1
		sta 	(zTemp0),y
		.block_release
		rts

BlockAltFetch:
		jsr 	BlockAltPointer
		.block_access
		lda 	(zTemp0)
		sta 	blockValue
		ldy 	#1
		lda 	(zTemp0),y
		sta 	blockValue+1
		.block_release
		rts

BlockAltPointer:
		jsr 	BlockEndPointer
		lda 	zTemp0+1 					; the same offset, in the other table
		clc
		adc 	#(BlockAltTable - BlockEndTable) >> 8
		sta 	zTemp0+1
		rts


; ************************************************************************************************
;
;						Compile a branch (GOTO/GOSUB) with following line #
;
; ************************************************************************************************

CompileBranchCommand:
		sta 	branchOpcode 				; the opcode cannot go out yet: pass two works its
		jsr 	GetNextNonSpace 			; operand out from where the opcode is going to sit
		jsr 	ParseConstant 				; the line number, into YA
		bcc 	_CBCSyntax
		sta 	branchTarget
		sty 	branchTarget+1
		lda 	branchOpcode
		jmp 	WriteBranchTo

_CBCSyntax:
		.error_syntax

; ************************************************************************************************
;
;		Write a branch: the opcode in A, the LINE it goes to in branchTarget.
;
;		PASS ONE WRITES THE LINE NUMBER, which is only ever counted, and pass two writes the
;		offset. The two are the same length, which is all pass one needs of it. It used to be
;		that pass one's line number was turned into an offset afterwards, once
;		the whole object is laid out. Pass two has pass one's line table already, so it writes the
;		offset -- and an object whose every byte is final on the way out is one that can be
;		streamed instead of built and then gone back over.
;
;		THE OFFSET IS MEASURED FROM THE OPCODE, which is why nothing is written until it has been
;		worked out: at that moment objPtr is still pointing at where the opcode is about to go.
;
;		A MISSING LINE IS AN ERROR for everything except .gotoz and RESTORE. A false IF branches
;		to "this line + 1", which is a line number that usually does not exist, and RESTORE with
;		no argument compiles as RESTORE 0. Both mean "the first line at or after this", which is
;		what STRFindLine returns with the carry set.
;
; ************************************************************************************************

WriteBranchTo:
		sta 	branchOpcode
		lda 	passNumber
		beq 	EmitBranch 					; pass one: the line number goes out as it stands
		;
		lda 	branchTarget
		ldy 	branchTarget+1
		jsr 	STRFindLine 				; where that line starts
		sta 	branchAddress
		sty 	branchAddress+1
		bcc 	_WBTFound
		lda 	branchOpcode 				; not an exact match, and only two opcodes may miss
		cmp 	#PCD_CMD_GOTOCMD_Z
		beq 	_WBTFound
		cmp 	#PCD_CMD_RESTORE
		bne 	_WBTNoLine
_WBTFound:
		lda 	branchAddress 				; the address it lands at is the operand from here on,
		sta 	branchTarget 				; which is exactly an FN call's problem
		lda 	branchAddress+1
		sta 	branchTarget+1
		lda 	branchOpcode
		bra 	WriteBranchToAddress

_WBTNoLine:
		lda 	branchTarget 				; name the line that is missing
		sta 	currentLineNumber
		lda 	branchTarget+1
		sta 	currentLineNumber+1
		.error_line

; ************************************************************************************************
;
;		The same, for the one operand that is an ABSOLUTE code address rather than a line: the
;		body of an FN, which FNCompile reads out of the variable record. Opcode in A, address in
;		branchTarget.
;
; ************************************************************************************************

WriteBranchToAddress:
		sta 	branchOpcode
		lda 	passNumber
		beq 	EmitBranch 					; pass one: the address goes out as it stands
		lda 	branchTarget
		ldy 	branchTarget+1
		jsr 	GPBankMakeOffset 			; an offset from here -- and corrected if this branch
		sta 	branchTarget 				; crosses into or out of a GP.BANKED region, which runs
		sty 	branchTarget+1 				; at $A000 rather than where it sits in the buffer

; ************************************************************************************************
;
;						Opcode in branchOpcode, operand in branchTarget
;
; ************************************************************************************************

EmitBranch:
		lda 	branchOpcode
		jsr 	WriteCodeByte
		lda 	#2 							; the operand is the answer pass two worked out and
		ldy 	#0 							; pass one could not, so the sum steps over it
		jsr 	SumSkipYA
		lda 	branchTarget
		jsr 	WriteCodeByte
		lda 	branchTarget+1
		jsr 	WriteCodeByte
		rts

BLOCK_MAX_NEST = 16 						; GP.DOs open at once, on SELECT_MAX_NEST's reasoning:
											; two bytes of compiler space each, and nothing in
											; the tree nests past three

;
;		Compiler-only working storage, in the CODE section rather than in storage, for the reason
;		select.asm gives: storage is the 1K hole below $0801 and is already full, and compiler
;		code is thrown away when the object is written, so these bytes cost a compiled program
;		nothing at all.
;
blockOrdinals: 								; the ordinal of each GP.DO that is open right now
		.fill 	2*BLOCK_MAX_NEST
blockCount: 								; how many this pass has opened altogether
		.fill 	2
blockIndex: 								; the table entry being read or written...
		.fill 	2
blockValue: 								; ...and what is in it
		.fill 	2
blockCheck: 								; what pass two thinks it should have been
		.fill 	2
blockWalk: 									; the relocator's place in the table
		.fill 	2
altCount: 									; how many alternatives this pass has written
		.fill 	2
blockAlt: 									; the alternative being opened, resolved or read
		.fill 	2
ifOrdinals: 								; the block ordinal of each open GP.IF...
		.fill 	2*BLOCK_MAX_NEST
ifPending: 									; ...and the alternative inside it still waiting for
		.fill 	2*BLOCK_MAX_NEST 			; a target, or $FFFF
ifDepth: 									; how many GP.IFs are open right now
		.fill 	1

		.send code

		.section storage
blockDepth: 								; GP.DO / GP.SELECT nesting at the statement being
		.fill 	1 						; compiled. Reset by the compiler's own start-up.
branchOpcode: 								; the branch being written, held while its operand is
		.fill 	1 							; worked out
branchTarget: 								; ...and that operand: a line number on the way in, the
		.fill 	2 							; offset that reaches it on the way out
branchAddress: 								; where the line the branch goes to starts
		.fill 	2
unwindTarget: 								; the block depth at that line
		.fill 	1
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
