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

		.send	code

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
