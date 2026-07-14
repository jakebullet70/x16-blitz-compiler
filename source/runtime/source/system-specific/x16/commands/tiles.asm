; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		tiles.asm
;		Purpose:	TILE, and the layer 1 map address it shares with TDATA and TATTR
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		TILE, TDATA and TATTR are conveniences over layer 1's tile map: they work out the VRAM
;		address of a character cell so a program does not have to. Each map entry is two bytes,
;		the tile (or screen code) and its attribute (the foreground/background colours in text
;		mode), so the address of cell (x,y) is
;
;			mapbase + y * rowbytes + x * 2
;
;		Both mapbase and rowbytes are read from VERA every time rather than assumed, because the
;		manual is explicit that these work "if VERA Layer 1's map base value is changed or the
;		map size is changed". In the default 80x60 text mode that is a 128-tile-wide map at
;		$1B000, so a row is 256 bytes and the cell is $1B000 + y*256 + x*2 -- but nothing here
;		depends on that.
;
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;						TILE <x>,<y>,<tile/screen code>[,<attribute>]
;
; ************************************************************************************************

Command_TILE: ;; [!tile]
		.entercmd
		phy
		ldx 	#3
_CTLInteger:
		.floatinteger
		dex
		bpl 	_CTLInteger

		lda 	NSMantissa0+0
		sta 	tileX
		lda 	NSMantissa1+0
		sta 	tileX+1
		lda 	NSMantissa0+1
		sta 	tileY
		lda 	NSMantissa1+1
		sta 	tileY+1
		jsr 	TileSetAddress

		lda 	NSMantissa0+2 				; the tile or screen code, and the auto-increment
		sta 	VRAMData0 					; then steps on to the attribute

		lda 	NSMantissa0+3 				; the attribute is optional. 255 means it was not
		cmp 	#255 						; supplied, and the cell keeps the colours it had.
		beq 	_CTLNoAttribute
		sta 	VRAMData0
_CTLNoAttribute:
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;		Point VERA data port 0 at the layer 1 map entry for the cell in tileX,tileY, with the
;		auto-increment set so that a second access reaches the attribute byte. X is untouched.
;
; ************************************************************************************************

TileSetAddress:
		lda 	VERAL1Config 				; a map row is 2 x (32 << map width) bytes, which is
		lsr 	a 							; 64 << map width. So the row offset is y shifted
		lsr 	a 							; left by 6 + map width, and the width field is
		lsr 	a 							; bits 5:4 of L1_CONFIG.
		lsr 	a
		and 	#3
		clc
		adc 	#6
		tay 								; Y = shift count, 6 to 9

		lda 	tileY 						; a 24 bit accumulator, because a 256 x 256 map of
		sta 	tileAddr 					; two byte entries is 128K -- the whole of VRAM
		lda 	tileY+1
		sta 	tileAddr+1
		stz 	tileAddr+2
_TSARow:
		asl 	tileAddr
		rol 	tileAddr+1
		rol 	tileAddr+2
		dey
		bne 	_TSARow

		lda 	tileX 						; + x * 2, one for the tile and one for its attribute
		asl 	a
		sta 	tileTemp
		lda 	tileX+1
		rol 	a
		sta 	tileTemp+1

		clc
		lda 	tileAddr
		adc 	tileTemp
		sta 	tileAddr
		lda 	tileAddr+1
		adc 	tileTemp+1
		sta 	tileAddr+1
		lda 	tileAddr+2
		adc 	#0
		sta 	tileAddr+2

		lda 	VERAL1MapBase 				; the map base register holds address bits 16:9, so
		stz 	tileTemp 					; the base is that shifted left by nine. Nine zero low
		asl 	a 							; bits means it only ever reaches the middle byte and
		sta 	tileTemp+1 					; bit 16.
		lda 	#0
		rol 	a
		sta 	tileTemp+2

		clc
		lda 	tileAddr
		adc 	tileTemp
		sta 	VRAMLow0
		lda 	tileAddr+1
		adc 	tileTemp+1
		sta 	VRAMMed0
		lda 	tileAddr+2
		adc 	tileTemp+2
		and 	#VRAMBank1 					; VRAM is 17 bits, so bit 16 is all that is left
		ora 	#VRAMIncrement1
		sta 	VRAMHigh0
		rts

		.send 	code

		.section storage
tileX:
		.fill 	2
tileY:
		.fill 	2
tileAddr: 									; 24 bit, see above
		.fill 	3
tileTemp:
		.fill 	3
tileSelect: 								; TDATA reads the tile, TATTR the byte after it
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
