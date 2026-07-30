; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		power.asm
;		Purpose:	Power operator
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								calculate S[0] ^ S[1]
;
; ************************************************************************************************

FloatPower:
		dex 							; S[X] = base, S[X+1] = exponent

;
;		x^0 is 1 for every x, 0^0 included -- which is what X16 BASIC answers.
;
		lda 	NSMantissa0+1,x
		ora 	NSMantissa1+1,x
		ora 	NSMantissa2+1,x
		ora 	NSMantissa3+1,x
		beq 	_FPWOne

;
;		0^n for nonzero n is 0. The logs below cannot do this at all -- log(0)
;		fails -- so this used to raise OUT OF RANGE where X16 BASIC just says 0.
;
		jsr 	FloatIsZero
		beq 	_FPWZero

;
;		A WHOLE exponent is done by repeated multiplication, which is EXACT.
;		exp(y*log x) is not: the round trip loses 7-8 bits, so 2^8 came back as
;		256.0000026 and 2^32 was 176 too large. Any program using 2^n as a bit mask
;		or an exact divisor was silently wrong -- the MD5 in testing/ slices a
;		64-bit length with 2^(8*J) and produced a wrong digest because of it.
;
;		Test for wholeness on a COPY in S[X+2]: FloatFractionalPart works on the
;		absolute value, which is exactly what the test wants. S[X+1] is left alone
;		so the logs path can still have the original exponent.
;
		inx 							; X = exponent
		txa
		tay
		iny 							; Y = scratch
		jsr 	CopyFloatXY
		inx 							; X = scratch
		jsr 	FloatFractionalPart
		jsr 	FloatIsZero 			; Z set (A = 0) if the exponent was whole
		dex
		dex 							; back to the base -- which trashes Z, so
		cmp 	#0 						; retest the A that FloatIsZero left
		bne 	_FPWUseLogs

;
;		Whole. Take the magnitude only if it fits one mantissa byte, the same shape
;		check FloatExponent makes. 256 and over cannot give a representable answer
;		for any |base| > 1 anyway, and for |base| < 1 the logs are the right tool.
;
		inx
		txa
		tay
		iny
		jsr 	CopyFloatXY 			; exponent -> scratch again
		inx
		jsr 	FloatIntegerPart
		dex
		dex

		lda 	NSMantissa1+2,x 		; anything above the low byte means >= 256
		ora 	NSMantissa2+2,x
		ora 	NSMantissa3+2,x
		ora 	NSExponent+2,x
		bne 	_FPWUseLogs
		lda 	NSMantissa0+2,x
		beq 	_FPWUseLogs 			; a zero exponent was handled above; belt and braces
		sta 	powCount

		lda 	NSStatus+1,x 			; which way to go at the end, while the
		sta 	powNegative 			; exponent is still untouched

;
;		The accumulator has to finish in S[X], where the base is now, so stash the
;		base up in S[X+3] and start S[X] at 1. S[X+3] is needed because
;		FloatMultiply SHIFTS ITS MULTIPLICAND to bits and leaves S[X+1] destroyed,
;		so the base has to be handed to it fresh every time round. S[X+2] is its
;		scratch. That is the same three slots above X the logs path already used.
;
		txa
		tay
		iny
		iny
		iny
		jsr 	CopyFloatXY 			; base -> S[X+3]
		lda 	#1
		jsr 	FloatSetByte 			; S[X] = 1

_FPWMulLoop:
		txa 							; Y = S[X+1], the multiplicand slot
		tay
		iny
		inx 							; X = S[X+3], where the base is kept
		inx
		inx
		jsr 	CopyFloatXY 			; refresh the multiplicand
		dex 							; X = S[X+1], so FloatMultiply's own dex
		dex 							; lands on the accumulator
		jsr 	FloatMultiply 			; S[X] *= S[X+1], returns X = accumulator
		dec 	powCount
		bne 	_FPWMulLoop

		lda 	powNegative
		bmi 	_FPWReciprocal
		clc
		rts

;
;		x^-n = 1/(x^n). Move the power up and divide one by it; FloatDivide reports
;		a zero divisor in carry, which is the answer for 0^-n.
;
_FPWReciprocal:
		txa
		tay
		iny
		jsr 	CopyFloatXY 			; x^n -> S[X+1]
		lda 	#1
		jsr 	FloatSetByte 			; S[X] = 1
		inx
		jmp 	FloatDivide 			; S[X] = 1 / S[X+1], and its carry is ours

_FPWOne:
		lda 	#1
		jsr 	FloatSetByte
		clc
		rts

_FPWZero:
		jsr 	FloatSetZero
		clc
		rts

;
;		Fractional exponent: the original exp(y * log x). This needs a positive
;		base, log() failing otherwise -- X16 BASIC refuses a fractional power of a
;		negative number too.
;
_FPWUseLogs:
		txa 							; copy 0 to 2, so we can process it
		tay
		iny
		iny
		jsr 	CopyFloatXY

		inx 							; 2 = Log(0)
		inx

		jsr 	FloatLogarithm
		bcs 	_FPWExit

		jsr 	FloatMultiply			; Multiply by original 1, into 1.

		txa 							; copy to slot 0
		tay
		dey
		jsr 	CopyFloatXY

		dex  							; Exponent code.

		jsr 	FloatExponent
_FPWExit:
		rts

		.send 	code

		.section storage
powCount: 									; whole exponent still to multiply in
		.fill 	1
powNegative: 								; sign of the exponent (bit 7)
		.fill 	1
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
