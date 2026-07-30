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
		;		BASIC prints in fixed notation only while the value fits nine significant digits
		;		with the point somewhere sensible -- that is, from 0.01 up to 1e9. Outside that it
		;		uses E notation:
		;
		;			 999999999  ->  999999999			2147483647  ->  2.14748365E+09
		;			1000000000  ->  1E+09				4294967295  ->  4.2949673E+09
		;			       .01  ->  .01					     .001  ->  1E-03
		;			                                          1/1024  ->  9.765625E-04
		;
		;		The old test was the exponent alone: nonzero and positive meant 2^31 or more, the
		;		most a 31 bit mantissa could hold as an integer. That was wrong twice over. The
		;		mantissa reaches 2^32 now, so it let 3000000000 print in full, which X16 never
		;		does; and 2^31 was never the real boundary. There was no low end at all.
		;
		;		Note X16 loses the low digits going up -- 4294967295 prints as 4294967300 -- even
		;		though its float holds the value exactly. That is the behaviour to copy.
		;
		jsr 	_CNTSNeedsE 				; CS if |value| is outside [0.01,1e9)
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
		;		Under 0.1 the first decimal place is a leading zero, and a leading zero is not a
		;		significant digit either -- .0100000001 needs TEN places to show its nine. Only
		;		[0.01,1e9) reaches here, so there can be at most one such zero.
		;
		jsr 	_CNTSUnderTenth
		bcc 	_CNTSDPDone
		inc 	decimalPlaces
_CNTSDPDone:
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
;		CS if |S[X]| falls outside [0.01,1e9) and so wants E notation. Works on a copy in S[X+2]
;		so the value itself is untouched, and decides on the mantissa directly -- not by
;		subtraction, so nothing rounds and 999999999 cannot be mistaken for 1e9.
;
;		Normalised, value = mantissa x 2^e with the mantissa in [2^31,2^32), so the value is in
;		[2^(31+e), 2^(32+e)) and each end needs one straddling case looked at properly:
;
;			e >=  -1 : value >= 2^30 = 1073741824		over 1e9
;			e ==  -2 : value in [2^29,2^30)				1e9 is inside: compare the mantissa
;			                                            against 1e9 x 2^2 = $EE6B2800
;			e >= -37 : value >= 2^-6 = 0.015625			comfortably inside the fixed range
;			e == -38 : value in [2^-7,2^-6)				0.01 is inside: compare the mantissa
;			                                            against 0.01 x 2^38 = $A3D70A3D
;			e <= -39 : value < 2^-7 = 0.0078125			under 0.01
;
;		$A3D70A3D is 0.01 x 2^38 ROUNDED (it is 2748779069.44 exactly), which is the same mantissa
;		our own 0.01 literal ends up with -- a hair under a true hundredth, because a hundredth is
;		not a binary fraction. Comparing against the true value instead would send .01 to E
;		notation, where X16 prints ".01": X16 rounds to nine significant digits BEFORE deciding,
;		and 0.00999999999839 rounds to 0.0100000000. Using the rounded constant gets the same
;		answer without having to round first.
;
; ************************************************************************************************

_CNTSNeedsE:
		jsr 	FloatShiftUpTwo 			; copy S[X] to S[X+2] and work on that
		inx
		inx
		jsr 	FloatNormalise
		beq 	_CNTSNEFixed 				; zero prints as "0", not in E notation
		;
		lda 	NSExponent,x
		bpl 	_CNTSNEUse 					; e >= 0 : 2^31 or more
		cmp 	#$FF 						; e == -1 : 2^30 or more
		beq 	_CNTSNEUse
		cmp 	#$FE 						; e == -2 : 1e9 is inside this range
		beq 	_CNTSNEHighEdge
		;
		;		e <= -3, so 1e9 is out of reach. Now the small end.
		;
		cmp 	#$DB 						; e >= -37 : 0.015625 or more, safely fixed
		bcs 	_CNTSNEFixed
		cmp 	#$DA 						; e == -38 : 0.01 is inside this range
		beq 	_CNTSNELowEdge
		bra 	_CNTSNEUse 					; e <= -39 : under 0.0078125
;
_CNTSNEHighEdge:
		lda 	NSMantissa3,x 				; mantissa vs $EE6B2800, top byte first
		cmp 	#$EE
		bne 	_CNTSNECarryUse 			; the cmp's carry is already the answer
		lda 	NSMantissa2,x
		cmp 	#$6B
		bne 	_CNTSNECarryUse
		lda 	NSMantissa1,x
		cmp 	#$28
		bne 	_CNTSNECarryUse 			; equal on all three: mantissa0 can only add, so >= 1e9
_CNTSNEUse:
		sec
		bra 	_CNTSNEExit
_CNTSNECarryUse: 							; at or above 1e9 -> E notation
		bcs 	_CNTSNEUse
_CNTSNEFixed:
		clc
_CNTSNEExit:
		dex 								; back down to the value, carry intact
		dex
		rts
;
_CNTSNELowEdge:
		lda 	NSMantissa3,x 				; mantissa vs $A3D70A3D, all four bytes -- unlike the
		cmp 	#$A3 						; high edge, the low byte of this one is not zero
		bne 	_CNTSNECarryFixed
		lda 	NSMantissa2,x
		cmp 	#$D7
		bne 	_CNTSNECarryFixed
		lda 	NSMantissa1,x
		cmp 	#$0A
		bne 	_CNTSNECarryFixed
		lda 	NSMantissa0,x
		cmp 	#$3D
_CNTSNECarryFixed: 							; at or above 0.01 -> fixed notation
		bcs 	_CNTSNEFixed
		bra 	_CNTSNEUse

; ************************************************************************************************
;
;		CS if |S[X]| < 0.1. Decided exactly, on a normalised copy in S[X+2], the same way
;		_CNTSNeedsE does:
;
;			e >= -34 : value >= 2^-3 = 0.125					not under
;			e == -35 : value in [2^-4,2^-3) -- 0.1 is inside, so compare the mantissa against
;			           0.1 x 2^35 = $CCCCCCCD (3435973836.8 rounded, which is exactly the mantissa
;			           our own 0.1 literal carries, so .1 lands on "not under" as it must)
;			e <= -36 : value < 2^-4 = 0.0625					under
;
; ************************************************************************************************

_CNTSUnderTenth:
		jsr 	FloatShiftUpTwo
		inx
		inx
		jsr 	FloatNormalise
		beq 	_CNTSUTNot 					; zero does not reach here, but do not spin on it
		;
		lda 	NSExponent,x
		bpl 	_CNTSUTNot 					; e >= 0 : far above 0.1
		cmp 	#$DE 						; e >= -34 : 0.125 or more
		bcs 	_CNTSUTNot
		cmp 	#$DD 						; e == -35 : 0.1 is inside this range
		bne 	_CNTSUTUnder 				; e <= -36 : under 0.0625
		;
		lda 	NSMantissa3,x 				; mantissa vs $CCCCCCCD
		cmp 	#$CC
		bne 	_CNTSUTCarry
		lda 	NSMantissa2,x
		cmp 	#$CC
		bne 	_CNTSUTCarry
		lda 	NSMantissa1,x
		cmp 	#$CC
		bne 	_CNTSUTCarry
		lda 	NSMantissa0,x
		cmp 	#$CD
_CNTSUTCarry: 								; at or above 0.1 -> not under
		bcs 	_CNTSUTNot
_CNTSUTUnder:
		sec
		bra 	_CNTSUTExit
_CNTSUTNot:
		clc
_CNTSUTExit:
		dex 								; back down to the value, carry intact
		dex
		rts

; ************************************************************************************************
;
;							Print a value outside [0.01,1e9), as d.dddddddE+nn
;
;		BASIC carries nine significant digits and turns over to E notation once the point can no
;		longer sit sensibly among them, so 999999999 prints in full and 1000000000 prints as
;		1E+09, .01 prints in full and .001 prints as 1E-03. The mantissa can hold rather more
;		than nine digits -- 4294967295 is exact in it -- but X16 prints that as 4.2949673E+09 all
;		the same, and matching X16 is the point.
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
		;		and the value can land outside [1e8,1e9) either way -- but sciDecExp is worked out
		;		from the digit count and the scale together, so it comes out right regardless. Only
		;		how many significant digits get shown depends on the estimate landing well.
		;
		lda 	NSExponent,x 				; E = e + 31 (it was +30 while the mantissa normalised
		clc 								; to bit 30)
		adc 	#31
		;
		;		Accumulate |E| x 77 in 8.8 fixed point and put the sign back afterwards. E is
		;		NEGATIVE for every value below 1, and the countdown below only runs one way -- for
		;		a negative E it would go round 256 times and give nonsense.
		;
		stz 	sciNegExp
		bpl 	_FTSEPositive
		eor 	#$FF 						; A = |E|
		inc 	a
		dec 	sciNegExp 					; $FF: negate k below
_FTSEPositive:
		tay 								; Y counts the loop down
		stz 	sciTemp 					; sciTemp:A is the 8.8 accumulator
		lda 	#0
		cpy 	#0
		beq 	_FTSEDone 					; E == 0, so k = 0; dey/bne would run 256 times
_FTSEstimate:
		clc
		adc 	#77
		bcc 	_FTSENoCarry
		inc 	sciTemp
_FTSENoCarry:
		dey
		bne 	_FTSEstimate
_FTSEDone:
		lda 	sciTemp 					; k, the integer part of the 8.8 accumulator
		bit 	sciNegExp
		bpl 	_FTSEHaveK
		eor 	#$FF 						; a value below 1 has a negative decimal exponent
		inc 	a
_FTSEHaveK:
		;
		;		Scale by 10^-(k-8) to land the value in [1e8,1e9) : a nine digit integer, which is
		;		as much as the mantissa can carry and exactly what BASIC prints. Going UP, for a
		;		small value, is a multiply by as much as 10^17 -- FloatScalePower10 applies it a
		;		tableful at a time, so nothing overflows on the way.
		;
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
		;
		lda 	sciDecExp 					; the sign of the decimal exponent. Values under 0.01
		bmi 	_FTSExpNegative 			; come here too now, and theirs is negative.
		lda 	#"+"
		bra 	_FTSExpSign
_FTSExpNegative:
		lda 	#"-"
_FTSExpSign:
		jsr 	WriteDecimalBuffer
		;
		lda 	sciDecExp 					; then two digits of its magnitude, tens first
		bpl 	_FTSExpMagnitude
		eor 	#$FF
		inc 	a
_FTSExpMagnitude:
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
sciNegExp: 									; $FF when the binary exponent was negative, so the
		.fill 	1 						; decimal one the estimate produces must be negated
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
