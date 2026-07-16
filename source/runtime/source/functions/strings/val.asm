; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		val.asm
;		Purpose:	String to Integer/Float#
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section	code

; ************************************************************************************************
;
; 											Val(String)
;
; ************************************************************************************************

ValUnary: ;; [val]
		.entercmd 							; restore stack pos
		lda 	NSMantissa0,x
		sta 	zTemp0
		lda 	NSMantissa1,x
		sta 	zTemp0+1
		jsr 	ValEvaluateZTemp0 			; always succeeds now (see below)
		.exitcmd

; ************************************************************************************************
;
;								Evaluate value at zTemp0 into X.
;
;		Interpreted BASIC's VAL never errors: it returns the value of the LEADING numeric part of
;		the string, or 0 when there is none -- VAL("")=0, VAL("AB")=0, VAL("12AB")=12, VAL(" -3")
;		=-3. This used to raise BAD VALUE on an empty string and on the first non-numeric
;		character (which broke, e.g., JUSTACLOCK's VAL(YO$) when YO$ was empty). Now it seeds the
;		result to 0, stops at the first character that is not part of a number, and returns what
;		it has built.
;
; ************************************************************************************************

ValEvaluateZTemp0:
		phy
		jsr 	FloatSetZero 				; default result 0 -- covers "" and non-numeric input
		lda 	#ESTA_Low 					; a first-character rejection must take FloatEncode's
		sta 	encodeState 				; integer path (_ENFail), never ENConstructFinal with a
		;									; stale decimal/exponent state left by an earlier VAL.
		lda 	(zTemp0) 					; length: empty string is just 0
		beq 	_VMCReturn
		ldy 	#0 							; start position
_VMCSpaces:
		iny 								; skip leading spaces
		lda 	(zTemp0),y
		cmp 	#" "
		beq 	_VMCSpaces
		pha 								; save first character (for the sign test)
		cmp 	#"-"		 				; is it - ?
		bne 	_VMCStart
		iny 								; skip over - if so.
		;
		;		Evaluation loop
		;
_VMCStart:
		lda 	(zTemp0),y 					; first character of the number proper.
		cmp 	#"$" 						; $hhhh hexadecimal constant ?
		beq 	_VMCHex
		cmp 	#"%" 						; %bbbb binary constant ?
		beq 	_VMCBinary
		sec 								; initialise first time round.
_VMCNext:
		tya 								; reached end of string
		dec 	a
		eor 	(zTemp0) 					; compare length preserve carry.
		beq 	_VMCFinalise 				; yes -- finalise the number built so far.

		lda 	(zTemp0),y 					; encode a number.
		iny
		jsr 	FloatEncode 				; send it to the number-builder
		bcc 	_VMCStopped 				; not part of a number: stop, it is already finalised.
		clc 								; next time round, continue
		bra 	_VMCNext

_VMCFinalise:
		lda 	#0 							; end of string: feed a duff value to finalise the last
		jsr 	FloatEncode 				; digit (a no-op for an integer, constructs a fraction/exp).
_VMCStopped:
		pla 								; if it was -ve
		cmp 	#"-"
		bne 	_VMCReturn
		jsr		FloatNegate 				; negate it.
_VMCReturn:
		ply
		clc 								; VAL always succeeds
		rts

; ************************************************************************************************
;
;		$hhhh hexadecimal / %bbbb binary. Y points at the '$' or '%'. Interpreted X16 BASIC
;		accepts these bases wherever it reads a number, including READ of a DATA item -- but VAL
;		here only knew decimal (FloatEncode), so READ of a hex DATA value (e.g. TILEDEMO's palette
;		table, DATA $44,$04,...) silently returned 0 and the tiles went black instead of grey.
;
;		The result slot S[X] is already zero (FloatSetZero above) and an integer (exponent 0), so
;		just accumulate the digits into its mantissa: shift left 4 (hex) or 1 (binary) and OR each
;		digit in, mirroring the compiler's InlineNonDecimal. Stop at the first character that is not
;		a valid digit for the base, exactly as the decimal path stops at the first non-digit. The
;		leading-sign handling above still applies: '-' was saved on the stack for _VMCStopped.
;
; ************************************************************************************************

_VMCHex:
		lda 	#16 						; hex: digit value must be < 16
		bra 	_VMCBase
_VMCBinary:
		lda 	#2 							; binary: digit value must be < 2
_VMCBase:
		sta 	valBase
		iny 								; consume the '$' or '%'
_VMCBaseLoop:
		tya 								; reached end of string ?
		dec 	a
		eor 	(zTemp0)
		beq 	_VMCStopped 				; yes -- number complete, apply any sign and return.
		lda 	(zTemp0),y 					; next character
		jsr 	_VMCHexDigit 				; -> 0..15, CS if a valid hex digit
		bcc 	_VMCStopped 				; not a digit at all: stop here.
		cmp 	valBase 					; in range for this base ? (e.g. '2' under %binary is not)
		bcs 	_VMCStopped 				; no: stop here.
		iny 								; consume the digit.
		pha 								; save digit while shifting.
		jsr 	FloatShiftLeft 				; mantissa x 2
		lda 	valBase 					; binary shifts once; hex needs three more (x16 total).
		cmp 	#2
		beq 	_VMCBaseOr
		jsr 	FloatShiftLeft 				; x4
		jsr 	FloatShiftLeft 				; x8
		jsr 	FloatShiftLeft 				; x16
_VMCBaseOr:
		pla 								; OR the digit into the low byte.
		ora 	NSMantissa0,x
		sta 	NSMantissa0,x
		bra 	_VMCBaseLoop

;
;		Char in A -> value 0..15 in A with CS, or CC if it is not a hex digit. A only; X/Y kept.
;
_VMCHexDigit:
		cmp 	#"0"
		bcc 	_VMCHDBad
		cmp 	#"9"+1
		bcc 	_VMCHDDigit 				; '0'-'9'
		and 	#$DF 						; fold 'a'-'f' down to 'A'-'F'
		cmp 	#"A"
		bcc 	_VMCHDBad
		cmp 	#"F"+1
		bcs 	_VMCHDBad
		sec
		sbc 	#"A"-10 					; 'A' -> 10 .. 'F' -> 15
		rts 								; (carry left set: A-F are all >= "A"-10)
_VMCHDDigit:
		and 	#$0F
		sec
		rts
_VMCHDBad:
		clc
		rts

		.send	code

		.section storage
valBase: 									; radix limit for a $/% constant (16 or 2)
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
