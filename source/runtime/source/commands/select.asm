; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		select.asm
;		Purpose:	GP.SELECT / GP.CASE / GP.ELSE / GP.ENDSEL
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;			GP.SELECT <expr> / GP.CASE <expr>[,<expr>...] / GP.ELSE / GP.ENDSEL
;
;		A multi-way branch on one value, modelled on prog8's "when". It is NOT a replacement for
;		ON x GOTO/GOSUB, which is a real skip table and stays the right answer for a dense 1..n
;		index; this is for the SPARSE selector -- key codes out of GET, state machines - where
;		ON cannot go.
;
;		THE SELECTOR LIVES IN A STACK FRAME, not on the number stack, and that is forced rather
;		than chosen: new.line resets the number stack pointer to $FF at every source line, so a
;		value left on it by GP.SELECT would be gone by the time the first GP.CASE on the next
;		line looked for it. A frame also gets the nesting and the cleanup for free -- GP.ENDSEL
;		finds its own frame through StackFindFrame, which discards anything a case body left
;		open above it, and GP.EXITDO's StackFindFrame discards a select the same way.
;
;		GP.CASE is "push the selector", and it is emitted ONCE PER ALTERNATIVE, so
;
;			GP.CASE 13,17
;
;		compiles to  gp.case 13 f.cmp =  gp.case 17 f.cmp =  or  .casenext
;
;		which is why there is no separate marker keyword and no stack-duplicate opcode: the fetch
;		IS the marker. FixBranches lands .casenext on the FIRST gp.case of the next alternative,
;		and the extra ones inside an alternative all sit before its .casenext, so the scan never
;		sees them.
;
; ************************************************************************************************

selpush	.macro 								; number stack -> frame
		lda 	\1,x
		sta 	(runtimeStackPtr),y
		iny
		.endm

selpull	.macro 								; frame -> number stack
		lda 	(runtimeStackPtr),y
		sta 	\1,x
		iny
		.endm

; ************************************************************************************************
;
;								GP.SELECT : open the frame
;
; ************************************************************************************************

CommandXSelect: ;; [gp.select]
		.entercmd
		lda 	#FRAME_SELECT 				; StackOpenFrame can raise OUT OF MEMORY, and Y is
		jsr 	StackOpenFrame 				; still the code offset here, so it reports honestly
		;
		phy 								; Y becomes the frame index from here on
		ldy 	#1
		.selpush NSMantissa0
		.selpush NSMantissa1
		.selpush NSMantissa2
		.selpush NSMantissa3
		.selpush NSExponent
		.selpush NSStatus
		ply
		dex 								; the selector is in the frame now, not on the stack
		.exitcmd

; ************************************************************************************************
;
;						GP.CASE : push a copy of the selector to test against
;
; ************************************************************************************************

CommandXCase: ;; [gp.case]
		.entercmd
		jsr 	SelectFindFrame 			; before phy, so a structure error reports honestly
		phy
		inx
		ldy 	#1
		.selpull NSMantissa0
		.selpull NSMantissa1
		.selpull NSMantissa2
		.selpull NSMantissa3
		.selpull NSExponent
		.selpull NSStatus
		ply
		.exitcmd

; ************************************************************************************************
;
;		GP.ELSE : nothing to do at all. It exists as a token because FixBranches needs somewhere
;		for the last GP.CASE's .casenext to land, and because the case bodies above it branch to
;		the GP.ENDSEL rather than falling through it.
;
; ************************************************************************************************

CommandXElse: ;; [gp.else]
		.entercmd
		.exitcmd

; ************************************************************************************************
;
;		GP.ENDSEL : drop the selector's frame. Reached three ways -- fallen out of the last case
;		body, branched to by a .caseend, or branched to by the .casenext of a select with nothing
;		matching and no GP.ELSE. All three want exactly this, which is why it is the target of
;		every branch rather than the instruction after it.
;
; ************************************************************************************************

CommandXEndSelect: ;; [gp.endsel]
		.entercmd
		jsr 	SelectFindFrame
		jsr 	StackCloseFrame
		.exitcmd

; ************************************************************************************************
;
;		Same guard NEXT and GP.LOOP use: a well nested select has its own frame on top, so
;		StackFindFrame would spend its time finding what is under its nose. Any other byte -- an
;		abandoned FOR opened inside a case body, or the $FF stack-empty marker that raises the
;		structure error for a GP.CASE with no GP.SELECT -- falls through to the general path,
;		which discards the strays on the way down.
;
; ************************************************************************************************

SelectFindFrame:
		lda 	(runtimeStackPtr)
		cmp 	#FRAME_SELECT
		beq 	_SelFrameHere
		lda 	#FRAME_SELECT
		jmp 	StackFindFrame
_SelFrameHere:
		rts

; ************************************************************************************************
;
;		0	GP.SELECT Marker 		[1]
;		1 	Selector 				[6]		mantissa 0-3, exponent, status -- one whole number
;											stack entry, copied out and back verbatim
;
; ************************************************************************************************

		.send 	code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		17/08/26		Written.
;
; ************************************************************************************************
