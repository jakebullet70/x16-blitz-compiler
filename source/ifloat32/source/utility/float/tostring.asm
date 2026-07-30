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

;
;		A on entry is the number of SIGNIFICANT digits to print, not the number of decimal places
;		-- BASIC always shows nine of them and puts the point wherever the value needs it, so the
;		decimal places are whatever the integer part does not use. Passing a fixed count of decimal
;		places instead is what printed 12345678.9 as "12345678.8984375", exposing the binary noise
;		below the ninth digit, while 1/3 got only ".3333333".
;
FloatToString:
		phx
		phy 								; save code position
		sta 	sigDigits 					; significant digits wanted (BASIC prints 9)
		stz 	dbOffset 					; offset into decimal buffer = start.

		jsr 	FloatIsZero 				; a zero mantissa is zero whatever the exponent and
		bne 	_CNTSNotZero 				; sign say, and needs none of the machinery below
		jmp 	_CNTSZero 					; (out of branch range)
_CNTSNotZero:
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
		;		Values of 1e9 and up go out in E notation, as BASIC does. The old test was the
		;		exponent alone -- nonzero and positive meant 2^31 or more, which was the most the
		;		31 bit mantissa could hold as an integer. Two things are wrong with that now. The
		;		mantissa holds a full 32 bits, so it reaches 2^32 and the old test let 3000000000
		;		print as "3000000000"; and 2^31 was never where BASIC switches anyway. BASIC
		;		carries NINE significant digits, so it turns over at 1e9:
		;
		;			 999999999  ->  999999999			2147483647  ->  2.14748365E+09
		;			1000000000  ->  1E+09				4294967295  ->  4.2949673E+09
		;
		;		Note X16 loses the low digits doing it -- 4294967295 prints as 4294967300 -- even
		;		though its float holds the value exactly. That is the behaviour to copy.
		;
		jsr 	_CNTSIsBig 					; CS if |value| >= 1e9
		bcs 	_CNTSBig
		;
		;		Share the nine digits out: the integer part takes what it needs, the fraction gets
		;		the remainder. 33333333.3 and .333333333 both carry nine, which is the whole point.
		;
		jsr 	_CNTSIntegerDigits 			; A = digits in the integer part, 1 upwards
		eor 	#$FF 						; decimalPlaces = sigDigits - A, without a scratch byte:
		sec 								; ~A is -A-1, so +sigDigits+1 gives sigDigits-A
		adc 	sigDigits
		bcs 	_CNTSHaveDP
		lda 	#0 							; more integer digits than we have to give
_CNTSHaveDP:
		sta 	decimalPlaces
		;
		lda 	NSExponent,x 				; zero: the mantissa IS the value, a plain integer,
		beq 	_CNTSNotFloat 				; and there is nothing below the point to round
		bpl 	_CNTSBig 					; positive: only reachable unnormalised, and that is
											; what it used to do -- leave it alone
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

;
;		Zero, printed as BASIC prints it: the sign column, then a single "0". The path above cannot
;		produce that -- it drops a lone leading zero and then trims the trailing ones, which leaves
;		the buffer empty. That is why a cancellation zero such as 16777216-16777216 printed as
;		nothing at all. It also catches -0, which BASIC shows as 0.
;
_CNTSZero:
		lda 	#" "
		jsr 	WriteDecimalBuffer
		lda 	#"0"
		jsr 	WriteDecimalBuffer
		ply
		plx
		rts

;
;		Count the SIGNIFICANT digits in the integer part of S[X], in A. Works on a copy in S[X+2],
;		as MakePlusTwoString does, so the value itself is untouched -- this runs before the value is
;		rounded, and rounding needs the count.
;
;		A value below 1 has an integer part of "0", and that zero is not a significant digit: it is
;		not even printed (BASIC writes .5, not 0.5). So it counts as none, and the whole nine go to
;		the fraction -- which is what makes 1/3 print as .333333333 rather than .33333333.
;
_CNTSIntegerDigits:
		phx
		jsr 	FloatShiftUpTwo
		inx
		inx
		jsr 	FloatIntegerPart
		lda 	#10
		jsr 	ConvertInt32 				; returns the buffer address in XA, so X is gone
		ldy 	#0 							; counting does not need it back yet
_CNTSIDCount:
		lda 	numberBuffer,y
		beq 	_CNTSIDDone
		iny
		bra 	_CNTSIDCount
_CNTSIDDone:
		cpy 	#1 							; a lone "0" is a placeholder, not a digit
		bne 	_CNTSIDExit
		lda 	numberBuffer
		cmp 	#"0"
		bne 	_CNTSIDExit
		ldy 	#0
_CNTSIDExit:
		plx
		tya
		rts

; ************************************************************************************************
;
;		CS if |S[X]| >= 1e9, the point at which BASIC gives up on fixed notation. Works on a copy
;		in S[X+2] so the value itself is untouched, and it is EXACT -- not a compare by
;		subtraction, so nothing rounds and 999999999 cannot be mistaken for 1e9.
;
;		Normalised, value = mantissa x 2^e with the mantissa in [2^31,2^32), so:
;
;			e >= -1 : value >= 2^30 = 1073741824, always over 1e9
;			e == -2 : value in [2^29,2^30) -- this alone straddles 1e9, so compare the mantissa
;			          against 1e9 x 2^2 = 4000000000 = $EE6B2800
;			e <= -3 : value < 2^29 = 536870912, never over 1e9
;
; ************************************************************************************************

_CNTSIsBig:
		jsr 	FloatShiftUpTwo 			; copy S[X] to S[X+2] and work on that
		inx
		inx
		jsr 	FloatNormalise
		beq 	_CNTSIBSmall 				; zero is not big
		;
		lda 	NSExponent,x
		bpl 	_CNTSIBBig 					; e >= 0 : 2^31 or more
		cmp 	#$FF 						; e == -1 : 2^30 or more
		beq 	_CNTSIBBig
		cmp 	#$FE 						; e <= -3 : under 2^29, cannot reach 1e9
		bne 	_CNTSIBSmall
		;
		lda 	NSMantissa3,x 				; e == -2 : mantissa vs $EE6B2800, top byte first
		cmp 	#$EE
		bne 	_CNTSIBCarry 				; the cmp's carry is already the answer
		lda 	NSMantissa2,x
		cmp 	#$6B
		bne 	_CNTSIBCarry
		lda 	NSMantissa1,x
		cmp 	#$28
		bne 	_CNTSIBCarry 				; equal on all three: mantissa0 can only add, so >= 1e9
_CNTSIBBig:
		sec
		bra 	_CNTSIBExit
_CNTSIBCarry:
		bcs 	_CNTSIBBig
_CNTSIBSmall:
		clc
_CNTSIBExit:
		dex 								; back down to the value, carry intact
		dex
		rts

; ************************************************************************************************
;
;								Print a value of 1e9 or more, as d.dddddddE+nn
;
;		BASIC carries nine significant digits and turns over to E notation once the integer part
;		would need a tenth, so 999999999 prints in full and 1000000000 prints as 1E+09. The
;		mantissa can hold rather more than that -- 4294967295 is exact in it -- but X16 prints it
;		as 4.2949673E+09 all the same, and matching X16 is the point.
;
;		Entered by jmp from FloatToString, with the sign already written to the buffer, the value
;		made positive, and X and Y saved on the 6502 stack. Leaves through its own ply/plx.
;
; ************************************************************************************************

FloatToStringScientific:
		jsr 	FloatNormalise 				; mantissa is now in [2^31,2^32), so the value is in
											; [2^(31+e), 2^(32+e)) -- call that exponent E.
		;
		;		Estimate the decimal exponent from the binary one: log10(v) is about E x log10(2),
		;		and 77/256 is log10(2) to within a quarter of a percent. It is only an estimate,
		;		and it can read one low, but it can never read high -- which is what makes the
		;		correction below safe.
		;
		lda 	NSExponent,x 				; E = e + 31 (it was +30 while the mantissa normalised
		clc 							 	; to bit 30). We only come here for values of 1e9 and
		adc 	#31 						; up, so E >= 29 and the countdown below is safe.
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
		lda 	sciTemp 					; k >= 8, because E >= 29, so the scale is never
		sec 								; negative and FloatScalePower10 handles the 0
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
		cpy 	#9 							; nine significant digits, as BASIC prints. The mantissa
		beq 	_FTSDigitsDone 				; holds about 9.6, so a tenth would be near enough
											; noise -- and X16 does not print it either.
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

sigDigits: 									; significant digits the caller asked for; the decimal
		.fill 	1 						; places below are derived from it and the integer width
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
