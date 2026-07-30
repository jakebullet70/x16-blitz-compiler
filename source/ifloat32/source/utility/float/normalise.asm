; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		normalise.asm
;		Purpose:	Normalise FP value
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									  Normalise Stack[X]
;
; ************************************************************************************************

FloatNormalise:
		jsr 	FloatIsZero 				; if zero exit 
		bne 	_NSNormaliseOptimise 		; if so, normalise it.
		asl 	NSStatus,x 					; clear the sign bit.
		ror 	NSStatus,x 					; (no -0)
		lda 	#0 							; set Z flag
		rts
		;
		;		Normalise by byte if the MSB is zero we can normalise it
		;		(providing bit 7 of 11th byte is not set)
		;
_NSNormaliseOptimise:
		lda 	NSMantissa3,x 				; upper byte zero ?
		bne 	_NSNormaliseLoop
		lda 	NSMantissa2,x 				; byte normalise. No "bit 7 of byte 2 set"
											; guard any more: bit 31 IS the normalised
											; position now, so moving a byte up is always
											; safe.
		sta 	NSMantissa3,x
		lda 	NSMantissa1,x
		sta 	NSMantissa2,x
		lda 	NSMantissa0,x
		sta 	NSMantissa1,x
		stz 	NSMantissa0,x
		;
		lda 	NSExponent,x
		sec
		sbc 	#8
		sta 	NSExponent,x
		bra 	_NSNormaliseOptimise
		;
		;		Normalise by bit
		;
;
;		Normalise to bit 31, so the mantissa uses all 32 bits: [2^31, 2^32). It used to stop at
;		bit 30, leaving bit 31 spare as carry headroom for addition, which cost the whole top bit
;		of precision -- above 2^31 the step was 2, so consecutive integers were indistinguishable
;		and 2147483648-2147483647 came out 2. X16 BASIC's float carries a full 32-bit mantissa and
;		answers 1, and matching it is the point. The adders now take their overflow and their
;		result sign from the CARRY instead of from bit 31.
;
;		This also fixes a LOCKUP. Stopping at bit 30 meant a mantissa of $80000000 -- bit 31 set,
;		bit 30 clear -- was shifted LEFT, losing the only bit it had; the loop never rechecks for
;		zero, so it span forever. Any value landing in [2^31, 3*2^30) hung the machine, which is
;		what  PRINT 2^31+1-2^31  did. Testing bit 31 exits on those immediately.
;
_NSNormaliseLoop:
		lda 	NSMantissa3,x 				; bit 31 set ?
		bmi 	_NSNExit 					; exit if so with Z flag clear
		jsr 	FloatShiftLeft 				; shift mantissa left
		dec 	NSExponent,x 				; adjust exponent
		bra 	_NSNormaliseLoop
_NSNExit:
		lda 	#$FF 						; clear Z flag
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
