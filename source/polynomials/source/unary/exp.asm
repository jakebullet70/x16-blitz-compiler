; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		exp.asm
;		Purpose:	Exponent function.
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									calculate EXP(x)
;
; ************************************************************************************************

FloatExponent:
	
		.pushfloat Const_Log2_e			; multiply by log2 e
		jsr 	FloatMultiply 

		jsr 	_UECopy01 				; copy 0 to 1, get integer part to 1
		inx
		jsr 	FloatIntegerPart
		dex

;
;		The integer part becomes the binary exponent of the result -- it is added straight
;		to NSExponent at the end -- so it has to fit a SIGNED byte. Too large is not an
;		error by itself; the SIGN of the argument decides which. A large POSITIVE argument
;		really does exceed the format, and that is a range error. A large NEGATIVE one only
;		underflows, and 0.0 is the correct answer for exp(-big), not a failure.
;
;		This used to cap the magnitude at 64 in both directions, which was far tighter than
;		the format (value = 32-bit mantissa * 2^signed-exponent, so ~2^127). It cost two
;		real cases: 2^64 -- whose exp() integer part is exactly 64, so it failed by one --
;		and EXP(-45), about 2.9e-20 and comfortably representable.
;
		lda 	NSMantissa1+1,x 		; |int| >= 256, so it cannot be added at all
		ora 	NSMantissa2+1,x
		ora 	NSMantissa3+1,x
		bne 	_UETooBig

		lda 	NSMantissa0+1,x 		; push integer part on stack.
		cmp 	#128 					; must still fit a SIGNED byte to be added below
		bcs 	_UETooBig
		pha

		lda 	NSStatus,x 				; push sign
		pha

		jsr 	FloatFractionalPart		; copy 0 to 1, get fractional part to 0

		pla 
		bpl 	_UEPositive

		inx 							; 1-x
		lda 	#1
		jsr 	FloatSetByte		
		dex
		jsr 	FloatNegate
		inx
		jsr 	FloatAdd

		pla 							; integer part +1 and negated.
		inc 	a
		eor 	#$FF
		inc 	a
		pha

_UEPositive:		
		jsr 	CoreExponent
		jsr 	CompletePolynomial

		pla 							; the integer part, already negated if the argument
		tay 							; was negative. Keep a copy: its sign is what tells
		clc 							; an overflow off the top from one off the bottom.
		adc 	NSExponent,x
		bvs 	_UEExpOutOfRange 		; ADC sets V on signed overflow of the exponent byte
		sta 	NSExponent,x
		clc
		rts

;
;		The exponent does not fit a signed byte. Adding a positive integer part means we
;		went off the top, which is a genuine range error; a negative one means off the
;		bottom, which underflows to zero.
;
_UEExpOutOfRange:
		tya
		bmi 	_UEUnderflow
		bra 	_UERangeError

;
;		|int| was too large to add at all. Same rule, decided by the sign of the argument.
;		That is still slot X, because slot X+1 is where the integer part was taken from.
;
_UETooBig:
		lda 	NSStatus,x
		bpl 	_UERangeError

_UEUnderflow: 							; exp(-big) is 0.0, and that is a success, not an error
		jsr 	FloatSetZero
		clc
		rts

_UECopy01:
		txa
		tay
		iny
		jmp 	CopyFloatXY

_UERangeError:
		sec
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
