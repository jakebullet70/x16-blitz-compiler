; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpmenu.asm
;		Purpose:	GP.MENU -- the menu interaction loop, and GP.SEL which reads its answer
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;						GP.MENU x,y,w,n,hotkeys$ [,flags]     ->  GP.SEL
;
;		BASL DRAWS THE MENU, THIS DRIVES IT. That split is the whole reason a menu costs one token
;		here where dotBASIC spent six: a menu waits on a HUMAN, so the speed argument that puts
;		sorting and screen copying in assembly does not apply to laying one out. What does not
;		belong in BASIC is the fiddly half -- reading keys, matching hotkeys, moving the highlight
;		without a flicker -- and that is exactly what this is.
;
;		So the caller has already drawn n rows, each w cells wide, the first at (x,y). This
;		highlights one, moves it with the cursor keys, and returns which row was chosen in GP.SEL:
;		1..n for a choice, and 0 for cancelled.
;
;		THE HIGHLIGHT IS A NIBBLE SWAP, and that is why the command takes no colours. A text cell's
;		attribute is (background << 4) | foreground, so exchanging the two nibbles is inverse video
;		-- whatever the caller drew, in whatever colours, highlights correctly and un-highlights
;		back to exactly what was there. A swap is its own inverse, so ONE routine does both, and
;		there is no "normal colour" to pass in, remember, or get wrong.
;
;		It also means the menu never repaints the text, only the attribute bytes, so moving the
;		highlight cannot disturb what BASL drew.
;
;		READ-MODIFY-WRITE OF A CELL NEEDS INCREMENT ZERO. VERA steps the address on every data
;		access, read included, so with the usual increment of 1 the write-back would land on the
;		next byte. TileSetAddress leaves increment 1, so the increment field is cleared before the
;		loop and the address stepped by hand -- two bytes a cell, because only the attribute is
;		being touched.
;
;		Keys: cursor up and down move, RETURN chooses, ESC and STOP cancel, and any other key is
;		tried against the hotkey string. A hotkey chooses its row immediately -- it does not merely
;		move the highlight there, which is what makes hotkeys worth having.
;
;		Hotkeys are matched WITHOUT CASE, through the same GPFoldUpper that GP.COMP and GP.SORT
;		use. hotkeys$ is one character per row in order; a shorter string simply means the later
;		rows have none, and an empty string means the menu is cursor-driven only.
;
; ************************************************************************************************

GPM_MUSTSEL  = 1 							; ESC does not cancel: only a real choice leaves
GPM_KEEPMARK = 2 							; leave the chosen row highlighted on the way out
GPM_NOWRAP   = 4 							; stop at the ends instead of wrapping round

GPM_DOWN  = $11 							; PETSCII cursor down / up, as GETIN reports them
GPM_UP    = $91
GPM_ENTER = $0D
GPM_ESC   = $1B
GPM_STOP  = $03

CommandGPMenu: ;; [!gp.menu]
		.entercmd
		phy
		ldx 	#3 							; x, y, w and n. Slot 4 is the hotkey STRING and must
_CGMInteger: 								; not be run through FloatIntegerPart at all
		.floatinteger
		dex
		bpl 	_CGMInteger
		ldx 	#5
		.floatinteger 						; the flags, past the string
		;
		lda 	NSMantissa0+0
		sta 	gpmX
		lda 	NSMantissa0+1
		sta 	gpmY
		lda 	NSMantissa0+2
		sta 	gpmW
		lda 	NSMantissa0+3
		sta 	gpmN
		lda 	NSMantissa0+5
		sta 	gpmFlags
		;
		stz 	gpmSel 						; 0 is the cancelled answer, and it is also what a
		lda 	gpmN 						; menu with no rows or no width returns -- without
		beq 	_CGMNothing 				; touching the screen or waiting for a key
		lda 	gpmW
		bne 	_CGMHaveMenu
_CGMNothing:
		jmp 	_CGMDone 					; the exit is past the whole loop, out of branch range
_CGMHaveMenu:
		;
		lda 	NSMantissa0+4 				; the hotkey string stays addressed for the whole
		sta 	zTemp1 						; loop: [length][data], as everything else here
		lda 	NSMantissa1+4
		sta 	zTemp1+1
		;
		inc 	gpmSel 						; start on the first row, showing where we are
		jsr 	GPMenuHighlight

_CGMKey:
		ldx 	#0 							; channel 0 is the keyboard. GETIN hands back 0 when
		jsr 	XGetCharacterFromChannel 	; nothing is waiting, so this is the wait.
		cmp 	#0
		beq 	_CGMKey
		sta 	gpmKey
		;
		cmp 	#GPM_DOWN
		beq 	_CGMDown
		cmp 	#GPM_UP
		beq 	_CGMUp
		cmp 	#GPM_ENTER
		beq 	_CGMChooseVia 				; these three leave via a trampoline: the handlers sit
		cmp 	#GPM_ESC 					; past the movement block, out of branch range, which
		beq 	_CGMCancelVia 				; 64tass catches rather than mis-assembling
		cmp 	#GPM_STOP
		beq 	_CGMCancelVia
		jmp 	_CGMHotkey
_CGMChooseVia:
		jmp 	_CGMChoose
_CGMCancelVia:
		jmp 	_CGMCancel

; ************************************************************************************************
;
;		Moving. The old row is un-highlighted first (the same call that highlighted it), the
;		selection moved, and the new row highlighted -- so only two rows are ever touched.
;
; ************************************************************************************************

_CGMDown:
		jsr 	GPMenuHighlight
		lda 	gpmSel
		cmp 	gpmN
		bcs 	_CGMDownEnd 				; already on the last row
		inc 	gpmSel
		bra 	_CGMShow
_CGMDownEnd:
		jsr 	GPMenuMayWrap
		bcc 	_CGMShow 					; NOWRAP: stay where we are, still highlighted
		lda 	#1
		sta 	gpmSel
		bra 	_CGMShow

_CGMUp:
		jsr 	GPMenuHighlight
		lda 	gpmSel
		cmp 	#2
		bcc 	_CGMUpEnd 					; already on the first row
		dec 	gpmSel
		bra 	_CGMShow
_CGMUpEnd:
		jsr 	GPMenuMayWrap
		bcc 	_CGMShow
		lda 	gpmN
		sta 	gpmSel
_CGMShow:
		jsr 	GPMenuHighlight
		jmp 	_CGMKey

; ************************************************************************************************
;
;		Leaving. A choice keeps gpmSel; a cancel zeroes it. Either way the highlight comes off
;		unless the caller asked to keep it, which is how a menu leaves its answer visible.
;
; ************************************************************************************************

_CGMCancel:
		lda 	gpmFlags
		and 	#GPM_MUSTSEL
		beq 	_CGMDoCancel
		jmp 	_CGMKey 					; MUST SELECT: escape is simply not an answer
_CGMDoCancel:
		jsr 	GPMenuHighlight
		stz 	gpmSel
		bra 	_CGMDone

_CGMChoose:
		lda 	gpmFlags
		and 	#GPM_KEEPMARK
		bne 	_CGMDone
		jsr 	GPMenuHighlight
_CGMDone:
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;		Anything else is tried as a hotkey. The scan stops at n even if the string is longer, so a
;		stray extra character cannot select a row that does not exist.
;
; ************************************************************************************************

_CGMHotkey:
		lda 	gpmKey
		jsr 	GPFoldUpper 				; the same fold GP.COMP and GP.SORT use
		sta 	gpmKey
		lda 	(zTemp1) 					; how many hotkeys were given
		beq 	_CGMKeyAgain 				; none at all: cursor keys only
		cmp 	gpmN
		bcc 	_CGMHaveLimit
		lda 	gpmN
_CGMHaveLimit:
		sta 	gpmLimit
		ldy 	#0
_CGMScan:
		iny
		lda 	(zTemp1),y
		jsr 	GPFoldUpper
		cmp 	gpmKey
		beq 	_CGMHit
		cpy 	gpmLimit
		bne 	_CGMScan
_CGMKeyAgain:
		jmp 	_CGMKey 					; no match: the key meant nothing, keep waiting

_CGMHit:
		sty 	gpmLimit 					; hold the row: BOTH calls below use Y and gpmTemp,
		jsr 	GPMenuHighlight 			; and gpmLimit is the one byte neither touches
		lda 	gpmLimit
		sta 	gpmSel
		jsr 	GPMenuHighlight 			; show the choice on its way past
		jmp 	_CGMChoose 					; a hotkey CHOOSES, it does not just move

; ************************************************************************************************
;
;		GP.SEL -- the row GP.MENU returned, 1..n, or 0 if it was cancelled. A value word rather
;		than a variable, exactly like GP.A and X16's own ST/MX/MY: nothing in the runtime can
;		write a BASIC variable by name.
;
; ************************************************************************************************

UnaryGPSel: ;; [!gp.sel]
		.entercmd
		lda 	gpmSel
		jmp 	GPRegPush 					; inx, FloatSetByte, and out -- shared with GP.A

; ************************************************************************************************
;
;		Carry SET if the selection is allowed to wrap round the ends.
;
; ************************************************************************************************

GPMenuMayWrap:
		lda 	gpmFlags
		and 	#GPM_NOWRAP
		beq 	_GMMWYes
		clc
		rts
_GMMWYes:
		sec
		rts

; ************************************************************************************************
;
;		Swap the attribute nibbles of row gpmSel's w cells: foreground and background trade
;		places, which is inverse video. Called once to highlight and again to un-highlight --
;		a nibble swap is its own inverse, so there is only ever one routine and one state.
;
; ************************************************************************************************

GPMenuHighlight:
		lda 	gpmX
		sta 	tileX
		stz 	tileX+1
		clc
		lda 	gpmY 						; row 1 is gpmY itself, so the offset is gpmSel-1
		adc 	gpmSel
		sta 	tileY
		dec 	tileY
		stz 	tileY+1
		jsr 	TileSetAddress
		;
		lda 	VRAMHigh0 					; increment ZERO: a read and a write must hit the same
		and 	#VRAMBank1 					; byte, and VERA steps the address on reads too
		sta 	VRAMHigh0
		inc 	VRAMLow0 					; the attribute is the second byte of the cell
		bne 	_GMHRow
		inc 	VRAMMed0
_GMHRow:
		ldy 	gpmW
_GMHCell:
		lda 	VRAMData0
		pha
		asl 	a 							; low nibble up
		asl 	a
		asl 	a
		asl 	a
		sta 	gpmTemp
		pla
		lsr 	a 							; high nibble down
		lsr 	a
		lsr 	a
		lsr 	a
		ora 	gpmTemp
		sta 	VRAMData0
		;
		clc 								; on to the next CELL, which is two bytes
		lda 	VRAMLow0
		adc 	#2
		sta 	VRAMLow0
		bcc 	_GMHNext
		inc 	VRAMMed0
_GMHNext:
		dey
		bne 	_GMHCell
		rts

		.send 	code

		.section storage
gpmX:
		.fill 	1
gpmY: 										; the row the FIRST entry sits on
		.fill 	1
gpmW: 										; how many cells wide the highlight is
		.fill 	1
gpmN: 										; how many entries
		.fill 	1
gpmSel: 									; 1..n while running, and the answer on the way out
		.fill 	1
gpmFlags:
		.fill 	1
gpmKey: 									; the key just read, folded once it reaches the hotkeys
		.fill 	1
gpmTemp: 									; the nibble being moved -- clobbered by every highlight
		.fill 	1
gpmLimit: 									; hotkey scan limit, then the row a hotkey hit
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
;
; ************************************************************************************************
