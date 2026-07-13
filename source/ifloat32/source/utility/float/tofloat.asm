; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		tofloat.asm
;		Purpose:	State machine number encoding
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

ESTA_Low = 1 								; state 1 is 1 byte, switches when A >= 24.
ESTA_High = 2 								; loading up to 32 bit integer in the mantissa
ESTA_Decimal = 3 							; fractional part.
ESTA_ExpSign = 4 							; just seen the E, a sign may follow.
ESTA_Exp = 5 								; accumulating the exponent digits.

;
;		The exponent's sign arrives as a TOKEN, not as ASCII. This machine is driven straight
;		from the tokenised BASIC text (compiler: ParseConstant), and the tokeniser has already
;		folded "+" and "-" into the PLUS and MINUS tokens -- so 1.5E-2 reaches us as
;		'1' '.' '5' 'E' $AB '2'. Digits and the E itself stay ASCII, which is why testing for
;		ASCII "-" here silently did the wrong thing: the sign went unrecognised, the number
;		stopped at 1.5, and the expression parser then read the $AB as a subtraction --
;		1.5E-2 evaluated to -0.5.
;
;		ifloat32 does not include the BASIC token table (it is a standalone float library), so
;		these mirror C64_PLUS / C64_MINUS in common-source/source/generated/c64tokens.inc.
;
ESTA_TokenPlus = $AA 						; = C64_PLUS
ESTA_TokenMinus = $AB 						; = C64_MINUS

; ************************************************************************************************
;
;		Encode Number. If CS, then start a new number. Returns CS if the number is okay,
;		CC if not.
;
;		A simple state machine.
;
;		State 1 is taking in integers up to 255 - this is very quick.
; 		State 2 is taking in integers up to 4 bytes
; 		State 3 is taking in numbers after the decimal place.
;
;		Do we need a state between 1 & 2 ?
;
; ************************************************************************************************

FloatEncodeStart: 							; come here to reset the FSM.
		sec
		bra 	FloatEncodeContinue+1

FloatEncodeContinue: 						; come here to continue it.
		clc
FloatEncode:
		php 								; save reset flag.
		cmp 	#"." 						; 0-9 and "." are always part of a number
		beq 	_ENIsOkay
		cmp 	#"0"
		bcc 	_ENMaybeExponent
		cmp 	#"9"+1
		bcc 	_ENIsOkay
		;
		;		Whether E, + or - belongs to the number depends on where we are. "E" opens an
		;		exponent; "+" and "-" are part of the number ONLY directly after that "E", and
		;		are the next operator anywhere else. None of them can START one.
		;
_ENMaybeExponent:
		plp 								; peek at the reset flag, then put it straight back.
		php 								; (neither plp nor php touches A)
		bcs 	_ENBadNumber 				; restarting: a number never begins with E, + or -.
		;
		cmp 	#"E"
		beq 	_ENExponentIntroducer
		cmp 	#ESTA_TokenPlus
		beq 	_ENExponentSign
		cmp 	#ESTA_TokenMinus
		beq 	_ENExponentSign
		bra 	_ENBadNumber
;
_ENExponentIntroducer: 						; "E" -- but not a second one.
		pha
		lda 	encodeState
		cmp 	#ESTA_ExpSign
		beq 	_ENExponentReject
		cmp 	#ESTA_Exp
		beq 	_ENExponentReject
		pla
		bra 	_ENIsOkay
;
_ENExponentSign: 							; "+"/"-" -- only immediately after the E.
		pha
		lda 	encodeState
		cmp 	#ESTA_ExpSign
		bne 	_ENExponentReject
		pla
		bra 	_ENIsOkay
;
_ENExponentReject:
		pla 								; not part of the number after all.
;
_ENBadNumber:
		plp 								; throw saved reset
		lda 	encodeState 				; a number that ended in a fraction or an exponent
		cmp 	#ESTA_Decimal 				; still has to be assembled from its pieces.
		beq 	_ENDoConstruct
		cmp 	#ESTA_Exp
		beq 	_ENDoConstruct
		cmp 	#ESTA_ExpSign 				; "1E" with no digits: the exponent is simply 0.
		beq 	_ENDoConstruct
_ENFail:
		clc 								; not allowed
		rts
_ENDoConstruct:
		jmp 	ENConstructFinal
;
_ENIsOkay:
		plp 								; are we restarting
		bcc 	_ENNoRestart

		; --------------------------------------------------------------------
		;
		;		First initialise
		;
		; --------------------------------------------------------------------

_ENStartEncode:
		;
		;		These persist across numbers, and an integer with an exponent (5E3) reaches
		;		_ENConstructFinal without ever passing through the decimal states -- so a stale
		;		decimalCount from an earlier literal would silently scale it. Reset them here.
		;
		stz 	decimalCount
		stz 	expValue
		stz 	expNegative
		;
		cmp 	#'.'						; first is decimal place, go straight to that.
		beq 	_ENFirstDP
		and 	#15 						; put digit in mantissa, initially a single digit constant
		jsr 	FloatSetByte 				; in single byte mode.
		lda 	#ESTA_Low
		;
		;		Come here to successfully change state.
		;
_ENExitChange:
		sta 	encodeState 				; save new state		
		sec
		rts

_ENFirstDP:
		jsr 	FloatSetZero 				; clear integer part
		bra 	_ESTASwitchFloat			; go straight to float and exi

		; --------------------------------------------------------------------
		;
		;		Not restarting. Figure out what to do next
		;
		; --------------------------------------------------------------------
_ENNoRestart:
		pha 								; save digit or DP on stack.
		lda 	encodeState 				; get current state
		cmp 	#ESTA_Low
		beq  	_ESTALowState
		cmp 	#ESTA_High
		beq 	_ESTAHighState
		cmp 	#ESTA_Decimal
		beq 	_ESTADecimalState
		cmp 	#ESTA_ExpSign
		beq 	_ESTAExpSignState
		cmp 	#ESTA_Exp
		beq 	_ESTAExpState
		.debug 								; should not happen !

		; --------------------------------------------------------------------
		;
		;		Inputting to a single byte.
		;
		; --------------------------------------------------------------------

_ESTALowState:
		pla 								; get value back
		cmp 	#"."						; decimal point
		beq 	_ESTASwitchFloat 			; then we need to do the floating point bit
		cmp 	#"E" 						; exponent, e.g. 5E3
		beq 	_ESTASwitchExponent
		and 	#15 						; make digit
		sta 	digitTemp 					; save it.
		;
		lda 	NSMantissa0,x 				; x mantissa0 x 10 and add it
		asl 	a
		asl 	a
		adc 	NSMantissa0,x
		asl 	a
		adc 	digitTemp
		sta 	NSMantissa0,x
		cmp 	#25 						; if >= 25 cannot guarantee next will be okay
		bcc 	_ESTANoSwitch 				; as could be 25 x 10 + 9
		lda 	#ESTA_High 					; so if so, switch to the high encoding state
		sta 	encodeState
_ESTANoSwitch:
		sec
		rts		

		; --------------------------------------------------------------------
		;
		;		Inputting to a the whole 4 byte mantissa
		;
		; --------------------------------------------------------------------

_ESTAHighState:
		pla 								; get value back
		cmp 	#"." 						; if DP switch to dloat
		beq 	_ESTASwitchFloat
		cmp 	#"E" 						; exponent, e.g. 1234E3
		beq 	_ESTASwitchExponent
		jsr 	ESTAShiftDigitIntoMantissa 	; a routine does this.
		sec
		rts

		; --------------------------------------------------------------------
		;
		;		Entering decimal mode - still have then input digit on the stack
		;
		; --------------------------------------------------------------------

_ESTASwitchFloat:
		stz 	decimalCount 				; reset the count of digits - we divide by 10^n at the end.
		inx 								; zero the decimal additive.
		jsr 	FloatSetZero
		dex
		lda 	#ESTA_Decimal 				; switch to decimal mode
		jmp 	_ENExitChange

		; --------------------------------------------------------------------
		;
		;		Decimal Mode
		;
		; --------------------------------------------------------------------

_ESTADecimalState:
		pla 								; digit.
		cmp 	#"." 						; a second decimal point ends the number.
		bne 	_ESTADNotPoint 				; (out of branch range for beq _ENFail)
		jmp 	_ENFail
_ESTADNotPoint:
		cmp 	#"E" 						; exponent, e.g. 9.2E5
		beq 	_ESTASwitchExponent
		;
		inx 								; put digit into fractional part of X+1
		jsr 	ESTAShiftDigitIntoMantissa
		dex
		;
		inc 	decimalCount 				; bump the count of decimals
		;
		lda 	decimalCount 				; too many decimal digits.
		cmp 	#11
		beq 	_ESTADSFail
		sec
		rts
_ESTADSFail:
		clc
		rts

		; --------------------------------------------------------------------
		;
		;		Exponent : "E" seen, so a sign may come next, then the digits.
		;
		; --------------------------------------------------------------------

_ESTASwitchExponent:
		lda 	#ESTA_ExpSign
		jmp 	_ENExitChange

_ESTAExpSignState:
		pla 								; sign or first exponent digit
		cmp 	#ESTA_TokenMinus
		beq 	_ESTAExpNegative
		cmp 	#ESTA_TokenPlus
		beq 	_ESTAExpDigitsNext 			; a leading + changes nothing
		jsr 	ESTAAddExponentDigit
		bra 	_ESTAExpDigitsNext
_ESTAExpNegative:
		lda 	#$FF
		sta 	expNegative
_ESTAExpDigitsNext: 						; from here on, only digits belong to the exponent,
		lda 	#ESTA_Exp 					; so a second sign correctly ends the number.
		jmp 	_ENExitChange

_ESTAExpState:
		pla 								; exponent digit
		jsr 	ESTAAddExponentDigit
		sec
		rts

; ************************************************************************************************
;
;			exponent = exponent x 10 + digit, clamped to 0..99.
;
;			The clamp is not cosmetic: the exponent is used as a SIGNED byte, so letting it run
;			past 127 would wrap a huge positive exponent into a negative one. iFloat32 tops out
;			around 1e38 anyway, so any exponent this saturates at is already out of range and
;			will overflow during scaling -- which is the right answer, rather than a wrong small one.
;
; ************************************************************************************************

ESTAAddExponentDigit:
		and 	#15
		sta 	scaleTemp
		lda 	expValue
		cmp 	#10 						; a third digit would exceed 99, so saturate.
		bcs 	_EAEDClamp
		asl 	a 							; x2
		asl 	a 							; x4 (and clears carry, as expValue < 10)
		adc 	expValue 					; x5
		asl 	a 							; x10
		clc
		adc 	scaleTemp 					; + digit
		sta 	expValue
		rts
_EAEDClamp:
		lda 	#99
		sta 	expValue
		rts

		; --------------------------------------------------------------------
		;
		;		Build final number from components
		;
		; --------------------------------------------------------------------

;
;		S[0] holds the integer digits and S[1] the fraction digits (as a plain integer), with
;		decimalCount of them; expValue/expNegative are the E exponent. Build:
;
;			value  =  S[0] x 10^e   +   S[1] x 10^(e-dc)
;
;		and NOT the obvious ( S[0] + S[1] x 10^-dc ) x 10^e. That forms the fraction first, and
;		9.2 is not exactly representable, so 9.2E5 would land on 919999.9 instead of 920000.
;		Scaling the two runs of digits independently keeps it as 9x10^5 + 2x10^4, which is exact.
;
ENConstructFinal:
		phy
		lda 	decimalCount
		beq 	_ENCFNoFraction
		;
		;		S[1] is also the scratch slot FloatScalePower10 needs in order to scale S[0],
		;		so lift the fraction digits clear of it first.
		;
		inx 								; X = 1
		jsr 	FloatShiftUpTwo 			; S[3] = S[1]
		dex 								; X = 0
		;
		jsr 	ENGetExponent 				; S[0] = integer digits x 10^e   (scratch S[1])
		jsr 	FloatScalePower10
		;
		jsr 	ENGetExponent 				; S[3] = fraction digits x 10^(e-dc)  (scratch S[4])
		sec
		sbc 	decimalCount
		inx
		inx
		inx 								; X = 3
		jsr 	FloatScalePower10
		dex
		dex
		dex 								; X = 0
		;
		lda 	NSMantissa0+3,x 			; bring the scaled fraction back down to S[1], so that
		sta 	NSMantissa0+1,x 			; it sits alongside S[0] for the add.
		lda 	NSMantissa1+3,x
		sta 	NSMantissa1+1,x
		lda 	NSMantissa2+3,x
		sta 	NSMantissa2+1,x
		lda 	NSMantissa3+3,x
		sta 	NSMantissa3+1,x
		lda 	NSExponent+3,x
		sta 	NSExponent+1,x
		lda 	NSStatus+3,x
		sta 	NSStatus+1,x
		;
		inx 								; FloatAdd does its own dex
		jsr 	FloatAdd 					; S[0] = S[0] + S[1]
		bra 	_ENCFExit
		;
_ENCFNoFraction: 							; a whole-number mantissa: only the exponent to apply.
		jsr 	ENGetExponent
		jsr 	FloatScalePower10
_ENCFExit:
		ply
		clc 								; reject the character that ended the number.
		rts

; ************************************************************************************************
;
;								The E exponent, as a signed byte in A
;
; ************************************************************************************************

ENGetExponent:
		lda 	expNegative
		bne 	_ENGENegate
		lda 	expValue
		rts
_ENGENegate:
		sec
		lda 	#0
		sbc 	expValue
		rts

; ************************************************************************************************
;
;		Scale S[X] by 10^A, where A is a SIGNED byte. X is preserved. S[X+1] is used as scratch,
;		so the caller must have a free slot directly above X.
;
;		Negative powers that the table covers are a single multiply by the tabulated 10^-n --
;		exactly what the plain decimal path has always done, so a literal with no exponent is
;		scaled bit for bit as before and cannot regress. Everything else is built by repeated
;		x10 or /10: that costs nothing at compile time, and the positive case is EXACT while the
;		mantissa stays whole, which is what lets 9.2E5 come out as precisely 920000.
;
; ************************************************************************************************

FloatScalePower10:
		cmp 	#0
		beq 	_FSPDone 					; 10^0, nothing to do
		bmi 	_FSPNegative
;
_FSPMultiplyLoop: 							; positive: multiply by 10, A times.
		pha
		inx
		lda 	#10
		jsr 	FloatSetByte 				; S[X+1] = 10
		jsr 	FloatMultiply 				; does its own dex: S[X] = S[X] x 10, X restored
		pla
		dec 	a
		bne 	_FSPMultiplyLoop
_FSPDone:
		rts
;
_FSPNegative:
		eor 	#$FF 						; A = |A|
		inc 	a
		cmp 	#FloatScalarTableSize+1
		bcs 	_FSPDivideLoop 				; deeper than the table reaches: divide instead.
		;
		phy
		sta 	scaleTemp 					; index it: five byte entries, 10^-1 first
		asl 	a
		asl 	a 							; x4 (clears carry: n <= table size)
		adc 	scaleTemp 					; x5
		tay
		;
		lda 	FloatScalarTable-5,y 		; copy 10^-n into S[X+1]
		sta 	NSMantissa0+1,x
		lda 	FloatScalarTable-5+1,y
		sta 	NSMantissa1+1,x
		lda 	FloatScalarTable-5+2,y
		sta 	NSMantissa2+1,x
		lda 	FloatScalarTable-5+3,y
		sta 	NSMantissa3+1,x
		lda 	FloatScalarTable-5+4,y
		sta 	NSExponent+1,x
		stz 	NSStatus+1,x 				; the constant is positive
		ply
		;
		inx 								; FloatMultiply does its own dex
		jsr 	FloatMultiply 				; S[X] = S[X] x 10^-n, X restored
		rts
;
_FSPDivideLoop: 							; past the table: divide by 10, A times.
		pha
		inx
		lda 	#10
		jsr 	FloatSetByte
		jsr 	FloatDivide 				; does its own dex: S[X] = S[X] / 10, X restored
		pla
		dec 	a
		bne 	_FSPDivideLoop
		rts

; ************************************************************************************************
;
;			Put digit A into the mantissa at X, e.g. mantissa = mantissa x 10 + digit
;
; ************************************************************************************************

ESTAShiftDigitIntoMantissa:
		and 	#15 						; save digit
		pha

		lda 	NSMantissa3,x 				; push mantissa on stack
		pha
		lda 	NSMantissa2,x 
		pha
		lda 	NSMantissa1,x 
		pha
		lda 	NSMantissa0,x 
		pha
		jsr 	FloatShiftLeft 				; x 2
		jsr 	FloatShiftLeft 				; x 4

		clc 								; pop mantissa and add
		pla 
		adc 	NSMantissa0,x
		sta 	NSMantissa0,x
		pla
		adc 	NSMantissa1,x
		sta 	NSMantissa1,x
		pla
		adc 	NSMantissa2,x
		sta 	NSMantissa2,x
		pla
		adc 	NSMantissa3,x
		sta 	NSMantissa3,x 				; x 5
		jsr 	FloatShiftLeft 				; x 10
		;
		pla 								; add digit
		clc
		adc 	NSMantissa0,x
		sta 	NSMantissa0,x
		bcc 	_ESTASDExit
		inc 	NSMantissa1,x
		bne 	_ESTASDExit
		inc 	NSMantissa2,x
		bne 	_ESTASDExit
		inc 	NSMantissa3,x
_ESTASDExit:
		rts

		.send code

		.section storage
encodeState:	 							; which state is it in ?
		.fill 	1
digitTemp:	 								; temp for current digit
		.fill 	1
decimalCount:								; how many decimal places to date
		.fill 	1
expValue: 									; magnitude of the E exponent, 0..99
		.fill 	1
expNegative: 								; $FF if that exponent was negative
		.fill 	1
scaleTemp: 									; scratch for the x10 and table-index arithmetic
		.fill 	1
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
