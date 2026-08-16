; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		refterm.asm
;		Purpose:	Get reference term
;		Created:	25th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;		On entry, A contains the first character.  Extract the variable name and locate it
;		creating if necessary, returning offset in YX, type in A.
;
; ************************************************************************************************

		.section code

GetReferenceTerm:
		jsr 	ExtractVariableName 		; get name & type info
		cpx 	#0 							; check for array handler
		bmi 	_GRTArray
		phx 								; save type on stack
		jsr 	FindVariable 				; find it
		bcs 	_GRTNoCreate 				; create if required.
		jsr 	CreateVariableRecord 		; create a variable.
		jsr 	AllocateBytesForType 		; allocate memory for it
_GRTNoCreate:		
		pla 								; get type back, strip out type information.
		and 	#NSSTypeMask+NSSIInt16
		rts		
	
_GRTArray:
		phx 								; save type information (also = the name if we must create)
		jsr 	FindVariable 				; CS: found, base address in YX. CC: unknown -> YX = name.
		lda 	#0 							; flag: 0 = the array already exists (LDA leaves carry alone)
		bcs 	_GRTKnown
		lda 	#$FF 						; $FF = undimensioned, create it once we know how many indices
_GRTKnown:
		pha 								; save that flag, and the name/address, over OutputIndexGroup
		phx
		phy
		;
		;		The NC form: subscripts only, no count word after them. How many there were comes
		;		back in IndexCount, and only a reference with two or more needs that count pushed
		;		-- the single-subscript case, which is very nearly all of them, uses the fused
		;		PCD_ARRAY1 below and that keyword already knows the count is one.
		;
		jsr 	OutputIndexGroupNC 			; compile the subscripts; IndexCount = how many
		lda 	IndexCount 					; take our own copy now: GetSetVariable and
		sta 	refIndexCount 				; RegisterImplicitArray both run before we read it back
		cmp 	#2
		bcc 	_GRTNoCountWord 			; one subscript -> the fused keyword needs no count
		jsr 	PushIntegerA 				; two or more -> PCD_ARRAY reads a count word
_GRTNoCountWord:
		ply 								; restore name/address into YX
		plx
		pla 								; and the create flag
		beq 	_GRTResolved 				; existing array -> YX is already its base address
		;
		;		Undimensioned array. Interpreted BASIC would auto-create it here as 0..10 in each
		;		dimension. We now know the dimension count (IndexCount), so register it -- the
		;		prologue emitted at the start of the program dimensions it before any code runs.
		;
		jsr 	RegisterImplicitArray 		; create the record now, returning its slot address in YX
_GRTResolved:
		lda 	#NSSIFloat+NSSIInt16 		; pretend it is an int16 reference.
		clc
		jsr 	GetSetVariable 				; load the address of the array structure.
		;
		;		One subscript takes the fused keyword. It saves the count word -- a whole p-code
		;		dispatch to push it, and a GetInteger8Bit in the runtime to read it back -- on an
		;		access whose count the compiler knew all along.
		;
		lda 	refIndexCount
		cmp 	#1
		bne 	_GRTManyIndices
		.keyword PCD_ARRAY1 				; convert that to an offset, count implicitly 1
		bra 	_GRTIndexed
_GRTManyIndices:
		.keyword PCD_ARRAY 					; convert that to an offset, count read off the stack
_GRTIndexed:
		pla 								; and the type data into A
		and 	#NSSTypeMask+NSSIInt16
		ora 	#$80 						; with the array flag set.
		rts

; ************************************************************************************************
;
;		Register an undimensioned array so the implicit-DIM prologue can create it. On entry YX
;		is the (array) name and IndexCount is the number of indices in the reference that
;		discovered it, which becomes its dimension count. Creates the variable record and its
;		pointer slot now (so this reference and later ones resolve normally) and records the slot
;		address, element type and dimension count for EmitImplicitDims. Returns YX = slot address.
;		Falls back to the old "unknown array" error only if more than 32 need dimensioning.
;
; ************************************************************************************************

RegisterImplicitArray:
		lda 	implicitDimCount 			; capacity check
		cmp 	#32
		bcs 	_RIAFull
		txa 								; element type comes from the name's type bits
		and 	#NSSTypeMask+NSSIInt16
		sta 	implicitDimType
		jsr 	CreateVariableRecord 		; make the record (YX = name) -> YX = slot address
		stx 	implicitDimAddr
		sty 	implicitDimAddr+1
		lda 	implicitDimType
		jsr 	AllocateBytesForType 		; reserve the pointer slot
		lda 	implicitDimCount 			; append a list entry at count*4
		asl 	a
		asl 	a
		tax
		lda 	implicitDimAddr
		sta 	implicitDimList+0,x
		lda 	implicitDimAddr+1
		sta 	implicitDimList+1,x
		lda 	implicitDimType
		sta 	implicitDimList+2,x
		lda 	IndexCount 					; dimension count (>= 1 for a real reference)
		bne 	_RIAHaveCount
		lda 	#1
_RIAHaveCount:
		sta 	implicitDimList+3,x
		inc 	implicitDimCount
		ldx 	implicitDimAddr 			; return the slot address in YX for GetSetVariable
		ldy 	implicitDimAddr+1
		rts
_RIAFull:
		.error_undeclared

; ************************************************************************************************
;
;		An explicit DIM found that its array already has a record. Decide whether that record was
;		created by RegisterImplicitArray (i.e. a reference auto-registered the array before this
;		DIM in source order) rather than by a real earlier DIM. On entry YX is the array's slot
;		address, exactly as FindVariable returned it. If a live list entry matches that address,
;		tombstone it -- set its dimension count to 0 so EmitImplicitDims emits nothing for it --
;		and return CS with YX preserved, so the DIM dimensions the array for real at the bounds
;		the programmer wrote. If nothing matches, return CC: this is a genuine re-DIM.
;
; ************************************************************************************************

TakeOverImplicitArray:
		stx 	zTemp0 						; remember the slot address to match, and to hand back
		sty 	zTemp0+1
		ldy 	implicitDimCount 			; entries to scan
		beq 	_TOIANo 					; none registered -> cannot be an implicit array
		ldx 	#0 							; byte offset into the 4-bytes-per-entry list
_TOIALoop:
		lda 	implicitDimList+3,x 		; dimension count; 0 = already tombstoned, skip it
		beq 	_TOIANext
		lda 	implicitDimList+0,x 		; match the slot address, low then high
		cmp 	zTemp0
		bne 	_TOIANext
		lda 	implicitDimList+1,x
		cmp 	zTemp0+1
		bne 	_TOIANext
		lda 	#0 							; found it -> tombstone so the prologue skips this array
		sta 	implicitDimList+3,x
		ldx 	zTemp0 						; hand the slot address back in YX
		ldy 	zTemp0+1
		sec 								; CS = taken over
		rts
_TOIANext:
		inx 								; step over this 4-byte entry
		inx
		inx
		inx
		dey
		bne 	_TOIALoop
_TOIANo:
		ldx 	zTemp0 						; restore YX = slot address
		ldy 	zTemp0+1
		clc 								; CC = not an implicitly-registered array
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
