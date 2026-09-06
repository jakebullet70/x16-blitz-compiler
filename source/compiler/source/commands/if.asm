; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		if.asm
;		Purpose:	If command
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;											IF
;
; ************************************************************************************************

CommandIF: 		
		jsr 	LookNextNonSpace 			; what follows the tests ?
		cmp 	#C64_GOTO 					; IF .. GOTO
		beq 	_CIGoto
		;
		lda 	#C64_THEN 					; should be THEN
		jsr 	CheckNextA
		;
		jsr 	LookNextNonSpace 			; THEN <number>
		jsr 	CharIsDigit
		bcs 	_CIGoto2
		bra 	CompileGotoEOL

_CIGoto:	
		jsr 	GetNext 					
_CIGoto2:		
		lda 	#PCD_CMD_GOTOCMD_NZ
		jsr 	CompileBranchCommand
		rts
		
CompileGotoEOL: 							; compile GOTOZ <next line>
		jsr 	GetLineNumber 				; Get the current line number => YA
		inc 	a 							; and branch to +1
		bne 	_CGENoCarry
		iny
_CGENoCarry:		
		sta 	branchTarget 				; a line number that usually does not exist, which is
		sty 	branchTarget+1 				; why .gotoz is allowed to miss -- see WriteBranchTo
		lda 	#PCD_CMD_GOTOCMD_Z
		jmp 	WriteBranchTo

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
