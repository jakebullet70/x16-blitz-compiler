; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		fractional.asm
;		Purpose:	Extract fractional part 
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									Get fractional part of Stack,X
;
; ************************************************************************************************

FloatFractionalPart:
		phy

		lda 	NSStatus,x 					; take absolute value 
		and 	#$7F
		sta 	NSStatus,x
		jsr 	FloatNormalise

		;
		;		The value is normalised, so the mantissa is in [2^30,2^31) and the number of
		;		bits above the point is exponent+32. The exponent is SIGNED, and the old code
		;		worked it out with an unsigned "sbc #$E0" and branched on the borrow -- which
		;		underflows for any exponent >= 0, i.e. for every value >= 2^30. Those were
		;		declared "already fractional" and handed back whole, so PRINT 2000000000 came
		;		out as 2000000000.125. Test the sign the way FloatIntegerPart does instead.
		;
		lda 	NSExponent,x 				; exponent >= 0 : a whole number, nothing below the
		bpl 	_FFPZero 					; point at all.
		;
		clc 								; bits to blank = exponent+32, for exponents -32..-1
		adc 	#32
		bmi 	_FFPExit 					; under -32 : entirely fractional, blank nothing
		;
		tay 								; put count to do in Y
		;
		lda 	NSMantissa3,x 				; do each in turn.
		jsr 	_FFPPartial
		sta 	NSMantissa3,x

		lda 	NSMantissa2,x
		jsr 	_FFPPartial
		sta 	NSMantissa2,x

		lda 	NSMantissa1,x
		jsr 	_FFPPartial
		sta 	NSMantissa1,x

		lda 	NSMantissa0,x
		jsr 	_FFPPartial
		sta 	NSMantissa0,x
		
		jsr 	FloatIsZero 					; zeroed check.
		bne 	_FFPExit

_FFPZero:
		jsr 	FloatSetZero
_FFPExit:	
		jsr 	FloatNormalise
		ply	
		rts		
;
;		Clear up to 8 bits from A from the left, subtract from the count remaining in Y
;
_FFPPartial:
		cpy 	#0 							; no more to do
		beq 	_FFFPPExit
		cpy 	#8 							; whole byte to do ?
		bcs 	_FFFPPWholeByte 
		;
		phy
_FFFPPLeft:
		asl 	a
		dey 	
		bne 	_FFFPPLeft		
		ply
_FFFPPRight:
		lsr 	a
		dey 	
		bne 	_FFFPPRight
		bra 	_FFFPPExit

_FFFPPWholeByte:
		tya 								; subtract 8 from count
		sec
		sbc 	#8
		tay
		lda 	#0 							; and clear all
_FFFPPExit:		
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
