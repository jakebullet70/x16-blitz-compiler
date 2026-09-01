; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		unwind.asm
;		Purpose:	.unwind <n> -- close n block frames so a GOTO can leave GP.DO / GP.SELECT
;		Created:	31st August 2026
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								.unwind <count>
;
;		GP.ENDSEL and GP.LOOP are what release a block's stack frame, so a GOTO that jumps past
;		them leaks one -- and in a loop that is one per pass. A GP.SELECT frame is 7 bytes against
;		a 4K frame stack, so a leaking select in a key loop dies after about 585 keystrokes.
;
;		This closes the innermost <count> BLOCK frames, and the compiler is what works out the
;		count: FixBranches knows the block depth at the GOTO and at its target, and the difference
;		is how many blocks the jump leaves. A count of zero is the normal case and does nothing --
;		the whole opcode is then two p-code bytes and about a dozen cycles.
;
;		STRAYS ARE DISCARDED WITHOUT BEING COUNTED. A FOR abandoned inside a case body sits above
;		the select's frame, and it has to go too, but it is not one of the blocks being left. This
;		is the same rule StackFindFrame applies -- it throws everything above the frame it wants --
;		written out here because we are counting rather than searching for a type.
;
;		AND IT STOPS AT $FF. That is the stack-empty marker, and reaching it means the count was
;		wrong; closing "frames" past it would walk off the end of the frame stack and into the
;		workspace. Stopping is silent on purpose: FixBranches has already raised BLOCK MISMATCH
;		for the structural errors it can see, and there is nothing useful to report from here.
;
;		ONLY GP.DO OPENS A BLOCK FRAME NOW. GP.SELECT did until 1st September 2026, when its
;		selector was restricted to a plain variable and the frame that kept an expression alive
;		became unnecessary -- so a GOTO leaving a select has nothing to close, and neither the
;		compiler nor FixBranches counts one any more. The two lines that recognised a select
;		frame here went with it.
;
;		WHY A SEPARATE OPCODE RATHER THAN gp.loop. gp.loop does the right thing to a loop frame
;		and emitting one before the GOTO would have cost nothing -- but FixBranches counts loop
;		nesting on gp.do/gp.loop, so an extra one inside a loop body captures that body's own
;		structure and sends its branches to the wrong place. The unwind has to be a token the
;		scanners do not count. It costs one vector slot, two bytes, in every compiled program;
;		the handler is above GPBase and so is free to any program that has a GP block already --
;		and one with a GP.DO in it does.
;
; ************************************************************************************************

CommandXUnwind: ;; [.unwind]
		.entercmd
		;
		;		NXCommand consumes the opcode byte before it dispatches, so Y ALREADY points at
		;		the operand on entry -- one iny here and the count read is the byte after it.
		;		The single iny below is what leaves Y on the next opcode for NextCommand.
		;
		lda 	(codePtr),y 				; the count
		sta 	unwindLeft
		iny 								; past it, where execution resumes
		lda 	unwindLeft
		beq 	_CXUDone 					; nothing to close, which is the common case
_CXULoop:
		lda 	(runtimeStackPtr) 			; the frame marker on top
		cmp 	#$FF 						; the stack-empty marker -- go no further
		beq 	_CXUDone
		and 	#$E0 						; the id is the upper 3 bits (frames.inc)
		cmp 	#FRAME_LOOP & $E0 			; GP.DO is the only block frame there is now --
		bne 	_CXUStray 					; GP.SELECT stopped opening one on 01/09/26, and a
		dec 	unwindLeft 					; FOR or GOSUB frame is closed but never counted
_CXUStray:
		jsr 	StackCloseFrame
		lda 	unwindLeft
		bne 	_CXULoop
_CXUDone:
		.exitcmd

		.send 	code

; ************************************************************************************************
;
;		Blocks still to close. In the storage section, which lives in the $0400-$0801 hole BELOW
;		the object's load address -- so it is uninitialised RAM at run time and not a byte in the
;		file. See the .cerror in common.inc that guards the hole from overflowing.
;
; ************************************************************************************************

		.section storage
unwindLeft:
		.fill 	1
		.send 	storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		31/08/26		Written.
;
; ************************************************************************************************
