; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		goto.asm
;		Purpose:	Goto command
;		Created:	18th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								Goto <Page and Address follows>
;	 							   (Page currently not used)
;
; ************************************************************************************************

;
;		.caseend is the branch that closes a GP.CASE body, and it is a .goto in every respect
;		except how FixBranches works out where it goes -- exactly the relationship .fngosub has
;		with .gosub. Two markers on one body, so it costs a vector slot and not a byte more.
;
CommandXGoto: ;; [.goto]
CommandXCaseEnd: ;; [.caseend]
		.entercmd
		;
		;		Come here to actually do the GOTO.
		;
PerformGOTO:		
		iny 								; push MSB of offset on stack
		lda 	(codePtr),y
		pha
		dey 								; point LSB of offset

		clc 								; add LSB
		lda 	(codePtr),y
		adc 	codePtr
		sta 	codePtr

		pla 								; restore offset MSB and add
		adc 	codePtr+1
		sta 	codePtr+1		

		.exitcmd

; ************************************************************************************************
;
;									Conditional Gotos
;
; ************************************************************************************************

;
;		.casenext -- a GP.CASE test that came out false -- is likewise a .goto.z: pop the result,
;		branch on zero. Only its target differs.
;
CommandGotoZ: ;; [.goto.z]
CommandXCaseNext: ;; [.casenext]
		.entercmd
		jsr 	FloatIsZero
		dex 
		cmp 	#0
		beq 	PerformGOTO
		iny
		iny
		.exitcmd

CommandGotoNZ: ;; [.goto.nz]
		.entercmd
		jsr 	FloatIsZero
		dex 
		cmp 	#0
		bne 	PerformGOTO
		iny
		iny
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
;
; ************************************************************************************************
