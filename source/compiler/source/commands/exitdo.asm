; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		exitdo.asm
;		Purpose:	GP.EXITDO command
;		Created:	16th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		GP.EXITDO -- leave the innermost GP.DO ... GP.LOOP early.
;
;		This cannot go in the command table as a plain "T", because .exitdo is a SYSTEM token and
;		system tokens carry an inline operand the table has no way to reserve. So the token and
;		its two operand bytes are written here.
;
;		PASS ONE WRITES A PLACEHOLDER, which FixBranches resolves by scanning forward for the
;		matching GP.LOOP -- it has the whole object laid out and can look. The value is never
;		read: FixBranches overwrites both bytes unconditionally, and errors out if there is no
;		matching GP.LOOP rather than leaving them.
;
;		PASS TWO WRITES THE OFFSET, out of the table pass one filled in as it passed each
;		GP.LOOP. See BlockDepthDown in commands/goto.asm.
;
;		MUST return carry CLEAR. A .def helper that returns carry set makes the generator silently
;		drop every token after it, with no error and no clue -- see the compiled OPEN15,8,15 hang.
;
; ************************************************************************************************

CommandExitDoCompile:
		lda 	passNumber
		bne 	_CEDResolve
		lda 	#PCD_CMD_EXITDO 			; pass one: FixBranches scans forward for the GP.LOOP
		jsr 	WriteCodeByte 				; and fills the offset in
		lda 	#0
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte
		clc
		rts
;
;		Pass two knows where the loop ends, because pass one wrote it down as it went past --
;		see BlockDepthDown in commands/goto.asm.
;
_CEDResolve:
		jsr 	BlockEnclosingDo 			; where the innermost open GP.DO ends
		lda 	#PCD_CMD_EXITDO
		jsr 	WriteBranchToAddress
		clc
		rts

		.send code

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
