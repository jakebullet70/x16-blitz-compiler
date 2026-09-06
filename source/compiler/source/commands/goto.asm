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
		sta 	gotoTarget
		sty 	gotoTarget+1
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
		jsr 	WriteCodeByte
		lda 	gotoTarget
		jsr 	WriteCodeByte
		lda 	gotoTarget+1
		jsr 	WriteCodeByte
		rts

_CGSyntax:
		.error_syntax

; ************************************************************************************************
;
;		How many block frames the GOTO to gotoTarget closes, in A.
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
		lda 	gotoTarget
		ldy 	gotoTarget+1
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
		jsr 	WriteCodeByte 				; write the command out.
		jsr 	GetNextNonSpace
		jsr 	ParseConstant 				; get constant into YA
		bcc 	_CBCSyntax

 				
		jsr 	WriteCodeByte				; and compile the actual line number
		tya
		jsr 	WriteCodeByte
		rts		

_CBCSyntax:
		.error_syntax

		.send code

		.section storage
blockDepth: 								; GP.DO / GP.SELECT nesting at the statement being
		.fill 	1 						; compiled. Reset by the compiler's own start-up.
gotoTarget: 								; the line a GOTO being compiled goes to, read before
		.fill 	2 							; the .unwind in front of it is written
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
