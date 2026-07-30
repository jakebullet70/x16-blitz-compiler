; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		for.asm
;		Purpose:	FOR compile
;		Created:	20th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;										Compile FOR command
;
;				Creates [Initial] Index! [Reference|Type] [Terminal] [Step] FOR
;
; ************************************************************************************************

CommandFOR: 
		;
		;		FOR [variable]
		;
		jsr 	GetNextNonSpace 			; first letter of index variable, should be.
		jsr 	CharIsAlpha 				; if not alpha , error
		bcc 	_CFFail
		jsr 	GetReferenceTerm 			; figure out the reference.
		;
		;		The index must be a plain float variable. Masking NSSTypeMask ($40) alone
		;		tested only float-vs-string, so an int16 (NSSIInt16, $20) passed -- but stock
		;		X16 BASIC does not allow an integer loop index at all: FOR I%=1 TO 10 is
		;		?SYNTAX ERROR there. Here it compiled and then ran WRONG. NEXT wrote a raw
		;		six-byte float back into the two-byte slot and every later read took those two
		;		bytes as two's complement, so a negative index came back as its magnitude:
		;
		;			FOR I%=2 TO -2 STEP -1 : PRINT I%; : NEXT   ->  2 1 0 1 2
		;
		;		with an exit value of 3 rather than -3. The trip count was right (NEXT compares
		;		the float), so it was silently wrong rather than a crash, and no positive-only
		;		loop could show it. Reject it at compile time, as the interpreter does. Nothing
		;		is lost by it: measured over 20,000 iterations compiled, an int16 index is no
		;		faster than a float one (65/65 jiffies empty, 257/261 reading the index), and
		;		no program written for stock could contain one anyway. Use % to shrink arrays
		;		-- DIM A%(n) really is two bytes an element -- not to speed up a loop.
		;
		and 	#NSSTypeMask|NSSIInt16 		; check it is a float: not a string, not an int16
		cmp 	#NSSIFloat
		bne 	_CFFail
		;
		; 		= [Start]
		;
		phy 								; save reference on the stack
		phx
		lda 	#C64_EQUAL 					; check for equal.
		jsr 	CheckNextA
		jsr 	CompileExpressionAt0 		; initial value
		plx 								; get reference back.
		ply
		phy
		phx
		sec 								; set initial value.
		jsr 	GetSetVariable
		;
		;		Push the reference on the stack. Bit 15 used to carry an int16 flag through to
		;		the runtime's FOR frame (offset 4, bit 7); with an int16 index now rejected
		;		above it could only ever be clear, and NEXT never read that bit back in any
		;		case -- which is precisely why the wrong answers above went unnoticed.
		;
		plx
		ply
		txa 								; reference in YA
		jsr 	PushIntegerYA
		;
		;		TO [End]
		;
		lda 	#C64_TO
		jsr 	CheckNextA
		jsr 	CompileExpressionAt0 		; terminal value
		and 	#NSSTypeMask 				; check it is numeric
		cmp 	#NSSIFloat 					
		bne 	_CFFail
		;
		;		Optional STEP [n]
		;
		jsr 	LookNextNonSpace 			; followed by STEP
		cmp 	#C64_STEP
		bne 	_CFNoStep
		;
		jsr 	GetNext 					; consume it.
		jsr 	CompileExpressionAt0 		; terminal value
		and 	#NSSTypeMask 				; check it is numeric
		cmp 	#NSSIFloat 					
		bne 	_CFFail
		bra 	_CFParametersDone
		;
_CFNoStep:
		lda 	#1 							; default STEP e.g. 1
		jsr 	PushIntegerA
_CFParametersDone:		
		lda 	#PCD_FOR  					; compile FOR word.
		jsr 	WriteCodeByte
		rts



_CFFail:
		.error_syntax

		.send code


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
