; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		tiledata.asm
;		Purpose:	TDATA() and TATTR()
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		The read half of TILE. Both share TileSetAddress (tiles.asm), which leaves VERA pointing
;		at the cell with the auto-increment on -- so the tile is the first byte read and its
;		attribute is the second.
;
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								TDATA(<x>,<y>) and TATTR(<x>,<y>)
;
; ************************************************************************************************

UnaryTDATA: ;; [!tdata]
		.entercmd
		phy 								; Y is the code position
		lda 	#0 							; TDATA wants the tile itself
		bra 	TileRead

UnaryTATTR: ;; [!tattr]
		.entercmd
		phy
		lda 	#1 							; TATTR wants the attribute, one byte further on

TileRead: 									; global, not a cheap local: TDATA branches in from
		sta 	tileSelect 					; its own scope and _locals do not cross one
		.floatinteger 						; y is the last argument, so it is the one X is on
		lda 	NSMantissa0,x
		sta 	tileY
		lda 	NSMantissa1,x
		sta 	tileY+1
		dex 								; X now addresses x -- which is also the slot the
		.floatinteger 						; result has to be left in, first argument's slot
		lda 	NSMantissa0,x
		sta 	tileX
		lda 	NSMantissa1,x
		sta 	tileX+1
		jsr 	TileSetAddress

		lda 	tileSelect
		beq 	_TRRead
		lda 	VRAMData0 					; step over the tile to reach its attribute
_TRRead:
		lda 	VRAMData0
		jsr 	FloatSetByte
		ply
		.exitcmd

		.send 	code

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
