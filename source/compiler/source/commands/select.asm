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
;		THE SELECTOR IS A PLAIN NUMERIC VARIABLE, and that restriction is what pays for all of
;		this. Until 1st September 2026 it was any expression, evaluated ONCE into a stack frame
;		because new.line resets the number stack at every source line and a value left there
;		would be gone before the first GP.CASE. The frame worked, and it cost 112 bytes of the GP
;		runtime block -- gp.select 44, gp.case 42, gp.endsel 10, SelectFindFrame 12 -- carried by
;		every program that used any GP keyword at all.
;
;		A variable does not need keeping alive: it is still there. So each alternative RE-READS
;		it, the frame is gone, and all four keywords are now MARKERS with a no-op handler in the
;		CORE (CommandXIfMark in runtime/commands/goto.asm, shared with GP.IF and GP.ENDIF).
;
;		TWO THINGS FOLLOW, and the second is the bigger one:
;
;		  - the 112 bytes come out of the block, and
;		  - a program whose only GP.BASIC keyword is a GP.SELECT is now GP-BASIC **OUT**.
;		    ScanGPUsage decides by HANDLER ADDRESS, and every opcode this emits -- the markers,
;		    the variable read, f.cmp, =, or, .casenext, .caseend -- has its handler below GPBase.
;		    Exactly what GP.IF already did, and for the same reason.
;
;		A volatile selector is spelled by hand now, which is honest rather than a loss:
;
;			T = RND(1)*3 : GP.SELECT T
;
;		THE MARKERS ARE STILL EMITTED AND MUST BE. FixBranches has no symbol table and no
;		back-patching, so the emitted token stream IS the block structure: it scans for
;		gp.select/gp.case/gp.other/gp.endsel to resolve .casenext and .caseend and to count
;		nesting. Delete the tokens and the branch resolver has nothing to walk. They cost one
;		vector slot each, in the core, which they already had.
;
;		AN ARRAY ELEMENT IS REFUSED -- GP.SELECT A(3) does not compile. GetReferenceTerm emits
;		the subscript expression as it parses, and re-issuing the read at each alternative would
;		not re-issue that, so the index would be whatever happened to be on the stack. A scalar
;		is a fixed slot and can be re-read as often as we like. Assign it to one first.
;
;		Lowering, for GP.SELECT K / GP.CASE 13,17 / GP.OTHER / GP.ENDSEL:
;
;			gp.select                           marker only -- nothing is evaluated or pushed
;			gp.case <K> 13 f.cmp = gp.case <K> 17 f.cmp = or  .casenext -> next alternative
;			<body>
;			.caseend -> gp.endsel               written by whatever alternative comes NEXT
;			gp.other
;			<body>
;			gp.endsel                           marker; every branch lands ON it
;
;		The p-code cost is +2 bytes per ALTERNATIVE (the variable read gp.case used to do in one
;		byte) and -2 per SELECT (the selector expression no longer compiled).
;
;		Case values are still ordinary EXPRESSIONS, not the compile-time constants prog8
;		restricts its "when" to -- each test is an expression compiled in the ordinary way.
;		Numeric only: a string selector would need s.cmp instead of f.cmp, and the type is not
;		known at the point each GP.CASE is compiled.
;
;		NO STACK FRAME MEANS NO UNWINDING. BlockDepthUp/Down are deliberately NOT called any
;		more, and FixBranches no longer counts gp.select/gp.endsel in either of its depth walks.
;		A GOTO leaving a select has nothing to close, and an .unwind emitted for one would close
;		a frame belonging to something else.
;
;		All four MUST return carry CLEAR. A .def helper returning carry set makes the generator
;		silently drop every token after it, with no error and no clue.
;
; ************************************************************************************************

SELECT_MAX_NEST = 8 						; selects open at once. Three bytes of compiler space
											; each, and nothing in the tree nests past two.

;
;		The three error exits are a long way below, so each is reached through a JMP here. A
;		relative branch cannot span this routine.
;
CommandSelectCompile:
		lda 	SelectDepth
		cmp 	#SELECT_MAX_NEST
		bcc 	_CSCRoom
		jmp 	SelectFailNest
_CSCRoom:
		;
		;		A plain numeric SCALAR, resolved now and re-read at every alternative. NOT
		;		GetReferenceTerm, which would accept an array element and emit its subscript
		;		here, where no alternative can repeat it -- see the header.
		;
		jsr 	GetNextNonSpace 			; a variable starts with a letter; a digit, a quote
		jsr 	CharIsAlpha 				; or a bracket cannot, which rejects expressions
		bcs 	_CSCAlpha
_CSCSyntax:
		jmp 	SelectFailSyntax
_CSCAlpha:
		jsr 	ExtractVariableName 		; name in YX, type bits in X, "(" consumed if present
		cpx 	#0
		bmi 	_CSCSyntax 					; the "(" was there, so it is an array element
		txa
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		beq 	_CSCNumeric
		jmp 	SelectFailType
_CSCNumeric:
		;
		phx 								; the type, over FindVariable
		jsr 	FindVariable 				; CS: exists, YX = its slot. CC: never mentioned yet,
		bcs 	_CSCHave 					; which BASIC creates on the spot, as LET would
		jsr 	CreateVariableRecord
		jsr 	AllocateBytesForType
_CSCHave:
		pla
		and 	#NSSTypeMask+NSSIInt16 		; the shape GetSetVariable wants to see later
		sta 	SelectSaveType
		stx 	SelectSaveLo 				; YX is the slot; park it while the index is worked out
		sty 	SelectSaveHi
		;
		lda 	SelectDepth
		jsr 	SelectIndexA 				; X = SelectDepth * 3
		lda 	SelectSaveLo
		sta 	SelectVars,x
		lda 	SelectSaveHi
		sta 	SelectVars+1,x
		lda 	SelectSaveType
		sta 	SelectVars+2,x
		inc 	SelectDepth
		;
		lda 	#PCD_GPCMD_SELECT 			; a MARKER, for FixBranches. Nothing runs.
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
		clc 								; NO BlockDepthUp -- there is no frame to unwind out
		rts 								; of any more. See the header.

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
		lda 	#PCD_GPCMD_CASE 			; the marker FixBranches looks for, then the read
		jsr 	WriteCodeByte
		jsr 	SelectEmitRead
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
		lda 	SelectDepth 				; underflow is not guarded, as with blockDepth: a
		beq 	_CESCFloor 					; stray GP.ENDSEL is caught structurally, by
		dec 	SelectDepth 				; FixBranches raising BLOCK MISMATCH
_CESCFloor:
		lda 	#PCD_GPCMD_ENDSEL
		jsr 	WriteCodeByte
		clc 								; NO BlockDepthDown -- nothing was opened
		rts

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

;
;		Emit a read of the innermost open select's variable. This is what gp.case used to do out
;		of the stack frame, and it is the only place the new scheme costs anything: two bytes of
;		p-code per alternative instead of one.
;
SelectEmitRead:
		lda 	SelectDepth
		beq 	SelectFailStructure 		; a GP.CASE with no GP.SELECT above it
		dec 	a
		jsr 	SelectIndexA 				; X = (SelectDepth-1) * 3
		lda 	SelectVars,x
		pha 								; the low byte, over the two loads that follow
		lda 	SelectVars+1,x
		tay
		lda 	SelectVars+2,x 				; the type, which GetSetVariable reads from A
		plx 								; and the low byte back, so YX is the slot again
		clc 								; carry clear = generate a READ
		jmp 	GetSetVariable

;
;		X = A * 3. Three bytes an entry rather than a power of two because eight of them is 24
;		bytes either way and the multiply is four instructions.
;
SelectIndexA:
		sta 	SelectSaveIdx
		asl 	a 							; *2 -- depth is under 8, so this cannot carry
		clc
		adc 	SelectSaveIdx 				; *3
		tax
		rts

SelectFailType:
SelectFailSyntax: 							; a non-variable selector aborts HARD, as a type error.
		.error_type 						; .error_syntax would DEFER: errorhandler.asm rolls the
											; statement back to a runtime throw-stub, so the
											; gp.select marker vanishes while the GP.ENDSEL lines
											; below still emit -- and an ENCLOSING select's branch
											; scan then closes a level early, with no diagnostic.
											; Block openers never defer.
SelectFailNest:
		.error_memory 						; more nesting than SELECT_MAX_NEST allows
SelectFailStructure:
		.error_structure

;
;		Compiler-only working storage, in the CODE section rather than in storage: storage is the
;		1K hole below $0801 and is already full (see application/source/file-io/read.asm), and
;		compiler code is above ObjectBase and thrown away when the object is written -- so these
;		28 bytes cost a compiled program nothing at all.
;
SelectDepth: 								; how many GP.SELECTs are open right now
		.fill 	1
SelectVars: 								; three bytes each: slot lo, slot hi, type
		.fill 	3*SELECT_MAX_NEST
SelectSaveLo:
		.fill 	1
SelectSaveHi:
		.fill 	1
SelectSaveType:
		.fill 	1
SelectSaveIdx:
		.fill 	1

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
;		01/09/26		Selector restricted to a plain numeric scalar, and the stack frame went
;						with it: 112 bytes out of the GP block, and GP.SELECT no longer pulls
;						the block in at all.
;
; ************************************************************************************************
