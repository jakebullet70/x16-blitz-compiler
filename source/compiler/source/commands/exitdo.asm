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
;		system tokens carry an inline operand the table has no way to reserve. So the token and a
;		two byte placeholder are written here, and FixBranches resolves the placeholder into a
;		branch offset by scanning forward for the matching GP.LOOP.
;
;		The placeholder value is never read -- FixBranches overwrites both bytes unconditionally,
;		and errors out if there is no matching GP.LOOP rather than leaving them.
;
;		MUST return carry CLEAR. A .def helper that returns carry set makes the generator silently
;		drop every token after it, with no error and no clue -- see the compiled OPEN15,8,15 hang.
;
; ************************************************************************************************

CommandExitDoCompile:
		lda 	#PCD_CMD_EXITDO
		jsr 	WriteCodeByte
		lda 	#0 							; branch offset placeholder, patched by FixBranches
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte
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
