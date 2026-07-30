; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		altbase.asm
;		Purpose:	Handle other bases
;		Created:	16th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						Compile a 32 bit other base constant. Type marker in A
;
;		THIRTY-TWO bits, not sixteen. This used to accumulate into a zero page pair and always
;		emit a 16 bit push, so every digit above the fourth was shifted out of the top and lost:
;		$10000 compiled to 0, $FFFFFF to 65535, $FFFFFFFF to 65535. X16 BASIC takes all 32 bits,
;		and it matters -- the MD5 program on the X16 wiki builds its constants as
;
;			A0 = $6745 * $10000 + $2301
;
;		which came out as $2301 and quietly produced a wrong digest with no error anywhere.
;
;		The value is built in the mantissa of stack slot 0, the same place ParseConstant builds a
;		decimal one, and emitted the same way: a compact 16 bit push when it fits, a float
;		constant when it does not.
;
; ************************************************************************************************

InlineNonDecimal:
		ldy 	#2 							; the base: % is binary, $ is hexadecimal
		cmp 	#"%"
		beq 	_INDHaveBase
		ldy 	#16
_INDHaveBase:
		sty 	zTemp1 						; base => zTemp1. This used to hold the type MARKER
		stz 	zTemp1+1 					; character, so the digit test below compared against
											; "$" (36) or "%" (37) -- right for hex by luck, and
											; wrong for binary, which accepted 0-36 as bits.
		;
		ldx 	#0 							; build it in stack slot 0: mantissa 0, exponent 0,
		jsr 	FloatSetZero 				; positive, so the mantissa IS the value
_INDLoop:
		jsr 	LookNext 					; check next character
		jsr 	ConvertHexStyle		 		; convert into range 0-35 for 0-9A-Z
		bcc		_INDDone 					; didn't convert
		cmp 	zTemp1 						; not a digit of THIS base ?
		bcs 	_INDDone
		;
		pha 								; keep the digit while the mantissa shifts up
		jsr 	_INDShift 					; x 2 ...
		lda 	zTemp1
		cmp 	#2
		beq 	_INDNotHex
		jsr 	_INDShift 					; ... or x 16
		jsr 	_INDShift
		jsr 	_INDShift
_INDNotHex:
		pla 								; or the digit in at the bottom
		ora 	NSMantissa0,x
		sta 	NSMantissa0,x
		jsr 	GetNext 					; consume
		inc 	zTemp1+1 					; bump count
		bra 	_INDLoop
		;
_INDDone:
		lda 	zTemp1+1 					; done at least 1 ?
		beq 	_INDError
		;
		lda 	NSMantissa2,x 				; anything above 16 bits ?
		ora 	NSMantissa3,x
		bne 	_INDFloat
		ldy 	NSMantissa1,x 				; no : the compact 16 bit push
		lda 	NSMantissa0,x
		jmp 	PushIntegerYA
_INDFloat:
		jmp 	PushFloatCommand 			; yes : a float constant, as the decimal path does

_INDError:
		.error_syntax

_INDShift:
		asl 	NSMantissa0,x
		rol 	NSMantissa1,x
		rol 	NSMantissa2,x
		rol 	NSMantissa3,x
		rts
		.send code

		.section storage
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
