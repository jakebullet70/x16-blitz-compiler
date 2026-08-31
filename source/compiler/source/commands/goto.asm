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
		;		A GOTO that is lexically inside a GP.DO or a GP.SELECT has to close those blocks'
		;		stack frames on its way out, because GP.LOOP and GP.ENDSEL -- the things that
		;		normally release them -- are exactly what it is jumping past. So it is prefixed
		;		with an .unwind whose count FixBranches fills in: it knows the block depth here
		;		and at the target, and the difference is how many blocks the jump leaves.
		;
		;		ONLY WHEN THE DEPTH IS NON-ZERO, and that matters more than it looks. The .unwind
		;		handler lives above GPBase, so emitting one unconditionally would mark EVERY
		;		program as using the GP block -- 2,048 bytes onto a program that never wrote a
		;		GP keyword. A program that is inside a GP.DO or GP.SELECT already carries it.
		;
		lda 	blockDepth
		beq 	_CGNoUnwind
		lda 	#PCD_CMD_UNWIND
		jsr 	WriteCodeByte
		lda 	#0 							; count placeholder, patched by FixBranches
		jsr 	WriteCodeByte
_CGNoUnwind:
		lda 	#PCD_CMD_GOTO
		jsr 	CompileBranchCommand
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
