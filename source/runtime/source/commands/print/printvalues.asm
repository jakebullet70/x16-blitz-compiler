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
		lda 	#9 							; nine significant digits, as stock BASIC prints -- not
		jsr 	FloatToString 				; a fixed count of decimal places, see FloatToString
		dex 								; drop
		phx
		ldx 	#0 							; print buffer.
_PNLoop:
		lda 	decimalBuffer,x
		jsr 	VectorPrintCharacter
		inx
		lda	 	decimalBuffer,x
		bne 	_PNLoop
		;
		;		Trailing separator after a number, and stock picks it by DEVICE -- which is the
		;		bit this used to miss. It emitted $1D unconditionally, with a comment asserting
		;		that was what stock did; half right, and the confident half is the expensive
		;		half. Both halves measured with the project's differential oracle (same PRG,
		;		same ROM, once interpreted and once compiled):
		;
		;		  to the SCREEN   PRINT "HELLO";I;"X"          -> 'HELLO 1',$1D,'X'
		;		  to a FILE       PRINT#1,"A";123;"B"          -> 'A 123 B'   ($20)
		;
		;		They are not interchangeable even on screen: $1D steps over a cell and leaves
		;		what was there, $20 blanks it. Anything that redraws a field in place -- e.g.
		;		samples/FSIM16_V1's HUD -- depends on the difference. And to a file, to CMD or
		;		to a printer, $1D is a control code where stock writes a space, which is how
		;		that sample's FLIGHT.LOG came out different compiled than interpreted.
		;
		;		Channel 0 is the screen (SetDefaultChannel in print.asm). Only A may be used
		;		here: Y carries the p-code pointer across .exitcmd, and X is the decimalBuffer
		;		index the caller still needs.
		;
		;		The LEADING sign space comes out of FloatToString and was always right.
		;
		lda 	currentChannel
		beq 	_PNScreenSeparator
		lda 	#$20 						; file / printer / anything not the screen
		bra 	_PNEmitSeparator
_PNScreenSeparator:
		lda 	#$1D 						; screen: CRSR-RIGHT, preserving the cell it skips
_PNEmitSeparator:
		jsr 	VectorPrintCharacter
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
