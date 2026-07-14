; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_getchar.asm
;		Purpose:	Character input interface
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code
		
; ************************************************************************************************
;
;						Get Input from Channel if available, else return 0
;										0 is the Keyboard
;
; ************************************************************************************************

XGetCharacterFromChannel:
		phx
		phy
		cpx 	#0 							; is it default
		bne 	_XGetChannel
		jsr 	X16_CLRCHN 					; set default channel
		bra 	_XGetChar
_XGetChannel:		
		jsr 	X16_CHKIN					; CHKIN set channel
		jsr 	X16_READST 					; check okay
		bne 	_XGCError
_XGetChar:		
		jsr 	X16_GETIN
		ply
		plx
		rts
_XGCError:
		ply 								; Y is the interpreter's instruction pointer and CHKIN has
		.error_channel 						; just trashed it. The error report prints codePtr+Y, so
											; without this the "@ $xxxx" names a line at random.

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
