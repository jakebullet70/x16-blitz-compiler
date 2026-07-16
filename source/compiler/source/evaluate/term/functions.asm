; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		functions.asm
;		Purpose:	FNx code
;		Created:	1st May 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;										FN handler
;
; ************************************************************************************************

FNCompile:
		;
		;		Identify FNxx(
		;
		jsr 	GetNextNonSpace				; get variable name w/type must be array e.g. DEF FNx(a)
		jsr 	ExtractVariableName 
		cpx 	#0
		bpl 	_FNError
		;
		txa 								; convert to a function reference - bit 7:0 clear bit 7:1 set
		and 	#$7F
		tax
		tya
		ora 	#$80
		tay
		;
		;		Check to see if it is defined.
		;
		jsr 	FindVariable				; does it already exist ?
		bcc 	_FNError 					; no -- a forward FN reference is not supported.
		;
		;		FindVariable returns the FN body's ABSOLUTE code position in X (low) and Y (high),
		;		as stored by SetVariableRecordToCodePosition. Emit it verbatim as the operand of a
		;		.fngosub -- its own opcode, so FixBranches turns this absolute address into an
		;		offset (like any branch) instead of mistaking it for a source line number. Push
		;		high then low so, after the argument is compiled, the low byte is written first.
		;
		phy 								; abs HIGH
		phx 								; abs LOW  (top of stack)
		;
		;		Handle <expression>)
		;
		jsr 	CompileExpressionAt0
		jsr 	CheckNextRParen
		;
		;		Compile the call : .fngosub <lo> <hi>
		;
		lda 	#PCD_CMD_FNGOSUB
		jsr 	WriteCodeByte
		pla 								; abs LOW  -> operand byte 1
		jsr 	WriteCodeByte
		pla 								; abs HIGH -> operand byte 2
		jsr 	WriteCodeByte

		clc
		rts

_FNError:
		.error_value
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
