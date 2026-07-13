; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		tostring.asm
;		Purpose:	Convert number to string
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						Convert FPA to String in ConversionBuffer
;
; ************************************************************************************************

FloatToString:
		phx
		phy 								; save code position
		sta 	decimalPlaces	 			; save number of DPs.
		stz 	dbOffset 					; offset into decimal buffer = start.

		lda 	NSStatus,x  				; is it -ve.
		bpl 	_CNTSNotNegative
		and 	#$7F 						; make +ve
		sta 	NSStatus,x
		lda 	#"-"
		bra 	_CNTMain
_CNTSNotNegative:
		lda 	#" "
_CNTMain:
		jsr 	WriteDecimalBuffer
		lda 	NSExponent,x 				; check if decimal
		beq 	_CNTSNotFloat
		;
		;		Round to the last decimal place that will actually be printed, by adding half
		;		of it -- 5 x 10^-(dp+1). The digits below that are then truncated away, which
		;		is what makes 2/3 come out as .6666667 rather than .6666666, and stops a value
		;		held a hair under 7 from printing as 6.9999999.
		;
		;		This used to add 1 x 2^exponent instead: one whole ULP of the BINARY mantissa,
		;		which has nothing to do with the decimal place being rounded to, and on a large
		;		value is enormous. 1000000000-999999999 is EXACTLY 1.0, held as mantissa 2 with
		;		exponent -1, so its ULP is 0.5 -- and it printed as "1.5".
		;
		inx 								; S[X+1] = 5
		lda 	#5
		jsr 	FloatSetByte
		lda 	decimalPlaces 				; A = -(dp+1)
		inc 	a
		eor 	#$FF
		inc 	a
		jsr 	FloatScalePower10 			; S[X+1] = 5 x 10^-(dp+1)
		jsr 	FloatAdd 					; does its own dex, so X is back on the value
_CNTSNotFloat:

		jsr 	MakePlusTwoString 			; do the integer part.
		jsr 	FloatFractionalPart 		; get the fractional part
		jsr 	FloatNormalise					; normalise , exit if zero
		beq 	_CNTSExit
		lda 	#"."
		jsr 	WriteDecimalBuffer 			; write decimal place
_CNTSDecimal:
		dec 	decimalPlaces 				; done all the decimals
		bmi 	_CNTSExit
		inx 								; x 10.0
		lda 	#10
		jsr 	FloatSetByte
		jsr 	FloatMultiply
		jsr 	MakePlusTwoString 			; put the integer e.g. next digit out.
		jsr 	FloatFractionalPart 		; get the fractional part
		jsr 	FloatNormalise 				; Z set when nothing is left over
		;
		;		Keep going while there is a remainder. The loop is already bounded by
		;		decimalPlaces, and the digits it emits are now correctly rounded, so there is
		;		nothing to protect against by stopping early. The old guard bailed out as soon
		;		as the remainder fell below about 4e-6, which silently ate the significant
		;		digits of any small number: 0.0000001 printed as "0.0".
		;
		bne 	_CNTSDecimal
_CNTSExit:
		jsr 	TrimTrailingZeros
		ply
		plx
		rts

; ************************************************************************************************
;
;		Drop the fraction's trailing zeros, and the decimal point with them if the whole
;		fraction goes. Rounding always fills the fraction out to the full width, so without
;		this 3.14159 prints as "3.1415900", and a whole number that happens to be held as a
;		float prints as "500000000.0000000". Everything downstream reads the buffer as ASCIIZ,
;		so it is enough to move the terminator back.
;
; ************************************************************************************************

TrimTrailingZeros:
		phx
		phy
		ldy 	#0 							; find the decimal point, if there is one
_TTZFind:
		cpy 	dbOffset
		beq 	_TTZExit 					; no point: a whole number, leave it alone
		lda 	decimalBuffer,y
		cmp 	#"."
		beq 	_TTZTrim
		iny
		bra 	_TTZFind
		;
_TTZTrim:
		ldx 	dbOffset 					; walk back from the end over the zeros
_TTZLoop:
		dex
		lda 	decimalBuffer,x
		cmp 	#"0"
		beq 	_TTZLoop
		cmp 	#"." 						; the fraction went entirely: drop the point too
		beq 	_TTZCut
		inx 								; else keep the last significant digit
_TTZCut:
		stx 	dbOffset
		stz 	decimalBuffer,x 			; re-terminate
_TTZExit:
		ply
		plx
		rts

; ************************************************************************************************
;
;		Make S[X] and integer, convert it to a string, and copy it to the decimal buffer
;		
; ************************************************************************************************

MakePlusTwoString:
		phx
		jsr 	FloatShiftUpTwo 			; copy S[X] to S[X+2] - we will use S[X+2] for the intege part.		
		inx 								; access it
		inx
		jsr 	FloatIntegerPart 			; make it an integer
		lda 	#10 						; convert it in base 10
		jsr 	ConvertInt32 
		ldx	 	#0 							; write that to the decimal buffer.
_MPTSCopy:
		lda 	numberBuffer,x
		jsr 	WriteDecimalBuffer
		inx		
		lda 	numberBuffer,x
		bne 	_MPTSCopy
		plx
		rts

; ************************************************************************************************
;
;									Write A to Decimal Buffer
;		
; ************************************************************************************************

WriteDecimalBuffer:
		phx
		ldx 	dbOffset
		sta 	decimalBuffer,x
		stz 	decimalBuffer+1,x
		inc 	dbOffset
		plx
		rts

		.send 	code
		
		.section storage

decimalPlaces:
		.fill 	1
dbOffset:
		.fill 	1				
decimalBuffer:
		.fill 	32
		
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
