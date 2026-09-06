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
;		there is exactly what is being asked for -- which is why this used to be FixBranches'
;		job, done after the whole object was laid out. It writes a zero and FixBranches fills it
;		in, the old way. Pass two has pass one's table and answers here.
;
;		A jump SIDEWAYS -- out of one block into another at the same depth -- computes zero and
;		closes nothing. That is not worth code to detect: the frame it lands in belongs to a
;		block whose own GP.LOOP will release it.
;
; ************************************************************************************************

UnwindCount:
		lda 	passNumber
		beq 	_UCNone 					; pass one: FixBranches still fills this in
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
;		Block nesting, counted at compile time purely so CommandGOTO above can ask "am I inside
;		one?". Nothing else needs it -- FixBranches works structurally, off the emitted code, and
;		deliberately keeps no compile-time state. GP.IF is NOT counted: it opens no stack frame
;		(its four opcodes are markers and reused goto handlers), so there is nothing to unwind.
;
;		Underflow is not guarded here. A stray GP.LOOP or GP.ENDSEL is caught structurally --
;		FixBranches raises BLOCK MISMATCH -- and a depth that went briefly negative would only
;		make a GOTO emit an .unwind it did not need, whose count FixBranches then computes as
;		zero anyway.
;
; ************************************************************************************************

BlockDepthUp: 								;; called from commands.def for GP.DO
		inc 	blockDepth
		clc 								; .def helpers MUST return carry clear
		rts

BlockDepthDown: 							;; and for GP.LOOP
		lda 	blockDepth
		beq 	_BDDFloor
		dec 	blockDepth
_BDDFloor:
		clc
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
;		PASS ONE WRITES THE LINE NUMBER and FixBranches turns it into an offset afterwards, once
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
		lda 	branchTarget 				; name the line that is missing, as FixBranches does
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
		lda 	branchTarget
		jsr 	WriteCodeByte
		lda 	branchTarget+1
		jsr 	WriteCodeByte
		rts

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
