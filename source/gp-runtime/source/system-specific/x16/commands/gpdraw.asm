; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpdraw.asm
;		Purpose:	GP.BOX / GP.FILL / GP.PRINTAT -- direct-to-VERA text drawing
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;			GP.BOX x,y,w,h [,style] [,col]      GP.FILL x,y,w,h,char [,col]
;			GP.PRINTAT x,y,text$ [,col]
;
;		The fast path for text-mode UI. These are not a restatement of LOCATE and PRINT -- they
;		write STRAIGHT INTO VERA. GPC's own character output makes TWO KERNAL calls for every
;		single character (x16_printchar.asm: CLRCHN to select the channel, then BSOUT, and BSOUT
;		itself carries scroll checks, quote mode and cursor handling). Here a cell is two stores
;		to VRAMData0, with the auto-increment walking the row.
;
;		THE TWO WORLDS ARE SEPARATE AND THAT IS DELIBERATE. Nothing here calls the KERNAL, so
;		nothing here moves the KERNAL cursor: a plain PRINT after a GP.PRINTAT resumes where the
;		KERNAL still thinks the cursor is, NOT after the text just drawn. Mixing them will
;		surprise someone at least once, which is why it is said here and in GPB.INC.BL.
;
;		THE OPTIONAL COLOUR DEFAULTS TO WHAT "COLOR" LAST SET. The KERNAL keeps the current text
;		colour in $0376 packed as (background << 4) | foreground -- which is byte for byte the
;		VERA attribute format, so the default costs one LDA and no repacking. Measured, not
;		assumed: COLOR 5,2 leaves $0376 = $25. GPC keeps no colour state of its own (CommandColor
;		emits PETSCII control codes and lets the KERNAL do the bookkeeping), so this really is
;		"the colour PRINT would have used", not a second, separate notion of colour.
;
;		The sentinel is 256, not 255, because $FF is a legal attribute (light grey on light grey).
;		OptionalColourCompile already pushes 256 for exactly that reason -- see the note on its
;		definition, and note that TILE gets this wrong and cannot write attribute $FF at all.
;
;		CHARACTERS ARE PETSCII, converted here. A screen code is not what a BASIC programmer has:
;		they have CHR$ and ASC, and no conversion exists anywhere else in GPC. One consequence is
;		worth knowing: pet2scr cannot reach screen codes $A0-$BF, the reverse-video glyphs, because
;		PETSCII expresses reverse with a control code rather than a character. That is not a loss
;		for a UI -- highlighting a menu row is a matter of swapping the ATTRIBUTE, which the colour
;		argument does directly.
;
;		NOTHING HERE CLIPS. x, y, w and h are bytes and are used as given, so a rectangle running
;		off the right edge wraps into the next row and one running off the bottom writes past the
;		end of the map. Zero width or height IS caught, because that is the one a program reaches
;		by accident (a computed size) and it would otherwise count down through 256 cells.
;
; ************************************************************************************************

;
;		Offsets into a border style's 8 bytes. This is VTUIlib's order, kept verbatim so the table
;		below is a checkable lift rather than a transcription: corners first as top-right,
;		top-left, bottom-right, bottom-left, then the four edges.
;
GPD_TR = 0
GPD_TL = 1
GPD_BR = 2
GPD_BL = 3
GPD_TOP = 4
GPD_BOTTOM = 5
GPD_LEFT = 6
GPD_RIGHT = 7

GPD_STYLES = 6

; ************************************************************************************************
;
;								GP.BOX x,y,w,h [,style] [,col]
;
; ************************************************************************************************

CommandGPBox: ;; [!gp.box]
		.entercmd
		phy
		ldx 	#5 							; every argument is numeric here
_CGBInteger:
		.floatinteger
		dex
		bpl 	_CGBInteger 				; leaves X = $FF, so X is free scratch from here on
		;
		jsr 	GPDrawGeometry
		beq 	_CGBExit
		lda 	gpdW 						; a box needs two columns and two rows to have two
		cmp 	#2 							; corners; anything less has no drawing to do that
		bcc 	_CGBExit 					; would not be a lie about what was asked for
		lda 	gpdH
		cmp 	#2
		bcc 	_CGBExit
		;
		ldx 	#5
		jsr 	GPDrawColour
		;
		lda 	NSMantissa0+4 				; the style, as an offset into the glyph table
		cmp 	#GPD_STYLES
		bcs 	_CGBBadStyle
		asl 	a
		asl 	a
		asl 	a
		tax 								; and X holds it for the whole of the drawing below,
		 									; because TileSetAddress leaves X alone
		;
		jsr 	GPDrawAddress 				; the top row: corner, edge run, corner
		lda 	GPDrawBorder+GPD_TL,x
		jsr 	GPDrawPutCell
		lda 	GPDrawBorder+GPD_TOP,x
		jsr 	GPDrawRun
		lda 	GPDrawBorder+GPD_TR,x
		jsr 	GPDrawPutCell
		;
		lda 	gpdH 						; the sides: two cells a row, so they are addressed
		sec 								; individually rather than walked
		sbc 	#2
		sta 	gpdCount
		beq 	_CGBBottom
_CGBSide:
		inc 	gpdY
		jsr 	GPDrawAddress
		lda 	GPDrawBorder+GPD_LEFT,x
		jsr 	GPDrawPutCell
		lda 	gpdX
		clc
		adc 	gpdW
		dec 	a 							; x + w - 1, the far column
		jsr 	GPDrawAddressA
		lda 	GPDrawBorder+GPD_RIGHT,x
		jsr 	GPDrawPutCell
		dec 	gpdCount
		bne 	_CGBSide
_CGBBottom:
		inc 	gpdY
		jsr 	GPDrawAddress
		lda 	GPDrawBorder+GPD_BL,x
		jsr 	GPDrawPutCell
		lda 	GPDrawBorder+GPD_BOTTOM,x
		jsr 	GPDrawRun
		lda 	GPDrawBorder+GPD_BR,x
		jsr 	GPDrawPutCell
_CGBExit:
		ply
		ldx 	#$FF
		.exitcmd

_CGBBadStyle:
		ply
		.error_range

; ************************************************************************************************
;
;								GP.FILL x,y,w,h,char [,col]
;
; ************************************************************************************************

CommandGPFill: ;; [!gp.fill]
		.entercmd
		phy
		ldx 	#5
_CGFInteger:
		.floatinteger
		dex
		bpl 	_CGFInteger
		;
		jsr 	GPDrawGeometry
		beq 	_CGFExit
		ldx 	#5
		jsr 	GPDrawColour
		lda 	NSMantissa0+4 				; the character is converted ONCE, not per cell
		jsr 	GPDrawPet2Scr
		sta 	gpdChar
_CGFRow:
		jsr 	GPDrawAddress 				; one address per row; the increment does the rest
		ldy 	gpdW
		lda 	gpdChar 					; GPDrawPutCell hands A back, so it is loaded once
_CGFCell:
		jsr 	GPDrawPutCell
		dey
		bne 	_CGFCell
		inc 	gpdY
		dec 	gpdH
		bne 	_CGFRow
_CGFExit:
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;								GP.PRINTAT x,y,text$ [,col]
;
;		IT FOLLOWS THE SCREEN INTO ISO MODE, per character, for five bytes and no keyword.
;
;		In ISO mode (PRINT CHR$(15), or the user pressing Ctrl+O) the VERA tile index IS the
;		character code, so translating PETSCII to a screen code is not merely wasted work, it is
;		WRONG: 'A' would go in as $01 and the string would come out as garbage. That made every
;		drawn interface -- INPHELP's fields, MENUHELP's bars -- unusable in ISO mode, which is
;		exactly the mode a program wants when it needs both letter cases.
;
;		BIT X16_EditorMode puts the KERNAL's own ISO bit into V and leaves A, X and Y untouched,
;		so the test costs 4 cycles and no register in the middle of a character loop. Asking the
;		KERNAL rather than being told means there is nothing to declare and nothing to get wrong:
;		no keyword, no argument threaded through every caller, no mode variable to leave stale.
;		Every existing program that switches charset is simply correct now, unchanged.
;
;		The bill is +7 cycles a cell in PETSCII mode, 94 -> 101, against 41 SAVED in ISO mode
;		(94 -> 60) because the whole GPDrawPet2Scr call goes away. Hoisting the test above the
;		loop would buy back the 7 for about eight more bytes of a block with 36 free; it is not
;		worth it at seven cycles on a command that draws chrome, not inner loops.
;
;		GP.FILL needs none of this. It converts its ONE character before the loop, and $20 is a
;		fixed point of the offset table ($20>>5 = 1, offset $00), so a space fill -- which is what
;		padding and blanking are, and all the library does -- is already right in both modes.
;
; ************************************************************************************************

CommandGPPrintAt: ;; [!gp.printat]
		.entercmd
		phy
		ldx 	#1 							; x and y. Slot 2 is the STRING and must not be run
_CGPInteger: 								; through FloatIntegerPart at all
		.floatinteger
		dex
		bpl 	_CGPInteger
		ldx 	#3
		.floatinteger 						; the optional colour, past the string
		;
		lda 	NSMantissa0+0
		sta 	gpdX
		lda 	NSMantissa0+1
		sta 	gpdY
		ldx 	#3
		jsr 	GPDrawColour
		;
		lda 	NSMantissa0+2 				; the stack carries the address of [length][data]
		sta 	zTemp0
		lda 	NSMantissa1+2
		sta 	zTemp0+1
		lda 	(zTemp0)
		beq 	_CGPExit 					; an empty string draws nothing
		sta 	gpdCount
		;
		jsr 	GPDrawAddress 				; addressed once for the whole string
_CGPChar:
		inc 	zTemp0 						; pre-bumped, so the length byte is stepped over
		bne 	_CGPNoCarry
		inc 	zTemp0+1
_CGPNoCarry:
		lda 	(zTemp0)
		bit 	X16_EditorMode 				; bit 6 -> V. BIT leaves A alone, which is the point:
		bvs 	_CGPRaw 					; in ISO mode the byte already IS the tile index
		jsr 	GPDrawPet2Scr
_CGPRaw:
		jsr 	GPDrawPutCell
		dec 	gpdCount
		bne 	_CGPChar
_CGPExit:
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;		x, y, w and h out of stack slots 0..3. Returns Z SET when there is nothing to draw --
;		either dimension zero -- which every caller tests, because a zero count would otherwise
;		count down through 256 cells and scribble over a whole screen.
;
; ************************************************************************************************

GPDrawGeometry:
		lda 	NSMantissa0+0
		sta 	gpdX
		lda 	NSMantissa0+1
		sta 	gpdY
		lda 	NSMantissa0+2
		sta 	gpdW
		lda 	NSMantissa0+3
		sta 	gpdH
		beq 	_GDGNone 					; h = 0, and Z is already set
		lda 	gpdW 						; otherwise the answer is whether w is zero
_GDGNone:
		rts

; ************************************************************************************************
;
;		The optional colour, out of the stack slot named by X. A non-zero HIGH byte is the 256
;		that OptionalColourCompile pushes for "omitted", which no real attribute can produce.
;
; ************************************************************************************************

GPDrawColour:
		lda 	NSMantissa1,x
		beq 	_GDCGiven
		lda 	X16_TextColour 				; what COLOR last set, already in attribute packing
		sta 	gpdCol
		rts
_GDCGiven:
		lda 	NSMantissa0,x
		sta 	gpdCol
		rts

; ************************************************************************************************
;
;		Point VERA at column A (GPDrawAddressA) or at gpdX (GPDrawAddress) of row gpdY, with the
;		auto-increment set so that consecutive accesses walk character, attribute, character...
;		TileSetAddress is the primitive TILE uses; it derives the map base and the row stride from
;		VERA rather than assuming them, and it does not touch X.
;
; ************************************************************************************************

GPDrawAddress:
		lda 	gpdX
GPDrawAddressA:
		sta 	tileX
		stz 	tileX+1
		lda 	gpdY
		sta 	tileY
		stz 	tileY+1
		jmp 	TileSetAddress

; ************************************************************************************************
;
;		Write the screen code in A and the current colour at the VERA address, and step on to the
;		next cell. A is preserved, so a caller can repeat one glyph without reloading it.
;
; ************************************************************************************************

GPDrawPutCell:
		sta 	VRAMData0
		pha
		lda 	gpdCol
		sta 	VRAMData0
		pla
		rts

;
;		The glyph in A, w-2 times: the run BETWEEN two corners. Only called after the w >= 2
;		check, so the double decrement cannot underflow.
;
GPDrawRun:
		ldy 	gpdW
		dey
		dey
		beq 	_GDRDone 					; w = 2 is two corners and no edge at all
_GDRLoop:
		jsr 	GPDrawPutCell
		dey
		bne 	_GDRLoop
_GDRDone:
		rts

; ************************************************************************************************
;
;		PETSCII in A to a screen code in A. Y is used; X is not.
;
;		The whole conversion is one add from a table indexed by the top three bits, which is how
;		prog8 does it and is far smaller than the chain of compares it replaces. $FF is the one
;		value the table cannot express -- pi is screen code $5E, and the arithmetic gives $7F --
;		so it is tested for. CHR$(222) is the same character and needs no special case.
;
; ************************************************************************************************

GPDrawPet2Scr:
		cmp 	#$FF
		beq 	_GP2SPi
		pha
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		tay
		pla
		clc
		adc 	GPDrawP2SOffset,y
		rts
_GP2SPi:
		lda 	#$5E
		rts

;
;		Added, not subtracted: every entry is the 8-bit offset from the PETSCII range to the
;		screen code range, so $C0 here means "minus $40".
;
GPDrawP2SOffset:
		.byte 	$80,$00,$C0,$E0,$40,$C0,$80,$80

; ************************************************************************************************
;
;		The six border styles, eight SCREEN CODES each, lifted byte for byte from VTUIlib (public
;		domain). Order per GPD_* above: TR, TL, BR, BL, top, bottom, left, right.
;
;		Verified against the ROM charset rather than taken on trust -- rendering the bitmaps out
;		of rom.bin is what settled the slot order, e.g. style 4's $77 is two filled rows at the
;		TOP of the cell and its $74 two filled columns at the LEFT, which no other reading fits.
;
; ************************************************************************************************

GPDrawBorder:
		.byte 	$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0 	; 0  solid block
		.byte 	$66,$66,$66,$66,$66,$66,$66,$66 	; 1  chequered dither
		.byte 	$6E,$70,$7D,$6D,$40,$40,$42,$42 	; 2  single line
		.byte 	$49,$55,$4B,$4A,$40,$40,$42,$42 	; 3  single line, rounded corners
		.byte 	$50,$4F,$7A,$4C,$77,$6F,$74,$6A 	; 4  thick line
		.byte 	$5F,$69,$E9,$DF,$77,$6F,$74,$6A 	; 5  thick line, shaded corners

		.send 	code

		.section storage
gpdX:
		.fill 	1
gpdY: 										; counts UP as the rows are drawn
		.fill 	1
gpdW:
		.fill 	1
gpdH: 										; counts DOWN as the rows are drawn
		.fill 	1
gpdChar: 									; GP.FILL's glyph, already a screen code
		.fill 	1
gpdCol: 									; the attribute written beside every character
		.fill 	1
gpdCount: 									; side rows for GP.BOX, characters for GP.PRINTAT
		.fill 	1
		.send 	storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		17/08/26		Written.
;
; ************************************************************************************************
