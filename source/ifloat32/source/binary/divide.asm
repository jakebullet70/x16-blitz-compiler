; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		divide.asm
;		Purpose:	32x32 bit integer division (2 variants)
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									Integer Division
;
; ************************************************************************************************

DivideInt32:
		jsr 	FloatIntegerPart 			; make both integers	
		dex
		jsr 	FloatIntegerPart
		jsr 	Int32Divide 				; divide
		jsr 	NSMCopyPlusTwoToZero 		; copy result
		jsr 	FloatCalculateSign 			; calculate result sign
		clc
		rts

NSMCopyPlusTwoToZero:		
		lda 	NSMantissa0+2,x 			; copy result down from +2
		sta 	NSMantissa0,x
		lda 	NSMantissa1+2,x
		sta 	NSMantissa1,x
		lda 	NSMantissa2+2,x
		sta 	NSMantissa2,x
		lda 	NSMantissa3+2,x
		sta 	NSMantissa3,x
		rts
		
; ************************************************************************************************
;
;		32 bit unsigned division of FPA Mantissa A by FPA Mantissa B, 32 bit result.
;									(see divide.py)
;
; ************************************************************************************************

Int32Divide:
		pha 								; save AXY
		phy
		jsr 	FloatShiftUpTwo 			; copy S[X] to S[X+2]
		jsr 	FloatSetZeroMantissaOnly 	; set S[X] to zero

		ldy 	#32 						; loop 32 times
_I32DivideLoop:
		inx
		inx
		jsr 	FloatShiftLeft				; shift S[X+2] S[X] left as a 64 bit element
		dex
		dex
		jsr 	FloatRotateLeft
		;		
		jsr 	FloatDivideCheck 			; check if subtract possible
		bcc 	_I32DivideNoCarryIn
		inc 	NSMantissa0+2,x 			; if possible, set Mantissa0[X+2].0
_I32DivideNoCarryIn:
		dey 								; loop round till division completed.
		bne 	_I32DivideLoop

		ply 								; restore AXY and exit
		pla
		clc
		rts

; ************************************************************************************************
;
;		Shifted Division used in Floating Point Divide - does (a << 30) // b
;									(see divide.py)
;
; ************************************************************************************************

Int32ShiftDivide:
		pha 								; save AY
		phy

		inx 								; clear S[X+2]
		inx
		jsr 	FloatSetZero
		dex
		dex

		stz 	divRemHigh 					; the remainder's 33rd bit, see below

		ldy 	#32 						; loop 32 times: the mantissa is normalised to bit 31
											; now, so the quotient wants one more bit than it did
											; and the shift is (a << 31), not (a << 30). The
											; caller's exponent fixup matches (sbc #31).
;
;		The remainder needs 33 bits now. It used to fit in 32 because a normalised mantissa left
;		bit 31 spare, so the shift below could never push anything out. With all 32 bits in use, a
;		dividend SMALLER than the divisor keeps bit 31 set and the shift threw it away -- which is
;		why 1/3 came out 0: the remainder was gone after the first step and every quotient bit
;		after it was zero. divRemHigh carries that bit. When it is set the remainder is >= 2^32,
;		which certainly exceeds the divisor, so the subtraction is known to succeed without a
;		compare and the quotient bit is 1.
;
_I32SDLoop:
		jsr 	_I32SDCheck 				; carry = this quotient bit
		jsr 	_I32SDShift 				; shift it into the quotient, advance the remainder
		dey 	 							; do 32 times
		bne 	_I32SDLoop
		;
		;		Round to nearest. The quotient in S[X+2] is floor((a<<31)/b), a 31- or 32-bit
		;		value. If bit 31 is already set it is 32-bit normalised and FloatNormalise will
		;		leave it alone, so one guard bit (the next quotient bit) rounds it. If bit 31 is
		;		clear it is 31-bit and FloatNormalise would shift it left one, filling the new LSB
		;		with a zero and throwing away a bit of precision -- so run one more division step
		;		to make that LSB a REAL quotient bit and drop the exponent to match, leaving a
		;		32-bit value that its own guard bit then rounds. Truncation was biased low; this
		;		is round-half-up and unbiased.
		;
		bit 	NSMantissa3+2,x 			; quotient bit 31 set ?
		bmi 	_I32SDGuard 				; yes -> already 32-bit, just round
		jsr 	_I32SDCheck 				; no -> compute the 32nd real bit ...
		jsr 	_I32SDShift 				; ... shift it in (now 32-bit normalised) ...
		dec 	NSExponent,x 				; ... and the extra shift is worth one exponent
_I32SDGuard:
		jsr 	_I32SDCheck 				; guard bit = the next quotient bit
		bcc 	_I32SDExit
		inc 	NSMantissa0+2,x 			; round half up
		bne 	_I32SDExit
		inc 	NSMantissa1+2,x
		bne 	_I32SDExit
		inc 	NSMantissa2+2,x
		bne 	_I32SDExit
		inc 	NSMantissa3+2,x
		bne 	_I32SDExit
		;
		;		Rounding up $FFFFFFFF wrapped the quotient to zero, so its true value is 2^32. Put
		;		the 1 back as bit 31 and raise the exponent to match; bit 31 set is the normalised
		;		state now, so nothing else needs fixing.
		;
		lda 	#$80
		sta 	NSMantissa3+2,x
		inc 	NSExponent,x
_I32SDExit:
		ply 								; restore AY and exit
		pla
		rts

;
;		One division step, split in two so the main loop and the two extra steps after it all
;		honour the remainder's 33rd bit identically.
;
;		_I32SDCheck returns the quotient bit in carry, subtracting the divisor when it fits. A set
;		divRemHigh means the remainder is already >= 2^32 and so certainly exceeds the divisor:
;		subtract without comparing. That subtraction always brings it back below 2^32 (the
;		remainder is under 2*divisor before each shift, and the divisor is >= 2^31), so the 33rd
;		bit is spent.
;
_I32SDCheck:
		lda 	divRemHigh
		bne 	_I32SDCForce
		jmp 	FloatDivideCheck 			; tail call -- its carry is our answer
_I32SDCForce:
		jsr 	FloatSubTopTwoStack
		stz 	divRemHigh
		sec 								; the quotient bit is 1
		rts

;
;		_I32SDShift puts the carry into the quotient as its new low bit and advances the remainder,
;		catching whatever leaves bit 31 in divRemHigh.
;
_I32SDShift:
		inx
		inx
		jsr 	FloatRotateLeft				; quotient <<= 1, the carry entering as its new bit
		dex
		dex
		clc 								; remainder <<= 1 with a zero at the bottom -- NOT the
		jsr 	FloatRotateLeft 			; carry out of the quotient, which is a value bit now
		rol 	divRemHigh 					; and whatever left bit 31 is the 33rd bit
		rts

; ************************************************************************************************
;
;							Do the division - check subtraction code
;
;			If can subtract FPB from FPA.Upper, do so, return carry set if was subtracted
;			Common code to both divisions.
;
; ************************************************************************************************

FloatDivideCheck:
		jsr 	FloatSubTopTwoStack 		; subtract Stack[X+1] from Stack[X+0]
		bcs 	_DCSExit 					; if carry set, then could do, exit
		jsr 	FloatAddTopTwoStack 		; add it back in
		clc 								; and return False
_DCSExit:
		rts

		.send 	code

		.section storage
divRemHigh: 								; bit 32 of the division remainder
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
