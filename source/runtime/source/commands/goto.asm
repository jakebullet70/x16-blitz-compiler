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
;		the GP handler block by comparing each emitted opcode's HANDLER ADDRESS against GPBase, so
;		putting these above it would drag the whole block into any program whose only GP.BASIC
;		keyword is an IF. Four bytes here buys that back.
;
;		ALL FOUR SELECT KEYWORDS JOINED THEM ON 1st SEPTEMBER 2026, which is how the last of the
;		select machinery left the block. gp.case is a marker like the rest now: the compiler
;		emits it and then emits a read of the selector variable behind it, where the old handler
;		pulled that value out of a stack frame. The
;		selector used to be any expression, kept alive in a stack frame across the source lines
;		between GP.SELECT and its alternatives; it is now a plain numeric VARIABLE that each
;		alternative simply re-reads, so there is nothing to keep. See
;		compiler/source/commands/select.asm for the whole argument.
;
;		THE THREE ARE STILL TOKENS, and must be. FixBranches has no symbol table: the emitted
;		token stream IS the block structure, and it scans for these to resolve .casenext and
;		.caseend and to count nesting. They cost a vector slot each, which they already had, and
;		now cost no handler at all.
;
;		gp.select carries a marker of its own rather than aliasing gp.if, because the two mean
;		different things to FixBranches -- gp.if is not counted for nesting and gp.select was.
;		(It is not counted any more either, but they are still distinct tokens.)
;
; ************************************************************************************************

CommandXIfMark: ;; [gp.if]
CommandXEndIf: ;; [gp.endif]
CommandXSelect: ;; [gp.select]
CommandXCase: ;; [gp.case]
CommandXOther: ;; [gp.other]
CommandXEndSelect: ;; [gp.endsel]
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
