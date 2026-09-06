; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		00compiler.asm
;		Purpose:	Compiler main
;		Created:	15th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						On entry YX points to API.  On Exit CC if okay.
;
; ************************************************************************************************

StartCompiler:
		stx 	zTemp0 						; access API
		sty 	zTemp0+1

		ldy 	#CompilerErrorHandler >> 8 	; set error handler to compiler one.
		ldx 	#CompilerErrorHandler & $FF
		jsr 	SetErrorHandler
		;
		ldy 	#1 							; copy API vector		
		lda 	(zTemp0)	
		sta 	APIVector
		lda 	(zTemp0),y
		sta 	APIVector+1

		iny 								; copy data area range.
		lda 	(zTemp0),y 					
		sta 	compilerStartHigh
		iny
		lda 	(zTemp0),y 					
		sta 	compilerEndHigh

		tsx 								; save stack pointer
		stx 	compilerSP

		stz 	passNumber 					; the first of the two
		stz 	pass1VarSpace 				; nothing known yet, so pass one emits zeroes into the
		stz 	pass1VarSpace+1 			; _variable.space operand and pass two emits the answer

; ************************************************************************************************
;
;		THE WHOLE SOURCE IS COMPILED TWICE, and the two passes emit exactly the same bytes.
;
;		Pass one exists to answer the questions a single forward pass cannot: where every line
;		ends up, how much space the variables need, where each block's forward branches land.
;		Pass two then compiles the same source again knowing all of it, so nothing has to be
;		written down and gone back to.
;
;		THE TWO PASSES PRODUCING IDENTICAL BYTES IS A LOAD-BEARING ASSUMPTION and nothing in the
;		structure enforces it -- so it is checked rather than trusted. WriteCodeByte accumulates
;		a Fletcher-16 over every byte, and the tail of pass two compares that and the length
;		against pass one's before anything is written out. A mismatch is a compiler bug and says
;		so; it is never a silently wrong object, which is the one failure this must not have.
;
;		Everything a compile accumulates has to be back at its starting value for pass two, which
;		is what ResetPassState is for. Anything missed from it shows up as a checksum mismatch on
;		the first program that touches it, rather than as a corrupt object months later.
;
; ************************************************************************************************

CompilePass:
		jsr 	ResetPassState 				; every counter and table this pass will fill

		lda 	#BLC_OPENIN					; reset data input
		jsr 	CallAPIHandler

		lda 	#BLC_RESETOUT 				; reset data output.
		jsr 	CallAPIHandler
		;
		;		_variable.space -- how much room the variables need. It sits at the very top of
		;		the program and the answer is only known at the very bottom, which is exactly the
		;		shape of problem the second pass exists to solve: pass one emits nothing useful
		;		here and finishes with the total, pass two writes that total straight in.
		;
		;		This used to be patched in place by FixBranches, which is why the opcode was here
		;		in the first place -- it was a one-pass compiler with one two-pass-shaped hole in
		;		it. That handler is gone.
		;
		lda 	#PCD_CMD_VARSPACE
		jsr 	WriteCodeByte
		lda 	pass1VarSpace 				; zero in pass one, the real figure in pass two
		jsr 	WriteCodeResolved
		lda 	pass1VarSpace+1
		jsr 	WriteCodeResolved
		;
		;		Emit the jump to the implicit-DIM prologue. The prologue lives at line $FFFF
		;		(emitted at the end); it dimensions every undimensioned array and then jumps to
		;		the first real line. It is emitted whether or not any arrays need it -- with none
		;		it is just a jump straight back -- because we don't yet know if the program has
		;		any. VARSPACE has already run, so the array allocator (availableMemory) is set up
		;		by the time the prologue executes.
		;
		lda 	#PCD_CMD_GOTO
		jsr 	WriteCodeByte
		lda 	#$FF 						; -> line $FFFF (the prologue)
		jsr 	WriteCodeByte
		jsr 	WriteCodeByte
		;
		;		Main compilation loop
		;
MainCompileLoop:
		lda 	#BLC_READIN 				; read next line into the buffer.		
		jsr 	CallAPIHandler

		bcc 	SaveCodeAndExit 			; end of source.
		jsr 	ProcessNewLine 				; set up pointer and line number.
		;
		jsr 	GetLineNumber 				; get line # (=> A low, Y high)
		;
		ldx 	implicitDimFirstSet 		; remember the first real line: the implicit-DIM prologue
		bne 	_MCLHaveFirst 				; jumps back here when it has finished. (A/Y untouched.)
		inc 	implicitDimFirstSet
		sta 	implicitDimFirst
		sty 	implicitDimFirst+1
_MCLHaveFirst:
		jsr 	STRMarkLine 				; remember the code position and number of this line.
		lda 	#PCD_NEWCMD_LINE 			; generate new command line
		jsr 	WriteCodeByte

_MCLSameLine:
		jsr 	GetNextNonSpace 			; get the first character.
		beq 	MainCompileLoop 			; end of line, get next line.
		cmp 	#":"						; if : then loop back.
		beq 	_MCLSameLine
		cmp 	#";" 						; a stray ; between statements (e.g. GOSUB 970;) is
		beq 	_MCLSameLine 				; tolerated by BASIC, so skip it like a colon.

		;
		;		A real statement follows. Checkpoint it for defer-to-runtime: remember the
		;		object write cursor and the compile-loop stack level, and arm SYNTAX-error
		;		deferral. If it then fails to compile with a SYNTAX error, CompilerErrorHandler
		;		rolls back to here and drops a runtime throw-stub in its place (see
		;		DeferStatementToRuntime) instead of aborting. Preserve A (the first character).
		;
		pha
		lda 	objPtr
		sta 	stmtRecoverObj
		lda 	objPtr+1
		sta 	stmtRecoverObj+1
		lda 	#1
		sta 	deferErrors
		pla
		tsx
		stx 	stmtRecoverSP
		;
		cmp 	#0 							; if ASCII then check for implied LET.
		bpl 	_MCLCheckAssignment

		ldx 	#CommandTables & $FF 		; do command tables.
		ldy 	#CommandTables >> 8
		jsr 	GeneratorProcess
		bcc 	_MCLNoHandler 				; a TOKEN the command tables do not know
		stz 	deferErrors 				; compiled OK -> disarm the deferral
		bra 	_MCLSameLine 				; keep trying to compile the line.

		;
		;		A RETIRED KEYWORD MUST NOT DEFER. Getting here means the first character was a
		;		TOKEN (>= $80, so the tokeniser knew the word) and no generator claimed it --
		;		which is a fact about the program, not a typo, because a misspelling arrives as
		;		ASCII and goes to _MCLCheckAssignment instead. Deferring it wrote a runtime
		;		throw-stub and said OK CODE, so a source file left calling GP.STASH or GP.SORT
		;		after they moved to GP.ASM modules compiled clean and threw SYNTAX ERROR at an
		;		address, whenever it was first reached. That cost two hours on 01/09/26 and it
		;		was two separate files, one broken since 15d90eb with nobody noticing.
		;
		;		NOT IMPLEMENTED rather than SYNTAX, for the reason UnsupportedCompile already
		;		gives (gensupport.asm): the word is valid BASIC, so blaming the spelling sends
		;		the reader looking in the wrong place. Only ErrorV_syntax is deferrable, so
		;		naming a different error is what makes this abort -- see errorhandler.asm.
		;
_MCLNoHandler:
		.error_unimplemented

_MCLSyntax: 								; syntax error.
		.error_syntax
		;
		;		Implied assignment ?
		;
_MCLCheckAssignment:
		jsr 	CharIsAlpha 				; if not alpha then syntax error
		bcc 	_MCLSyntax
		jsr 	CommandLETHaveFirst  		; LET first character, do assign
		stz 	deferErrors 				; assignment compiled OK -> disarm the deferral
		bra		_MCLSameLine 				; loop back.
		;
		;		End of compile, fix up GOTO/GOSUB etc., save it and exit.
		;
; ************************************************************************************************
;
;		Reached from CompilerErrorHandler when a statement failed to compile with a SYNTAX error
;		while deferral was armed. The stack is already unwound to stmtRecoverSP and the object
;		cursor rolled back to stmtRecoverObj, so just drop a single throw-stub in the statement's
;		place (raises SYNTAX ERROR at runtime, but only if reached) and carry on at the next
;		line -- the remainder of this line sits after the stub, so it can never run.
;
; ************************************************************************************************

DeferStatementToRuntime:
		lda 	#PCD_CMD_DEFERROR
		jsr 	WriteCodeByte
		jmp 	MainCompileLoop 			; drop the rest of this source line: everything after the
										; stub is unreachable (it throws first), so read the next line.

SaveCodeAndExit:
		lda 	#BLC_CLOSEIN				; finish input.
		jsr 	CallAPIHandler

		lda 	#$00 						; end-of-program line = $FE00 for forward THEN / goto-past-end.
		ldy 	#$FE 						; Deliberately NOT $FFxx: STRFindLine treats any entry whose
		jsr 	STRMarkLine 				; line-number high byte is $FF as the end-of-table sentinel,
		lda 	#PCD_EXIT 					; so only the $FFFF prologue line (the last entry) may use it.
		jsr 	WriteCodeByte 				; ($FE00 is above every real line and forward-THEN target.)
		;
		;		The implicit-DIM prologue. Unreachable by fall-through (the END above stops first);
		;		entered only by the GOTO $FFFF that StartCompiler emitted at the very top. It
		;		dimensions every undimensioned array, then jumps back to the first real line.
		;
		lda 	#$FF 						; prologue line = $FFFF (the largest line, marked last, so it
		ldy 	#$FF 						; is also the $FF end-of-table sentinel STRFindLine expects)
		jsr 	STRMarkLine
		jsr 	EmitImplicitDims
		lda 	#PCD_CMD_GOTO 				; return to the first real line (or $FFFE if none)
		jsr 	WriteCodeByte
		lda 	implicitDimFirst
		jsr 	WriteCodeByte
		lda 	implicitDimFirst+1
		jsr 	WriteCodeByte
		;
		lda 	#$FF 						; add end marker
		jsr 	WriteCodeByte
		;
		;		END OF A PASS. Pass one stops here and goes round again -- everything below this
		;		point runs once, on the p-code pass two produced.
		;
		;		The pool is deliberately NOT flushed in pass one. AsmFlushPool appends it through
		;		WriteCodeByte, so flushing would put it in the checksum, and pass two rebuilds the
		;		pool from scratch anyway (ResetPassState clears AsmPoolLen). Comparing the p-code
		;		alone is the comparison that means something.
		;
		lda 	passNumber
		bne 	_SCECompare
		;
		lda 	passSum 					; what pass two now has to reproduce, exactly
		sta 	pass1Sum
		lda 	passSum+1
		sta 	pass1Sum+1
		lda 	objPtr
		sta 	pass1Len
		lda 	objPtr+1
		sta 	pass1Len+1
		lda 	freeVariableMemory 			; ...and the answer pass two writes into the operand
		sta 	pass1VarSpace 				; at the top of the program. STRReset zeroes the
		lda 	freeVariableMemory+1 		; original, so it has to be kept here.
		sta 	pass1VarSpace+1
		inc 	passNumber
		jmp 	CompilePass

		;
		;		Pass two. Length first, then the sum: a length mismatch is the likelier bug and
		;		the more informative one, though both land in the same place.
		;
_SCECompare:
		lda 	objPtr
		cmp 	pass1Len
		bne 	_SCEDiverged
		lda 	objPtr+1
		cmp 	pass1Len+1
		bne 	_SCEDiverged
		lda 	passSum
		cmp 	pass1Sum
		bne 	_SCEDiverged
		lda 	passSum+1
		cmp 	pass1Sum+1
		bne 	_SCEDiverged
		;
		;		And the variable space, which pass two wrote into the program before it had
		;		recomputed it. Free to check and it covers the one value the object carries that
		;		the byte stream cannot see -- the operand holding it is not in the sum.
		;
		lda 	freeVariableMemory
		cmp 	pass1VarSpace
		bne 	_SCEDiverged
		lda 	freeVariableMemory+1
		cmp 	pass1VarSpace+1
		beq 	_SCEAgreed
		;
		;		The passes disagree, so some piece of compile state was carried from one into the
		;		other -- ResetPassState is missing something. Nothing has been written yet, and
		;		nothing is going to be: an object built from two different compiles of the same
		;		source is exactly the corrupt output this check exists to prevent.
		;
_SCEDiverged:
		.error_internal

_SCEAgreed:
		jsr 	AsmFlushPool 				; append the GP.ASM blob pool AFTER the $FF end marker,
											; where nothing walks -- see commands/gpasmcode.asm
		jsr 	GPBankRelocate 				; lift a GP.BANKED region out to the end of the object,
											; past the pool. AFTER AsmFlushPool so the pool stays in
											; low memory below it, and BEFORE FixBranches so every
											; branch is still a line number -- commands/gpbank.asm.
											; Does nothing to a program without a region.
		;
		;		FIXBRANCHES DESTROYS objPtr. It rewinds to the start and walks to the end marker,
		;		so it comes back pointing at the $FF -- and everything after that is invisible to
		;		it. That used to be the whole object, because the GP.ASM pool was appended
		;		afterwards. Now the pool goes on first, and objPtr is the length WriteObjectCode
		;		streams, so leaving it at the end marker silently truncated every pool: a program
		;		with an inline blob compiled OK and jumped into nothing at the first call.
		;
		lda 	objPtr
		sta 	objectEnd
		lda 	objPtr+1
		sta 	objectEnd+1
		jsr 	FixBranches 				; fix up GOTO/GOSUB etc.
		lda 	objectEnd
		sta 	objPtr
		lda 	objectEnd+1
		sta 	objPtr+1

		lda 	#BLC_CLOSEOUT 				; close output store 
		jsr 	CallAPIHandler
		clc 								; CC = success

ExitCompiler:
		ldx 	compilerSP 					; reload SP and exit.
		txs
		rts

; ************************************************************************************************
;
;		Put every piece of state a compile accumulates back to where it started, so the next pass
;		sees exactly what the last one saw. Called once per pass, before a byte is read or
;		written.
;
;		THE STORAGE SECTION IS UNINITIALISED RAM (a .dsection at $0400, below the loaded file --
;		see common.inc), so most of this was already needed for the FIRST pass. What the second
;		pass adds is the two GP.ASM counters below, which live in the code section and so used to
;		arrive zeroed by the loader and never needed clearing again.
;
; ************************************************************************************************

ResetPassState:
		jsr 	STRReset 					; line number table, variable list, free variable memory

		stz 	SelectDepth 				; open GP.SELECTs, for the selector-variable stack
		stz 	blockDepth 					; GP.DO nesting -- a non-zero start makes every GOTO
											; emit an .unwind it does not need
		stz 	gpBankState 				; no GP.BANKED region seen yet, and nothing relocated.
		stz 	gpBankActive
		stz 	gpBankCount 				; MUST start at zero: it is the length of every region
											; table, so a stale byte walks all of them off the end.
		stz 	gpBankNumber 				; The last two are read unconditionally by the bootstrap
		stz 	gpBankRunBase 				; patch table, and gpBankRunBase derives from FreeMemory,
											; so left stale it writes a dead byte into a non-banked
											; object that MOVES when the compiler's own size changes.
		stz 	implicitDimCount
		stz 	implicitDimFirstSet
		stz 	clrCheckpoint 				; no CLR compiled yet -> no array is re-DIMmable
		stz 	clrCheckpoint+1
		stz 	deferErrors 				; not deferring compile errors until a statement arms it
		lda 	#$00 						; default return target $FE00 (the END marker) so an
		sta 	implicitDimFirst 			; empty program's prologue just exits cleanly.
		lda 	#$FE
		sta 	implicitDimFirst+1
		;
		;		GP.ASM. The pool and the fixup list are both rebuilt from scratch by each pass --
		;		the fixups especially, because AsmFixTarget records the address the operand landed
		;		at, and pass one's addresses are not the ones PatchAsmFixups will be resolving.
		;
		stz 	AsmPoolLen
		stz 	AsmPoolLen+1
		stz 	AsmFixupCount
		;
		stz 	passSum 					; and the stream checksum this pass will build
		stz 	passSum+1
		rts

; ************************************************************************************************
;
;										Call API Functions
;
; ************************************************************************************************

CallAPIHandler:
		jmp 	(APIVector)

; ************************************************************************************************
;
;		Emit the runtime code that dimensions every registered undimensioned array to bound 10
;		(11 elements, 0..10) in each dimension -- exactly what interpreted BASIC does on first
;		use. Emitted once, into the prologue. Each list entry is 4 bytes: slot addr lo, slot addr
;		hi, element type, dimension count. The emitted sequence per array mirrors CommandDIM:
;		push the bound once per dimension, push the dimension count, push the type, DIM (which
;		builds the array and leaves its offset on the stack), then store that offset into the
;		array variable's slot.
;
; ************************************************************************************************

EmitImplicitDims:
		lda 	implicitDimCount
		bne 	_EIDGo
		rts 								; nothing undimensioned -> emit nothing.
_EIDGo:
		sta 	implicitDimEntries
		stz 	implicitDimIdx
_EIDLoop:
		ldx 	implicitDimIdx 				; dimension count for this array (registered >= 1)
		lda 	implicitDimList+3,x
		beq 	_EIDSkip 					; 0 = tombstoned: an explicit DIM took this array over,
		sta 	implicitDimN 				; so it dimensions it for real -- emit nothing here.
		sta 	implicitDimRem
_EIDPushBound:								; push the bound 10 once per dimension
		lda 	implicitDimRem
		beq 	_EIDPushed
		lda 	#10
		jsr 	PushIntegerA
		dec 	implicitDimRem
		bra 	_EIDPushBound
_EIDPushed:
		lda 	implicitDimN 				; push the dimension count
		jsr 	PushIntegerA
		ldx 	implicitDimIdx 				; push the element type
		lda 	implicitDimList+2,x
		jsr 	PushIntegerA
		.keyword PCD_DIM 					; build the array, leaving its offset on the stack
		ldx 	implicitDimIdx 				; store that offset into the array variable's slot
		lda 	implicitDimList+0,x
		ldy 	implicitDimList+1,x
		tax 								; X = addr lo, Y = addr hi
		lda 	#NSSIFloat+NSSIInt16 		; pretend int16, exactly as CommandDIM stores it
		sec
		jsr 	GetSetVariable
_EIDSkip:
		lda 	implicitDimIdx 				; advance to the next entry
		clc
		adc 	#4
		sta 	implicitDimIdx
		dec 	implicitDimEntries
		bne 	_EIDLoop
		rts

		.send code

		.section storage
compilerSP:									; stack pointer 6502 on entry.
		.fill 	1
APIVector: 									; call API here
		.fill 	2
compilerStartHigh:							; MSB of workspace start address
		.fill 	1
compilerEndHigh:							; MSB of workspace end address
		.fill 	1
objectEnd:									; the true end of the object, held across FixBranches --
		.fill 	2							; which rewinds objPtr and leaves it at the end marker
;
;		The two passes. passNumber is 0 while the first is running and 1 for the second, and it
;		is the only thing that tells them apart -- everything else about a pass is identical, by
;		construction and by the checksum below.
;
passNumber:								; 0 = first pass, 1 = second
		.fill 	1
passSum:									; Fletcher-16 over every byte this pass emitted,
		.fill 	2							; accumulated by WriteCodeByte (helpers/api.asm)
pass1Sum:									; ...and what pass one came to, kept for the compare
		.fill 	2
pass1Len:									; pass one's object length, compared the same way
		.fill 	2
pass1VarSpace:								; what the variables came to -- zero while pass one is
		.fill 	2							; running, which is what it emits into _variable.space
;
;		Implicit array dimensioning. Interpreted BASIC auto-creates an array (0..10 per
;		dimension) the first time it is used without a DIM. We can't do that lazily -- this VM
;		has no branch that targets a point inside a line, so there is nowhere to put a per-access
;		"dimension it if it isn't yet" test. Instead every undimensioned array is registered here
;		as it is discovered, and a prologue at the very start of the program (jumped to before any
;		user code) dimensions them all once. See EmitImplicitDims and _GRTArray.
;
implicitDimCount:							; number of undimensioned arrays registered
		.fill 	1
implicitDimFirst:							; first real line number = where the prologue returns to
		.fill 	2
implicitDimFirstSet:						; nonzero once implicitDimFirst has been captured
		.fill 	1
implicitDimIdx:								; scratch: byte offset into the list while emitting
		.fill 	1
implicitDimEntries:							; scratch: entries left to emit
		.fill 	1
implicitDimN:								; scratch: dimension count of the array being emitted
		.fill 	1
implicitDimRem:								; scratch: bounds left to push for this array
		.fill 	1
implicitDimAddr:							; scratch: a variable slot address
		.fill 	2
implicitDimType:							; scratch: element type bits
		.fill 	1
implicitDimList:							; per entry: slot addr lo, slot addr hi, type, dim count
		.fill 	4*32 						; capacity 32 -- more than that falls back to the old error
deferErrors: 								; nonzero while a statement is compiling whose SYNTAX errors
		.fill 	1 							; should defer to a runtime throw-stub, not abort the compile
stmtRecoverSP: 							; 6502 stack level to unwind to when deferring a statement
		.fill 	1
stmtRecoverObj: 						; object write cursor to roll back to (discards partial code)
		.fill 	2
		.send storage

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
