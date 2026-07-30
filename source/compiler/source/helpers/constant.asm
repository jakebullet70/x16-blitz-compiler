; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		constant.asm
;		Purpose:	Output integer constants
;		Created:	15th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Output code to push integer YA / A
;
; ************************************************************************************************

PushIntegerYA:
		cpy 	#0 							; 0-255
		beq 	PushIntegerA
		pha
		lda 	#PCD_CMD_WORD 				; send .word
		jsr 	WriteCodeByte 	
		pla 								; then LSB
		jsr 	WriteCodeByte 	
		tya 								; then MSB
		jsr 	WriteCodeByte 	
		rts

PushIntegerA:
		cmp 	#64 						; if > 64 send byte as is
		bcc 	_PIWriteA
		pha 								
		lda 	#PCD_CMD_BYTE 				; send .byte
		jsr 	WriteCodeByte 	
		pla
_PIWriteA:		
		jsr 	WriteCodeByte
		rts

; ************************************************************************************************
;
;										Push TOS Float
;
;		Six bytes: exponent, then the four mantissa bytes, then the sign in a byte of its own.
;
;		The sign used to ride in bit 7 of the top mantissa byte, which was free while the mantissa
;		normalised to bit 30 and integers were capped at $7FFFFFFF. Bit 31 is a value bit now
;		(see FloatNormalise), so packing the sign there DESTROYED it: the constant 4000000000
;		($EE6B2800) was written as $EE, read back as mantissa $6E6B2800 with the sign set, and
;		printed as -1852516352 -- the value less 2^31, negated. Every literal from 2^31 up was
;		wrong, and everything computed from one with it.
;
;		The extra byte costs one byte per float constant in the object code, and CommandPushN and
;		pcode.py's .float size must agree with it.
;
; ************************************************************************************************

PushFloatCommand:
		lda 	#PCD_CMD_FLOAT 				; write CMD_FLOAT
		jsr 	WriteCodeByte
		lda 	NSExponent,x 				; and the data
		jsr 	WriteCodeByte
		lda 	NSMantissa0,x
		jsr 	WriteCodeByte
		lda 	NSMantissa1,x
		jsr 	WriteCodeByte
		lda 	NSMantissa2,x
		jsr 	WriteCodeByte
		lda 	NSMantissa3,x 				; all four mantissa bytes are value now
		jsr 	WriteCodeByte
		lda 	NSStatus,x 					; the sign, on its own
		and 	#$80
		jsr 	WriteCodeByte
		rts

		.send code

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
