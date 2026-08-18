; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpstash.asm
;		Purpose:	GP.STASH / GP.RESTR -- save and restore a text rectangle
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;				GP.STASH bank,x,y,w,h        GP.RESTR bank [,x,y]
;
;		Copy a rectangle of the text screen into a banked RAM bank, and put it back. The use is
;		the one every text UI needs: draw a menu or a dialogue over the screen, then restore what
;		was underneath without redrawing the program's own display.
;
;		Worth assembly by the rule in the plan: it is bulk data. A 40x10 panel is 800 bytes, and
;		the BASIC equivalent is 400 VPEEK/VPOKE pairs.
;
;		THE ADDRESSING IS TileSetAddress, tiles.asm -- the same primitive TILE, TDATA and TATTR
;		use. It reads the map base from VERAL1MapBase and the row stride from VERAL1Config bits
;		5:4 on every call, so ANY map width works, and it accumulates in 24 bits because a
;		256 x 256 map of two byte entries is the whole 128K of VRAM.
;
;		This started out hand-rolled, with a check that the map was 128 tiles wide so a row step
;		could be a single inc of the middle address byte. That check was a restriction dressed up
;		as a guard: TileSetAddress had the general answer all along and is SMALLER than the
;		special case was.
;
;		THE STASH IS SELF-DESCRIBING. Four header bytes go in first -- w, h, x, y -- so GP.RESTR
;		needs only the bank. That fixes the flaw dotBASIC admits to in its own .CUT/.PASTE, which
;		"requires correctly re-describing the width and height of each cut". Supplying x,y to
;		GP.RESTR pastes the rectangle somewhere else instead, which is copy-and-paste for free.
;
;		A BANK IS 8192 BYTES and a cell is two of them, so the most that fits is 4094 cells --
;		a full 80x60 screen is 9,600 bytes and does NOT fit. The limit is enforced per row, before
;		the write that would cross $C000, so an over-large rectangle is an error and never a
;		corruption of the next bank.
;
; ************************************************************************************************

GPS_BANKREG = 0 							; the X16 RAM bank select register
GPS_WINDOW  = $A000 						; where the selected bank appears
GPS_WINDEND = $C000

CommandGPStash: ;; [!gp.stash]
		.entercmd
		phy
		jsr 	GPStashArgs 				; h,w,y,x,bank off the stack, VERA set up
		;
		lda 	gssW 						; the header describes the stash, so GP.RESTR needs
		sta 	GPS_WINDOW 					; only the bank
		lda 	gssH
		sta 	GPS_WINDOW+1
		lda 	gssX
		sta 	GPS_WINDOW+2
		lda 	gssY
		sta 	GPS_WINDOW+3
		;
		lda 	#<(GPS_WINDOW+4) 			; data follows the header
		sta 	zTemp0
		lda 	#>(GPS_WINDOW+4)
		sta 	zTemp0+1
		;
_GSTRow:
		jsr 	GPStashRowFits 				; would this row cross out of the bank ?
		jsr 	GPStashSetVera 				; point VERA at the start of the row
		ldy 	#0
_GSTByte:
		lda 	VRAMData0 					; the address auto-increments, so this walks the row
		sta 	(zTemp0),y
		iny
		cpy 	gssW2
		bne 	_GSTByte
		jsr 	GPStashNextRow
		bne 	_GSTRow
		jmp 	GPStashDone

; ************************************************************************************************

CommandGPRestore: ;; [!gp.restr]
		.entercmd
		phy
		;
		;		<y> and <x> are optional and default to 255. 0 could not have doubled as the
		;		sentinel here, because 0 is a perfectly good place to paste a rectangle.
		;
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssY
		dex
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssX
		dex
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssBank
		dex
		;
		jsr 	GPStashBankIn 				; select the bank and check the screen layout
		;
		lda 	GPS_WINDOW 					; geometry comes from the header
		sta 	gssW
		lda 	GPS_WINDOW+1
		sta 	gssH
		lda 	gssX 						; unless the caller named a destination
		cmp 	#255
		bne 	_GSRHaveXY
		lda 	GPS_WINDOW+2
		sta 	gssX
		lda 	GPS_WINDOW+3
		sta 	gssY
_GSRHaveXY:
		jsr 	GPStashGeometry 			; validate w/h and work out the row width
		;
		lda 	#<(GPS_WINDOW+4)
		sta 	zTemp0
		lda 	#>(GPS_WINDOW+4)
		sta 	zTemp0+1
		;
_GSRRow:
		jsr 	GPStashRowFits
		jsr 	GPStashSetVera
		ldy 	#0
_GSRByte:
		lda 	(zTemp0),y 					; the only difference from the stash loop is the
		sta 	VRAMData0 					; direction of this pair
		iny
		cpy 	gssW2
		bne 	_GSRByte
		jsr 	GPStashNextRow
		bne 	_GSRRow
		jmp 	GPStashDone

; ************************************************************************************************
;
;		Read h,w,y,x,bank off the stack (h was pushed last), select the bank, and validate.
;
; ************************************************************************************************

GPStashArgs:
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssH
		dex
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssW
		dex
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssY
		dex
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssX
		dex
		jsr 	FloatIntegerPart
		lda 	NSMantissa0,x
		sta 	gssBank
		dex
		jsr 	GPStashBankIn
		;		fall through to the geometry check

;
;		w and h must be usable, and w*2 MUST fit a byte -- the inner loop counts it in Y, and the
;		row-fits check adds it to a pointer. w = 128 doubles to zero and defeats both, which is
;		exactly how an over-large rectangle got through the first time this was tested.
;
GPStashGeometry:
		lda 	gssW
		beq 	_GSGBad
		cmp 	#128 						; 127 is the limit, NOT 128: w*2 has to fit a byte so the
		bcs 	_GSGBad 					; inner loop can count it in Y, and 128*2 is 0 in a byte
		 									; -- which silently made every size guard below see a
		 									; zero-width row and pass. Same boundary that bit
		 									; GPSortElementY. 127 columns is wider than a screen.
		lda 	gssH
		beq 	_GSGBad
		cmp 	#65
		bcs 	_GSGBad
		lda 	gssW 						; the row width in BYTES, two per cell
		asl 	a
		sta 	gssW2
		rts
_GSGBad:
		jmp 	GPStashRange

;
;		Select the bank. The previous bank is saved and put back at the end -- a command that
;		silently repointed $A000 would be a trap of exactly the kind this codebase already has
;		too many of.
;
GPStashBankIn:
		lda 	GPS_BANKREG
		sta 	gssOldBank
		lda 	gssBank
		sta 	GPS_BANKREG
		rts

; ************************************************************************************************
;
;		Point VERA at (gssX, gssY), with the auto-increment set so the row walks itself. Any map
;		width, because TileSetAddress derives the stride rather than assuming it.
;
; ************************************************************************************************

GPStashSetVera:
		lda 	gssX
		sta 	tileX
		stz 	tileX+1
		lda 	gssY
		sta 	tileY
		stz 	tileY+1
		jmp 	TileSetAddress 				; X is untouched by it, which is what matters here

;
;		Advance to the next screen row and the next slot in the bank. Returns Z set when the
;		last row has been done.
;
GPStashNextRow:
		inc 	gssY
		clc
		lda 	zTemp0
		adc 	gssW2
		sta 	zTemp0
		bcc 	_GSNRNoCarry
		inc 	zTemp0+1
_GSNRNoCarry:
		dec 	gssH
		rts

;
;		Would the row about to be copied run past the end of the bank window? Checked BEFORE the
;		write rather than after, so an over-large rectangle is an error and never a corruption of
;		whatever the next bank holds.
;
GPStashRowFits:
		clc
		lda 	zTemp0
		adc 	gssW2
		lda 	zTemp0+1
		adc 	#0
		cmp 	#>GPS_WINDEND
		bcs 	_GSRFBad
		rts
_GSRFBad:
		jmp 	GPStashRange

;
;		Shared exit: put the caller's bank back, restore the code pointer, and leave.
;
GPStashDone:
		lda 	gssOldBank
		sta 	GPS_BANKREG
		ply
		.exitcmd

GPStashRange:
		lda 	gssOldBank 					; the bank must go back even on the error path, or the
		sta 	GPS_BANKREG 				; program continues with $A000 pointing somewhere else
		ply
		.error_range

		.send 	code

		.section storage
gssBank: 									; the bank being written to or read from
		.fill 	1
gssOldBank: 								; whatever was selected before, put back on the way out
		.fill 	1
gssX:
		.fill 	1
gssY:
		.fill 	1
gssW:
		.fill 	1
gssH: 										; counts DOWN as the rows are done
		.fill 	1
gssW2: 										; the row width in bytes, w*2
		.fill 	1
		.send 	storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		17/08/26		Written.
;		17/08/26		Re-based on TileSetAddress: any map width, and smaller.
;
; ************************************************************************************************
