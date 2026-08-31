; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		select.asm
;		Purpose:	GP.SELECT / GP.CASE / GP.OTHER / GP.ENDSEL
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		GP.SELECT <expr>
;		GP.CASE <expr> [,<expr> ...]
;		GP.OTHER
;		GP.ENDSEL
;
;		None of these can be table entries: three of the four write a SYSTEM token with an inline
;		two byte operand, which the command table has no way to reserve, and GP.CASE writes a
;		different number of them depending on how many alternatives it is given. So each writes
;		its own tokens here, exactly as GP.EXITDO does.
;
;		Lowering, for GP.SELECT K / GP.CASE 13,17 / GP.OTHER / GP.ENDSEL:
;
;			<K> gp.select                       selector into a stack frame
;			gp.case 13 f.cmp = gp.case 17 f.cmp = or  .casenext -> next alternative
;			<body>
;			.caseend -> gp.endsel               written by whatever alternative comes NEXT
;			gp.other
;			<body>
;			gp.endsel                           closes the frame; every branch lands ON it
;
;		Case values are ordinary EXPRESSIONS, not the compile-time constants prog8 restricts its
;		"when" to. That falls out of the design rather than costing anything: the selector is
;		re-fetched from the frame for every alternative, so each test is just an expression
;		compiled in the ordinary way. Numeric only -- a string selector would need s.cmp instead
;		of f.cmp, and the type is not known at the point each GP.CASE is compiled.
;
;		All four MUST return carry CLEAR. A .def helper returning carry set makes the generator
;		silently drop every token after it, with no error and no clue.
;
; ************************************************************************************************

CommandSelectCompile:
		jsr 	CompileExpressionAt0 		; the selector, evaluated exactly once
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	SelectFailType
		lda 	#PCD_GPCMD_SELECT
		jsr 	WriteCodeByte
		;
		;		The alternative that comes next is the FIRST one, so it must not be preceded by
		;		a .caseend -- there is no case body in front of it to branch out of. One byte
		;		of state is enough for any depth of nesting: an inner GP.SELECT sets the flag,
		;		its own first alternative clears it, and by the time the outer select's next
		;		alternative is reached the flag is clear again, which is exactly right.
		;
		lda 	#$FF
		sta 	SelectFirstCase
		jmp 	BlockDepthUp 				; a frame is open from here: see goto.asm

CommandCaseCompile:
		jsr 	CompileCaseEnd 				; close the previous case body, if there was one
		jsr 	CompileCaseTest 			; the first alternative
_CCCList:
		jsr 	LookNextNonSpace 			; a comma list is an OR of tests, and it is cheaper
		cmp 	#"," 						; than a branch per alternative: 1 byte, not 3
		bne 	_CCCDone
		jsr 	GetNext
		jsr 	CompileCaseTest
		lda 	#PCD_OR
		jsr 	WriteCodeByte
		bra 	_CCCList
_CCCDone:
		lda 	#PCD_CMD_CASENEXT 			; and branch on to the next alternative if none matched
		jsr 	WriteCodeByte
		bra 	SelectWritePlaceholder

;
;		One alternative: fetch the selector again, compile the value, compare. CompareEqual
;		reads the -1/0/1 that f.cmp leaves, so the pair is what the expression compiler itself
;		emits for any "=" between numbers.
;
CompileCaseTest:
		lda 	#PCD_GPCMD_CASE
		jsr 	WriteCodeByte
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	SelectFailType
		lda 	#PCD_FCMD_CMP
		jsr 	WriteCodeByte
		lda 	#PCD_EQUAL
		jmp 	WriteCodeByte

CommandOtherCompile:
		jsr 	CompileCaseEnd
		lda 	#PCD_GPCMD_OTHER
		jsr 	WriteCodeByte
		clc
		rts

;
;		GP.ENDSEL deliberately writes NO .caseend of its own -- the last body simply falls into
;		it, which is three bytes and one branch cheaper than jumping to the next instruction.
;		It does clear the flag, so an EMPTY select (GP.SELECT x : GP.ENDSEL) cannot leave it set
;		for an enclosing one to trip over.
;
CommandEndSelectCompile:
		stz 	SelectFirstCase
		lda 	#PCD_GPCMD_ENDSEL
		jsr 	WriteCodeByte
		jmp 	BlockDepthDown 				; the frame closes here: see goto.asm

;
;		The branch out of a finished case body. Written at the START of the alternative that
;		FOLLOWS it, because that is the first moment the compiler knows the body has ended --
;		this compiler has no back-patching, so there is no going back to add it later.
;
CompileCaseEnd:
		lda 	SelectFirstCase
		beq 	_CCEBranch
		stz 	SelectFirstCase 			; the first alternative: nothing in front to leave
		rts
_CCEBranch:
		lda 	#PCD_CMD_CASEEND
		jsr 	WriteCodeByte
;
;		Two placeholder bytes. The value is never read: FixBranches overwrites both
;		unconditionally, and errors out rather than leaving them if it cannot resolve the branch.
;
SelectWritePlaceholder:
		lda 	#0
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte
		clc
		rts

SelectFailType:
		.error_type

		.send code

		.section storage
SelectFirstCase: 							; $FF between a GP.SELECT and its first alternative
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
;		17/08/26		Written.
;
; ************************************************************************************************
