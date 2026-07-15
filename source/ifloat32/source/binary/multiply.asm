; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		multiply.asm
;		Purpose:	32x32 bit integer multiplication, 32 bit result with rounding and shift
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		Multiply stack entry X by stack entry X+1. If necessary right shifts. Returns on 
;		exit the number of left shifts required to fix it up. Calculates sign of result.
;
;		Does not change exponent.
;
; ************************************************************************************************

FloatMultiplyShort:
		phy 								; save Y
		jsr 	FloatShiftUpTwo 			; copy S[X] to S[X+2]
		jsr 	FloatSetZeroMantissaOnly 	; set mantissa S[X] to zero
		ldy 	#0 							; Y is the shift count.
		stz 	FMulGuard 					; no rounding bits dropped yet
		stz 	FMulGuard2
		;
		;		Main multiply loop.
		;				
_I32MLoop:
		lda 	NSMantissa0+2,x 			; check S[X+2] is zero
		ora 	NSMantissa1+2,x
		ora 	NSMantissa2+2,x
		ora 	NSMantissa3+2,x
		beq 	_I32MExit 					; exit if zero

		;
		;		Eat eight zero bits of the multiplier at a time.
		;
		;		When the multiplicand has bit 30 set it can never be doubled, so an iteration
		;		whose multiplier bit is zero does nothing at all except halve the accumulator and
		;		bump the shift count. Eight of those in a row are just "accumulator >>= 8,
		;		multiplier >>= 8, count += 8" -- three byte moves instead of eight trips round the
		;		loop. Truncation composes, so the result is bit for bit identical; only the loop
		;		gets shorter.
		;
		;		This is what makes integer x float fast, and it is not a corner case: normalising
		;		shifts LEFT, so an integer operand arrives packed with trailing zeros. I=8000
		;		normalises to $7D000000 -- eighteen of them -- and the loop used to grind through
		;		every one a bit at a time. (It is guarded on bit 30 because the integer fast path
		;		still wants to double a small multiplicand rather than halve the accumulator.)
		;
		lda 	NSMantissa0+2,x 			; low byte of the multiplier all zero ?
		bne 	_I32MByBit
		bit 	NSMantissa3+1,x 			; and the multiplicand cannot be doubled ?
		bvc 	_I32MByBit

		lda 	NSMantissa1+2,x 			; multiplier >>= 8
		sta 	NSMantissa0+2,x
		lda 	NSMantissa2+2,x
		sta 	NSMantissa1+2,x
		lda 	NSMantissa3+2,x
		sta 	NSMantissa2+2,x
		stz 	NSMantissa3+2,x

		lda 	NSMantissa0,x 				; the eight bits about to fall off the bottom: bit 7
		and 	#$80 						; is the new 0.5-ulp guard, bit 6 the 0.25-ulp guard2
		sta 	FMulGuard
		lda 	NSMantissa0,x
		and 	#$40
		sta 	FMulGuard2

		lda 	NSMantissa1,x 				; accumulator >>= 8
		sta 	NSMantissa0,x
		lda 	NSMantissa2,x
		sta 	NSMantissa1,x
		lda 	NSMantissa3,x
		sta 	NSMantissa2,x
		stz 	NSMantissa3,x

		tya 								; and the shift count catches up
		clc
		adc 	#8
		tay
		bra 	_I32MLoop

_I32MByBit:
		lda 	NSMantissa0+2,x 			; check LSB of n1
		and 	#1
		beq 	_I32MNoAdd
		;
		jsr 	FloatAddTopTwoStack 		; if so add S[X+1] to S[X+0]
		;
		lda 	NSMantissa3,x 				; has MantissaA overflowed ?
		bpl 	_I32MNoAdd
		;
		;		Overflow. Shift result right, increment the shift count, keeping the
		; 		result in 31 bits - now we lose some precision though.
		;
_I32ShiftRight:
		lda 	FMulGuard 					; the old 0.5-ulp guard drops to the 0.25-ulp slot
		sta 	FMulGuard2
		lda 	NSMantissa0,x 				; the bit about to fall off the bottom is the new
		and 	#1 							; guard bit (0.5 ulp - the shift count only grows,
		sta 	FMulGuard 					; so each dropped bit outranks the last)
		jsr 	FloatShiftRight 			; shift S[X] right
		iny 								; increment shift count
		bra 	_I32MShiftUpper 			; n2 is doubled by default.
		;
_I32MNoAdd:
		bit 	NSMantissa3+1,x				; if we can't shift S[X+1] left, shift everything right
		bvs 	_I32ShiftRight 				; instead.

		inx
		jsr 	FloatShiftLeft 				; shift additive S[X+1] left
		dex

_I32MShiftUpper:
		inx 								; shift S[X+2] right
		inx
		jsr 	FloatShiftRight
		dex
		dex

		bra 	_I32MLoop 					; try again.

_I32MExit:
		;
		;		Round to nearest. The multiply keeps the top 31 bits exactly - guard/guard2 hold
		;		the 0.5- and 0.25-ulp bits that fell off the bottom. But FloatNormalise runs next
		;		and, when bit 30 is clear, shifts the mantissa left one place, which would move the
		;		rounding point. So do that one normalise here first, folding the guard bit in as the
		;		real low bit it is, and let guard2 become the bit we round on.
		;
		bit 	NSMantissa3,x 				; bit 30 already set -> normalised, round on guard
		bvs 	_I32MRound
		lda 	NSMantissa3,x 				; bit 30 clear but bit 29 set -> exactly one left shift
		and 	#$20 						; is pending, so fold the guard in below. Neither set
		beq 	_I32MRound 					; means the value is too small to have dropped a bit
		lda 	FMulGuard 					; (exact, guard 0) - leave the whole normalise to
		cmp 	#1 							; FloatNormalise. carry := guard (0 or 1)
		rol 	NSMantissa0,x 				; mantissa = mantissa*2 + guard
		rol 	NSMantissa1,x
		rol 	NSMantissa2,x
		rol 	NSMantissa3,x
		dey 								; the *2 is one fewer net right shift
		lda 	FMulGuard2 					; guard2 is now the 0.5-ulp bit to round on
		sta 	FMulGuard
_I32MRound:
		lda 	FMulGuard 					; round to nearest: if the dropped 0.5-ulp bit was
		beq 	_I32MRounded 				; set, add one to the mantissa (round half up)
		inc 	NSMantissa0,x 				; propagate the carry up the 32 bit mantissa
		bne 	_I32MChkTop
		inc 	NSMantissa1,x
		bne 	_I32MChkTop
		inc 	NSMantissa2,x
		bne 	_I32MChkTop
		inc 	NSMantissa3,x
_I32MChkTop:
		bit 	NSMantissa3,x 				; rounding up 2^31-1 carries into bit 31; shift it
		bpl 	_I32MRounded 				; back into [2^30,2^31) and bump the shift count
		jsr 	FloatShiftRight
		iny
_I32MRounded:
		jsr 	FloatCalculateSign
		tya 								; shift in A
		ply 								; restore Y and exit
		rts

; ************************************************************************************************
;
;								Calculate sign from the two signs
;
; ************************************************************************************************

FloatCalculateSign:
		lda 	NSStatus,x 					; sign of result is 0 if same, 1 if different.
		asl 	NSStatus,x 					; shift result left
		eor 	NSStatus+1,x
		asl 	a 							; shift bit 7 into carry
		ror 	NSStatus,x 					; shift right into status byte.
		rts

FMulGuard: 									; the 0.5- and 0.25-ulp bits dropped as the accumulator
		.byte 	0 						; was shifted right; used to round the product to nearest
FMulGuard2: 								; at exit (guard2 is only needed when a trailing left
		.byte 	0 						; normalise turns the guard bit into a real mantissa bit)

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
