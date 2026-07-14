; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		findvar.asm
;		Purpose:	Find variable.
;		Created:	25th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;		  XY contains a variable name. Find it, returning address in YXA and CS if found
;		
;					  Returns $8000 > for special variables TI ($8000) TI$($C001)
;
; ************************************************************************************************

		.section code

FindVariable:
		stx 	zTemp1 						; save name.
		sty 	zTemp1+1
		;
		;		The CBM reserved names. These are NOT keywords and never get tokenised -- they
		;		arrive here as ordinary identifiers -- so this is the only place they can be
		;		caught. ExtractVariableName has already packed the name into X = first character
		;		and 31 (with the type bits) and Y = second character and 63:
		;
		;			TI  = $14,$09		TI$ = $54,$09		ST = $13,$14
		;
		;		Each returns a FAKE address with bit 7 of Y set, which is what tells GetSetVariable
		;		to emit a keyword instead of a variable access. The high byte picks which one.
		;
_IVCheckSpecial:
		cpy 	#$09	 					; TI and TI$ both end $09 e.g. I
		bne 	_IVCheckStatus
		cpx 	#$14 						; TI is $14
		beq 	_IVTIFloat
		cpx 	#$54 						; TI$ is $54
		bne 	_IVStandard
		ldy 	#$C0 						; TI$ returns string $C001
		ldx 	#$01
		lda 	#NSSString
		sec
		rts
_IVTIFloat: 								; TI returns ifloat at $8000
		ldy 	#$80
		ldx 	#$00
		lda 	#0
		sec
		rts
		;
		;		ST, the KERNAL status byte. Two significant characters, exactly as CBM has it, so
		;		STATUS is the same name as ST and is reserved too -- which is what stock does.
		;		A type or array suffix leaves the bits in X set, so ST$, ST% and ST( all miss this
		;		and stay ordinary variables.
		;
_IVCheckStatus:
		cpy 	#$14 						; ST is $13,$14
		bne 	_IVStandard
		cpx 	#$13
		bne 	_IVStandard
		ldy 	#$A0 						; ST returns ifloat at $A000
		ldx 	#$00
		lda 	#0
		sec
		rts
		;
		;		Not a reserved name
		;
_IVStandard:
		lda 	compilerStartHigh			; start scanning from here.
		sta 	zTemp0+1
		stz 	zTemp0

		.storage_access
_IVCheckLoop:
		lda 	(zTemp0) 					; finished ?
		beq  	_IVNotFound 				; if so, return with CC.
		;
		ldy 	#1 							; match ?
		lda 	(zTemp0),y
		cmp 	zTemp1
		bne	 	_IVNext
		iny
		lda 	(zTemp0),y
		cmp 	zTemp1+1
		beq 	_IVFound
_IVNext: 									; go to next
		clc
		lda 	zTemp0
		adc 	(zTemp0)
		sta 	zTemp0
		bcc 	_IVCheckLoop
		inc 	zTemp0+1
		bra 	_IVCheckLoop
		;
_IVFound:		
		ldy 	#3 							; get address into YX
		lda 	(zTemp0),y
		tax
		iny
		lda 	(zTemp0),y
		pha
		iny
		lda 	(zTemp0),y
		ply
		.storage_release
		sec
		rts

_IVNotFound:
		.storage_release
		ldx 	zTemp1 						; get variable name back
		ldy 	zTemp1+1
		clc
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
