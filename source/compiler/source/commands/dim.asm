; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		dim.asm
;		Purpose:	DIM command
;		Created:	26th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;											DIM command
;
; ************************************************************************************************

CommandDIM:
		jsr 	GetNextNonSpace 			; get the first non space character
		jsr 	ExtractVariableName 		; variable name to XY
		phx 								; save name with type bits.
		cpx 	#0 							; is it an array (bit 7 / NSSArray set) ?
		bpl 	_CDScalar 					; no -- DIM of a simple variable, just reserve it.
		jsr 	FindVariable	 			; see if already exist
		bcc 	_CDCreate 					; brand new array -> create its record
		;
		;		The array already has a record. If an earlier reference (before this DIM in source
		;		order) auto-registered it via RegisterImplicitArray, THIS DIM is the real one: take
		;		it over -- tombstone the implicit entry so the startup prologue does not also
		;		default-dimension it, reuse the record, and dimension it to the bounds written here.
		;		Otherwise it is a genuine second DIM of the same array and the redefine error stands.
		;
		jsr 	TakeOverImplicitArray 		; CS: taken over (YX = slot address). CC: not implicit.
		bcs 	_CDDimension
		.error_redefine
_CDCreate:
		jsr 	CreateVariableRecord 		; create the basic variable
		jsr 	AllocateBytesForType 		; allocate memory for it
_CDDimension:
		pla 								; restore type bits
		phy 								; save the address of the basic storage
		phx
		pha
		jsr 	OutputIndexGroup 			; create an index group and generate them, preserving type data
		pla
		and 	#NSSTypeMask+NSSIInt16 		; 2 bit type data
		jsr 	PushIntegerA 				; push that type data out.

		.keyword PCD_DIM 					; call the keyword to dimension the array with this information.

		plx 								; restore address
		ply
		lda 	#NSSIFloat+NSSIInt16 		; pretend it is an int16 reference.
		sec
		jsr 	GetSetVariable 				; store the address in the reference to the array structure.
		bra 	_CDComma
		;
		;		DIM of a simple variable. Stock BASIC allows this (e.g. DIM A%,B%) and it is
		;		valid on the X16 -- it just forces the variable to exist now instead of on first
		;		use. There is nothing to dimension and no runtime code to emit, so we only reserve
		;		the record. Already exists (used before the DIM) -> leave it, don't redefine-error;
		;		the redefine rule is for arrays, and scalars carry no dimensions to conflict.
		;
_CDScalar:
		jsr 	FindVariable 				; does it already exist ?
		bcs 	_CDScalarDone 				; yes -- nothing to do.
		jsr 	CreateVariableRecord 		; no -- create it
		jsr 	AllocateBytesForType 		; and give it storage.
_CDScalarDone:
		pla 								; discard the saved type bits.
		;
_CDComma:
		jsr 	LookNextNonSpace 			; , follows ?
		cmp 	#","
		bne 	_CDExit
		jsr 	GetNext 					; consume comma
		bra 	CommandDIM 					; do another DIM
_CDExit:
		rts

; ************************************************************************************************
;
;									Consume an index group
;
; ************************************************************************************************

OutputIndexGroup:
		stz 	IndexCount 					; count of number of indices.
_OIGNext:
		jsr 	CompileExpressionAt0 		; get a dimension
		and 	#NSSTypeMask 				; check it is numeric
		cmp 	#NSSIFloat
		bne 	_OIGType
		inc 	IndexCount 					; bump the counter.
		jsr 	LookNextNonSpace 			; does a , follow ?
		cmp 	#","
		bne 	_OIGCheckEnd
		jsr 	GetNext 					; consume comma
		bra 	_OIGNext 					; get next dimension
_OIGCheckEnd:
		jsr 	CheckNextRParen 			; check and consume )
		lda 	IndexCount
		jsr 	PushIntegerA 				; compile the dimension count.
		rts

_OIGType:
		.error_type
		
		.send code

		.section storage
IndexCount:
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
