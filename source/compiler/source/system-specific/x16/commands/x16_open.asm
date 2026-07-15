; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_open.asm
;		Purpose:	OPEN command
;		Created:	2nd May 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						OPEN command - first 2 are already on the stack.
;
;		supports 	OPEN #,#
;					OPEN #,#,#
;					OPEN #,#,$
;					OPEN #,#,#,$
;
;		Adds dummies so whatever there are three integers and a string compiled.
;
; ************************************************************************************************

CommandOPEN:
		jsr 	LookNextNonSpace 			; followed by a , ?
		cmp 	#","
		bne 	_COTwoDefaults
		jsr 	GetNext 					; consume comma
		jsr 	CompileExpressionAt0 		; what follows could be text or number.
		and 	#NSSString 					; if a number want a string to follow
		beq 	_COThreeIntegers
		;
		;		n,n,$
		;
		lda 	#0		 					; so we have n,n,$,0 so swap !
		jsr 	PushIntegerA
		.keyword PCD_SWAP
		clc 								; see _COCompileNullString: WriteCodeByte returns CS,
		rts 								; and CS here would abort generation before PCD_OPEN.
		;
		;		Two numeric values, add default 0 and empty string.
		;
_COTwoDefaults:
		lda 	#0
		jsr 	PushIntegerA
_COCompileNullString:
		.keyword PCD_CMD_STRING 			; an empty (no filename) string is just a zero length
		lda 	#0 							; byte -- BufferOutput emits [length][chars], so length
		jsr 	WriteCodeByte 				; 0 and no data. (The old code wrote a SECOND $0 here,
		;									; a stray push that was harmless in itself.)
		;
		;		WriteCodeByte returns with CARRY SET (its CompilerAPI dispatch matches on
		;		cmp #BLC_WRITEOUT and _CAWriteByte never clears it). This routine is an X:
		;		generator helper, and the generator loop is "jsr GeneratorExecute / bcc" --
		;		a carry-SET return STOPS generation, which dropped the PCD_OPEN token that the
		;		OPEN descriptor emits next. With no OPEN opcode the logical file was never
		;		registered, so a later CHKIN failed and CHRIN blocked on the keyboard -- which
		;		is why OPEN15,8,15 (the one OPEN with no filename) hung on the first read while
		;		every named OPEN worked. Clear carry so the OPEN token is still emitted.
		;
		clc
		rts
		;
		;		Full constants e.g. 1,8,2 possibly no file name
		;
_COThreeIntegers:		
		jsr 	LookNextNonSpace 			; is there a , 
		cmp 	#","
		bne 	_COCompileNullString 		; if not it is n,n,n so default filename.
		jsr 	GetNext
		jsr 	CompileExpressionAt0 		; should be a filename
		and 	#NSSString
		beq 	_COType
		rts
_COType:
		.error_type		
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
