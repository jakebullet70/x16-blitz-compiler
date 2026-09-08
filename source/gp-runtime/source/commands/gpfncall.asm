; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpfncall.asm
;		Purpose:	.fnsave / .fnrestore / .fnpush / .fnpop -- the frame stack under a call
;		Created:	8th September 2026
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								.fnsave  /  .fnrestore
;
;		GP.SUB needs neither of these and GP.FN cannot work without them. A GP.SUB is a
;		STATEMENT: its arguments are stored into the formals before the call, so nothing of the
;		caller's is half-finished when the routine runs. GP.FN is an EXPRESSION TERM, and
;		"A + GP.FN(V,1)" reaches the call with A already pushed.
;
;		WHAT DESTROYS IT IS new.line, AND EVERY SOURCE LINE HAS ONE. CommandNewLine is four
;		instructions -- stz stringInitialised and ldx #$FF -- and the compiler emits it in front
;		of every line, so the callee wipes the caller's evaluation stack and hands its string
;		temporaries out again on its FIRST line. DEF FN escapes this only because its body is
;		compiled inline on the DEF line and so contains no new.line at all; a GP.DEFPROC body is
;		ordinary source lines and cannot.
;
;		SO THE CALL SITE BRACKETS THE .fngosub WITH THESE TWO. The compiler emits
;
;			<argument> ... into the formals, exactly as GP.SUB does
;			.fnsave
;			.fngosub  <body>
;			.fnrestore
;			<read the RETURNS variable>
;
;		and the result comes back in a VARIABLE rather than on the stack, which is what RETURNS
;		names. It has to: the body is many lines, and the stack does not survive them.
;
;		ONE FRAME PER SLOT, NOT ONE FRAME FOR THE LOT. A frame's size lives in the low five bits
;		of its marker, so 31 bytes is the most one can hold, and twelve slots of six bytes is 72.
;		A frame apiece keeps every marker honest, which is what lets StackFindFrame walk over
;		them correctly if it ever has to. They are pushed TOP DOWN so .fnrestore, which pops from
;		the top, meets slot 0 first and can rebuild X by counting.
;
;		AND THE STRING HALF IS A BASE, NOT A COPY. Temporaries start stringTempPages below the
;		heap ceiling; raising it for the length of the call puts the callee's own resets BELOW
;		the temporaries the caller is still holding, so nothing has to be copied anywhere. The
;		heap ceiling itself could not be moved instead -- StringConcrete's scavenger walks the
;		blocks upward from it and needs them to tile it exactly.
;
;		All four handlers are above GPBase, so they cost a program with no GP block nothing but
;		the vector slots -- four bytes apiece -- that every system token costs.
;
; ************************************************************************************************

CommandXFnSave: ;; [.fnsave]
		.entercmd 							; X is the caller's live stack index
		phy 								; ...and Y is the code offset, which the frame
		phx 								; writes below need for themselves
		;
		;		Make the string state definite before saving it: the caller may not have
		;		allocated a temporary yet, and then stringTempPointer is stale rather than wrong.
		;
		jsr 	StringInitialise
		;
		lda 	#FRAME_FNSTATE
		jsr 	StackOpenFrame
		ldy 	#1
		lda 	stringTempPointer
		sta 	(runtimeStackPtr),y
		iny
		lda 	stringTempPointer+1
		sta 	(runtimeStackPtr),y
		iny
		lda 	stringTempPages
		sta 	(runtimeStackPtr),y
		;
		;		Then the live slots, highest first.
		;
		pla
		sta 	fnSaveIndex
_CXSLoop:
		ldx 	fnSaveIndex
		bmi 	_CXSBase 					; $FF is an empty stack, and the usual case
		jsr 	FnPushSlot
		dec 	fnSaveIndex
		bra 	_CXSLoop
		;
		;		Drop the temporary base below what the caller is holding, and a page clear of it.
		;		It only ever goes down here -- a nested call has already taken it further, and
		;		its own .fnrestore is what brings it back.
		;
_CXSBase:
		sec
		lda 	stringHighMemory+1
		sbc 	stringTempPointer+1
		inc 	a
		cmp 	stringTempPages
		bcc 	_CXSDone
		sta 	stringTempPages
		;
		;		...and stop if that has taken the temporaries into the arrays. Nothing downstream
		;		would notice: StringInitialise tests the heap CEILING against availableMemory, and
		;		the ceiling has not moved.
		;
		sec
		lda 	stringHighMemory+1
		sbc 	stringTempPages
		cmp 	availableMemory+1
		bcc 	_CXSMemory
_CXSDone:
		stz 	stringInitialised 			; so the callee allocates from the new base
		ldx 	#$FF 						; the saved slots are the caller's copy now, and the
											; callee is entitled to the whole stack
		ply
		.exitcmd

_CXSMemory:
		.error_memory

; ************************************************************************************************
;
;		Put both back. The slot frames rebuild X by counting, so the caller's depth is not
;		stored anywhere -- an empty stack simply has no slot frames and leaves X at $FF.
;
; ************************************************************************************************

CommandXFnRestore: ;; [.fnrestore]
		.entercmd
		phy
		ldx 	#$FF
_CXRLoop:
		lda 	(runtimeStackPtr) 			; frame marker on top
		and 	#$E0 						; the id is the upper 3 bits (frames.inc)
		cmp 	#FRAME_FNSLOT & $E0
		bne 	_CXRState
		inx
		cpx 	#MathStackSize 				; more slot frames than the stack has slots, so a store
		bcs 	_CXRBroken 					; here would run off NSExponent into whatever is next
		jsr 	FnPullSlot
		bra 	_CXRLoop
_CXRState:
		cmp 	#FRAME_FNSTATE & $E0 		; whatever else it is, the pairing is broken
		bne 	_CXRBroken
		ldy 	#1
		lda 	(runtimeStackPtr),y
		sta 	stringTempPointer
		iny
		lda 	(runtimeStackPtr),y
		sta 	stringTempPointer+1
		iny
		lda 	(runtimeStackPtr),y
		sta 	stringTempPages
		jsr 	StackCloseFrame
		lda 	#$FF 						; the caller's temporaries are live again, so nothing
		sta 	stringInitialised 			; may hand that memory out a second time
		ply
		.exitcmd

_CXRBroken:
		.error_structure

; ************************************************************************************************
;
;								.fnpush  /  .fnpop
;
;		AN ARGUMENT LIST IS EVALUATED IN FULL BEFORE ANY OF IT IS STORED, and these are where
;		it waits. A formal is a plain variable, so a call that stored as it read would let
;		GP.FN(AREA,2,GP.FN(AREA,3,4)) write A.W for the inner call while the outer call's 2 was
;		still sitting in it -- the wrong answer, silently, with both passes agreeing.
;
;		THE EVALUATION STACK IS THE WRONG PLACE TO HOLD THEM. It is MathStackSize -- twelve --
;		slots for the whole expression, it has no overflow check anywhere, and slot 12 is
;		NSMantissa0[0]: overflowing it corrupts the bottom of the same stack rather than
;		reporting anything. Twelve formals against twelve slots put a real program one deep
;		argument away from that, and holding the arguments there would have made the formal
;		count a cap on what may be written.
;
;		SO EACH ARGUMENT GOES TO THE FRAME STACK AS IT IS EVALUATED, and comes back one at a
;		time as the stores run. The evaluation stack then holds ONE argument at a time however
;		many there are, the depth a call needs is the depth of its deepest single argument, and
;		the frame stack -- 4K, and checked by StackOpenFrame -- is what a long list runs into.
;
;		THE LAST ARGUMENT IS NEVER PUSHED. It is evaluated last and stored first, so nothing
;		runs between the two and there is nothing to protect it from. A verb of one formal
;		therefore emits neither of these and costs exactly what the longhand did.
;
;		They use FRAME_FNSLOT, the same frame .fnsave pushes, because that is what they are:
;		one saved evaluation stack slot. The two never meet -- .fnsave's frames sit above its
;		FRAME_FNSTATE and .fnrestore stops there -- and .fnpop pops exactly one frame rather
;		than counting, so an argument frame left under a callee's own frames is invisible to it.
;
; ************************************************************************************************

CommandXFnPush: ;; [.fnpush]
		.entercmd 							; X is the argument just evaluated
		phy
		jsr 	FnPushSlot
		dex 								; it lives on the frame stack now, so the slot is free
		ply
		.exitcmd

CommandXFnPop: ;; [.fnpop]
		.entercmd
		phy
		lda 	(runtimeStackPtr) 			; frame marker on top
		and 	#$E0
		cmp 	#FRAME_FNSLOT & $E0 		; anything else and the pairing is broken
		bne 	_CXPBroken
		inx
		cpx 	#MathStackSize 				; and a store here would run off NSExponent
		bcs 	_CXPBroken
		jsr 	FnPullSlot
		ply
		.exitcmd

_CXPBroken:
		.error_structure

; ************************************************************************************************
;
;		One evaluation stack slot to a new frame, and one back from the top frame. X is the slot
;		in both and both leave it alone -- StackOpenFrame and StackCloseFrame never touch X, and
;		the restore loop above has always counted on the second of those.
;
; ************************************************************************************************

FnPushSlot:
		lda 	#FRAME_FNSLOT
		jsr 	StackOpenFrame
		ldy 	#1
		lda 	NSStatus,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa0,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa1,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa2,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa3,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSExponent,x
		sta 	(runtimeStackPtr),y
		rts

FnPullSlot:
		ldy 	#1
		lda 	(runtimeStackPtr),y
		sta 	NSStatus,x
		iny
		lda 	(runtimeStackPtr),y
		sta 	NSMantissa0,x
		iny
		lda 	(runtimeStackPtr),y
		sta 	NSMantissa1,x
		iny
		lda 	(runtimeStackPtr),y
		sta 	NSMantissa2,x
		iny
		lda 	(runtimeStackPtr),y
		sta 	NSMantissa3,x
		iny
		lda 	(runtimeStackPtr),y
		sta 	NSExponent,x
		jmp 	StackCloseFrame

		.send 	code

; ************************************************************************************************
;
;		The slot being saved. In the storage section, which lives in the $0400-$0801 hole BELOW
;		the object's load address, so it is uninitialised RAM at run time and not a byte in the
;		file.
;
; ************************************************************************************************

		.section storage
fnSaveIndex:
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
;		08/09/26		Written.
;		08/09/26		.fnpush / .fnpop added: an argument list waits on the frame stack, not on
;						the twelve-slot evaluation stack it used to fill one slot a formal.
;
; ************************************************************************************************
