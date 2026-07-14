; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		sprites.asm
;		Purpose:	SPRITE, SPRMEM and MOVSPR
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		These three write VERA's sprite attributes directly, because there is no ROM layer to
;		call. The KERNAL does have sprite_set_image and sprite_set_position, but neither is the
;		right shape: sprite_set_position only handles sprites 0-31 where MOVSPR takes 0-127, and
;		sprite_set_image converts pixel data out of host RAM where SPRMEM merely points a sprite
;		at pixels already sitting in VRAM. BASIC writes the attributes itself, and so do we.
;
;		A sprite's 8 attribute bytes (VERA reference, "Sprite attributes"):
;
;			0	Address (12:5)
;			1	7 = mode (0 = 4bpp, 1 = 8bpp), 3:0 = Address (16:13)
;			2	X (7:0)
;			3	1:0 = X (9:8)
;			4	Y (7:0)
;			5	1:0 = Y (9:8)
;			6	7:4 = collision mask, 3:2 = Z-depth, 1 = V-flip, 0 = H-flip
;			7	7:6 = height, 5:4 = width, 3:0 = palette offset
;
;		EVERY OPTIONAL PARAMETER IS READ-MODIFY-WRITE. The compiler pushes 255 for an argument
;		that was not supplied (OptionalParameterCompile), and 255 is out of range for all of
;		these fields -- the widest is a nibble -- so it makes an unambiguous "leave this alone".
;		That is not a convenience, it is required: the manual's own example is
;
;			20 SPRMEM 1,1,$3000,1
;			30 SPRITE 1,3,0,0,3,3
;
;		where SPRITE omits the colour depth. Defaulting it to 0 would silently undo the 8bpp
;		that SPRMEM just set on the line before.
;
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;			SPRITE <idx>,<priority>[,<paloffset>[,<flip>[,<x-width>[,<y-width>[,<depth>]]]]]
;
; ************************************************************************************************

Command_SPRITE: ;; [!sprite]
		.entercmd
		phy
		ldx 	#6 							; make all seven parameters integers up front, so
_CSPInteger: 								; that nothing below has to worry about floats
		.floatinteger
		dex
		bpl 	_CSPInteger

		;
		;		Byte 6 : Z-depth and the flip bits. The collision mask lives in the top nibble
		;		of the same byte and no keyword touches it, so it has to survive.
		;
		lda 	NSMantissa0+0 				; sprite index
		ldy 	#6
		jsr 	SpriteSetAddress
		lda 	VRAMData0
		sta 	spriteByte

		lda 	NSMantissa0+1 				; priority is the Z-depth, bits 3:2
		cmp 	#255
		beq 	_CSPNoPriority
		and 	#3
		asl 	a
		asl 	a
		sta 	spriteTemp
		lda 	spriteByte
		and 	#$F3
		ora 	spriteTemp
		sta 	spriteByte
_CSPNoPriority:
		lda 	NSMantissa0+3 				; BASIC's flip is bit 0 = "X is flipped" and bit 1 =
		cmp 	#255 						; "Y is flipped"; VERA's byte 6 is bit 0 = H-flip and
		beq 	_CSPNoFlip 					; bit 1 = V-flip. Same two bits in the same order, so
		and 	#3 							; the parameter drops straight in.
		sta 	spriteTemp
		lda 	spriteByte
		and 	#$FC
		ora 	spriteTemp
		sta 	spriteByte
_CSPNoFlip:
		lda 	spriteByte 					; the increment is zero, so this goes back to byte 6
		sta 	VRAMData0

		;
		;		Byte 7 : palette offset, and the two size fields.
		;
		lda 	NSMantissa0+0
		ldy 	#7
		jsr 	SpriteSetAddress
		lda 	VRAMData0
		sta 	spriteByte

		lda 	NSMantissa0+2 				; palette offset, bits 3:0
		cmp 	#255
		beq 	_CSPNoPalette
		and 	#$0F
		sta 	spriteTemp
		lda 	spriteByte
		and 	#$F0
		ora 	spriteTemp
		sta 	spriteByte
_CSPNoPalette:
		lda 	NSMantissa0+4 				; x-width is VERA's sprite width, bits 5:4
		cmp 	#255
		beq 	_CSPNoWidth
		and 	#3
		asl 	a
		asl 	a
		asl 	a
		asl 	a
		sta 	spriteTemp
		lda 	spriteByte
		and 	#$CF
		ora 	spriteTemp
		sta 	spriteByte
_CSPNoWidth:
		lda 	NSMantissa0+5 				; y-width is VERA's sprite height, bits 7:6
		cmp 	#255
		beq 	_CSPNoHeight
		and 	#3
		asl 	a
		asl 	a
		asl 	a
		asl 	a
		asl 	a
		asl 	a
		sta 	spriteTemp
		lda 	spriteByte
		and 	#$3F
		ora 	spriteTemp
		sta 	spriteByte
_CSPNoHeight:
		lda 	spriteByte
		sta 	VRAMData0

		;
		;		Byte 1 : the colour depth shares a byte with the top of the pixel address, so
		;		it is only touched when it was actually given.
		;
		lda 	NSMantissa0+6
		cmp 	#255
		beq 	_CSPNoDepth
		lda 	NSMantissa0+0
		ldy 	#1
		jsr 	SpriteSetAddress
		lda 	VRAMData0
		ldy 	NSMantissa0+6
		jsr 	SpriteApplyDepth
		sta 	VRAMData0
_CSPNoDepth:
		jsr 	SpriteEnableLayer 			; "If VERA's sprite layer is disabled when the SPRITE
											; command is called, the sprite layer will be enabled"
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;					SPRMEM <idx>,<VRAM bank>,<VRAM address>[,<depth>]
;
; ************************************************************************************************

Command_SPRMEM: ;; [!sprmem]
		.entercmd
		phy
		ldx 	#3
_CSMInteger:
		.floatinteger
		dex
		bpl 	_CSMInteger

		;
		;		The pixel address is 17 bits -- the bank is bit 16 -- and the attribute holds it
		;		shifted right by five. That shift is the manual's "the lowest 5 bits are ignored".
		;
		;			byte 0 = Address (12:5)  = (high & $1F) << 3 | low >> 5
		;			byte 1 = Address (16:13) = bank << 3 | high >> 5
		;
		lda 	NSMantissa1+2 				; address, high byte
		and 	#$1F
		asl 	a
		asl 	a
		asl 	a
		sta 	spriteTemp
		lda 	NSMantissa0+2 				; address, low byte
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		ora 	spriteTemp
		sta 	spriteByte

		lda 	NSMantissa1+2
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		sta 	spriteTemp
		lda 	NSMantissa0+1 				; VRAM bank, 0 or 1, becomes address bit 16
		and 	#1
		asl 	a
		asl 	a
		asl 	a
		ora 	spriteTemp
		sta 	spriteTemp

		lda 	NSMantissa0+0
		ldy 	#0
		jsr 	SpriteSetAddress
		lda 	spriteByte
		sta 	VRAMData0 					; byte 0

		lda 	NSMantissa0+0
		ldy 	#1
		jsr 	SpriteSetAddress
		lda 	VRAMData0 					; byte 1 carries the mode bit as well as the top of
		and 	#$80 						; the address, and the depth is optional, so read it
		ora 	spriteTemp 					; back and keep bit 7 unless we were given one
		ldy 	NSMantissa0+3
		jsr 	SpriteApplyDepth
		sta 	VRAMData0
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;								MOVSPR <idx>,<x>,<y>
;
; ************************************************************************************************

Command_MOVSPR: ;; [!movspr]
		.entercmd
		phy
		;
		;		x and y are signed, and the manual says they "wrap every 1024 values" -- -10 and
		;		1014 are the same place. VERA's X and Y are 10 bit fields, so taking the low ten
		;		bits of the two's complement value IS that wrap, with nothing to special-case.
		;		GetInteger16Bit hands back exactly that two's complement value.
		;
		ldx 	#2
		jsr 	GetInteger16Bit 			; y
		lda 	zTemp0
		sta 	spriteY
		lda 	zTemp0+1
		and 	#3
		sta 	spriteY+1

		dex
		jsr 	GetInteger16Bit 			; x
		lda 	zTemp0
		sta 	spriteX
		lda 	zTemp0+1
		and 	#3
		sta 	spriteX+1

		lda 	NSMantissa0+0 				; sprite index; bytes 2..5 are written in order so
		ldy 	#2 							; the auto-increment can walk them
		jsr 	SpriteSetAddressInc
		lda 	spriteX
		sta 	VRAMData0 					; byte 2 : X (7:0)
		lda 	spriteX+1
		sta 	VRAMData0 					; byte 3 : X (9:8)
		lda 	spriteY
		sta 	VRAMData0 					; byte 4 : Y (7:0)
		lda 	spriteY+1
		sta 	VRAMData0 					; byte 5 : Y (9:8)
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;		Point VERA data port 0 at byte Y of sprite A's attribute block. A is the sprite index
;		and Y the offset 0-7. The float stack pointer X is not touched.
;
; ************************************************************************************************

SpriteSetAddress: 							; leave the address alone after each access
		pha
		lda 	#VRAMBank1
		bra 	SpriteSetAddressCommon

SpriteSetAddressInc: 						; step it on by one, to walk a run of bytes
		pha
		lda 	#VRAMBank1 | VRAMIncrement1

;		This scratches spriteLow/spriteMed/spriteHigh and NOTHING else. It must not touch
;		spriteTemp: SPRMEM works out an attribute byte and only then calls this to point at
;		where the byte goes, so anything this borrowed would be destroyed on the way.

SpriteSetAddressCommon: 					; global, not a cheap local: SpriteSetAddress branches
		sta 	spriteHigh 					; in from its own scope, and _locals do not cross one
		pla
		and 	#$7F 						; sprite index is 0-127
		stz 	spriteMed
		asl 	a 							; spriteMed:A = index x 8, the block's byte offset
		rol 	spriteMed 					; from $1FC00. The top comes out at index >> 5, which
		asl 	a 							; is at most 3.
		rol 	spriteMed
		asl 	a
		rol 	spriteMed
		sta 	spriteLow
		tya 								; the low three bits of index x 8 are clear and Y is
		ora 	spriteLow 					; 0-7, so the byte offset just ORs in
		sta 	VRAMLow0
		lda 	spriteMed
		clc
		adc 	#SpriteAttributeBase 		; never carries: 3 + $FC = $FF
		sta 	VRAMMed0
		lda 	spriteHigh
		sta 	VRAMHigh0
		rts

; ************************************************************************************************
;
;		Apply an optional colour depth to attribute byte 1, which arrives in A. The parameter
;		is in Y, and 255 means it was not supplied, so the mode bit is left as it was.
;
; ************************************************************************************************

SpriteApplyDepth:
		cpy 	#255
		beq 	_SADExit
		and 	#$7F 						; 0 = 4bpp, anything else = 8bpp
		cpy 	#0
		beq 	_SADExit
		ora 	#$80
_SADExit:
		rts

; ************************************************************************************************
;
;		Switch VERA's sprite layer on. DC_VIDEO is only at $9F29 while DCSEL is zero, and a
;		program is free to have left DCSEL pointing anywhere, so park it and put it back.
;
; ************************************************************************************************

SpriteEnableLayer:
		lda 	VERACtrl
		pha
		and 	#VERADCSelMask 				; DCSEL is bits 6:1; clear it, keep reset and ADDRSEL
		sta 	VERACtrl
		lda 	VERADCVideo
		ora 	#VERASpritesEnable
		sta 	VERADCVideo
		pla
		sta 	VERACtrl
		rts

		.send 	code

		.section storage
spriteLow: 									; SpriteSetAddress's private scratch -- see the note
		.fill 	1 							; there, it must not overlap spriteTemp
spriteMed:
		.fill 	1
spriteHigh:
		.fill 	1
spriteTemp: 								; a field being assembled by the caller
		.fill 	1
spriteByte: 								; the attribute byte being read-modify-written
		.fill 	1
spriteX:
		.fill 	2
spriteY:
		.fill 	2
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
