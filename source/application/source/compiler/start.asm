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
		bcs 	_CCRejected 				; shared-mode reject (PROGRAM TOO BIG) -- already reported
		jsr 	WriteMapFile 				; and the line#->offset map, if GPC.INPUT asked for one
		lda 	#"O" 						; the only other thing it prints, and the only way a
		jsr 	$FFD2 						; caller can tell a compile that worked from one that
		lda 	#"K" 						; stopped on an error, so it stays.
		jsr 	$FFD2
		rts

_CCRejected: 								; WriteObjectCode set carry (e.g. PROGRAM TOO BIG); it has
		rts 								; already printed why, so stop -- no map file, no OK.

_CCNoControlFile: 							; a compiler that guesses at what it was asked to
		jmp 	PrintNoControlFile 			; build is worse than one that refuses

; ************************************************************************************************
;
;									API Setup for the compiler
;
; ************************************************************************************************

; ************************************************************************************************
;
;		THE TWO LIMITS THAT BOUND A COMPILE.  They are separate, and conflating them is what
;		made large programs miscompile in silence.
;
;		ObjectCeiling  is how far the OBJECT CODE may grow. It is written by _CAWriteByte
;		               (api.asm) from FreeMemory upwards, and $9F00 is simply where usable low
;		               RAM stops -- the I/O page. Capacity = ObjectCeiling - FreeMemory.
;
;		CompilerWorkspace{Start,End}  is where the compiler keeps its two TABLES: the variable
;		               name list growing UP from Start, the line-number table growing DOWN from
;		               End (reset.asm). This lives in BANKED RAM at $A000-$BFFF, reached through
;		               the storage_access/storage_release macros, so it does not compete with the
;		               object code for low memory.
;
;		Before this was split, the workspace started at $8000 and the object code was allowed to
;		run into it unchecked: at exactly $8000-$5100 = 12,032 bytes of p-code the object code
;		began overwriting the head of the variable name list, FindVariable then failed for EVERY
;		variable, and CreateVariableRecord handed each reference a fresh slot. The compiler
;		printed OK and emitted an object in which "X" on one line and "X" on the next were
;		different variables. samples/FSIM16_V1 (12,766 bytes of p-code) tripped it by 734 bytes.
;
; ************************************************************************************************

ObjectCeiling           = $9F00 			; object code may occupy FreeMemory..ObjectCeiling-1
CompilerWorkspaceStart  = $A000 			; banked RAM: variable name table, grows up
CompilerWorkspaceEnd    = $C000 			; banked RAM: line number table, grows down

APIDesc:
		.word 	CompilerAPI 				; the compiler API Implementeation
		.byte 	CompilerWorkspaceStart >> 8 	; start of workspace for compiler
		.byte 	CompilerWorkspaceEnd >> 8 		; end of workspace for compiler

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
