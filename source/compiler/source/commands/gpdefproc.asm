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
;		ONE SET OF FORMALS IS ENOUGH BECAUSE GP.SUB IS A STATEMENT. Nothing an argument
;		expression can contain re-enters this file. GP.FN, which is an expression term, will not
;		have that: it can appear inside an argument to another GP.FN, and these buffers will have
;		to become a stack before it is built.
;
; ************************************************************************************************

		.section code

PROC_MAXFORMALS = 12 						; formals one verb may take. Three bytes of the code
											; section each, so the number is about what a shim
											; plausibly wants and not about room.
PROC_FLAG = $40 							; bit 6 of the second name character: this is a verb

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
_CDPRead:
		lda 	procCount
		asl 	a
		clc
		adc 	procCount 					; three bytes a formal
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
		;		One argument a formal, in order, each assigned to it. This is CommandLET without
		;		the left hand side: the same type test, and the same GetSetVariable to write it.
		;
		stz 	procIndex
_CSCArgument:
		lda 	procIndex
		cmp 	procCount
		beq 	_CSCCall
		jsr 	LookNextNonSpace
		cmp 	#","
		beq 	_CSCComma
		jmp 	ProcArity 					; fewer arguments than the declaration has formals
_CSCComma:
		jsr 	GetNextNonSpace 			; consume the comma
		jsr 	CompileExpressionAt0
		ldx 	procIndex
		eor 	procFormalType,x 			; only string against number matters, exactly as an
		and 	#NSSTypeMask 				; assignment has it
		bne 	_CSCType
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
		inc 	procIndex
		bra 	_CSCArgument
		;
		;		And the call itself.
		;
_CSCCall:
		jsr 	LookNextNonSpace
		cmp 	#","
		bne 	_CSCEmit
		jmp 	ProcArity 					; more arguments than the declaration has formals
_CSCEmit:
		lda 	procTarget
		sta 	branchTarget
		lda 	procTarget+1
		sta 	branchTarget+1
		lda 	#PCD_CMD_FNGOSUB
		jsr 	WriteBranchToAddress
		rts

_CSCType:
		.error_type

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
		.text 	"GP.SUB DOES NOT MATCH ITS GP.DEFPROC", 0

; ************************************************************************************************
;
;		Compiler only working storage, in the CODE section rather than in storage, for the reason
;		goto.asm and select.asm both give: storage is the 1K hole below $0801 and compiler code is
;		thrown away when the object is written, so these bytes cost a compiled program nothing.
;
; ************************************************************************************************

procFormalLo: 								; each formal's address, as GetSetVariable takes it...
		.fill 	PROC_MAXFORMALS
procFormalHi:
		.fill 	PROC_MAXFORMALS
procFormalType: 							; ...and its type bits
		.fill 	PROC_MAXFORMALS
procCount: 									; how many formals the verb being read or called has
		.fill 	1
procIndex: 									; the argument GP.SUB is compiling
		.fill 	1
procTarget: 								; the code position GP.SUB is calling
		.fill 	2
procType: 									; one formal, between GetReferenceTerm and the table
		.fill 	1
procAddr:
		.fill 	2
procScratch: 								; one byte for the room test, where A is the only
		.fill 	1 							; register free

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
