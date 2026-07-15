; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		printvalues.asm
;		Purpose:	Print String/Number
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						  				Print number
;
; ************************************************************************************************

PrintNumber: ;; [print.n]
		.entercmd
		lda 	#7
		jsr 	FloatToString 				; to number in decimal buffer
		dex 								; drop
		phx
		ldx 	#0 							; print buffer.
_PNLoop:
		lda 	decimalBuffer,x
		jsr 	VectorPrintCharacter
		inx
		lda	 	decimalBuffer,x
		bne 	_PNLoop
		lda 	#$1D 						; trailing CRSR-RIGHT, as stock BASIC does -- it looks
		jsr 	VectorPrintCharacter 		; like a space on screen but writes $1D not $20 to a
											; file (PRINT#) or through CMD, which is what stock does
		plx
		.exitcmd

; ************************************************************************************************
;
;						  				Print string
;
; ************************************************************************************************

PrintString: ;; [print.s]
		.entercmd
		lda 	NSMantissa0,x 				; point zTemp0 to string
		sta 	zTemp0
		lda 	NSMantissa1,x
		sta 	zTemp0+1
		dex 								; drop
		phx
		phy
		lda 	(zTemp0) 					; X = count
		tax
		ldy 	#1 							; Y = position
_PSLoop:
		cpx 	#0 							; complete ?
		beq 	_PSExit
		dex 								; dec count
		lda 	(zTemp0),y 					; print char and bump
		jsr 	VectorPrintCharacter
		iny
		bra 	_PSLoop

_PSExit:
		ply
		plx
		.exitcmd


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
