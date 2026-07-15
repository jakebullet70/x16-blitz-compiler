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
		cpx 	#0 							; is it the default channel (the keyboard) ?
		bne 	_XGetChannel
		jsr 	X16_CLRCHN 					; yes: restore default I/O
		jsr 	X16_GETIN 					; GETIN returns 0 when no key is waiting, which the
		ply 								; caller's poll loop relies on -- a blocking read here
		plx 								; would stop INPUT/LINPUT echoing as the user types.
		rts
_XGetChannel:
		jsr 	X16_CHKIN					; a real channel: a file, or the device command channel
		jsr 	X16_READST 					; at end of file ?
		and 	#$40 						; bit 6 is the KERNAL EOF flag (same test as linput.asm
		bne 	_XGCEndOfFile 				; and st.asm). If so, stop here -- do not read past it.
		jsr 	X16_CHRIN 					; read the next byte. CHRIN reads a channel properly;
		ply 								; GETIN returns 0 for a serial device, which made INPUT#
		plx 								; spin forever on the command channel (e.g. reading the
		rts 								; DOS status to see whether a file exists).
_XGCEndOfFile:
		ply 								; End of the channel's data: return CR, which ends the
		plx 								; current INPUT line/field exactly as a delimiter would,
		lda 	#13 						; rather than aborting the whole program. A non-zero
		rts 								; status that is NOT end of file (e.g. the stale DOS error
											; a failed OPEN leaves -- which is how the "does this file
											; exist?" idiom reads the command channel) is ignored, so
											; the read still happens. Interpreted BASIC ignores it too.

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
