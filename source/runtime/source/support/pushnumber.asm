; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		pushnumber.asm
;		Purpose:	Push number onto stack 
;		Created:	14th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								Push Number <EXP> <MANTISSA> <SIGN>
;
;		Six bytes, matching PushFloatCommand: the sign has a byte to itself because bit 31 of the
;		mantissa is a value bit now (see FloatNormalise) and can no longer be borrowed to carry it.
;		Masking bit 31 off here and reading it as the sign turned every constant of 2^31 or more
;		into value-2^31, negated.
;
; ************************************************************************************************

CommandPushN: ;; [.float]
		.entercmd

		inx 								; next slot on stack

		lda 	(codePtr),y 				; exponent
		sta 	NSExponent,x
		iny

		lda 	(codePtr),y 				; mantissa, all four bytes of it
		sta 	NSMantissa0,x
		iny
		lda 	(codePtr),y
		sta 	NSMantissa1,x
		iny
		lda 	(codePtr),y
		sta 	NSMantissa2,x
		iny
		lda 	(codePtr),y
		sta 	NSMantissa3,x
		iny
		lda 	(codePtr),y 				; and the sign, already masked to bit 7
		sta 	NSStatus,x
		iny
		.exitcmd

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
