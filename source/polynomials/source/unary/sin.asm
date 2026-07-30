; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		sin.asm
;		Purpose:	Sine function.
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									calculate SIN(x)
;
; ************************************************************************************************

FloatSine:
		lda 	NSStatus,x 					; save sign
		pha
		stz 	NSStatus,x 					; make +ve

		.pushfloat Const_1Div2Pi 			; divide by 2*Pi

		jsr 	FloatMultiply 
		jsr 	FloatFractionalPart 		; take the fractional part

		;
		;		Quadrant split on the normalised exponent. The mantissa is in [2^31,2^32) now, so
		;		these are one lower than they were: 0.25-0.5 is exponent -33 ($DF, was $E0) and
		;		0.75 is mantissa $C0000000 (was $60000000) -- see FloatNormalise.
		;
		lda 	NSExponent,x 				; check exponent
		cmp 	#$DF 						; < $DF exponent : 0-0.25
		bcc 	_USProcessExit
		beq 	_USSubtractFromHalf 		; = $DF exponent : 0.25-0.5
		lda 	NSMantissa3,x 				; if > 0.75 which is $C0000000:$E0
		cmp 	#$C0
		bcs 	_USSubtractOne
_USSubtractFromHalf:						; 0.25 - 0.75 calculate 0.5-x
		.pushfloat Const_half 				; so calculate x-0.5
		jsr 	FloatSubtract
		jsr 	FloatNegate 				; then negate it
		bra 	_USProcessExit 				; and exit

_USSubtractOne:								; 0.75 - 1.0 calculate x - 1
		inx
		lda 	#1
		jsr 	FloatSetByte
		jsr 	FloatSubtract

_USProcessExit:
		jsr 	CoreSine
		jsr 	CompletePolynomial
		pla 								; restore sign and apply
		eor 	NSStatus,x
		sta 	NSStatus,x
		clc
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
