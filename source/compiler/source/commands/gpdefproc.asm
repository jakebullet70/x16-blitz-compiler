; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpdefproc.asm
;		Purpose:	GP.DEFPROC / GP.SUB -- one line calls to BASL routines
;		Created:	8th September 2026
;		Reviewed: 	No
;		Author:		Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************
;
;		GP.DEFPROC <verb> [,<formal> ...] declares the routine that FOLLOWS it and names the
;		variables its callers fill in. It emits nothing, so the code position it records is the
;		first byte of the next statement. GP.SUB <verb> [,<expression> ...] assigns each
;		expression to the matching formal and calls that position with a .fngosub.
;
;		SO THE P-CODE IS THE ASSIGNMENTS AND THE GOSUB WRITTEN OUT BY HAND, and a program that
;		uses this pays exactly what the long spelling cost. Nothing here writes a keyword token
;		either, so a program whose only GP.BASIC keywords are these two stays GP OUT and carries
;		none of the GP runtime block -- GP.BANKED's argument, for the same reason.
;
;		THE VERB IS AN ORDINARY NAME, kept in the variable list rather than in a table of its own.
;		ExtractVariableName packs a name into X = first character and 31 with the type bits and
;		Y = second character and 63, so bit 7 of Y is spare -- and DEF FN already claims it to
;		keep FNA apart from the variable A. Bit 6 is the other one, and it is what makes a verb
;		a verb here. That is a namespace, not a table: no compile time bank, no per verb storage,
;		and FindVariable returning CC is the "called before it was declared" error for free.
;
;		A RECORD IS AS LONG AS IT NEEDS TO BE. Byte 0 of a variable record is its length and
;		FindVariable walks by it, so a proc record simply runs on past the six bytes
;		CreateVariableRecord writes: byte 5 is the formal count (which FindVariable hands back in
;		A, having read it already) and three bytes a formal follow it -- address low, address
;		high, type -- which is what GetSetVariable takes. The record is created AFTER the formals
;		are read, because reading one may create a variable record of its own and that would land
;		on the space this one is about to grow into.
;
;		THE CALL CARRIES AN ADDRESS, NOT A LINE NUMBER, so a GP.SUB above its GP.DEFPROC cannot
;		work and is refused by name. .fngosub is the opcode for exactly this -- FNCompile's
;		header explains why it is not .gosub -- and WriteBranchToAddress turns the address into
;		an offset, correcting it when either end sits inside a GP.BANKED region and so runs at
;		$A000 rather than where it lies in the object.
;
;		ONE SET OF FORMALS WAS ENOUGH WHILE GP.SUB WAS THE ONLY CALLER, because nothing an
;		argument to a STATEMENT can contain re-enters this file. GP.FN is an expression term and
;		can appear inside an argument to another GP.FN, so procState is a stack now -- pushed
;		and pulled around every argument expression by ProcCompileArguments.
;
; ************************************************************************************************

		.section code

PROC_MAXFORMALS = 12 						; formals one verb may take. Three bytes of the code
											; section each, so the number is about what a shim
											; plausibly wants and not about room.
PROC_FLAG = $40 							; bit 6 of the second name character: this is a verb
GP_TOKEN_RETURNS = 52814 & $FF 			; the second byte of RETURNS ($CE $4E)
PROC_MAXNEST = 8 							; GP.FN calls nested inside one another's
											; arguments. Free bytes in the code section, so the
											; number is generosity and not room

; ************************************************************************************************
;
;		Read a verb name into YX with the verb bit set. A suffix or a subscript makes it a
;		different kind of thing, so all three are refused here rather than quietly ignored.
;
; ************************************************************************************************

ProcReadVerb:
		jsr 	GetNextNonSpace
		jsr 	ExtractVariableName
		txa
		and 	#NSSTypeMask+NSSIInt16+NSSArray
		beq 	_PRVPlain 					; the messages are one block at the end of the file and
		jmp 	ProcBadVerb 				; out of a branch's reach, so every one of them is
_PRVPlain: 									; entered the way object.asm enters _WOCSCodePart
		tya
		ora 	#PROC_FLAG
		tay
		rts

; ************************************************************************************************
;
;										GP.DEFPROC
;
; ************************************************************************************************

CommandDefProcCompile:
		stz 	deferErrors 				; a declaration must never defer to runtime: rolled back, it
										; leaves no verb record, and every call to it then reports
										; itself as being above its own declaration
		jsr 	ProcReadVerb
		phx 								; the name has to outlive the formals
		phy
		jsr 	FindVariable
		bcc 	_CDPNew
		jmp 	ProcDuplicate
_CDPNew:
		;
		;		The formals. GetReferenceTerm creates each one if the program has not used it
		;		yet, and hands back the address GetSetVariable will want at every call site.
		;
		stz 	procCount
_CDPFormal:
		jsr 	LookNextNonSpace
		cmp 	#","
		bne 	_CDPRead
		jsr 	GetNextNonSpace 			; consume the comma
		jsr 	GetNextNonSpace 			; ...and take the first character of the formal
		jsr 	GetReferenceTerm
		cmp 	#0 							; bit 7 set is an array reference, which has just
		bpl 	_CDPScalar 					; compiled its subscripts into the object as well
		jmp 	ProcBadFormal
_CDPScalar:
		sta 	procType
		stx 	procAddr
		sty 	procAddr+1
		ldx 	procCount
		cpx 	#PROC_MAXFORMALS
		bcc 	_CDPFits
		jmp 	ProcTooManyFormals
_CDPFits:
		lda 	procAddr
		sta 	procFormalLo,x
		lda 	procAddr+1
		sta 	procFormalHi,x
		lda 	procType
		sta 	procFormalType,x
		inc 	procCount
		bra 	_CDPFormal
		;
		;		Room for the whole record and the end marker after it. CreateVariableRecord makes
		;		this test for the six bytes it knows about; the formals are this file's to check.
		;
_CDPBadReturn:
		jmp 	ProcBadReturn
_CDPRead:
		;
		;		RETURNS <variable>, if there is one. It names where the routine leaves its result,
		;		and it is what makes the verb callable from GP.FN. A body of many lines cannot hand
		;		one back on the evaluation stack -- new.line empties that at every line -- so the
		;		result travels in a variable and GP.FN reads it once the call is over.
		;
		stz 	procRetBytes
		stz 	procReturnFlag
		jsr 	LookNextNonSpace
		cmp 	#$CE 						; the GP keyword prefix
		bne 	_CDPNoReturns
		jsr 	GetNextNonSpace 			; consume it, then the keyword itself
		jsr 	GetNext
		cmp 	#GP_TOKEN_RETURNS
		bne 	_CDPBadReturn
		jsr 	GetNextNonSpace
		jsr 	GetReferenceTerm 			; created here if the program has not used it yet. Bit 7
		cmp 	#0 							; is an array reference, which has just compiled a subscript
		bmi 	_CDPBadReturn 				; and has no fixed address to write to
		sta 	procRetType
		stx 	procRetLo
		sty 	procRetHi
		lda 	#3 							; three more bytes on the end of the record...
		sta 	procRetBytes
		lda 	#$80 						; ...and bit 7 of the formal count says they are there
		sta 	procReturnFlag
_CDPNoReturns:
		lda 	procCount
		asl 	a
		clc
		adc 	procCount 					; three bytes a formal
		clc
		adc 	procRetBytes 				; and three more for a RETURNS
		clc
		adc 	#7 							; the record itself, and the end marker past it
		clc
		adc 	variableListEnd
		sta 	procScratch
		lda 	variableListEnd+1
		adc 	#0
		cmp 	compilerEndHigh 			; the record must end at or below the top of the bank,
		bcc 	_CDPRoom 					; so on the high byte matching the low byte has to be
		bne 	_CDPTooBig 					; exactly zero
		lda 	procScratch
		beq 	_CDPRoom
_CDPTooBig:
		.error_toobig
_CDPRoom:
		;
		;		Create the record, point it at the code that follows, and run it on past the six
		;		bytes CreateVariableRecord wrote. zTemp0 is the record throughout: nothing between
		;		here and the end may call anything that moves it.
		;
		ply
		plx
		jsr 	CreateVariableRecord
		jsr 	SetVariableRecordToCodePosition

		.varstore_access
		ldy 	#5 							; the formal count, where FindVariable reads it
		lda 	procCount
		ora 	procReturnFlag 				; bit 7 -- a RETURNS variable follows the formals
		sta 	(zTemp0),y
		iny
		ldx 	#0
_CDPWrite:
		cpx 	procCount
		beq 	_CDPWritten
		lda 	procFormalLo,x
		sta 	(zTemp0),y
		iny
		lda 	procFormalHi,x
		sta 	(zTemp0),y
		iny
		lda 	procFormalType,x
		sta 	(zTemp0),y
		iny
		inx
		bra 	_CDPWrite
_CDPWritten:
		ldx 	procRetBytes 				; the RETURNS variable, if the declaration named one
		beq 	_CDPNoRetWrite
		lda 	procRetLo
		sta 	(zTemp0),y
		iny
		lda 	procRetHi
		sta 	(zTemp0),y
		iny
		lda 	procRetType
		sta 	(zTemp0),y
		iny
_CDPNoRetWrite:
		lda 	#0 							; the list's end marker, where the record now ends
		sta 	(zTemp0),y
		tya 								; ...and where it ends is its length
		sta 	(zTemp0)
		.varstore_release
		;
		;		CreateVariableRecord moved the end of the list on by six. The formals are the
		;		rest of it.
		;
		lda 	procCount
		asl 	a
		clc
		adc 	procCount
		clc
		adc 	procRetBytes
		clc
		adc 	variableListEnd
		sta 	variableListEnd
		bcc 	_CDPDone
		inc 	variableListEnd+1
_CDPDone:
		rts

; ************************************************************************************************
;
;										GP.SUB
;
; ************************************************************************************************

CommandSubCompile:
		jsr 	ProcReadVerb
		jsr 	FindVariable
		bcs 	_CSCFound
		jmp 	ProcNotDeclared 			; CC is a call above its own declaration, or a typo
_CSCFound:
		stx 	procTarget 					; X and Y are the code position, A the formal count
		sty 	procTarget+1
		and 	#$7F 						; bit 7 is a RETURNS, which a GP.SUB is entitled to ignore
		sta 	procCount
		;
		;		TAKE THE FORMALS OUT OF THE RECORD NOW. Compiling the first argument expression
		;		uses zTemp0 for its own purposes, so the record is only reachable here.
		;
		.varstore_access
		ldy 	#6
		ldx 	#0
_CSCRead:
		cpx 	procCount
		beq 	_CSCReadDone
		lda 	(zTemp0),y
		sta 	procFormalLo,x
		iny
		lda 	(zTemp0),y
		sta 	procFormalHi,x
		iny
		lda 	(zTemp0),y
		sta 	procFormalType,x
		iny
		inx
		bra 	_CSCRead
_CSCReadDone:
		.varstore_release
		;
		;		Then the arguments, and the call.
		;
		jsr 	ProcCompileArguments
		lda 	procTarget
		sta 	branchTarget
		lda 	procTarget+1
		sta 	branchTarget+1
		lda 	#PCD_CMD_FNGOSUB
		jsr 	WriteBranchToAddress
		rts

; ************************************************************************************************
;
;		The arguments, which GP.SUB and GP.FN read the same way. One argument a formal, in order,
;		each assigned to it -- CommandLET without the left hand side: the same type test, and the
;		same GetSetVariable to write it. On return the next thing in the source is the caller's:
;		end of statement for GP.SUB, the closing bracket for GP.FN.
;
;		EVERY ARGUMENT IS EVALUATED BEFORE ANY OF THEM IS STORED, and that is not tidiness.
;		A formal is a plain variable, so GP.FN(AREA,2,GP.FN(AREA,3,4)) storing as it goes lets
;		the inner call write A.W while the outer call's 2 is already sitting in it -- 36 for what
;		the longhand makes 24, silently, with both passes agreeing. Leaving the values on the
;		evaluation stack until the whole list is read means the inner call runs and finishes
;		before the outer writes a formal at all. The stores then come off the stack LAST FIRST.
;
;		THEY WAIT ON THE FRAME STACK, NOT ON THE EVALUATION STACK, and that is the second half
;		of the same decision. The evaluation stack is twelve slots for the WHOLE expression with
;		no overflow check anywhere -- slot 12 is NSMantissa0[0], so overflowing it corrupts the
;		bottom of the same stack silently -- and twelve formals holding a slot each would have
;		put a real program one deep argument away from that, with PROC_MAXFORMALS as the cap.
;		.fnpush sends each argument to the frame stack as it is evaluated and .fnpop brings it
;		back in front of its store, so the evaluation stack holds one argument at a time however
;		many there are. The LAST one is neither pushed nor popped: it is evaluated last and
;		stored first, so nothing runs between the two. A verb of one formal emits neither.
;
; ************************************************************************************************

ProcCompileArguments:
		stz 	procIndex
_CSCArgument:
		lda 	procIndex
		cmp 	procCount
		beq 	_CSCAllRead
		jsr 	LookNextNonSpace
		cmp 	#","
		beq 	_CSCComma
		jmp 	ProcArity 					; fewer arguments than the declaration has formals
_CSCComma:
		jsr 	GetNextNonSpace 			; consume the comma
		jsr 	ProcStatePush 				; an argument may hold another call, which would
		jsr 	CompileExpressionAt0 		; otherwise compile over this one's formals
		pha 								; the type it came out as
		jsr 	ProcStatePull
		pla
		ldx 	procIndex
		eor 	procFormalType,x 			; only string against number matters, exactly as an
		and 	#NSSTypeMask 				; assignment has it
		bne 	_CSCType
		inc 	procIndex
		lda 	procIndex
		cmp 	procCount 					; the last argument is stored first and nothing runs
		beq 	_CSCArgument 				; between, so it waits where it already is
		lda 	#PCD_CMD_FNPUSH
		jsr 	WriteCodeByte
		bra 	_CSCArgument
		;
		;		A comma left over is one argument too many.
		;
_CSCAllRead:
		jsr 	LookNextNonSpace
		cmp 	#","
		beq 	_CSCTooMany
		;
		;		Now the stores, LAST FORMAL FIRST -- the values are sitting on the evaluation
		;		stack in the order they were written and GetSetVariable takes the top one.
		;
_CSCStore:
		dec 	procIndex
		bmi 	_CSCEmit
		lda 	procIndex
		inc 	a
		cmp 	procCount 					; ...so the last formal takes its value off the evaluation
		beq 	_CSCTop 					; stack, and every other one off the frame stack
		lda 	#PCD_CMD_FNPOP
		jsr 	WriteCodeByte
_CSCTop:
		ldx 	procIndex
		lda 	procFormalType,x
		pha
		lda 	procFormalHi,x
		tay
		lda 	procFormalLo,x
		tax
		pla
		sec
		jsr 	GetSetVariable
		bra 	_CSCStore
_CSCEmit:
		rts

_CSCTooMany:
		jmp 	ProcArity 					; more arguments than the declaration has formals

_CSCType:
		.error_type

; ************************************************************************************************
;
;		Save and restore everything a call in progress knows, around one argument expression.
;
;		GP.SUB got away with a single set of these because a statement's argument cannot contain
;		another GP.SUB. GP.FN can: GP.FN(V, GP.FN(W,1)) reads W's formals over V's while V is
;		still using them, and V then assigns its remaining arguments to whatever W declared --
;		silently, and with both passes agreeing. The buffers are in the code section, so depth
;		costs a compiled program nothing and PROC_MAXNEST is set by what anyone might plausibly
;		write rather than by room.
;
; ************************************************************************************************

ProcStatePush:
		lda 	procNest
		cmp 	#PROC_MAXNEST
		bcs 	_PSPDeep
		jsr 	ProcStateSlot
		inc 	procNest
		ldy 	#0
_PSPCopy:
		lda 	procState,y
		sta 	(zTemp0),y
		iny
		cpy 	#PROC_STATE
		bne 	_PSPCopy
		rts
_PSPDeep:
		jmp 	ProcTooDeep

ProcStatePull:
		dec 	procNest
		jsr 	ProcStateSlot
		ldy 	#0
_PSLCopy:
		lda 	(zTemp0),y
		sta 	procState,y
		iny
		cpy 	#PROC_STATE
		bne 	_PSLCopy
		rts

;
;		zTemp0 = procSaveStack + procNest * PROC_STATE. A loop rather than a multiply: the depth
;		is eight, and zTemp0 is free here because the variable window is released before an
;		argument is compiled and GetSetVariable does not run until after it.
;
ProcStateSlot:
		lda 	#<procSaveStack
		sta 	zTemp0
		lda 	#>procSaveStack
		sta 	zTemp0+1
		ldx 	procNest
		beq 	_PSSDone
_PSSAdd:
		clc
		lda 	zTemp0
		adc 	#PROC_STATE
		sta 	zTemp0
		bcc 	_PSSNext
		inc 	zTemp0+1
_PSSNext:
		dex
		bne 	_PSSAdd
_PSSDone:
		rts

; ************************************************************************************************
;
;										GP.FN
;
;		GP.FN(<verb>[, <expression> ...]) is GP.SUB from inside an expression. The arguments go
;		into the formals in exactly the same way, and the result comes back out of the variable
;		the declaration named after RETURNS -- which is why a verb without one cannot be called
;		this way, and is told so by name.
;
;		WHAT IT ADDS IS THE PAIR AROUND THE CALL. GP.SUB is a STATEMENT, so nothing of the
;		caller's is half finished when the routine runs. "A + GP.FN(V,1)" reaches the call with
;		A already on the evaluation stack, and the callee's first new.line would empty it --
;		ldx #$FF and stz stringInitialised, in front of every source line. .fnsave and
;		.fnrestore carry the stack and the string temporaries across; the whole of why they
;		exist is written up in gp-runtime/commands/gpfncall.asm.
;
;		THE ARGUMENTS ARE COMPILED BEFORE THE .fnsave, and that is what makes the pair small
;		enough to be worth having: each one is consumed into its formal as it is read, so at the
;		save there is nothing on the stack but the caller's own.
;
;		THE TYPE IS THE RETURNS VARIABLE'S, so this ends the generator itself -- CS with the
;		type in A, exactly as _GEXExitNumber and _GEXExitString do. The N in unary.def is
;		never reached and is there to keep the row looking like its neighbours.
;
; ************************************************************************************************

GPFNCompile:
		jsr 	CheckNextLParen
		jsr 	ProcReadVerb
		jsr 	FindVariable
		bcs 	_GPFFound
		jmp 	ProcFnNotDeclared 			; CC is a call above its own declaration, or a typo
_GPFFound:
		stx 	procTarget 					; X and Y are the code position, A the formal count
		sty 	procTarget+1
		tax 								; ...whose bit 7 says a RETURNS variable follows them
		and 	#$7F
		sta 	procCount
		txa
		bmi 	_GPFHasReturn
		jmp 	ProcNoReturn
_GPFHasReturn:
		;
		;		TAKE THE FORMALS AND THE RETURN VARIABLE OUT OF THE RECORD NOW. Compiling the
		;		first argument expression uses zTemp0 for its own purposes, so the record is
		;		only reachable here.
		;
		.varstore_access
		ldy 	#6
		ldx 	#0
_GPFRead:
		cpx 	procCount
		beq 	_GPFReadDone
		lda 	(zTemp0),y
		sta 	procFormalLo,x
		iny
		lda 	(zTemp0),y
		sta 	procFormalHi,x
		iny
		lda 	(zTemp0),y
		sta 	procFormalType,x
		iny
		inx
		bra 	_GPFRead
_GPFReadDone:
		lda 	(zTemp0),y 					; the RETURNS variable sits past the last formal
		sta 	procRetLo
		iny
		lda 	(zTemp0),y
		sta 	procRetHi
		iny
		lda 	(zTemp0),y
		sta 	procRetType
		.varstore_release
		;
		;		The arguments, then the call with the save and the restore around it.
		;
		jsr 	ProcCompileArguments
		jsr 	CheckNextRParen
		lda 	#PCD_CMD_FNSAVE
		jsr 	WriteCodeByte
		lda 	procTarget
		sta 	branchTarget
		lda 	procTarget+1
		sta 	branchTarget+1
		lda 	#PCD_CMD_FNGOSUB
		jsr 	WriteBranchToAddress
		lda 	#PCD_CMD_FNRESTORE
		jsr 	WriteCodeByte
		;
		;		...and the value of the term is whatever RETURNS named.
		;
		ldy 	procRetHi
		ldx 	procRetLo
		lda 	procRetType
		clc
		jsr 	GetSetVariable
		lda 	procRetType
		and 	#NSSTypeMask
		sec
		rts

; ************************************************************************************************
;
;		The messages live up here in compiler space, not in errors.asm, for the reason
;		gpasmcode.asm gives: that file links below GPBase and is copied into every compiled
;		program, so an entry there would tax a program that never writes one of these keywords.
;		CallErrorHandler reads its text from its own return address, so it can be anywhere.
;
; ************************************************************************************************

ProcBadVerb:
		jsr 	CallErrorHandler
		.text 	"GP.DEFPROC VERB IS NOT A PLAIN NAME", 0

ProcDuplicate:
		jsr 	CallErrorHandler
		.text 	"GP.DEFPROC VERB ALREADY DECLARED", 0

ProcBadFormal:
		jsr 	CallErrorHandler
		.text 	"GP.DEFPROC FORMAL IS NOT A VARIABLE", 0

ProcTooManyFormals:
		jsr 	CallErrorHandler
		.text 	"TOO MANY GP.DEFPROC FORMALS", 0

ProcNotDeclared:
		jsr 	CallErrorHandler
		.text 	"GP.SUB BEFORE ITS GP.DEFPROC", 0

ProcArity:
		jsr 	CallErrorHandler
		.text 	"ARGUMENTS DO NOT MATCH THE GP.DEFPROC", 0

ProcBadReturn:
		jsr 	CallErrorHandler
		.text 	"GP.DEFPROC RETURNS IS NOT A VARIABLE", 0

ProcFnNotDeclared:
		jsr 	CallErrorHandler
		.text 	"GP.FN BEFORE ITS GP.DEFPROC", 0

ProcNoReturn:
		jsr 	CallErrorHandler
		.text 	"GP.FN NEEDS A VERB DECLARED RETURNS", 0

ProcTooDeep:
		jsr 	CallErrorHandler
		.text 	"GP.FN CALLS NESTED TOO DEEPLY", 0

; ************************************************************************************************
;
;		Compiler only working storage, in the CODE section rather than in storage, for the reason
;		goto.asm and select.asm both give: storage is the 1K hole below $0801 and compiler code is
;		thrown away when the object is written, so these bytes cost a compiled program nothing.
;
; ************************************************************************************************

; ------------------------------------------------------------------------------------------------
;
;		EVERYTHING A CALL IN PROGRESS KNOWS, IN ONE RUN OF BYTES, because an argument expression
;		can contain another call and would otherwise overwrite it. ProcCompileArguments saves and
;		restores the lot around every argument -- see there for why one set is not enough.
;
; ------------------------------------------------------------------------------------------------

procState:
procFormalLo: 								; each formal's address, as GetSetVariable takes it...
		.fill 	PROC_MAXFORMALS
procFormalHi:
		.fill 	PROC_MAXFORMALS
procFormalType: 							; ...and its type bits
		.fill 	PROC_MAXFORMALS
procCount: 									; how many formals the verb being read or called has
		.fill 	1
procIndex: 									; the argument being compiled
		.fill 	1
procTarget: 								; the code position being called
		.fill 	2
procRetLo: 									; the RETURNS variable, as GetSetVariable takes it
		.fill 	1
procRetHi:
		.fill 	1
procRetType:
		.fill 	1
procStateEnd:

PROC_STATE = procStateEnd - procState

procSaveStack: 								; PROC_MAXNEST copies of it, deepest call last
		.fill 	PROC_STATE * PROC_MAXNEST
procNest: 									; how many are on it
		.fill 	1

; ------------------------------------------------------------------------------------------------
;
;		...and the rest, which only the DECLARATION uses and nothing can re-enter.
;
; ------------------------------------------------------------------------------------------------

procType: 									; one formal, between GetReferenceTerm and the table
		.fill 	1
procAddr:
		.fill 	2
procScratch: 								; one byte for the room test, where A is the only
		.fill 	1 							; register free
procRetBytes: 								; 3 if the declaration named a RETURNS, 0 if not
		.fill 	1
procReturnFlag: 							; $80 if it did -- what goes into bit 7 of the count
		.fill 	1

		.send code

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
