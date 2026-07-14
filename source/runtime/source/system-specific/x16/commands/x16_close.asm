; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_close.asm
;		Purpose:	CLOSE
;		Created:	2nd May 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;					<logical> CLOSE (cancels CMD effect if that channel closed)
;
; ************************************************************************************************

CommandClose: ;; [close]
		.entercmd
		phy 								; Y is the interpreter's instruction pointer and the
											; KERNAL's CLOSE is free to clobber it -- see the note
											; in x16_open.asm, which had the same bug
		jsr 	GetInteger8Bit 				; channel to close
		cmp 	currentChannel 				; is it the current channel
		bne 	_CCNotCurrent
		stz 	currentChannel 				; effectively disables CMD
_CCNotCurrent:
		jsr 	X16_CLOSE 					; close the file
		ply
		ldx 	#$FF 						; and empty the float stack, as every other command
											; does -- see the note in x16_open.asm
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
