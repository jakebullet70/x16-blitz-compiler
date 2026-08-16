; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		do.asm
;		Purpose:	GP.DO / GP.LOOP counted loop
;		Created:	16th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								<Count> GP.DO ... GP.LOOP
;
;		A counted loop with NO loop variable, modelled on prog8's "repeat" and named after CBM
;		BASIC 7.0's DO/LOOP. That missing variable is the entire point: FOR/NEXT spends most of
;		its time on the index -- decoding an operand address, reading six iFloat32 bytes,
;		comparing against a terminal value and writing six bytes back -- and none of that exists
;		here. The counter lives in the frame itself and is a plain 16 bit decrement.
;
;		Everything it needs was already in the image and is already linked for FOR/NEXT/GOSUB:
;		GetInteger16Bit, StackOpenFrame, StackSaveCurrentPosition, StackLoadCurrentPosition,
;		StackCloseFrame and StackFindFrame. This file adds glue, not machinery, which is why the
;		whole construct costs well under a tenth of what FOR alone does.
;
; ************************************************************************************************

CommandXDo: ;; [gp.do]
		.entercmd
		lda 	#FRAME_LOOP 				; open the frame FIRST.
		jsr 	StackOpenFrame
		jsr 	StackSaveCurrentPosition 	; normalise to Y=0 and save the loop-back position.
		;
		;		Order matters and is not stylistic: StackOpenFrame uses zTemp0 as scratch for the
		;		frame size, so fetching the count before opening the frame would have it
		;		overwritten. GetInteger16Bit is therefore called last, and its result is consumed
		;		immediately.
		;
		jsr 	GetInteger16Bit 			; count => zTemp0, truncated to 16 bits
		ldy 	#4
		lda 	zTemp0
		sta 	(runtimeStackPtr),y
		iny
		lda 	zTemp0+1
		sta 	(runtimeStackPtr),y
		dex 								; throw the count
		ldy 	#0
		.exitcmd

; ************************************************************************************************
;
;									GP.LOOP : end of a GP.DO
;
; ************************************************************************************************

CommandXLoop: ;; [gp.loop]
		.entercmd
		;
		;		Same guard as NEXT: a well nested loop has its own frame already on top, so
		;		StackFindFrame would spend ~34 cycles finding what is under its nose. Any other
		;		byte -- a FOR or GOSUB frame, or the $FF fail marker that raises the structure
		;		error -- falls through to the general path exactly as before.
		;
		lda 	(runtimeStackPtr) 			; loop frame already on top ?
		cmp 	#FRAME_LOOP
		beq 	_CLOnTop
		lda 	#FRAME_LOOP
		jsr 	StackFindFrame
_CLOnTop:
		;
		;		MUST come before Y is touched, exactly as NEXT does it. On entry Y is the offset
		;		into the current code page, and the frame accesses below overwrite it -- so
		;		without this the position is simply lost. The loop-back path happens to survive
		;		(StackLoadCurrentPosition reloads codePtr AND zeroes Y), but the exit path's
		;		"ldy #0" would then resume at the START of the page rather than after GP.LOOP,
		;		and the VM runs off into whatever follows. That is a BRK into the monitor with no
		;		error message, which is exactly how this first showed up.
		;
		jsr 	FixUpY 						; normalise codePtr so Y is free to use
		;
		;		Decrement the 16 bit counter, exit when it REACHES zero. Post-tested, so the body
		;		has already run once by the time we get here and a count of n gives exactly n
		;		passes.
		;
		;		A counter of zero ON ENTRY therefore cannot be a counted loop winding down -- we
		;		close the frame the moment a decrement produces zero, so zero is never left behind
		;		on a live loop. That makes it unambiguous, and it is what a bare GP.DO compiles to
		;		(OptionalNumberCompile pushes 0 for an omitted argument): ZERO MEANS FOREVER, and
		;		it loops back without touching the counter at all.
		;
		ldy 	#4
		lda 	(runtimeStackPtr),y 		; counter low
		bne 	_CLDecLow 					; non-zero, so no borrow needed
		iny
		lda 	(runtimeStackPtr),y 		; counter high
		beq 	_CLBack 					; $0000 => loop forever
		dec 	a 							; borrow from the high byte
		sta 	(runtimeStackPtr),y
		dey
		lda 	#0 							; low was zero, so it becomes $FF below
_CLDecLow:
		dec 	a
		sta 	(runtimeStackPtr),y 		; Y is 4 on both paths
		bne 	_CLBack 					; low non-zero => counter cannot be zero
		ldy 	#5
		lda 	(runtimeStackPtr),y
		bne 	_CLBack 					; high non-zero => still running
		;
		jsr 	StackCloseFrame 			; counter hit zero, drop the frame and fall through
		ldy 	#0
		.exitcmd
_CLBack:
		jsr 	StackLoadCurrentPosition 	; back to the top of the body (sets Y = 0)
		.exitcmd

; ************************************************************************************************
;
;							GP.EXITDO : leave the innermost GP.DO early
;
;		The whole command is three instructions because both halves already exist. StackFindFrame
;		lands on the innermost GP.DO frame and DISCARDS everything stacked above it on the way, so
;		a FOR abandoned inside the loop is cleaned up for free -- and if there is no loop at all it
;		stops on the $FF marker and raises the structure error, which is the runtime backstop for
;		an EXITDO the compiler somehow let through. Y is the code pointer offset here and neither
;		StackFindFrame nor StackCloseFrame touches it (both use 65C02 zp INDIRECT, not
;		indirect-indexed), so the error address stays meaningful and PerformGOTO still finds its
;		operand where it expects it.
;
;		The operand is a branch offset with exactly the shape of a .goto's, filled in by
;		FixBranches, so the jump itself is literally the GOTO code.
;
; ************************************************************************************************

CommandXExitDo: ;; [.exitdo]
		.entercmd
		lda 	#FRAME_LOOP 				; innermost GP.DO frame, discarding anything above it
		jsr 	StackFindFrame
		jsr 	StackCloseFrame 			; drop it -- we are leaving the loop for good
		jmp 	PerformGOTO 				; and branch past the matching GP.LOOP

; ************************************************************************************************
;
;		0	GP.DO Marker 			[1]
;		1 	(unused)				[1]		so +2/+3 line up with FRAME_FOR, which is what
;		2 	Position for loop 		[2]		StackSave/LoadCurrentPosition hard-code
;		4	Counter, 16 bit 		[2]		$0000 = loop forever
;
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
;		16/08/26		Written.
;
; ************************************************************************************************
