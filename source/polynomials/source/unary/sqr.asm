; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		sqr.asm
;		Purpose:	Square root function.
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									calculate SQR(x)
;
; ************************************************************************************************

FloatSquareRoot:
		jsr 	FloatIsZero 				; SQR(0) = 0. This routine computes the root as
		beq 	_FSQZero 					; exp(0.5*ln(x)), but ln(0) is undefined so
		;									; FloatLogarithm errors on 0 -- special-case it here,
		;									; matching interpreted BASIC (SQR(0)=0, SQR(-x)=error).
		jsr 	FloatLogarithm
		bcs 	_FSQExit
		dec 	NSExponent,x
		jsr 	FloatExponent
		clc
_FSQExit:
		rts
_FSQZero:
		jsr 	FloatSetZero 				; canonical +0 in slot X
		clc 								; CC = success
		rts

		.send 	code

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
