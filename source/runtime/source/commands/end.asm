; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		end.asm
;		Purpose:	END command
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;										END command
;
; ************************************************************************************************

CommandEnd: ;; [!end]
		.entercmd
		stx 	zTemp0
		clc 								; exited okay.
EndRuntime:
		php 								; restore default I/O before handing back to BASIC.
		jsr 	$FFCC 						; CLRCHN -- a program that read a file (e.g. GET#8 over
		plp 								; a directory) leaves the default input on device 8, and
											; BASIC's READY loop then reads EOF from it forever --
											; the screen scrolls blank lines without end. Stock
											; BASIC does this on END; the runtime has to as well.
		ldx 	Runtime6502SP 				; set up the stack pointer
		txs
		rts

; ************************************************************************************************

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
