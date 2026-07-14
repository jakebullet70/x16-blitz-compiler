; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		vera.inc
;		Purpose:	Vera constants
;		Created:	29th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code
		
VRAMLow0 = $9F20
VRAMMed0 = $9F21
VRAMHigh0 = $9F22
VRAMData0 = $9F23
;
;		VRAMHigh0 is not just the top address bit: 7:4 are the auto-increment, 3 is DECR,
;		2:1 are the nibble controls, and only bit 0 is VRAM address bit 16. So writing a
;		bare bank number (as VPOKE does) means "this bank, do not increment", and $10 is
;		the increment-by-one that lets consecutive reads or writes walk a structure.
;
VRAMBank1 = $01 							; VRAM address bit 16
VRAMIncrement1 = $10 						; step the address on by one after each access
;
VERACtrl = $9F25 							; 7 = reset, 6:1 = DCSEL, 0 = ADDRSEL
VERADCSelMask = $81 						; keep reset and ADDRSEL, clear DCSEL
VERADCVideo = $9F29 						; only at this address while DCSEL is zero
VERASpritesEnable = $40
;
VERAL1Config = $9F34 						; 7:6 map height, 5:4 map width, 1:0 colour depth
VERAL1MapBase = $9F35 						; map base address, bits 16:9
;
;		The 128 sprite attribute blocks are 8 bytes each, based at VRAM $1FC00. Sprite 127
;		starts at $FC00 + 127*8 = $FFF8, so the offset never carries out of the low 16 bits
;		and the VRAM bank is always 1.
;
SpriteAttributeBase = $FC 					; high byte of $FC00

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
