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
		;
		;		The exponent says which of the three shapes this is. Zero means the mantissa IS
		;		the value, a plain integer. Negative means there is something below the point.
		;		Positive means the value needs more than the mantissa's 31 bits -- it is 2^31 or
		;		more -- and there is no way to write it as a plain integer at all, so it goes out
		;		in E notation, exactly as BASIC does.
		;
		lda 	NSExponent,x
		beq 	_CNTSNotFloat
		bpl 	_CNTSBig
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
		bra 	_CNTSNotFloat
;
_CNTSBig:
		jmp 	FloatToStringScientific 	; leaves through the same ply/plx
;
_CNTSNotFloat:

		jsr 	MakePlusTwoString 			; do the integer part.
		jsr 	FloatFractionalPart 		; get the fractional part
		jsr 	FloatNormalise					; normalise , exit if zero
		beq 	_CNTSExit
		;
		;		Stock BASIC drops the leading zero of a pure fraction: .5, not 0.5 (and -.5,
		;		not -0.5). MakePlusTwoString has just written the integer part; if it is a lone
		;		"0" -- the character before it is the sign/space, not another digit -- back the
		;		buffer up over it so the point lands where the zero was.
		;
		ldy 	dbOffset
		dey 								; Y -> last integer digit
		lda 	decimalBuffer,y
		cmp 	#"0"
		bne 	_CNTSPoint 					; not a zero, so nothing to drop
		dey
		bmi 	_CNTSDropZero 				; nothing before it at all (no sign) : lone zero
		lda 	decimalBuffer,y 			; the character before the zero
		cmp 	#"0"
		bcs 	_CNTSPoint 					; a digit : the 0 belongs to a bigger integer, keep it
_CNTSDropZero:
		dec 	dbOffset 					; sign/space before it : the 0 was the whole integer part
_CNTSPoint:
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
;								Print a value of 2^31 or more, as d.dddddddE+nn
;
;		The mantissa carries 31 bits, so it simply cannot hold a number this big as an integer
;		and there is nothing sensible to print in full: 4294967295 is not representable, and
;		writing it out as "4294967294" would only claim a precision that is not there. BASIC
;		prints these in E notation and so do we.
;
;		Entered by jmp from FloatToString, with the sign already written to the buffer, the value
;		made positive, and X and Y saved on the 6502 stack. Leaves through its own ply/plx.
;
; ************************************************************************************************

FloatToStringScientific:
		jsr 	FloatNormalise 				; mantissa is now in [2^30,2^31), so the value is in
											; [2^(30+e), 2^(31+e)) -- call that exponent E.
		;
		;		Estimate the decimal exponent from the binary one: log10(v) is about E x log10(2),
		;		and 77/256 is log10(2) to within a quarter of a percent. It is only an estimate,
		;		and it can read one low, but it can never read high -- which is what makes the
		;		correction below safe.
		;
		lda 	NSExponent,x 				; E = e + 30, and e >= 1 here so E >= 31
		clc
		adc 	#30
		tay 								; Y counts the loop down
		stz 	sciTemp 					; sciTemp:A is 8.8 fixed point
		lda 	#0
_FTSEstimate:
		clc
		adc 	#77
		bcc 	_FTSENoCarry
		inc 	sciTemp
_FTSENoCarry:
		dey
		bne 	_FTSEstimate
		;
		;		Scale by 10^-(k-8) to land the value in [1e8,1e9) : a nine digit integer, which is
		;		as much as the mantissa can carry and exactly what BASIC prints.
		;
		lda 	sciTemp 					; k >= 9, because E >= 31, so the scale is at least 1
		sec
		sbc 	#8
		sta 	sciScale
		eor 	#$FF 						; A = -scale
		inc 	a
		jsr 	FloatScalePower10
		;
		;		If the estimate read low the value is still 2^31 or over, and will not convert.
		;		Divide it down until it fits. At most a trip or two.
		;
_FTSFit:
		lda 	NSExponent,x
		beq 	_FTSFits 					; exponent 0 : an integer, and so below 2^31
		bmi 	_FTSFits 					; exponent < 0 : smaller still
		inx 								; S[X+1] = 10
		lda 	#10
		jsr 	FloatSetByte
		jsr 	FloatDivide 				; does its own dex
		inc 	sciScale
		bra 	_FTSFit
;
_FTSFits:
		inx 								; S[X+1] = 0.5, so the conversion rounds to the nearest
		lda 	#1 							; digit rather than truncating. A mantissa of 1 with an
		jsr 	FloatSetByte 				; exponent of -1 IS a half.
		lda 	#$FF
		sta 	NSExponent,x
		jsr 	FloatAdd 					; does its own dex
		jsr 	FloatIntegerPart 			; and now the digits are an exact integer
		;
		phx 								; ConvertInt32 returns the buffer address in XA, so it
		lda 	#10 						; does not leave X alone.
		jsr 	ConvertInt32
		plx
		;
		ldy 	#0 							; count the digits it produced
_FTSCount:
		lda 	numberBuffer,y
		beq 	_FTSCounted
		iny
		bra 	_FTSCount
_FTSCounted:
		sty 	sciDigits
		;
		tya 								; the value is 0.d1..dn x 10^(scale+n), so the exponent
		clc 								; printed against a leading d1. is scale + n - 1
		adc 	sciScale
		dec 	a
		sta 	sciDecExp
		;
		lda 	numberBuffer 				; d1 "." d2 d3 ...
		jsr 	WriteDecimalBuffer
		lda 	#"."
		jsr 	WriteDecimalBuffer
		ldy 	#1
_FTSDigits:
		cpy 	sciDigits
		beq 	_FTSDigitsDone
		cpy 	#9 							; nine significant digits. The mantissa holds about
		beq 	_FTSDigitsDone 				; 9.3, so a tenth would only be printing noise.
		lda 	numberBuffer,y
		jsr 	WriteDecimalBuffer
		iny
		bra 	_FTSDigits
_FTSDigitsDone:
		jsr 	TrimTrailingZeros 			; takes the point with them when the whole fraction
											; goes, so 3e9 prints as 3E+09 and not 3.E+09
		lda 	#"E"
		jsr 	WriteDecimalBuffer
		lda 	#"+" 						; we only come here for values of 2^31 and up, so the
		jsr 	WriteDecimalBuffer 			; decimal exponent is always positive, and at least 9
		;
		lda 	sciDecExp 					; two digits, tens first
		ldy 	#"0"-1
_FTSTens:
		iny
		sec
		sbc 	#10
		bcs 	_FTSTens
		adc 	#10 						; A = units, Y = tens as ASCII
		pha
		tya
		jsr 	WriteDecimalBuffer
		pla
		clc
		adc 	#"0"
		jsr 	WriteDecimalBuffer
		;
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
sciTemp: 									; E notation: the log10(2) estimate accumulates here
		.fill 	1
sciScale: 									; power of ten the value was scaled down by
		.fill 	1
sciDigits: 									; how many digits the conversion produced
		.fill 	1
sciDecExp: 									; the decimal exponent finally printed
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
