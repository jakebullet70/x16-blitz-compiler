; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		00compiler.asm
;		Purpose:	Compiler main
;		Created:	15th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						On entry YX points to API.  On Exit CC if okay.
;
; ************************************************************************************************

StartCompiler:
		stx 	zTemp0 						; access API
		sty 	zTemp0+1

		ldy 	#CompilerErrorHandler >> 8 	; set error handler to compiler one.
		ldx 	#CompilerErrorHandler & $FF
		jsr 	SetErrorHandler
		;
		ldy 	#1 							; copy API vector		
		lda 	(zTemp0)	
		sta 	APIVector
		lda 	(zTemp0),y
		sta 	APIVector+1

		iny 								; copy data area range.
		lda 	(zTemp0),y 					
		sta 	compilerStartHigh
		iny
		lda 	(zTemp0),y 					
		sta 	compilerEndHigh

		tsx 								; save stack pointer
		stx 	compilerSP

		stz 	passNumber 					; the first of the two
		stz 	pass1VarSpace 				; nothing known yet, so pass one emits zeroes into the
		stz 	pass1VarSpace+1 			; _variable.space operand and pass two emits the answer

; ************************************************************************************************
;
;		THE WHOLE SOURCE IS COMPILED TWICE, and the two passes produce exactly the same object.
;
;		Pass one exists to answer the questions a single forward pass cannot: where every line
;		ends up, how much space the variables need, where each block's forward branches land.
;		Pass two then compiles the same source again knowing all of it, so nothing has to be
;		written down and gone back to.
;
;		THE TWO PASSES PRODUCING THE SAME OBJECT IS A LOAD-BEARING ASSUMPTION and nothing in the
;		structure enforces it -- so it is checked rather than trusted. Each pass lays its object
;		out and ObjectChecksum sums the result; the tail of pass two compares that, the length
;		and the variable space against pass one's before anything is written out. A mismatch is a
;		compiler bug and says so; it is never a silently wrong object, which is the one failure
;		this must not have.
;
;		THE FINISHED OBJECT, NOT THE STREAM OF WRITES. It was the stream to begin with, summed in
;		WriteCodeByte, and that is the weaker check: the object is what ships, and the order the
;		bytes are written in is free to differ -- a region is emitted where it appears and moved
;		afterwards, and it will not always be.
;
;		Everything a compile accumulates has to be back at its starting value for pass two, which
;		is what ResetPassState is for. Anything missed from it shows up as a checksum mismatch on
;		the first program that touches it, rather than as a corrupt object months later.
;
; ************************************************************************************************

CompilePass:
		jsr 	ResetPassState 				; every counter and table this pass will fill

		lda 	#BLC_OPENIN					; reset data input
		jsr 	CallAPIHandler

		lda 	#BLC_RESETOUT 				; reset data output.
		jsr 	CallAPIHandler
		;
		;		_variable.space -- how much room the variables need. It sits at the very top of
		;		the program and the answer is only known at the very bottom, which is exactly the
		;		shape of problem the second pass exists to solve: pass one emits nothing useful
		;		here and finishes with the total, pass two writes that total straight in.
		;
		;		This used to be patched in place by FixBranches, which is why the opcode was here
		;		in the first place -- it was a one-pass compiler with one two-pass-shaped hole in
		;		it. That handler is gone.
		;
		lda 	#PCD_CMD_VARSPACE
		jsr 	WriteCodeByte
		lda 	pass1VarSpace 				; zero in pass one, the real figure in pass two --
		jsr 	WriteCodeByte 				; the one place the two objects differ on purpose,
		lda 	pass1VarSpace+1 			; which is why ObjectChecksum skips these two bytes
		jsr 	WriteCodeByte
		;
		;		Emit the jump to the implicit-DIM prologue. The prologue lives at line $FFFF
		;		(emitted at the end); it dimensions every undimensioned array and then jumps to
		;		the first real line. It is emitted whether or not any arrays need it -- with none
		;		it is just a jump straight back -- because we don't yet know if the program has
		;		any. VARSPACE has already run, so the array allocator (availableMemory) is set up
		;		by the time the prologue executes.
		;
		lda 	#$FF 						; -> line $FFFF (the prologue)
		sta 	branchTarget
		sta 	branchTarget+1
		lda 	#PCD_CMD_GOTO
		jsr 	WriteBranchTo
		;
		;		Main compilation loop
		;
MainCompileLoop:
		lda 	#BLC_READIN 				; read next line into the buffer.		
		jsr 	CallAPIHandler

		bcc 	SaveCodeAndExit 			; end of source.
		jsr 	ProcessNewLine 				; set up pointer and line number.
		;
		jsr 	GetLineNumber 				; get line # (=> A low, Y high)
		;
		ldx 	implicitDimFirstSet 		; remember the first real line: the implicit-DIM prologue
		bne 	_MCLHaveFirst 				; jumps back here when it has finished. (A/Y untouched.)
		inc 	implicitDimFirstSet
		sta 	implicitDimFirst
		sty 	implicitDimFirst+1
_MCLHaveFirst:
		jsr 	RegionSwitch 				; pass two: if this line opens or closes a GP.BANKED
											; region, move the write cursor BEFORE the line is
											; marked, so the marker and its table entry land on
											; the side the line belongs to
		jsr 	STRMarkLine 				; remember the code position and number of this line.
		lda 	#PCD_NEWCMD_LINE 			; generate new command line
		jsr 	WriteCodeByte

_MCLSameLine:
		jsr 	GetNextNonSpace 			; get the first character.
		beq 	MainCompileLoop 			; end of line, get next line.
		cmp 	#":"						; if : then loop back.
		beq 	_MCLSameLine
		cmp 	#";" 						; a stray ; between statements (e.g. GOSUB 970;) is
		beq 	_MCLSameLine 				; tolerated by BASIC, so skip it like a colon.

		;
		;		A real statement follows. Checkpoint it for defer-to-runtime: remember the
		;		object write cursor and the compile-loop stack level, and arm SYNTAX-error
		;		deferral. If it then fails to compile with a SYNTAX error, CompilerErrorHandler
		;		rolls back to here and drops a runtime throw-stub in its place (see
		;		DeferStatementToRuntime) instead of aborting. Preserve A (the first character).
		;
		pha
		lda 	objPtr
		sta 	stmtRecoverObj
		lda 	objPtr+1
		sta 	stmtRecoverObj+1
		lda 	#1
		sta 	deferErrors
		pla
		tsx
		stx 	stmtRecoverSP
		;
		cmp 	#0 							; if ASCII then check for implied LET.
		bpl 	_MCLCheckAssignment

		ldx 	#CommandTables & $FF 		; do command tables.
		ldy 	#CommandTables >> 8
		jsr 	GeneratorProcess
		bcc 	_MCLNoHandler 				; a TOKEN the command tables do not know
		stz 	deferErrors 				; compiled OK -> disarm the deferral
		bra 	_MCLSameLine 				; keep trying to compile the line.

		;
		;		A RETIRED KEYWORD MUST NOT DEFER. Getting here means the first character was a
		;		TOKEN (>= $80, so the tokeniser knew the word) and no generator claimed it --
		;		which is a fact about the program, not a typo, because a misspelling arrives as
		;		ASCII and goes to _MCLCheckAssignment instead. Deferring it wrote a runtime
		;		throw-stub and said OK CODE, so a source file left calling GP.STASH or GP.SORT
		;		after they moved to GP.ASM modules compiled clean and threw SYNTAX ERROR at an
		;		address, whenever it was first reached. That cost two hours on 01/09/26 and it
		;		was two separate files, one broken since 15d90eb with nobody noticing.
		;
		;		NOT IMPLEMENTED rather than SYNTAX, for the reason UnsupportedCompile already
		;		gives (gensupport.asm): the word is valid BASIC, so blaming the spelling sends
		;		the reader looking in the wrong place. Only ErrorV_syntax is deferrable, so
		;		naming a different error is what makes this abort -- see errorhandler.asm.
		;
_MCLNoHandler:
		.error_unimplemented

_MCLSyntax: 								; syntax error.
		.error_syntax
		;
		;		Implied assignment ?
		;
_MCLCheckAssignment:
		jsr 	CharIsAlpha 				; if not alpha then syntax error
		bcc 	_MCLSyntax
		jsr 	CommandLETHaveFirst  		; LET first character, do assign
		stz 	deferErrors 				; assignment compiled OK -> disarm the deferral
		bra		_MCLSameLine 				; loop back.
		;
		;		End of compile, fix up GOTO/GOSUB etc., save it and exit.
		;
; ************************************************************************************************
;
;		Reached from CompilerErrorHandler when a statement failed to compile with a SYNTAX error
;		while deferral was armed. The stack is already unwound to stmtRecoverSP and the object
;		cursor rolled back to stmtRecoverObj, so just drop a single throw-stub in the statement's
;		place (raises SYNTAX ERROR at runtime, but only if reached) and carry on at the next
;		line -- the remainder of this line sits after the stub, so it can never run.
;
; ************************************************************************************************

DeferStatementToRuntime:
		lda 	#PCD_CMD_DEFERROR
		jsr 	WriteCodeByte
		jmp 	MainCompileLoop 			; drop the rest of this source line: everything after the
										; stub is unreachable (it throws first), so read the next line.

SaveCodeAndExit:
		lda 	#BLC_CLOSEIN				; finish input.
		jsr 	CallAPIHandler

		lda 	#$00 						; end-of-program line = $FE00 for forward THEN / goto-past-end.
		ldy 	#$FE 						; Deliberately NOT $FFxx: STRFindLine treats any entry whose
		jsr 	STRMarkLine 				; line-number high byte is $FF as the end-of-table sentinel,
		lda 	#PCD_EXIT 					; so only the $FFFF prologue line (the last entry) may use it.
		jsr 	WriteCodeByte 				; ($FE00 is above every real line and forward-THEN target.)
		;
		;		The implicit-DIM prologue. Unreachable by fall-through (the END above stops first);
		;		entered only by the GOTO $FFFF that StartCompiler emitted at the very top. It
		;		dimensions every undimensioned array, then jumps back to the first real line.
		;
		lda 	#$FF 						; prologue line = $FFFF (the largest line, marked last, so it
		ldy 	#$FF 						; is also the $FF end-of-table sentinel STRFindLine expects)
		jsr 	STRMarkLine
		jsr 	EmitImplicitDims
		lda 	implicitDimFirst 			; return to the first real line (or to the END marker
		sta 	branchTarget 				; at $FE00 if the program has none)
		lda 	implicitDimFirst+1
		sta 	branchTarget+1
		lda 	#PCD_CMD_GOTO
		jsr 	WriteBranchTo
		;
		lda 	#$FF 						; add end marker
		jsr 	WriteCodeByte
		;
		;		END OF A PASS. Both passes lay the object out -- the pool goes on, the regions are
		;		moved into place, the branches are resolved -- and then the finished object is
		;		checksummed. Pass one stops there and goes round again; everything below the
		;		comparison runs once.
		;
		jsr 	AsmFlushPool 				; append the GP.ASM blob pool AFTER the $FF end marker,
											; where nothing walks -- see commands/gpasmcode.asm
		lda 	passNumber
		bne 	_SCEPlaced
		jsr 	GPBankRelocate 				; PASS ONE ONLY. It lifts each region out to the end
		jsr 	SaveLayout 					; of the object and works out where they all go; pass
		bra 	_SCEResolve 				; two is handed that and writes them there directly
_SCEPlaced:
		jsr 	ClaimRegionTop 				; the layout itself was restored before this pass began
		;
		;		BOTH PASSES RESOLVE, so the checksum compares a FINISHED object rather than one
		;		with holes in it. That is what lets the resolving move into pass two's emitter one
		;		branch kind at a time: pass one still answers from the laid-out object, the old
		;		way, and a disagreement between the two answers is a mismatch here rather than a
		;		wrong program. Pass one keeps FixBranches for as long as it has a buffer to walk.
		;
		;		FIXBRANCHES DESTROYS objPtr. It rewinds to the start and walks to the end marker,
		;		so it comes back pointing at the $FF -- and everything after that is invisible to
		;		it. That used to be the whole object, because the GP.ASM pool was appended
		;		afterwards. Now the pool goes on first, and objPtr is the length WriteObjectCode
		;		streams, so leaving it at the end marker silently truncated every pool: a program
		;		with an inline blob compiled OK and jumped into nothing at the first call.
		;
_SCEResolve:
		lda 	passNumber
		bne 	_SCEChecksum 				; PASS TWO RESOLVES EVERY BRANCH WHERE IT WRITES IT.
		lda 	objPtr 						; Nothing is left for a second look, which is what
		sta 	objectEnd 					; step seven needs: an object that is final on the
		lda 	objPtr+1 					; way out can go straight to the file.
		sta 	objectEnd+1
		jsr 	FixBranches 				; fix up GOTO/GOSUB etc.
		lda 	objectEnd
		sta 	objPtr
		lda 	objectEnd+1
		sta 	objPtr+1
		;
		;		THE LENGTH IS THE LAST THING PASS ONE HAD TO FIND OUT, so this is where the
		;		application settles what follows from it -- how much of the runtime this program
		;		needs, where its object code lands, where its workspace starts. PROGRAM TOO BIG
		;		is that test, and it is here now rather than after the whole compile: a program
		;		with no room to run is refused before pass two writes a byte of it.
		;
		;		BEFORE THE CHECKSUM, because pass two is going to be told these answers and
		;		compile against them -- so pass one has to have finished with them too.
		;
		lda 	#BLC_ENDPASS1
		jsr 	CallAPIHandler
		bcc 	_SCEChecksum
		sec 								; too big, and it has already said so
		jmp 	ExitCompiler
_SCEChecksum:
		jsr 	ObjectChecksum
		;
		lda 	passNumber
		bne 	_SCECompare
		;
		lda 	passSum 					; what pass two now has to reproduce, exactly
		sta 	pass1Sum
		lda 	passSum+1
		sta 	pass1Sum+1
		lda 	objPtr
		sta 	pass1Len
		lda 	objPtr+1
		sta 	pass1Len+1
		lda 	freeVariableMemory 			; ...and the answer pass two writes into the operand
		sta 	pass1VarSpace 				; at the top of the program. STRReset zeroes the
		lda 	freeVariableMemory+1 		; original, so it has to be kept here.
		sta 	pass1VarSpace+1
		inc 	passNumber
		jmp 	CompilePass

		;
		;		Pass two. Length first, then the sum: a length mismatch is the likelier bug and
		;		the more informative one, though both land in the same place.
		;
_SCECompare:
		lda 	objPtr
		cmp 	pass1Len
		bne 	_SCEDiverged
		lda 	objPtr+1
		cmp 	pass1Len+1
		bne 	_SCEDiverged
		lda 	passSum
		cmp 	pass1Sum
		bne 	_SCEDiverged
		lda 	passSum+1
		cmp 	pass1Sum+1
		bne 	_SCEDiverged
		;
		;		And the variable space, which pass two wrote into the program before it had
		;		recomputed it. Free to check, and it is what covers the three bytes ObjectChecksum
		;		skips -- the only place the two objects are meant to differ.
		;
		lda 	freeVariableMemory
		cmp 	pass1VarSpace
		bne 	_SCEDiverged
		lda 	freeVariableMemory+1
		cmp 	pass1VarSpace+1
		beq 	_SCEAgreed
		;
		;		The passes disagree, so some piece of compile state was carried from one into the
		;		other -- ResetPassState is missing something. Nothing has been written yet, and
		;		nothing is going to be: an object built from two different compiles of the same
		;		source is exactly the corrupt output this check exists to prevent.
		;
_SCEDiverged:
		.error_internal

_SCEAgreed:
		lda 	#BLC_CLOSEOUT 				; close output store, which is already resolved
		jsr 	CallAPIHandler
		clc 								; CC = success

ExitCompiler:
		ldx 	compilerSP 					; reload SP and exit.
		txs
		rts

; ************************************************************************************************
;
;		Put every piece of state a compile accumulates back to where it started, so the next pass
;		sees exactly what the last one saw. Called once per pass, before a byte is read or
;		written.
;
;		THE STORAGE SECTION IS UNINITIALISED RAM (a .dsection at $0400, below the loaded file --
;		see common.inc), so most of this was already needed for the FIRST pass. What the second
;		pass adds is the two GP.ASM counters below, which live in the code section and so used to
;		arrive zeroed by the loader and never needed clearing again.
;
; ************************************************************************************************

ResetPassState:
		jsr 	STRReset 					; line number table, variable list, free variable memory

		stz 	SelectDepth 				; open GP.SELECTs, for the selector-variable stack
		stz 	blockDepth 					; GP.DO nesting -- a non-zero start makes every GOTO
											; emit an .unwind it does not need
		stz 	blockCount 					; ...and the ordinals handed to the blocks themselves,
		stz 	blockCount+1 				; which BOTH passes count out and must agree on
		stz 	altCount
		stz 	altCount+1
		stz 	ifDepth 					; no GP.IF open
		stz 	gpBankState 				; no GP.BANKED region seen yet, and nothing relocated.
		stz 	gpBankActive
		stz 	gpBankCount 				; MUST start at zero: it is the length of every region
											; table, so a stale byte walks all of them off the end.
		stz 	gpBankNumber 				; The last two are read unconditionally by the bootstrap
		stz 	gpBankRunBase 				; patch table, and gpBankRunBase derives from FreeMemory,
											; so left stale it writes a dead byte into a non-banked
											; object that MOVES when the compiler's own size changes.
		stz 	implicitDimCount
		stz 	implicitDimFirstSet
		stz 	clrCheckpoint 				; no CLR compiled yet -> no array is re-DIMmable
		stz 	clrCheckpoint+1
		stz 	deferErrors 				; not deferring compile errors until a statement arms it
		lda 	#$00 						; default return target $FE00 (the END marker) so an
		sta 	implicitDimFirst 			; empty program's prologue just exits cleanly.
		lda 	#$FE
		sta 	implicitDimFirst+1
		;
		;		GP.ASM. The pool and the fixup list are both rebuilt from scratch by each pass --
		;		the fixups especially, because AsmFixTarget records the address the operand landed
		;		at, and pass one's addresses are not the ones PatchAsmFixups will be resolving.
		;
		stz 	AsmPoolLen
		stz 	AsmPoolLen+1
		stz 	AsmFixupCount
		;
		stz 	nextRegion 					; ...and pass two's place in the region layout
		stz 	regionOpen
		;
		;		PASS TWO STARTS WITH PASS ONE'S REGION LAYOUT ALREADY IN PLACE, because it needs
		;		it while it compiles and not merely afterwards: a branch that crosses into or out
		;		of a region is out by the difference between where the region sits and the $A000
		;		it runs at, and GPBankMakeOffset cannot correct that without the table. The lines
		;		above have just cleared the two fields that say a layout exists, so this goes last.
		;
		lda 	passNumber
		beq 	_RPSDone
		jsr 	RestoreLayout
_RPSDone:
		rts

; ************************************************************************************************
;
;		Fletcher-16 over the object this pass has just laid out. Called once per pass, after the
;		pool has gone on, the regions have been placed and the branches resolved, so what it sums
;		is the object exactly as it would be written to disk.
;
;		THE FIRST THREE BYTES ARE SKIPPED. They are _variable.space and its operand, and the
;		operand is the one thing the two passes are MEANT to differ on -- pass one does not yet
;		know the figure. The opcode is a constant and the figure is compared directly in the
;		tail, so nothing is left uncovered.
;
;		BLC_RESETOUT is how the object's base is found: the compiler library cannot name
;		FreeMemory -- it is an application symbol, and this half also builds standalone -- and
;		resetting the cursor is the only thing that asks the API where the object starts.
;		FixBranches rewinds the same way.
;
; ************************************************************************************************

ObjectChecksum:
		lda 	objPtr 						; where the object ends, over the rewind below
		sta 	sumEnd
		lda 	objPtr+1
		sta 	sumEnd+1

		lda 	#BLC_RESETOUT
		jsr 	CallAPIHandler
		clc 								; ...and start three bytes in, past _variable.space
		lda 	objPtr
		adc 	#3
		sta 	zTemp0
		lda 	objPtr+1
		adc 	#0
		sta 	zTemp0+1

		stz 	passSum
		stz 	passSum+1
_OCLoop:
		lda 	zTemp0+1 					; reached the end ?
		cmp 	sumEnd+1
		bne 	_OCByte
		lda 	zTemp0
		cmp 	sumEnd
		beq 	_OCDone
_OCByte:
		lda 	(zTemp0)
		clc
		adc 	passSum 					; sum1 += byte
		sta 	passSum
		clc
		adc 	passSum+1 					; sum2 += sum1, so a reordering shows up too
		sta 	passSum+1
		inc 	zTemp0
		bne 	_OCLoop
		inc 	zTemp0+1
		bra 	_OCLoop
_OCDone:
		lda 	sumEnd 						; put the cursor back: it is the object's length, and
		sta 	objPtr 						; WriteObjectCode streams up to it
		lda 	sumEnd+1
		sta 	objPtr+1
		rts

; ************************************************************************************************
;
;		PASS TWO WRITES EACH GP.BANKED REGION STRAIGHT INTO ITS FINAL PLACE.
;
;		Pass one compiles a region where it appears and GPBankRelocate rotates it out to the end
;		of the object afterwards -- see the diagram in commands/gpbank.asm. So pass one has
;		already worked out where every region lands, and pass two is handed the answer: reaching
;		the GP.BANKED line it drops the entry bridge in low memory and moves the write cursor to
;		the region's address, and reaching the GP.ENDBANKED line it writes the exit bridge and
;		the region's end marker and moves the cursor back. Nothing is rotated.
;
;		THE SWITCH HAPPENS BEFORE THE LINE IS MARKED, which is why this is called from the main
;		loop and not from the GP.BANKED generator. A region begins ON the GP.BANKED line's marker
;		byte, so by the time the generator runs the marker has already been written -- into low
;		memory, where it does not belong.
;
;		Regions cannot nest and are placed in source order, so which one is next is an index
;		rather than a search.
;
; ************************************************************************************************

RegionSwitch:
		pha 								; STRMarkLine IS CALLED WITH THE LINE NUMBER IN YA --
		phx 								; GetLineNumber loaded it before the main loop reached
		phy 								; here -- so this has to hand A, X and Y back untouched
		jsr 	RegionSwitchWork
		ply
		plx
		pla
		rts

RegionSwitchWork:
		lda 	passNumber 					; pass one compiles inline and relocates afterwards,
		beq 	_RSDone 					; exactly as it always did
		lda 	regionOpen
		bne 	_RSClosing
		;
		;		Outside a region. Does this line open the next one ? gpBankLinesIn still holds
		;		pass one's answer at this point: pass two writes its own copy in the generator,
		;		which runs after this, and writes the same value.
		;
		lda 	nextRegion
		cmp 	layoutCount
		bcs 	_RSDone 					; every region is placed already
		asl 	a
		tax
		lda 	currentLineNumber
		cmp 	gpBankLinesIn,x
		bne 	_RSDone
		lda 	currentLineNumber+1
		cmp 	gpBankLinesIn+1,x
		bne 	_RSDone
		;
		;		It does. The entry bridge stays behind in low memory, where the region used to
		;		be, and the cursor moves to where the region goes.
		;
		phx 								; X IS THE REGION, and the bridge now resolves its own
		jsr 	_RSBridge 					; target -- which goes through GPBankMakeOffset, and
		plx 								; that works through X
		lda 	objPtr
		sta 	lowResume
		lda 	objPtr+1
		sta 	lowResume+1
		lda 	layoutStart,x
		sta 	objPtr
		lda 	layoutStart+1,x
		sta 	objPtr+1
		inc 	regionOpen
_RSDone:
		rts
		;
		;		Inside a region. Does this line close it ? The GP.ENDBANKED line's marker belongs
		;		in LOW memory -- it is the first byte of what follows the region, not the last
		;		byte of it -- so the region has to be finished off before that marker is written.
		;
_RSClosing:
		lda 	nextRegion
		asl 	a
		tax
		lda 	currentLineNumber
		cmp 	gpBankLinesOut,x
		bne 	_RSDone
		lda 	currentLineNumber+1
		cmp 	gpBankLinesOut+1,x
		bne 	_RSDone

		jsr 	_RSBridge
		lda 	#$FF 						; the region's own end marker, which is what stops the
		jsr 	WriteCodeByte 				; walkers once they have hopped up here
		lda 	lowResume
		sta 	objPtr
		lda 	lowResume+1
		sta 	objPtr+1
		stz 	regionOpen
		inc 	nextRegion
		rts
;
;		Both bridges are GOTO THIS LINE, and that is the whole trick -- a region begins and ends
;		on a line marker, so both lines have a table entry pointing exactly at a boundary and
;		FixBranches resolves the bridges by the path it resolves every other branch. No new
;		opcode and no absolute operand. See the header in commands/gpbank.asm.
;
_RSBridge:
		lda 	currentLineNumber 			; both bridges go to the line the switch happens on:
		sta 	branchTarget 				; the entry one into the region, the exit one back out
		lda 	currentLineNumber+1
		sta 	branchTarget+1
		lda 	#PCD_CMD_GOTO
		jmp 	WriteBranchTo

; ************************************************************************************************
;
;		The layout pass one worked out, kept across the reset and handed back to pass two.
;
;		A BULK COPY RATHER THAN A SECOND CALCULATION. Pass two records region bounds of its own
;		as it compiles -- it has to, the generators are the same code -- but they describe where
;		it PUT things, which for gpBankEnds is not what the relocator means by the same name.
;		Overwriting the lot afterwards is shorter than teaching the generators the difference,
;		and it is pass one's figures that FixBranches and the bootstrap patcher want.
;
;		THE ALIGNMENT PADDING IS NOT REWRITTEN. Pass two lands its low code and its regions on
;		the addresses pass one used, in the same buffer, so the gaps between them still hold the
;		bytes pass one left there. That stops being true the day pass two streams to a file, and
;		the gaps will have to be filled then.
;
; ************************************************************************************************

SaveLayout:
		lda 	gpBankCount
		sta 	layoutCount
		beq 	_SLDone 					; no regions, nothing to keep
		asl 	a 							; the two-byte tables want the count doubled
		tax
_SLLoop:
		dex
		lda 	gpBankStarts,x
		sta 	layoutStart,x
		lda 	gpBankEnds,x
		sta 	layoutEnd,x
		lda 	gpBankHops,x
		sta 	layoutHops,x
		txa
		bne 	_SLLoop

		ldx 	layoutCount
_SLByteLoop:
		dex
		lda 	gpBankPageCounts,x
		sta 	layoutPages,x
		lda 	gpBankCrossings,x
		sta 	layoutCross,x
		txa
		bne 	_SLByteLoop

		lda 	gpBankRunBase
		sta 	layoutRunBase
_SLDone:
		rts

RestoreLayout:
		lda 	layoutCount
		beq 	_RLDone 					; no regions, and nothing pass two did needs undoing
		sta 	gpBankCount
		asl 	a
		tax
_RLLoop:
		dex
		lda 	layoutStart,x
		sta 	gpBankStarts,x
		lda 	layoutEnd,x
		sta 	gpBankEnds,x
		lda 	layoutHops,x
		sta 	gpBankHops,x
		txa
		bne 	_RLLoop

		ldx 	layoutCount
_RLByteLoop:
		dex
		lda 	layoutPages,x
		sta 	gpBankPageCounts,x
		lda 	layoutCross,x
		sta 	gpBankCrossings,x
		txa
		bne 	_RLByteLoop

		lda 	layoutRunBase
		sta 	gpBankRunBase
		lda 	#1 							; the hop is open: the walk crosses the low code and
		sta 	gpBankActive 				; then jumps up to the regions
_RLDone:
		rts

; ************************************************************************************************
;
;		The object reaches the top of the LAST region, and pass two's write cursor came to rest
;		at the end of the low code -- the regions are above it and it did not write them last.
;		Pass one's length is that top, so take it back, or WriteObjectCode would stream the low
;		code and stop.
;
; ************************************************************************************************

ClaimRegionTop:
		lda 	layoutCount
		beq 	_CRTDone 					; no regions, so the cursor is already the top
		lda 	pass1Len
		sta 	objPtr
		lda 	pass1Len+1
		sta 	objPtr+1
_CRTDone:
		rts

; ************************************************************************************************
;
;										Call API Functions
;
; ************************************************************************************************

CallAPIHandler:
		jmp 	(APIVector)

; ************************************************************************************************
;
;		Emit the runtime code that dimensions every registered undimensioned array to bound 10
;		(11 elements, 0..10) in each dimension -- exactly what interpreted BASIC does on first
;		use. Emitted once, into the prologue. Each list entry is 4 bytes: slot addr lo, slot addr
;		hi, element type, dimension count. The emitted sequence per array mirrors CommandDIM:
;		push the bound once per dimension, push the dimension count, push the type, DIM (which
;		builds the array and leaves its offset on the stack), then store that offset into the
;		array variable's slot.
;
; ************************************************************************************************

EmitImplicitDims:
		lda 	implicitDimCount
		bne 	_EIDGo
		rts 								; nothing undimensioned -> emit nothing.
_EIDGo:
		sta 	implicitDimEntries
		stz 	implicitDimIdx
_EIDLoop:
		ldx 	implicitDimIdx 				; dimension count for this array (registered >= 1)
		lda 	implicitDimList+3,x
		beq 	_EIDSkip 					; 0 = tombstoned: an explicit DIM took this array over,
		sta 	implicitDimN 				; so it dimensions it for real -- emit nothing here.
		sta 	implicitDimRem
_EIDPushBound:								; push the bound 10 once per dimension
		lda 	implicitDimRem
		beq 	_EIDPushed
		lda 	#10
		jsr 	PushIntegerA
		dec 	implicitDimRem
		bra 	_EIDPushBound
_EIDPushed:
		lda 	implicitDimN 				; push the dimension count
		jsr 	PushIntegerA
		ldx 	implicitDimIdx 				; push the element type
		lda 	implicitDimList+2,x
		jsr 	PushIntegerA
		.keyword PCD_DIM 					; build the array, leaving its offset on the stack
		ldx 	implicitDimIdx 				; store that offset into the array variable's slot
		lda 	implicitDimList+0,x
		ldy 	implicitDimList+1,x
		tax 								; X = addr lo, Y = addr hi
		lda 	#NSSIFloat+NSSIInt16 		; pretend int16, exactly as CommandDIM stores it
		sec
		jsr 	GetSetVariable
_EIDSkip:
		lda 	implicitDimIdx 				; advance to the next entry
		clc
		adc 	#4
		sta 	implicitDimIdx
		dec 	implicitDimEntries
		bne 	_EIDLoop
		rts

		.send code

		.section storage
compilerSP:									; stack pointer 6502 on entry.
		.fill 	1
APIVector: 									; call API here
		.fill 	2
compilerStartHigh:							; MSB of workspace start address
		.fill 	1
compilerEndHigh:							; MSB of workspace end address
		.fill 	1
objectEnd:									; the true end of the object, held across FixBranches --
		.fill 	2							; which rewinds objPtr and leaves it at the end marker
;
;		The two passes. passNumber is 0 while the first is running and 1 for the second, and it
;		is the only thing that tells them apart -- everything else about a pass is identical, by
;		construction and by the checksum below.
;
passNumber:								; 0 = first pass, 1 = second
		.fill 	1
passSum:									; Fletcher-16 over the object this pass laid out
		.fill 	2
sumEnd:										; one past its last byte, held across the walk
		.fill 	2
;
;		The GP.BANKED layout, carried from pass one into pass two. The tables mirror the ones in
;		commands/gpbank.asm they are copied from.
;
layoutCount:								; regions pass one found and placed
		.fill 	1
layoutStart:								; where each one ended up
		.fill 	2*GPBANK_MAXREGIONS
layoutEnd:									; and one past where each one ends
		.fill 	2*GPBANK_MAXREGIONS
layoutHops:									; where the walk leaves off to reach each one
		.fill 	2*GPBANK_MAXREGIONS
layoutPages:								; pages of each, for the bootstrap's table
		.fill 	GPBANK_MAXREGIONS
layoutCross:								; what a branch crossing into each one is out by
		.fill 	GPBANK_MAXREGIONS
layoutRunBase:								; the page the whole run of them starts at
		.fill 	1
nextRegion:									; which region pass two is looking for next
		.fill 	1
regionOpen:									; nonzero while pass two is writing into one
		.fill 	1
lowResume:									; where the low code left off, across a region
		.fill 	2
pass1Sum:									; ...and what pass one came to, kept for the compare
		.fill 	2
pass1Len:									; pass one's object length, compared the same way
		.fill 	2
pass1VarSpace:								; what the variables came to -- zero while pass one is
		.fill 	2							; running, which is what it emits into _variable.space
;
;		Implicit array dimensioning. Interpreted BASIC auto-creates an array (0..10 per
;		dimension) the first time it is used without a DIM. We can't do that lazily -- this VM
;		has no branch that targets a point inside a line, so there is nowhere to put a per-access
;		"dimension it if it isn't yet" test. Instead every undimensioned array is registered here
;		as it is discovered, and a prologue at the very start of the program (jumped to before any
;		user code) dimensions them all once. See EmitImplicitDims and _GRTArray.
;
implicitDimCount:							; number of undimensioned arrays registered
		.fill 	1
implicitDimFirst:							; first real line number = where the prologue returns to
		.fill 	2
implicitDimFirstSet:						; nonzero once implicitDimFirst has been captured
		.fill 	1
implicitDimIdx:								; scratch: byte offset into the list while emitting
		.fill 	1
implicitDimEntries:							; scratch: entries left to emit
		.fill 	1
implicitDimN:								; scratch: dimension count of the array being emitted
		.fill 	1
implicitDimRem:								; scratch: bounds left to push for this array
		.fill 	1
implicitDimAddr:							; scratch: a variable slot address
		.fill 	2
implicitDimType:							; scratch: element type bits
		.fill 	1
implicitDimList:							; per entry: slot addr lo, slot addr hi, type, dim count
		.fill 	4*32 						; capacity 32 -- more than that falls back to the old error
deferErrors: 								; nonzero while a statement is compiling whose SYNTAX errors
		.fill 	1 							; should defer to a runtime throw-stub, not abort the compile
stmtRecoverSP: 							; 6502 stack level to unwind to when deferring a statement
		.fill 	1
stmtRecoverObj: 						; object write cursor to roll back to (discards partial code)
		.fill 	2
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
