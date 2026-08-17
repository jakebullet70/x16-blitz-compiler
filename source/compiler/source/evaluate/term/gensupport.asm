; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gensupport.asm
;		Purpose:	Support functions for generation
;		Created:	16th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		MID$ has a support function because it has different numbers of parameters.
;		e.g. MID$(a$,b,c) or MID$(a$,b)
;
; ************************************************************************************************

OptionalParameterCompile:
		jsr 	LookNextNonSpace 			; what follows.
		;
		cmp 	#","
		bne 	_MidDefault
		jsr 	GetNext 					; consume ,
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	MidFailType
		bra 	_MidComplete
_MidDefault:
		lda 	#255 						; default of 255
		jsr 	PushIntegerA
_MidComplete:
		clc
		rts

MidFailType:
		.error_type

; ************************************************************************************************
;
;		As OptionalParameterCompile, but defaulting to ZERO -- GP.CALL's registers, GP.INSTR's start.
;
;		No sentinel is involved and none is needed: an unspecified register genuinely IS zero, so
;		the runtime never has to test for "omitted" and carries no code to do it. Zero also fits
;		the one byte short constant path, so an omitted argument costs LESS here than a supplied
;		one -- the opposite of OptionalParameterCompile, whose 255 default cannot fit and emits a
;		two byte .byte instruction every time.
;
; ************************************************************************************************

OptionalZeroCompile:
		jsr 	LookNextNonSpace 			; what follows.
		cmp 	#","
		bne 	_ORCDefault
		jsr 	GetNext 					; consume ,
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	MidFailType 				; which must be numeric
		clc
		rts
_ORCDefault:
		lda 	#0
		jsr 	PushIntegerA
		clc
		rts

; ************************************************************************************************
;
;		As OptionalParameterCompile, but for a trailing COLOUR argument (RECT/LINE/FRAME/OVAL/
;		RING). A palette index is 0..255, so 255 is a real colour and cannot double as the
;		"omitted" sentinel the way it can for sprite fields. The default is 256 instead -- out of
;		range for an 8-bit colour -- so the runtime (GraphicsColourOptional) reads a non-zero
;		high byte as "leave the current draw colour", and every explicit 0..255 still works.
;
; ************************************************************************************************

OptionalColourCompile:
		jsr 	LookNextNonSpace 			; what follows.
		cmp 	#","
		bne 	_OCCDefault
		jsr 	GetNext 					; consume ,
		jsr 	CompileExpressionAt0 		; the supplied colour
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	MidFailType 				; which must be numeric
		clc
		rts
_OCCDefault:
		lda 	#0 							; default of 256 = $0100: PushIntegerYA emits a 16-bit
		ldy 	#1 							; constant when Y (the high byte) is non-zero, and that
		jsr 	PushIntegerYA 				; high byte is what marks the colour as omitted.
		clc
		rts

; ************************************************************************************************
;
;		An optional *leading* numeric parameter, for commands that are valid with or without
;		an argument in stock BASIC (e.g. bare SLEEP as well as SLEEP <ticks>). Unlike
;		OptionalParameterCompile this argument has no leading comma to key off -- it is the
;		first and only parameter -- so absence is end-of-statement, tested exactly as
;		CommandRESTORE tests its optional line number (a ':' or EOL). When absent we push 0,
;		so bare SLEEP compiles to SLEEP 0 (an immediate return in the runtime handler).
;
; ************************************************************************************************

OptionalNumberCompile:
		jsr 	LookNextNonSpace 			; what follows the keyword ?
		cmp 	#':' 						; end of statement -> argument omitted
		beq 	_ONCDefault
		cmp 	#0 							; end of line     -> argument omitted
		beq 	_ONCDefault
		jsr 	CompileExpressionAt0 		; else compile the supplied expression
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	MidFailType 				; which must be numeric
		clc
		rts
_ONCDefault:
		lda 	#0 							; bare command == argument 0
		jsr 	PushIntegerA
		clc
		rts

; ************************************************************************************************
;
;		A generation helper for keywords that are recognised (so tokenised BASIC loads and
;		round-trips) but are not implemented by this version of the compiler. Rather than let
;		the term evaluator fall through to a bare "SYNTAX ERROR" -- which makes a valid-BASIC
;		keyword look like a typo -- we route the token here and raise NOT IMPLEMENTED, so the
;		user sees "NOT IMPLEMENTED @ <line>" and knows the feature, not their spelling, is the
;		problem. Used by POINTER and STRPTR (x16_unary.def): both expose the interpreter's
;		internal variable layout, which the compiled runtime stores differently, so honouring
;		them would silently misbehave rather than fail loudly. This never returns.
;
; ************************************************************************************************

UnsupportedCompile:
		.error_unimplemented

; ************************************************************************************************
;
;		NOT has a support function as its single expression parameter is done part way
;		up precedence
;
; ************************************************************************************************

NotUnaryCompile:
											; precedence of comparators
		lda 	PrecedenceTable+C64_EQUAL-C64_PLUS		
		jsr 	CompileExpressionAtA 		; evaluate at that level
		and 	#NSSTypeMask 				; check compile returns number.
		cmp 	#NSSIFloat
		bne 	MidFailType
		lda 	#PCD_NOT 					; and NOT it.
		jsr 	WriteCodeByte		
		rts

; ************************************************************************************************
;
;		A STRING VARIABLE, for the in-place statements GP.TRIM / GP.PAD / GP.UPPER / GP.LOWER.
;
;		These modify the string block the value points at, so handing them anything that is not a
;		variable is a live hazard rather than a nuisance: a LITERAL is pushed by CommandPushS
;		pointing INTO THE P-CODE, so GP.UPPER "abc" would rewrite the running program, and a
;		temporary (GP.UPPER A$+B$) would edit a block about to be reclaimed. Both would appear to
;		work. So require a plain variable at compile time, exactly as FOR requires one for its
;		index, and it cannot be expressed at all.
;
;		GetReferenceTerm locates (or creates) it and hands back the address in YX and the type in
;		A; GetSetVariable with carry CLEAR then emits the read, so the runtime handler gets the
;		block address on the stack and needs no checking of its own. Array elements are fine and
;		deliberately allowed -- GetReferenceTerm resolves those too.
;
; ************************************************************************************************

StringVariableCompile:
		jsr 	GetNextNonSpace 			; a variable starts with a letter; a quote or a digit
		jsr 	CharIsAlpha 				; cannot, which is what rejects literals outright
		bcc 	_SVCFail
		jsr 	GetReferenceTerm 			; locate it -- address in YX, type in A
		pha
		and 	#NSSTypeMask 				; and it has to be a string
		cmp 	#NSSString
		bne 	_SVCFailPull
		pla
		clc 								; carry clear = read, so the VALUE is pushed
		jsr 	GetSetVariable
		clc
		rts

_SVCFailPull:
		pla
_SVCFail:
		.error_syntax

; ************************************************************************************************
;
;		A STRING ARRAY, written with EMPTY parentheses -- GP.SORT A$(). Pushes the array's BASE
;		address and nothing else.
;
;		The parentheses are required and are not decoration: in BASIC A$ and A$() are different
;		variables, so accepting the bare name would find the SCALAR and silently sort nothing at
;		all. ExtractVariableName already sets NSSArray when it sees the "(" and consumes it, so
;		all that is left here is to insist on the ")".
;
;		Deliberately does NOT emit PCD_ARRAY1 -- that is the keyword that turns a base address
;		plus subscripts into an ELEMENT address, and the whole point here is to hand the runtime
;		the array itself. Pushing the base is the same idiom GetReferenceTerm uses just before it
;		emits that keyword: pretend the slot is an int16 and read it.
;
; ************************************************************************************************

;		AnyArrayCompile is the same thing with the element-type check dropped -- GP.ARRPTR wants
;		the address of a FLOAT array just as much as a string one. Deliberately duplicated rather
;		than factored behind a flag: compiler code is not copied into the object, so the dozen
;		bytes are free, and a shared routine would need the flag in storage to survive the jsrs.

AnyArrayCompile:
		jsr 	GetNextNonSpace 			; a variable starts with a letter
		jsr 	CharIsAlpha
		bcc 	SACFail
		jsr 	ExtractVariableName 		; name in YX, type bits in X, "(" consumed if present
		cpx 	#0
		bpl 	SACFail 					; no "(" at all, so it is a scalar, not an array
		bra 	SACParens

StringArrayCompile:
		jsr 	GetNextNonSpace 			; a variable starts with a letter
		jsr 	CharIsAlpha
		bcc 	SACFail
		jsr 	ExtractVariableName 		; name in YX, type bits in X, "(" consumed if present
		cpx 	#0
		bpl 	SACFail 					; no "(" at all, so it is a scalar, not an array
		txa
		and 	#NSSTypeMask
		cmp 	#NSSString
		bne 	SACFail 					; and it has to be a string array
SACParens:
		;
		phy 								; hold the name over the ")" check
		phx
		jsr 	GetNextNonSpace
		cmp 	#")"
		bne 	SACFailPull 				; empty parentheses only -- no subscript belongs here
		plx
		ply
		;
		jsr 	FindVariable 				; CS: exists, YX = its slot. CC: never mentioned.
		bcc 	SACFail
		lda 	#NSSIFloat+NSSIInt16 		; read the slot as an int16, which pushes the array's
		clc 								; base address without indexing into it
		jsr 	GetSetVariable
		clc
		rts

SACFailPull:
		plx
		ply
SACFail: 									; global, not _SACFail: 64tass scopes a _ label
		.error_syntax 						; to the enclosing global one, and BOTH entry
											; points above need to reach it

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
