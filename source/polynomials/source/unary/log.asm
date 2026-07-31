; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		log.asm
;		Purpose:	Log function.
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									calculate LOG(x)
;
; ************************************************************************************************

FloatLogarithm: 	
	
		lda 	NSStatus,x 					; check > 0
		bmi 	_ULRange
		jsr 	FloatIsZero
		beq 	_ULRange
		jsr 	FloatNormalise 				; put into FP mode.

		;
		;		LOG(1) has to be EXACTLY 0, and the general path below cannot deliver that. It
		;		computes log(f) + k*log(2); for x=1 those are -log(2) and +log(2), so the answer
		;		is the difference of two nearly equal numbers and comes out only as exactly as
		;		the polynomial is exact at the very END of its fitted interval (f = 0.5, k = 1).
		;		It was not: LOG(1) returned 3.2277181E-10 where stock X16 BASIC gives 0. Every
		;		other logarithm measured against stock already agreed, so special-case the one
		;		value rather than disturb the polynomial.
		;
		;		Normalised, the mantissa sits in [2^31,2^32), so 1.0 is the ONLY value with
		;		mantissa $80000000 and exponent -31 -- this is an exact identity test.
		;
		;		Deliberately NOT FloatCompare: that ignores the low 12 bits of the difference
		;		(compare.asm calls it "almost equal", 1 part in ~500,000), so it would also
		;		swallow everything just either side of 1 and return 0 for logarithms that are
		;		genuinely non-zero -- trading a wrong answer at one point for wrong answers
		;		across a whole neighbourhood.
		;
		lda 	NSMantissa0,x
		ora 	NSMantissa1,x
		ora 	NSMantissa2,x
		bne 	_ULNotOne
		lda 	NSMantissa3,x
		cmp 	#$80
		bne 	_ULNotOne
		lda 	NSExponent,x
		cmp 	#(-31) & $FF
		bne 	_ULNotOne
		jsr 	FloatSetZero 				; LOG(1) = 0, exactly. Clears the sign too.
		clc
		rts
_ULNotOne:

		lda 	NSExponent,x 				; get power
		pha

		;
		;		Split the value as f x 2^k with f in [0.5,1), which is the range the polynomial is
		;		fitted over. Normalised, the mantissa is in [2^31,2^32), so f is the mantissa read
		;		with an exponent of -32 and k is the real exponent plus 32. It was -31/+31 while
		;		the mantissa normalised to bit 30 -- see FloatNormalise. The two errors very nearly
		;		cancel (log2(2f) = log2(f)+1) which is why this looked half-alive, but it fed the
		;		polynomial an argument outside the interval it is fitted on.
		;
		lda 	#(-32) & $FF 				; force into range 0.5 -> 1
		sta 	NSExponent,x


		.pushfloat Const_sqrt_half 			; add sqrt 0.5
		jsr 	FloatAdd


		txa 								; divide into sqrt 2.0
		tay
		iny
		jsr 	CopyFloatXY
		dex
		.pushfloat Const_sqrt_2
		inx

		jsr 	FloatDivide 				; if zero, error.
		bcs 	_ULRangePla

		jsr 	FloatNegate 				; subtract from 1
		inx
		lda 	#1
		jsr 	FloatSetByte
		jsr 	FloatAdd

		jsr 	CoreLog
		jsr 	CompletePolynomial

		pla 								; add exponent
		clc
		adc 	#32 						; fix up, matching the -32 forced above

		pha
		bpl 	_LogNotNeg
		eor 	#$FF
		inc 	a		
_LogNotNeg:		
		inx 								; set byte and sign.
		jsr 	FloatSetByte

		pla
		and 	#$80
		sta 	NSStatus,x
		jsr 	FloatAdd

		.pushfloat Const_ln_e 			; * log2(e)
		jsr 	FloatMultiply
		clc
		rts

_ULRangePla:
		pla
_ULRange:
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
