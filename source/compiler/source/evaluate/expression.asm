; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		expression.asm
;		Purpose:	Expression evaluator
;		Created:	16th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Compile expression precedence A/0
;
; ************************************************************************************************

CompileExpressionAt0:
		lda 	#0
CompileExpressionAtA:
		pha  								; save level
		jsr 	CompileTerm 				; compile a term.
		plx 								; get level back into X
		;
		;		Expression main loop - X is the precedence level, A the type.
		;
_ECALoop:				
		pha 								; save type on stack.
		jsr 	LookNextNonSpace 			; get the next character
		cmp 	#C64_PLUS 					; go to be + ... < in the C64 code.
		bcc 	_ECAExit
		cmp 	#C64_LESS+1
		bcc 	_ECAHaveToken
_ECAExit:
		pla 								; throw type off stack
		rts
		;
		;		Have a partial token - check precedence (because the >= <= <> precedence is the same as < and >)
		;
_ECAHaveToken:		
		stx 	zTemp0 						; save current precedence in zTemp0
		tax 								; X contains the operator token

		lda 	PrecedenceTable-C64_PLUS,x  ; read precedence.
		cmp 	zTemp0 						; if < then exit
		bcc 	_ECAExit
		sta 	zTemp0+1 					; save the precedence of the operator.
		jsr 	GetNext 					; consume the token.
		;
		;		Now fold the two-character relational operators. CBM/X16 BASIC accepts <, = and >
		;		in ANY order, so all six of  <>  ><  <=  =<  >=  =>  are legal and reduce to three
		;		operators. Only <> <= >= were handled here: a leading "=" was never examined at
		;		all, and ">" only ever looked for "=", so =< => and >< were rejected as syntax
		;		errors on perfectly valid X16 BASIC.
		;
		;		The operator token is later turned into P-Code by adding a FIXED offset, so these
		;		exact values matter:
		;			>=  = C64_GREATER+3  ($B4 -> PCD_GREATEREQUAL $8A)
		;			<>  = C64_LESS+2     ($B5 -> PCD_LESSGREATER  $8B)
		;			<=  = C64_LESS+3     ($B6 -> PCD_LESSEQUAL    $8C)
		;		Precedence has already been read from the FIRST token above, and <, = and > all
		;		share precedence 2, so rewriting X here is safe.
		;
		cpx 	#C64_GREATER
		beq 	_ECAAfterGreater
		cpx 	#C64_EQUAL
		beq 	_ECAAfterEqual
		cpx 	#C64_LESS
		bne 	_ECAHaveFullToken
		;
		jsr 	LookNext 					; seen "<" : accept <> and <=
		cmp 	#C64_GREATER
		beq 	_ECASetNotEqual
		cmp 	#C64_EQUAL
		beq 	_ECASetLessEqual
		bra 	_ECAHaveFullToken

_ECAAfterGreater: 							; seen ">" : accept >= and ><
		jsr 	LookNext
		cmp 	#C64_EQUAL
		beq 	_ECASetGreaterEqual
		cmp 	#C64_LESS
		beq 	_ECASetNotEqual
		bra 	_ECAHaveFullToken

_ECAAfterEqual: 							; seen "=" : accept => and =<
		jsr 	LookNext
		cmp 	#C64_GREATER
		beq 	_ECASetGreaterEqual
		cmp 	#C64_LESS
		beq 	_ECASetLessEqual
		bra 	_ECAHaveFullToken

_ECASetNotEqual:
		ldx 	#C64_LESS+2
		bra 	_ECAConsumeSecond
_ECASetGreaterEqual:
		ldx 	#C64_GREATER+3
		bra 	_ECAConsumeSecond
_ECASetLessEqual:
		ldx 	#C64_LESS+3
_ECAConsumeSecond:
		jsr 	GetNext 					; consume the second character of the operator
_ECAHaveFullToken:
		;
		;		Check for + string => concat
		;
		cpx 	#C64_PLUS
		bne 	_ECANotConcat
		pla 								; get type back
		pha
		and 	#NSSTypeMask
		cmp 	#NSSString
		bne 	_ECANotConcat
		ldx 	#(PCD_CONCAT-(PCD_PLUS-C64_PLUS)) & $FF
_ECANotConcat:		
		;
		;		Now have the correct token in X.
		;
		phx 								; save operator on the stack
		ldx 	zTemp0 						; push current precedence on the stack
		phx
		;
		;		Evaluate the RHS
		;
		lda 	zTemp0+1 					; get precedence of operator
		inc 	a
		jsr 	CompileExpressionAtA 		; and compile at the next level up.
		sta 	zTemp0 						; save type in zTemp0
		;
		plx 								; restore current precedence in X

		pla 								; restore operator
		sta 	zTemp0+1 					; save it in zTemp0+1.
		;
		;		Check if we need f.cmp or s.cmp
		;
		cmp 	#C64_GREATER 				; check for not compare
		bcc 	_ECANotCompare
		cmp 	#C64_GREATER+6
		bcs 	_ECANotCompare
		ply 								; get type into Y
		phy 
		pha 								; save operator

		tya 								; get type
		ldy 	#PCD_SCMD_CMP 				; Y is the token to use
		and 	#NSSTypeMask 				
		cmp 	#NSSString
		beq 	_ECANotString
		ldy 	#PCD_FCMD_CMP
_ECANotString:		
		tya									; output token Y
		jsr 	WriteCodeByte
		pla 								; restore operator.
_ECANotCompare:		
		;
		;		Compile the operator, which may be wrong (e.g. multiplying strings)
		;
		clc 								; convert to P-Code and compile.
		adc 	#(PCD_PLUS-C64_PLUS) & $FF 	; it might be invalid at this point
		jsr 	WriteCodeByte
		;
		;		Check the types match
		;
		pla 								; type of current result
		eor 	zTemp0 						; check compatible with r-expr type
		and 	#NSSTypeMask 				; the types should be compatible, only interested in number vs float
		bne		_ECAType
		;
		lda 	zTemp0 						; get type back
		cmp 	#NSSString 					; if it is a number, then all operators work.
		bne 	_ECAGoLoop 			
		;
		;		For strings only, check the command is valid (e.g. only + and comparators)
		;
		lda 	zTemp0+1 					; check operator is + or comparator
		cmp 	#(PCD_CONCAT-(PCD_PLUS-C64_PLUS)) & $FF
		beq 	_ECAOkayString 				; (this is post conversion)

		cmp 	#C64_GREATER 				; must be a comparison then.
		bcc 	_ECAType
		cmp 	#C64_LESS+1+3 				; the +3 is because of >= <= <>
		bcs 	_ECAType
		lda 	#NSSIFloat 					; compare returns number.
		jmp 	_ECALoop

_ECAType: 									; types mixed ?
		.error_type

_ECAOkayString:		
		lda 	#NSSString 					; current is string, go round again.
_ECAGoLoop:		
		jmp 	_ECALoop

; ************************************************************************************************
;
;										Operator precedence table
;
; ************************************************************************************************

PrecedenceTable:
		.byte 	3 					; '+'
		.byte 	3 					; '-'
		.byte 	4 					; '*'
		.byte 	4 					; '/'
		.byte 	5 					; '^'
		.byte 	1 					; 'and'
		.byte 	0 					; 'or'
		.byte 	2 					; '>'
		.byte 	2 					; '='
		.byte 	2 					; '<'
		.byte 	2 					; '>=' (C64_GREATER+3)
		.byte 	2 					; '<>' (C64_LESS+2)   -- these two were the wrong way round
		.byte 	2 					; '<=' (C64_LESS+3)

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
