; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		testing.asm
;		Purpose:	Basic testing for runtime
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

;
;		Match the shipping configuration (application/source/compiler/start.asm): the compiler's
;		two work tables live in BANKED RAM, reached through storage_access/storage_release. Left
;		at $8000/$9F00 the harness would still pass while exercising a layout nothing ships.
;
StartWorkSpace = $A000
EndWorkspace = $C000

WrapperBoot:	
		ldx 	#APIDesc & $FF
		ldy 	#APIDesc >> 8
		jsr 	StartCompiler
_WBError: 									; stop on error
		bcs 	_WBError
		jmp 	$FFFF

APIDesc:
		.word 	TestAPI 					; the testing API.
		.byte 	StartWorkSpace >> 8 		; start of workspace for compiler
		.byte 	EndWorkspace >> 8 			; end of workspace for compiler
											; this example is 8000-9EFF.
		.send code

		.include "api/api.asm"
		.include "api/line.asm"
		.include "api/save.asm"

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

