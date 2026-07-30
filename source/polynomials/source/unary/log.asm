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
