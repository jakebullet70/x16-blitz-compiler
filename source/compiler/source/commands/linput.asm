; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		linput.asm
;		Purpose:	LINPUT, LINPUT# and BINPUT#
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		The emitted code has to come out in this order:
;
;			push the delimiter (or the count)		<- the P-code reads it from S[X]
;			[linput] / [binput]						<- and replaces it with the string
;			store into the variable
;
;		but the SOURCE reads the other way round -- "LINPUT# 1,A$,34" names the variable first and
;		the delimiter last. GetReferenceTerm emits nothing, so the variable can be parsed early and
;		its store emitted late; what it DOES do is hand back the address in X and Y, which is what
;		GetSetVariable wants. Compiling the delimiter expression in between will certainly not leave
;		X and Y alone, so the address is parked on the 6502 stack across it.
;
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;										LINPUT <var$>
;
; ************************************************************************************************

CommandLINPUT:
		jsr 	LinputGetVariable 			; A = type, XY = address; nothing emitted yet
		pha
		phx
		phy
		lda 	#13 						; the keyboard form always ends at a carriage return
		jsr 	PushIntegerA
		bra 	LinputEmit

; ************************************************************************************************
;
;					LINPUT# <n>,<var$>[,<delimiter>]
;
;		The channel and its comma have already been eaten by the C: prefix (ChannelPrefix).
;
; ************************************************************************************************

CommandLINPUTStream:
		jsr 	LinputGetVariable
		pha
		phx
		phy
		jsr 	LookNextNonSpace 			; an explicit delimiter ?
		cmp 	#","
		bne 	_CLISDefault
		jsr 	GetNext 					; consume the comma
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	LinputType
		bra 	LinputEmit
_CLISDefault:
		lda 	#13 						; "the delimiter of a line by default is 13"
		jsr 	PushIntegerA

LinputEmit: 								; global, not a cheap local: LINPUT branches in from its
		.keyword PCD_LINPUT 				; own scope, and _locals do not cross one
LinputStore:
		ply 								; the variable was parked before the delimiter was
		plx 								; compiled; take it back and write the store
		pla
		sec
		jsr 	GetSetVariable
		rts

; ************************************************************************************************
;
;						BINPUT# <n>,<var$>,<len>
;
;		The length is not optional, so there is no default to fall back on.
;
; ************************************************************************************************

CommandBINPUTStream:
		jsr 	LinputGetVariable
		pha
		phx
		phy
		jsr 	GetNextNonSpace
		cmp 	#","
		bne 	LinputSyntax
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	LinputType
		.keyword PCD_BINPUT
		bra 	LinputStore

; ************************************************************************************************
;
;		Parse the target variable. All three of these read into a string and nothing else.
;
; ************************************************************************************************

LinputGetVariable:
		jsr 	GetNextNonSpace
		jsr 	CharIsAlpha
		bcc 	LinputSyntax
		jsr 	GetReferenceTerm 			; A = type, XY = the variable's address
		pha
		and 	#NSSTypeMask
		cmp 	#NSSString
		bne 	LinputType
		pla 								; leaves XY alone, which is the whole point
		rts

LinputType:
		.error_type

LinputSyntax:
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
