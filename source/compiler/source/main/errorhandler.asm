; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		errorhandler.asm
;		Purpose:	Error handler
;		Created:	1st May 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code
	
CompilerErrorHandler:
		pla
		ply
		sta 	zTemp0
		sty 	zTemp0+1
		;
		;		Defer-to-runtime: while a statement compiles (deferErrors armed) a SYNTAX error
		;		does not abort -- roll the statement back and let DeferStatementToRuntime drop a
		;		runtime throw-stub in its place. Identified by the message pointer: ErrorV_syntax's
		;		text sits at ErrorV_syntax+3, so the pushed return (=that-1) is +2. Other error
		;		types, and any error while not armed, report and abort as before.
		;
		lda 	deferErrors
		beq 	_EHReport
		lda 	zTemp0
		cmp 	#<(ErrorV_syntax+2)
		bne 	_EHReport
		lda 	zTemp0+1
		cmp 	#>(ErrorV_syntax+2)
		bne 	_EHReport
		stz 	deferErrors 				; disarm
		ldx 	stmtRecoverSP 			; unwind the 6502 stack to the statement-dispatch level
		txs
		lda 	stmtRecoverObj 			; roll the object cursor back -> discard partial p-code
		sta 	objPtr
		lda 	stmtRecoverObj+1
		sta 	objPtr+1
		jmp 	DeferStatementToRuntime
_EHReport:
		ldx 	#0 							; output msg to channel #0 
		ldy 	#1
_EHDisplayMsg:
		lda 	(zTemp0),y
		jsr 	PrintCharacter
		iny
		lda 	(zTemp0),y
		bne 	_EHDisplayMsg
		lda 	#32
		jsr 	PrintCharacter
		lda 	#64
		jsr 	PrintCharacter
		;
		ldx 	#0 							; convert line# to string
		jsr 	FloatSetByte
		jsr 	GetLineNumber
		sta 	NSMantissa0,x
		tya
		sta 	NSMantissa1,x
		jsr 	FloatToString
		ldy 	#0 							; display that string.
		ldx 	#0
_EHDisplayLine:
		lda 	decimalBuffer,y
		jsr 	PrintCharacter
		iny
		lda 	decimalBuffer,y
		bne 	_EHDisplayLine
		lda 	#13
		jsr 	PrintCharacter
		sec 								; CS = error	
		jmp 	ExitCompiler
						
		.send code

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
