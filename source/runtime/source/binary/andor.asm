; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		andor.asm
;		Purpose:	And/Or operators
;		Created:	14th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;									AND/OR code
;
; ************************************************************************************************

BinaryAnd: ;; [and]
		.entercmd
		sec
		bra 	AndOrCommon
BinaryOr: ;; [or]
		.entercmd
		clc

AndOrCommon:
		php 								; save AND/OR flag
			 								; convert both to 16 bit format.
		jsr 	AndOrGet16
		dex
		jsr 	AndOrGet16

		plp
		bcc 	_AOCOrCode
	
		lda 	NSMantissa0,x 				; AND code
		and		NSMantissa0+1,x
		sta 	NSMantissa0,x
		lda 	NSMantissa1,x
		and		NSMantissa1+1,x
		sta 	NSMantissa1,x
		bra 	_AOCComplete
_AOCOrCode:
		lda 	NSMantissa0,x 				; OR code
		ora		NSMantissa0+1,x
		sta 	NSMantissa0,x
		lda 	NSMantissa1,x
		ora		NSMantissa1+1,x
		sta 	NSMantissa1,x
_AOCComplete:		
		stz 	NSStatus,x 					; make integer ?
		bit 	NSMantissa1,x 				; result is -ve
		bpl 	_AOCExit

		jsr 	Negate16Bit 				; 2's complement
		lda 	#$80 						; make it -ve
		sta 	NSStatus,x
_AOCExit:
		.exitcmd

; ************************************************************************************************
;
;		Truncate one operand to an integer and convert it to 16 bit two's complement, rejecting
;		anything that will not fit. AND/OR are 16 bit operations here, as they are in stock X16
;		BASIC, but the old code reached GetInteger16Bit directly and that only ever touches
;		Mantissa0/1 -- Mantissa2/3 were left holding the top half of the operand and rode
;		straight through into the result:
;
;			70000 AND -1  ->  70000        ($00011170, low word ANDed, $0001 untouched)
;			4294967295 AND 0  ->  4294901760   ($FFFF0000)
;
;		Stock raises ?ILLEGAL QUANTITY ERROR for an operand outside -32768..32767 rather than
;		returning something, so range check instead of masking: measured against R49, 32767 and
;		-32768 are accepted, 32768, 65535, 65536, -32769 and 70000 are all rejected, and a
;		fraction truncates (3.7 AND -1 = 3) in both. Checking has to happen on the MAGNITUDE,
;		before the two's complement conversion -- afterwards -32768 and -40000 both leave a
;		high byte with bit 7 set and are indistinguishable.
;
; ************************************************************************************************

AndOrGet16:
		.floatinteger 						; truncate toward zero first: the range is checked
											; against the integer part, as stock's is.
		lda 	NSMantissa2,x 				; magnitude must fit in 16 bits at all.
		ora 	NSMantissa3,x
		bne 	_AOGRange
		lda 	NSMantissa1,x
		bpl 	_AOGConvert 				; magnitude <= $7FFF is always fine.
		;
		;		$8000..$FFFF is legal only as exactly -32768.
		;
		bit 	NSStatus,x 					; BIT leaves A alone, so Mantissa1 survives the test
		bpl 	_AOGRange 					; positive -> 32768 or above -> out of range
		cmp 	#$80 						; negative -> magnitude must be exactly $8000
		bne 	_AOGRange
		lda 	NSMantissa0,x
		bne 	_AOGRange
_AOGConvert:
		bit 	NSStatus,x 					; negative operands become two's complement, which is
		bpl 	_AOGDone 					; what GetInteger16Bit did. Mantissa2/3 are known zero
		jmp 	Negate16Bit 				; by now, so Negate16Bit's 16 bit reach is enough.
											; (jmp, not bmi: it lives in support/integers.asm,
											; well out of branch range from here.)
_AOGDone:
		rts
_AOGRange:
		.error_range

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
