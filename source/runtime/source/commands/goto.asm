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
;		with .gosub. .ifelse -- the jump out of a GP.IF body, and over a GP.ELSEIF test -- is the
;		same again. Three markers on one body, so each costs a vector slot and not a byte more.
;
CommandXGoto: ;; [.goto]
CommandXCaseEnd: ;; [.caseend]
CommandXIfElse: ;; [.ifelse]
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
;		branch on zero. So is .ifnext, a GP.IF or GP.ELSEIF test that came out false. Only their
;		targets differ, and only FixBranches knows that.
;
CommandGotoZ: ;; [.goto.z]
CommandXCaseNext: ;; [.casenext]
CommandXIfNext: ;; [.ifnext]
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

; ************************************************************************************************
;
;							GP.IF / GP.ENDIF -- markers, not code
;
;		Neither does anything at runtime. They exist so FixBranches has something to count nesting
;		on (gp.if) and somewhere for a false test to land (gp.endif) -- the same job gp.other does
;		for GP.SELECT, and for the same reason: a block IF needs no stack frame, so there is
;		nothing for either of them to open or close.
;
;		DELIBERATELY IN THE CORE, not gp-runtime. ScanGPUsage decides whether an object carries
;		the 2K GP handler block by comparing each emitted opcode's HANDLER ADDRESS against GPBase,
;		so aliasing these to CommandXOther in gp-runtime/select.asm would drag the whole block into
;		any program whose only GP.BASIC keyword is an IF. Four bytes here buys that back.
;
; ************************************************************************************************

CommandXIfMark: ;; [gp.if]
CommandXEndIf: ;; [gp.endif]
		.entercmd
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
