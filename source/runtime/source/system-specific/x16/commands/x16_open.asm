; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_open.asm
;		Purpose:	OPEN
;		Created:	2nd May 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;					<logical> <device> <secondary> <filename> OPEN command
;
; ************************************************************************************************

CommandXOpen: ;; [open]
		.entercmd
		phy 								; Y is the INTERPRETER'S INSTRUCTION POINTER -- the
											; offset from codePtr that NextCommand fetches through.
											; SETLFS loads Y with the secondary address, so without
											; this, every OPEN resumed execution at codePtr plus
											; whatever the KERNAL left in Y, and whether the program
											; survived was pure luck of code layout: the same OPEN
											; worked at one line offset and crashed at another.
		;
		;		Set up the file name
		;
		lda 	NSMantissa0+3  				; point zTemp0 to string head, also in XY
		sta 	zTemp0
		tax
		lda 	NSMantissa1+3
		sta 	zTemp0+1
		tay

		inx 								; XY points to first character
		bne 	_CONoCarry
		iny
_CONoCarry:
		lda 	(zTemp0) 					; get length of filename
		jsr 	X16_SETNAM
		;
		; 		Set up the logical channel.
		;
		lda 	NSMantissa0+0
		ldx 	NSMantissa0+1
		ldy 	NSMantissa0+2
		jsr 	X16_SETLFS
		;
		;		Open
		;
		jsr 	X16_OPEN
		bcs 	_COError
		ply
		ldx 	#$FF 						; empty the float stack, as every other command does.
											; This is NOT cosmetic: OPEN reads its arguments from
											; slots 0-3 ABSOLUTELY, which only works if the stack
											; started empty. Leaving X at 3 meant a SECOND OPEN in
											; a program read garbage and handed the KERNAL a junk
											; filename pointer.
		.exitcmd
_COError:
		ply 								; the error report prints codePtr+Y, so put Y back
		.error_channel 						; first or the @ address is nonsense

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
