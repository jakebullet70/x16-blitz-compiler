; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		runtime.inc
;		Purpose:	Runtime includes
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

entercmd 	.macro
		plx
		.endm

exitcmd 	.macro
		jmp 	NextCommand
		.endm

;
;		A handler in bank 1 (HANDLER_BANK) ends with .exitbank, never .exitcmd. BankedExit is in
;		low RAM, selects the program's bank again and runs on into NextCommand.
;
exitbank 	.macro
		jmp 	BankedExit
		.endm

		
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
