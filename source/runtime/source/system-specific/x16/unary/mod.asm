; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		mod.asm
;		Purpose:	MOD(dividend,divisor) function
;		Created:	13th July 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								MOD(<dividend>,<divisor>)
;
;		The truncated remainder, so the result takes the sign of the DIVIDEND:
;		-7 MOD 3 is -1, and 7 MOD -3 is 1.
;
;		Int32Divide already does all the work, we just keep the half that DivideInt32 throws
;		away. It is an unsigned mantissa divide leaving the quotient in S[X+2] and the
;		remainder in S[X], and it clears S[X] with FloatSetZeroMantissaOnly -- the mantissa
;		and nothing else -- so the dividend's status byte survives the divide untouched. That
;		byte is its sign, which is exactly the sign a truncated remainder needs, so there is
;		no sign fixup here at all. (Contrast FloatCalculateSign, which DivideInt32 uses to xor
;		the two signs together: right for a quotient, wrong for a remainder.)
;
;		The X16 ROM restricts MOD to 16 bit signed operands. Blitz does not need to: this is
;		a full 32 bit remainder, which is a superset.
;
; ************************************************************************************************

UnaryMOD: ;; [mod]
		.entercmd 							; X is the divisor, the dividend is below it at S[X-1]
		phy
		jsr 	FloatIntegerPart 			; make the divisor an integer
		jsr 	FloatIsZero 				; dividing by zero is an error
		beq 	_UMDivideByZero
		dex 								; X is now the dividend, so S[X+1] is the divisor
		jsr 	FloatIntegerPart 			; make the dividend an integer
		jsr 	Int32Divide 				; S[X] mantissa = |dividend| mod |divisor|
		stz 	NSExponent,x 				; below the divisor, so it is a whole number
		jsr 	FloatIsZero 				; a zero remainder must not come back as -0
		bne 	_UMExit
		stz 	NSStatus,x
_UMExit:
		ply
		.exitcmd

_UMDivideByZero:
		.error_divzero

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
