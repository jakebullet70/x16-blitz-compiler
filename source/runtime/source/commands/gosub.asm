; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gosub.asm
;		Purpose:	Gosub/Return commands
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								Gosub <Page and Address follows>
;
; ************************************************************************************************

CommandXFnGosub: ;; [.fngosub]
		.entercmd 							; a DEF FN call. Identical to GOSUB at runtime -- open a
		lda 	#FRAME_GOSUB 				; frame, save the return position, jump. Its own opcode
		jsr 	StackOpenFrame 				; exists only so the compiler's FixBranches can tell an
		jsr 	StackSaveCurrentPosition 	; FN call (operand = absolute address) apart from an
		jmp 	PerformGOTO 				; ordinary GOSUB (operand = source line number).

CommandXGosub: ;; [.gosub]
		.entercmd
		lda 	#FRAME_GOSUB
		jsr 	StackOpenFrame
		jsr 	StackSaveCurrentPosition
		jmp 	PerformGOTO

CommandReturn: ;; [return]
		.entercmd
		lda 	#FRAME_GOSUB
		jsr 	StackFindFrame
		jsr 	StackLoadCurrentPosition
		iny
		iny
		jsr 	StackCloseFrame
		.exitcmd


		.send 	code
		
; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		22/06/23 		Uses FindFrame on Return, so will throw any incomplete NEXTs.
;
; ************************************************************************************************
