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
