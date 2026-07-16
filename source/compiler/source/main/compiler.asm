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

		jsr 	STRReset 					; reset storage (line#, variable)

		lda 	#BLC_OPENIN					; reset data input
		jsr 	CallAPIHandler

		lda 	#BLC_RESETOUT 				; reset data output.
		jsr 	CallAPIHandler
		;
		;		Compile _variable.space, filled in on pass 2.
		;
		lda 	#PCD_CMD_VARSPACE
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte
		jsr 	WriteCodeByte
		;
		;		Reset implicit-array tracking, and emit the jump to the implicit-DIM prologue.
		;		The prologue lives at line $FFFF (emitted at the end); it dimensions every
		;		undimensioned array and then jumps to the first real line. It is emitted whether
		;		or not any arrays need it -- with none it is just a jump straight back -- because
		;		we don't yet know if the program has any. VARSPACE has already run, so the array
		;		allocator (availableMemory) is set up by the time the prologue executes.
		;
		stz 	implicitDimCount
		stz 	implicitDimFirstSet
		stz 	clrCheckpoint 				; no CLR compiled yet -> no array is re-DIMmable
		stz 	clrCheckpoint+1
		lda 	#$00 						; default return target $FE00 (the END marker) so an
		sta 	implicitDimFirst 			; empty program's prologue just exits cleanly.
		lda 	#$FE
		sta 	implicitDimFirst+1
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

		cmp 	#0 							; if ASCII then check for implied LET.
		bpl 	_MCLCheckAssignment

		ldx 	#CommandTables & $FF 		; do command tables.
		ldy 	#CommandTables >> 8
		jsr 	GeneratorProcess
		bcs 	_MCLSameLine 				; keep trying to compile the line.

_MCLSyntax: 								; syntax error.
		.error_syntax
		;
		;		Implied assignment ?
		;
_MCLCheckAssignment:
		jsr 	CharIsAlpha 				; if not alpha then syntax error
		bcc 	_MCLSyntax
		jsr 	CommandLETHaveFirst  		; LET first character, do assign
		bra		_MCLSameLine 				; loop back.
		;
		;		End of compile, fix up GOTO/GOSUB etc., save it and exit.
		;
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
		jsr 	FixBranches 				; fix up GOTO/GOSUB etc.

		lda 	#BLC_CLOSEOUT 				; close output store 
		jsr 	CallAPIHandler
		clc 								; CC = success

ExitCompiler:		
		ldx 	compilerSP 					; reload SP and exit.
		txs
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
