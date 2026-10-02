; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		print.asm
;		Purpose:	Print Indirection Control etc.
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;							Get/Set Print Channel from/to stack
;
; ************************************************************************************************

GetChannel: ;; [getchannel]
		.entercmd
		lda 	currentChannel
		inx
		jsr 	FloatSetByte
		.exitcmd

;
;		The compiler emits this before and after every statement that names a channel, so each
;		one ends with the channel released, as PRINT# and INPUT# do in ROM BASIC. A disk command
;		runs when its channel is released, not when its last character arrives.
;
SetChannel: ;; [setchannel]
		.entercmd
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	currentChannel
		dex
		phx 								; the float stack
		phy 								; the instruction pointer
		jsr 	X16_CLRCHN
		ply
		plx
		.exitcmd

SetDefaultChannel:
		stz 	currentChannel
		rts

; ************************************************************************************************
;
;						  				Print Character
;
; ************************************************************************************************

VectorPrintCharacter:
		phx
		ldx 	currentChannel

;
;		Check we're sending it to the correct channel.
;
;		pha
;		txa
;		ora 	#48
;		jsr 	XPrintCharacterToChannel
;		pla

		jsr 	XPrintCharacterToChannel
		plx
		rts

; ************************************************************************************************
;
;						  				Get Character
;
; ************************************************************************************************

VectorGetCharacter:
		phx
		ldx 	currentChannel
		jsr 	XGetCharacterFromChannel
		plx
		rts

		.send code

		.section storage
currentChannel:
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
