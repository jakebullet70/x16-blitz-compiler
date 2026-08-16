; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		fixbranches.asm
;		Purpose:	Fix up GOTO and GOSUB commands
;		Created:	18th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Fix up GOTO and GOSUB, and VARSPACE
;
; ************************************************************************************************

FixBranches:
		lda 	#BLC_RESETOUT				; back to the start of the *object* code.
		jsr 	CallAPIHandler
_FBLoop:
		lda 	(objPtr) 					; get the next one.
		cmp 	#PCD_CMD_GOTO 				; found GOTO or GOSUB, patch up.
		beq 	_FBFixGotoGosub
		cmp 	#PCD_CMD_GOSUB
		beq 	_FBFixGotoGosub
		cmp 	#PCD_CMD_FNGOSUB 			; an FN call: resolve like a branch but from an
		beq 	_FBFixFnGosub 				; absolute address, not a line number.
		cmp 	#PCD_CMD_GOTOCMD_NZ 		; patch the conditional GOTOs for Z/NZ TOS.
		beq 	_FBFixGotoGosub
		cmp 	#PCD_CMD_GOTOCMD_Z 
		beq 	_FBFixGotoGosub
		cmp 	#PCD_CMD_VARSPACE
		beq 	_FBFixVarSpace
		cmp 	#PCD_CMD_RESTORE 			; patch restore.
		beq 	_FBFixRestore
		cmp 	#PCD_CMD_EXITDO 			; GP.EXITDO: resolve against its own GP.LOOP.
		beq 	_FBExitDoFar
_FBNext:
		jsr 	MoveObjectForward 			; move forward in object code.
		bcc 	_FBLoop 					; not finished
_FBExit:
		rts
;
;		The GP.EXITDO handler lives at the very end of this file, deliberately: dropping it inline
;		pushed the branches around it out of range. Hence this trampoline.
;
_FBExitDoFar:
		jmp 	_FBFixExitDo
;
;		Found an FN call (.fngosub). Its operand is already the ABSOLUTE code position of the FN
;		body, not a source line number, so skip STRFindLine: load the address into YA and join the
;		shared tail, which turns it into an offset from this opcode -- exactly like every branch.
;
_FBFixFnGosub:
		ldy 	#1
		lda 	(objPtr),y 					; operand byte 1 = abs LOW
		pha
		iny
		lda 	(objPtr),y 					; operand byte 2 = abs HIGH
		tay 								; Y = abs HIGH
		pla 								; A = abs LOW
		jmp 	_FBFFound
;
;		Found GOTO/GOSUB - look it up in the line# table and fix it up.
;
;		also handles RESTORE.
;
_FBFixGotoGosub:
_FBFixRestore:
		ldy 	#1							; line number in YA
		lda 	(objPtr),y
		pha
		iny
		lda 	(objPtr),y
		tay
		pla
		jsr 	STRFindLine			 		; find where it is YA
		bcc 	_FBFFound 					; not found, so must be >
		pha
		lda 	(objPtr) 					; which is a fail if not CMD_GOTOCMD_Z
		cmp 	#PCD_CMD_GOTOCMD_Z 			; or RESTORE. These go to the next line
		beq 	_FBFAllowZero 				; after ; for IF forward scanning, and
		cmp 	#PCD_CMD_RESTORE 			; because RESTORE <n> <n> is optional.
		bne 	_FBFFail
_FBFAllowZero:		
		pla

_FBFFound:		
		jsr 	STRMakeOffset 				; make it an offset from X:YA
		
		phy	 								; patch the GOTO/GOSUB
		ldy 	#1
		sta 	(objPtr),y
		iny
		pla
		sta 	(objPtr),y
		bra 	_FBNext

;
;		Report the line number that could not be found. The operand is at offsets 1 (low) and
;		2 (high) -- the same place _FBFixGotoGosub reads it from and _FBFFound patches it. Do
;		not use the ldy #2/iny idiom from GetNextLine: that reads a *source* line record,
;		where the line number follows a 2 byte link, and applying it here reported
;		(next opcode << 8) | line high -- a meaningless number.
;
_FBFFail:
		ldy 	#1
		lda 	(objPtr),y
		sta 	currentLineNumber
		iny
		lda 	(objPtr),y
		sta 	currentLineNumber+1
		.error_line

;
;		Found VarSpace, fix up with free space after variables
;
_FBFixVarSpace:
		ldy 	#1
		lda 	freeVariableMemory
		sta 	(objPtr),y
		iny
		lda 	freeVariableMemory+1
		sta 	(objPtr),y
		bra 	_FBNext

;
;		Found GP.EXITDO. Its target is whatever follows the GP.LOOP that closes the GP.DO it sits
;		inside, which is not known when the command is compiled -- and this compiler has no
;		back-patching machinery at all (IF sidesteps the problem entirely by branching to "current
;		line + 1" and letting STRFindLine resolve it). So resolve it HERE instead, where the whole
;		object is laid out and randomly addressable through objPtr.
;
;		Scan FORWARD from the .exitdo counting nesting: every GP.DO seen is a loop that must close
;		before ours, so it raises the depth; every GP.LOOP lowers it, and the one found at depth
;		zero is ours. That is a structural match on the emitted code, so it cannot be fooled by
;		line numbering or by an inner loop, and it needs no compile-time state whatsoever.
;
;		MoveObjectForward is what makes the walk safe: it steps by real instruction size, so an
;		operand byte that happens to equal a GP.DO or GP.LOOP token is never read as one.
;
_FBFixExitDo:
		lda 	objPtr 						; remember where the .exitdo is, to come back and patch
		sta 	_FBExitSave
		lda 	objPtr+1
		sta 	_FBExitSave+1
		stz 	_FBExitDepth
_FBEDScan:
		jsr 	MoveObjectForward
		bcs 	_FBEDNoLoop 				; ran off the end without finding one
		lda 	(objPtr)
		cmp 	#PCD_GPCMD_LOOP
		beq 	_FBEDLoop
		cmp 	#PCD_GPCMD_DO
		bne 	_FBEDScan
		inc 	_FBExitDepth 				; a nested GP.DO -- its GP.LOOP is not ours
		bra 	_FBEDScan
_FBEDLoop:
		lda 	_FBExitDepth
		beq 	_FBEDFound 					; depth zero, so this GP.LOOP closes OUR loop
		dec 	_FBExitDepth
		bra 	_FBEDScan
;
;		Found it. The target is the instruction AFTER the GP.LOOP -- one more step forward. If that
;		step hits the end of the object the target is the end marker, which is exactly where the
;		loop would have fallen through to anyway, so the carry is deliberately ignored here.
;
_FBEDFound:
		jsr 	MoveObjectForward
		lda 	objPtr
		sta 	_FBExitTarget
		lda 	objPtr+1
		sta 	_FBExitTarget+1
		;
		lda 	_FBExitSave 				; back to the .exitdo: STRMakeOffset works from objPtr
		sta 	objPtr
		lda 	_FBExitSave+1
		sta 	objPtr+1
		;
		lda 	_FBExitTarget 				; target in YA, exactly as the GOTO path passes it
		ldy 	_FBExitTarget+1
		jsr 	STRMakeOffset
		phy
		ldy 	#1
		sta 	(objPtr),y
		iny
		pla
		sta 	(objPtr),y
		jmp 	_FBNext
;
;		A GP.EXITDO with no GP.LOOP after it at its own nesting depth is not in a loop at all. This
;		is the compile-time half of the check; StackFindFrame's structure error is the runtime half.
;
_FBEDNoLoop:
		lda 	_FBExitSave 				; put objPtr back so nothing downstream sees the walk
		sta 	objPtr
		lda 	_FBExitSave+1
		sta 	objPtr+1
		.error_structure

		.send code

		.section storage
_FBExitSave:								; where the .exitdo being resolved lives
		.fill 	2
_FBExitTarget:								; where its branch should land
		.fill 	2
_FBExitDepth:								; nested GP.DOs still to be closed before ours
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
;
; ************************************************************************************************
