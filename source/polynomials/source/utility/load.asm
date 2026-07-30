; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		load.asm
;		Purpose:	Load constant offset Y into X+1, preserving X
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									Load Constant
;
;		Six bytes per entry: four mantissa, exponent, sign (see mathconstants.py).
;
;		The sign used to ride in bit 7 of the top mantissa byte and be masked off here. That was
;		safe only while the mantissa normalised to bit 30 and left bit 31 spare; it holds a full
;		32 bits now, so the mask DESTROYED the top bit of every constant and read it back as a
;		minus. Const_Log2_e (1.44269504) came through as -0.442695, which is what made EXP(1)
;		return 2/e and took LOG, SQR and the trig functions with it.
;
; ************************************************************************************************

LoadConstant:
		phy
		tay
		lda 	Const_Base+0,y
		sta 	NSMantissa0+1,x
		lda 	Const_Base+1,y
		sta 	NSMantissa1+1,x
		lda 	Const_Base+2,y
		sta 	NSMantissa2+1,x
		lda 	Const_Base+3,y 				; all four mantissa bytes are value now
		sta 	NSMantissa3+1,x
		lda 	Const_Base+4,y
		sta 	NSExponent+1,x
		lda 	Const_Base+5,y 				; and the sign, in a byte of its own
		sta 	NSStatus+1,x
		ply
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
