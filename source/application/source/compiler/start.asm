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
		jsr 	IODeleteOutputs 			; and clear the object AND map from a PREVIOUS run, so a
								; compile that stops on an error leaves nothing behind
		jsr 	ValidateSourceFile 			; and REFUSE ANYTHING THAT IS NOT A TOKENISED PRG.
		bcs 	_CCStopped 				; AFTER the delete, so a refused compile leaves nothing
								; behind either, and after PrintWorking, so the message
								; lands under the IN:/OUT: lines that name the file.
								; It has already said which of the two reasons it was.

		;
		;		GP.BANKED needs to know where the p-code will RUN, and it needs it INSIDE the
		;		compile: FixBranches resolves the branches that cross into the bank long before
		;		WriteObjectCode has settled anything. In shared mode that is the constant
		;		PCODE_PAGE, so it can be handed over now. Embedded, it depends on ScanGPUsage --
		;		and there is no bootstrap there to copy the region either, so gpbank.asm refuses
		;		a region rather than guessing.
		;
		lda 	#(PCODE_PAGE - (FreeMemory >> 8)) & $FF
		sta 	gpBankRunPage
		stz 	gpBankShared
		lda 	ModeText 					; GPC.INPUT line 4 -- 'S' is SHARED
		cmp 	#'S'
		bne 	_CCNotShared
		inc 	gpBankShared
_CCNotShared:
		jsr 	GPScanReset 				; before a byte is written, because pass one decides
											; gpUsed as it writes them
		ldx 	#APIDesc & $FF
		ldy 	#APIDesc >> 8
		jsr 	StartCompiler
		bcs 	_CCStopped 					; THE COMPILE ITSELF FAILED. StartCompiler documents CC = okay
									; and CompilerErrorHandler has already printed the message and the
									; line, so there is nothing to add -- but this carry used to be
									; DROPPED, and WriteObjectCode ran anyway. A structure error out of
									; FixBranches (GP.IF with no GP.ENDIF, GP.SELECT with no GP.ENDSEL,
									; GP.EXITDO with no GP.LOOP) therefore wrote out the half-resolved
									; object -- truncated at the branch it could not fix, because
									; _FBEDNoLoop restores objPtr to it -- and then printed OK.
		jsr 	WriteMapFile 				; and the line#->offset map, if GPC.INPUT asked for one
		lda 	#"O" 						; the only other thing it prints, and the only way a
		jsr 	$FFD2 						; caller can tell a compile that worked from one that
		lda 	#"K" 						; stopped on an error, so it stays.
		jsr 	$FFD2
		lda 	#' '
		jsr 	$FFD2
		jmp 	PrintMemoryReport 			; ... and what it cost -- see compiler/memreport.asm

_CCStopped: 								; either half set carry and has already said why, so stop
		jmp 	ObjStreamAbort 				; here: no object -- and the object file is created
											; before pass two now, so a half written one has to
											; be taken away -- no map file, and above all no OK.

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
;		THEY ARE A BANK EACH, so Start..End bounds them SEPARATELY rather than jointly -- 2,048
;		lines and 1,365 variables, not 8K shared. Sharing one bank made the real limit the sum of
;		the two, and samples/editor had reached 7,981 of 8,192 (1,461 lines, 356 variables): fifty
;		more lines of source raised PROGRAM TOO BIG with a third of the OBJECT budget unused. The
;		message was right, the limit behind it was the wrong one. See x16_storage.inc.
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
