; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpasm.asm
;		Purpose:	GP.ASM / GP.ENDASM -- inline 65C02 assembly
;		Created:	30th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		GP.ASM
;		REM <instruction>
;		...
;		GP.ENDASM
;
;		Inline assembly, assembled HERE, at compile time, on the X16. Both delimiters are alone
;		on their line and the body rides in REM statements, one instruction each.
;
;		WHY THE BODY IS REMS. BASLOAD stores remark text byte for byte, so ORA, AND, EOR and ROR
;		reach us intact -- outside a REM they are tokenised into keywords and the text is
;		destroyed. Braces survive too, which is what makes {VAR} possible later. Measured, not
;		assumed: see docs/blitz/GP-BASIC.ASM.RESEARCH.md section 17.
;
;		WHY THE DELIMITERS ARE NOT REMS. #REM 0 is BASLOAD's default, and with it the body is
;		stripped before the compiler is ever run. Real keywords mean we still see an empty block
;		and can refuse it; REM delimiters would leave NOTHING to detect and the program would
;		compile clean and simply not contain the code. That is why AsmBodyLines is counted.
;
;		THIS STATEMENT READS ITS OWN SOURCE LINES. MainCompileLoop has no swallow-until-terminator
;		mode, so the block does its own BLC_READIN/ProcessNewLine walk. ProcessNewLine keeps
;		currentLineNumber up to date as it goes, so an error inside the block still names the line
;		it is on. The swallowed lines deliberately do NOT get an STRMarkLine or a new.line: the
;		whole block is one statement and there is nothing inside it to branch to.
;
;		Errors are .error_structure, reusing an existing message rather than adding a clearer one.
;		errors.asm is in common-source, which links BELOW GPBase and is therefore copied into
;		every compiled object -- a new message would cost its own text in bytes in every program
;		that never uses GP.ASM. See the runtime-only cost rule in the research document.
;
;		Must return carry CLEAR. A .def helper returning carry set makes the generator silently
;		drop every table element after it, with no error and no clue.
;
; ************************************************************************************************

;
;		The low byte of GP.ENDASM's keyword id (52825 = $CE59). GP keywords are two bytes, $CE
;		then this. Written as the id so it tracks c64tokens.py rather than a bare $59.
;
GP_TOKEN_ENDASM = 52825 & $FF

CommandAsmCompile:
		stz 	deferErrors 				; a block opener must never defer -- a rolled back
											; opener leaves its closer behind and corrupts the
											; nesting of any block enclosing it, silently.
		stz 	AsmBodyLines
		jsr 	AsmOpenBlock 				; remember where this blob starts in the pool
		jsr 	AsmRequireEOL 				; GP.ASM is alone on its line

_CACNextLine:
		lda 	#BLC_READIN 				; pull the next source line ourselves
		jsr 	CallAPIHandler
		bcc 	_CACNoEnd 					; source ran out with the block still open
		jsr 	ProcessNewLine 				; srcPtr and currentLineNumber for the line just read

		jsr 	GetNextNonSpace 			; first thing on it
		beq 	_CACNextLine 				; blank line inside the block, ignore it
		cmp 	#C64_REM
		beq 	_CACBody
		cmp 	#$CE 						; the GP keyword prefix ?
		bne 	_CACNotAsm
		jsr 	GetNext 					; which GP keyword
		cmp 	#GP_TOKEN_ENDASM
		beq 	_CACClose
_CACNotAsm: 								; anything else in here is not assembly
		.error_structure

_CACBody:
		jsr 	AsmAssembleLine 			; assemble it into the pool
		inc 	AsmBodyLines 				; a body line -- the block is not empty
		bne 	_CACNextLine 				; (255 lines wraps to 0; the emptiness test only
		dec 	AsmBodyLines 				;  cares about zero, so stick at 255)
		bra 	_CACNextLine

;
;		GP.ENDASM. An empty block is the #REM 0 case: the body was stripped by the tokeniser and
;		the program would otherwise compile clean and contain no code at all.
;
_CACClose:
		lda 	AsmBodyLines
		beq 	_CACNotAsm 					; empty block -- almost always a missing #REM 1
		jsr 	AsmCloseBlock 				; cap the blob and emit the call to it
		jmp 	AsmRequireEOL

_CACNoEnd: 									; GP.ASM with no GP.ENDASM
		.error_structure

;
;		A GP.ENDASM reached by the main compile loop had no GP.ASM to close -- CommandAsmCompile
;		consumes its own, so this is only ever reached by a stray one.
;
CommandEndAsmCompile:
		stz 	deferErrors
		.error_structure

;
;		Nothing may follow either delimiter. With deferErrors already disarmed this aborts the
;		compile rather than quietly becoming a runtime throw-stub.
;
AsmRequireEOL:
		jsr 	LookNextNonSpace
		bne 	_ARENotEOL
		clc 								; .def helpers MUST return carry clear
		rts
_ARENotEOL:
		.error_syntax

		.send code

		.section storage
AsmBodyLines: 								; REM lines seen in the block so far, capped at 255.
		.fill 	1 							; Zero at GP.ENDASM means #REM 1 was never turned on.
		.send storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		30/08/26		Written. Block structure only -- the body is recognised and counted,
;						but not yet assembled and nothing is emitted for it.
;
; ************************************************************************************************
