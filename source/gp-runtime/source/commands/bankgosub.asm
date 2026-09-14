; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		bankgosub.asm
;		Purpose:	.bgosub -- a GOSUB that selects the bank its target runs in
;		Created:	13th September 2026
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								.bgosub <offset> <bank>
;
;		The compiler emits this in place of a .gosub whose target is inside a GP.BANKED region,
;		so the call selects the bank itself and no low-memory shim has to. The offset is a
;		.gosub's, measured from its own first byte; the bank byte follows it.
;
;		THE FRAME IS FRAME_BGOSUB, $E5, and its +1 byte is the CALLER'S bank, a byte a GOSUB
;		frame never uses. StackFindFrame ignores bit 0 of the marker and hands it back in carry,
;		so RETURN's search for FRAME_GOSUB finds this frame too and knows to put the bank back
;		and step over the longer operand. A plain GOSUB frame restores nothing: a BANK inside
;		an ordinary subroutine still holds after its RETURN, as it does in stock BASIC.
;
;		ONLY THE HARDWARE REGISTER MOVES; ramBank IS LEFT ALONE. ramBank is what BANK last set,
;		$FF until BANK is used, and PEEK and POKE switch to it around each access. Copying it
;		into the register would select bank 255 on the RETURN of a program that never used
;		BANK, and leaving it alone means a PEEK inside the routine still reaches the bank the
;		program chose.
;
;		THE OFFSET IS READ BEFORE THE BANK CHANGES. A caller inside another region has its
;		operand at $A000 up, under its own bank, so selecting the target's bank first would read
;		the offset out of the wrong one. That is also why PerformGOTO is not shared: it ends by
;		dispatching the next command, and the bank has to change between the two.
;
;		IT LIVES IN THE GP BLOCK, not beside .gosub in the core. The embedded image had 16 bytes
;		of core before GPBase moves a page, and RETURN's half takes 11 of them. The GP usage
;		scan decides by handler address, so a program that calls into a region loads the GP
;		block.
;
; ************************************************************************************************

CommandXBankGosub: ;; [.bgosub]
		.entercmd
		lda 	#FRAME_BGOSUB
		jsr 	StackOpenFrame
		jsr 	StackSaveCurrentPosition 	; codePtr on the offset, Y = 0
		ldy 	#1
		lda 	SelectRAMBank 				; the caller's bank, for RETURN
		sta 	(runtimeStackPtr),y
		iny
		lda 	(codePtr),y 				; the target's bank, held until the offset is read
		pha
		dey
		lda 	(codePtr),y 				; offset MSB
		pha
		dey
		clc 								; add the offset, as PerformGOTO does
		lda 	(codePtr),y
		adc 	codePtr
		sta 	codePtr
		pla
		adc 	codePtr+1
		sta 	codePtr+1
		pla 								; and only now select the target's bank
		sta 	SelectRAMBank
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
;		13/09/26		Written.
;
; ************************************************************************************************
