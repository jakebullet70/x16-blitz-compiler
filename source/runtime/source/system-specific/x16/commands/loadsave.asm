; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		loadsave.asm
;		Purpose:	BLOAD, BVLOAD, VLOAD, BSAVE and BVERIFY
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		All five are the KERNAL's LOAD ($FFD5) and BSAVE ($FEBA) with SETNAM and SETLFS in front,
;		which is exactly what BASIC does with them. Two separate knobs decide what a load means,
;		and it is easy to conflate them:
;
;		The SECONDARY ADDRESS, given to SETLFS, says what to do with the file's first two bytes:
;
;			0	they are an address header; skip them and load at the address we passed
;			1	they are an address header; load THERE and ignore the address we passed
;			2	there is no header; load the whole file at the address we passed
;
;		The ACCUMULATOR, given to LOAD, says where the bytes go:
;
;			0	system memory			2	VRAM, from $00000 + address
;			1	verify, do not write	3	VRAM, from $10000 + address
;
;		So BLOAD is (secondary 2, A=0), BVLOAD is (secondary 2, A=2+bank), and VLOAD is the same
;		as BVLOAD but secondary 0 -- the one difference between them is that VLOAD eats the
;		two byte header and BVLOAD does not. BVERIFY is (secondary 2, A=1).
;
;		LOAD into banked RAM starts at whatever bank $00 selects and advances it by itself when a
;		file runs past $BFFF, so setting the bank IS the whole of the bank handling.
;
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;		Carry set means the KERNAL reported a failure. This is reached by jsr rather than by a
;		branch on purpose: the five commands are spread over far more than a branch can reach,
;		and carry survives a jsr untouched.
;
; ************************************************************************************************

LoadSaveCheckError:
		bcs 	LoadSaveError
		rts

LoadSaveError:
		.error_channel

; ************************************************************************************************
;
;						BLOAD <filename>,<device>,<bank>,<address>
;
; ************************************************************************************************

Command_BLOAD: ;; [!bload]
		.entercmd
		phy
		ldx 	#3
		jsr 	LoadSaveIntegers

		lda 	NSMantissa0+2 				; the bank the load begins in
		sta 	SelectRAMBank
		sta 	ramBank

		lda 	#2 							; no header: BLOAD takes the file exactly as it is
		jsr 	LoadSaveSetup

		lda 	#0 							; into system memory
		ldx 	NSMantissa0+3
		ldy 	NSMantissa1+3
		jsr 	X16_LOAD
		jsr 	LoadSaveCheckError 			; carry set = the KERNAL failed

		stx 	SYS_Reg_X 					; "after a successful load, $030D and $030E will contain
		sty 	SYS_Reg_Y 					; the address of the final byte loaded + 1"
		lda 	SelectRAMBank 				; LOAD advances the bank as it fills each one, and BLOAD
		sta 	ramBank 					; leaves it where it stopped, as if BANK had been called
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;			BVLOAD <filename>,<device>,<VERA high>,<VERA low>   -- raw, no header
;			VLOAD  <filename>,<device>,<VERA high>,<VERA low>   -- skips a two byte header
;
; ************************************************************************************************

Command_BVLOAD: ;; [!bvload]
		.entercmd
		phy
		lda 	#2 							; no header
		bra 	VLoadCommon

Command_VLOAD: ;; [!vload]
		.entercmd
		phy
		lda 	#0 							; skip the two byte address header

VLoadCommon: 								; global, not a cheap local: BVLOAD branches in from
		pha 								; its own scope, and _locals do not cross one
		ldx 	#3
		jsr 	LoadSaveIntegers
		pla
		jsr 	LoadSaveSetup

		lda 	NSMantissa0+2 				; LOAD takes A=2 for VRAM at $00000 + address and A=3
		and 	#1 							; for $10000 + address, so the VERA high address is
		clc 								; simply added on
		adc 	#2
		ldx 	NSMantissa0+3
		ldy 	NSMantissa1+3
		jsr 	X16_LOAD
		jsr 	LoadSaveCheckError 			; carry set = the KERNAL failed
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;					BSAVE <filename>,<device>,<bank>,<start>,<end>
;
; ************************************************************************************************

Command_BSAVE: ;; [!bsave]
		.entercmd
		phy
		ldx 	#4
		jsr 	LoadSaveIntegers

		lda 	SelectRAMBank 				; the manual documents BLOAD and BVERIFY as leaving the
		sta 	lsSavedBank 		 		; bank where they stopped, "as if you called BANK", and
		lda 	NSMantissa0+2 				; says nothing at all about BSAVE. A save cannot advance
		sta 	SelectRAMBank 				; a bank, so there is nothing to report -- put it back
											; rather than silently redirect the next PEEK.
		lda 	#1 							; secondary 1 is the CBM "this is a save" convention
		jsr 	LoadSaveSetup 				; -- and it uses zTemp0, so the start address below
											; has to be put there AFTERWARDS, not before
		lda 	NSMantissa0+3 				; BSAVE wants the start address in zero page and A
		sta 	zTemp0 						; holding the address OF that pointer
		lda 	NSMantissa1+3
		sta 	zTemp0+1

		ldx 	NSMantissa0+4 				; and the EXCLUSIVE end in XY: "the save will stop one
		ldy 	NSMantissa1+4 				; byte before <end address>"
		lda 	#zTemp0
		jsr 	X16_BSAVE
		php 								; putting the bank back must not lose the carry that
		lda 	lsSavedBank 				; says whether the save worked
		sta 	SelectRAMBank
		plp
		jsr 	LoadSaveCheckError 			; carry set = the KERNAL failed
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;					BVERIFY <filename>,<device>,<bank>,<start>
;
;		FOUR parameters, not the five the manual gives it. "BVERIFY <filename>,<device>,<bank>,
;		<start address>,<end address>" is a hard ?SYNTAX ERROR in the R49 ROM -- run it and see.
;		BSAVE's signature looks to have been copied into the manual by mistake. Four is also what
;		the KERNAL implies: LOAD with A=1 verifies, and takes no end address, because the length
;		of the file is what bounds the comparison.
;
;		Stock reports a mismatch by setting ST, and Blitz has no ST -- it is a CBM pseudo variable
;		rather than a keyword, and nothing in the compiler recognises it. A compiled program that
;		could not see the answer would be pointless, so a mismatch is raised as an I/O error.
;		That is a deliberate difference from stock, and the only one here.
;
; ************************************************************************************************

Command_BVERIFY: ;; [!bverify]
		.entercmd
		phy
		ldx 	#3
		jsr 	LoadSaveIntegers

		lda 	NSMantissa0+2
		sta 	SelectRAMBank
		sta 	ramBank

		lda 	#2 							; no header
		jsr 	LoadSaveSetup

		lda 	#1 							; compare, do not write
		ldx 	NSMantissa0+3
		ldy 	NSMantissa1+3
		jsr 	X16_LOAD
		jsr 	LoadSaveCheckError 			; carry set = the KERNAL failed

		jsr 	X16_READST 					; bit 4 is the CBM "verify mismatch" flag
		and 	#$10
		beq 	_BVMatched
		jmp 	LoadSaveError 				; jmp, not a branch: out of range from here
_BVMatched:
		ply
		ldx 	#$FF
		.exitcmd

; ************************************************************************************************
;
;		Make S[1]..S[X] integers. S[0] is the filename and is skipped -- it is a string, and
;		FloatIntegerPart would happily maul its address into nonsense.
;
; ************************************************************************************************

LoadSaveIntegers:
_LSILoop:
		.floatinteger
		dex
		bne 	_LSILoop
		rts

; ************************************************************************************************
;
;		SETNAM from the filename in S[0] and SETLFS from the device in S[1], with the secondary
;		address in A. Clobbers X, so it must be called once the parameters are already integers.
;
; ************************************************************************************************

LoadSaveSetup:
		sta 	lsSecondary
		lda 	NSMantissa0+0 				; the string's first byte is its length and the
		sta 	zTemp0 						; characters follow it, so XY has to point one on
		tax
		lda 	NSMantissa1+0
		sta 	zTemp0+1
		tay
		inx
		bne 	_LSSNoCarry
		iny
_LSSNoCarry:
		lda 	(zTemp0)
		jsr 	X16_SETNAM

		lda 	#1 							; the logical file number is not used for anything
		ldx 	NSMantissa0+1 				; here; the device and the secondary are what matter
		ldy 	lsSecondary
		jsr 	X16_SETLFS
		rts

		.send 	code

		.section storage
lsSecondary:
		.fill 	1
lsSavedBank: 								; BSAVE puts the RAM bank back; see the note there
		.fill 	1
		.send storage

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
