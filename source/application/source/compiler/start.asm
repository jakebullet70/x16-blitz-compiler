; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		start.asm
;		Purpose:	Start actual compilation.
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;									Compile the code from disk
;
; ************************************************************************************************

CompileCode:
		jsr 	ReadControlFile 			; GPC.INPUT says what to compile and where to put it
		bcs 	_CCNoControlFile 			; and without it there is nothing to be done
		jsr 	PrintWorking 				; which is all the compiler now says for itself

		ldx 	#APIDesc & $FF
		ldy 	#APIDesc >> 8
		jsr 	StartCompiler
		jsr 	WriteObjectCode
		lda 	#"O" 						; the only other thing it prints, and the only way a
		jsr 	$FFD2 						; caller can tell a compile that worked from one that
		lda 	#"K" 						; stopped on an error, so it stays.
		jsr 	$FFD2
		rts

_CCNoControlFile: 							; a compiler that guesses at what it was asked to
		jmp 	PrintNoControlFile 			; build is worse than one that refuses

; ************************************************************************************************
;
;									API Setup for the compiler
;
; ************************************************************************************************

APIDesc:
		.word 	CompilerAPI 				; the compiler API Implementeation
		.byte 	$80 						; start of workspace for compiler $8000
		.byte 	$9F							; end of workspace for compiler $9F00

;
;		The source and object file names used to be two .text constants here. They are now the
;		first two lines of GPC.INPUT -- see file-io/control.asm.
;

		.send code

		.section storage
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
