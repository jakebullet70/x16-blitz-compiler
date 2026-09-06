; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpif.asm
;		Purpose:	GP.IF / GP.ELSEIF / GP.ELSE / GP.ENDIF
;		Created:	30th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		GP.IF <expr> THEN
;		GP.ELSEIF <expr> THEN
;		GP.ELSE
;		GP.ENDIF
;
;		A block IF. Each keyword is ALONE ON ITS LINE -- there is no single line form, and the
;		THEN is required, so "GP.IF X > 5 THEN PRINT" is rejected rather than quietly opening a
;		block that swallows every line until the next GP.ENDIF.
;
;		Lowering, for GP.IF a / GP.ELSEIF b / GP.ELSE / GP.ENDIF:
;
;			<a> gp.if .ifnext -> one past the .ifelse below
;			<body>
;			.ifelse -> gp.endif       <b> .ifnext -> one past the next .ifelse
;			<body>
;			.ifelse -> gp.endif
;			<body>
;			gp.endif                  a marker, nothing more; there is no frame to close
;
;		NO STACK FRAME, unlike GP.SELECT. The frame there is forced by new.line resetting the
;		number stack at every source line, because the selector has to survive to the next line.
;		A condition is evaluated and consumed by its .ifnext on the SAME line, so there is
;		nothing to preserve -- which is why the whole construct costs 12 runtime bytes and none
;		of them are code. .ifnext runs the .goto.z handler and .ifelse runs the .goto handler;
;		only FixBranches tells them from .casenext and .caseend.
;
;		GP.ELSEIF IS WHAT FORCES gp.if TO EXIST. Without it FixBranches could count nesting on
;		.ifnext against gp.endif, one to one, and the marker would not be needed. But GP.ELSEIF
;		emits .ifelse and then its OWN <cond> .ifnext, which would inflate the depth of a scan
;		already in flight and send it past its own gp.endif. So depth is counted on a marker
;		GP.ELSEIF does not emit -- and note below that it deliberately writes no gp.if.
;
;		THAT IS PASS ONE'S PROBLEM ONLY NOW. Pass two keeps a stack of the open GP.IFs instead of
;		scanning for one, so an inner IF is invisible to an outer one's branches because it is a
;		different entry, not because a count came out right. The marker stays: pass one still
;		resolves the old way, and the checksum compares the two answers.
;
;		ALL FOUR DISARM deferErrors FIRST. A statement that fails with a SYNTAX error while the
;		deferral is armed is rolled back and replaced with a runtime throw-stub -- which for a
;		block opener means its gp.if vanishes while the GP.ENDIF on a later line still compiles
;		and still emits. The block is left with a closer and no opener, and an ENCLOSING IF's
;		scan then counts one extra close and resolves its branches to the wrong place, silently.
;		Three bytes of stz buys a hard, correctly-named error instead.
;
;		All four MUST return carry CLEAR. A .def helper returning carry set makes the generator
;		silently drop every table element after it, with no error and no clue.
;
; ************************************************************************************************

CommandIfCompile:
		stz 	deferErrors 				; a block opener must never defer -- see the header
		jsr 	CompileExpressionAt0 		; the condition
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	IfFailType
		jsr 	IfRequireThenEOL
		jsr 	IfOpen 						; this IF's ordinal, and nothing pending inside it yet
		lda 	#PCD_GPCMD_IF 				; the marker FixBranches counts nesting on
		jsr 	WriteCodeByte
		jmp 	IfWriteNext 				; false -> the next alternative, or the gp.endif

;
;		GP.ELSEIF is a closer and an opener in one: the .ifelse leaves the body above, then the
;		test opens the next. It writes NO gp.if -- an ELSEIF does not deepen the nesting, it
;		continues the chain the GP.IF started, and the scans depend on that.
;
CommandElseIfCompile:
		stz 	deferErrors
		jsr 	IfWriteElse 				; out of the body above, to the gp.endif
		jsr 	IfAltHere 					; and the test above lands HERE, one past it
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	IfFailType
		jsr 	IfRequireThenEOL
		jmp 	IfWriteNext

CommandElseCompile:
		stz 	deferErrors
		jsr 	IfWriteElse
		jsr 	IfAltHere
		jmp 	IfRequireEOL

;
;		GP.ENDIF is a marker and nothing else. Every .ifnext that ran out of alternatives lands
;		ON it and every .ifelse lands ON it, which costs nothing because it does nothing.
;
CommandEndIfCompile:
		stz 	deferErrors
		jsr 	IfAltHere 					; the last test lands ON the gp.endif...
		jsr 	IfClose 					; ...and so does every body that finished
		lda 	#PCD_GPCMD_ENDIF
		jsr 	WriteCodeByte
		jmp 	IfRequireEOL

;
;		THEN is a ROM keyword ($a7), so BASLOAD tokenises it with no GP keyword slot spent and it
;		emits no p-code of its own. Requiring it costs the five bytes CommandIF already spends.
;
IfRequireThenEOL:
		lda 	#C64_THEN
		jsr 	CheckNextA
;
;		Nothing may follow. This is the check that makes the single line form illegal rather than
;		merely undefined, and with deferErrors already disarmed it aborts the compile instead of
;		becoming a throw-stub.
;
IfRequireEOL:
		jsr 	LookNextNonSpace
		beq 	_IREDone
		.error_syntax
_IREDone:
		rts

;
;		Two placeholder bytes, in pass one. The value is never read: FixBranches overwrites both
;		unconditionally, and errors out rather than leaving them if it cannot resolve the branch.
;		Pass two writes the offset instead and never comes through here.
;
IfWritePlaceholder:
		lda 	#0
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte
		clc
		rts

;
;		The three ways an IF can be refused, and the one line of arithmetic every hook below
;		starts with. HERE, above the hooks rather than under them: the tests that reach these
;		are on both sides of a hundred and fifty bytes of table plumbing, and a relative branch
;		does not span it.
;
;		X = (ifDepth-1) * 2, the innermost open GP.IF.
;
IfIndex:
		lda 	ifDepth
		beq 	IfFailStructure 			; a GP.ELSEIF, GP.ELSE or GP.ENDIF with no GP.IF
		dec 	a
		asl 	a
		tax
		rts

IfFailType:
		.error_type
IfFailNest:
		.error_memory
IfFailStructure:
		.error_structure

; ************************************************************************************************
;
;		The four hooks that make this resolvable in one forward pass. Pass one writes placeholders
;		and notes where each branch should land as it goes past the landing place; pass two writes
;		the offsets out of those notes. See commands/goto.asm for the tables.
;
;		THE OPEN GP.IFs ARE A STACK, because an inner IF's alternatives must be invisible to the
;		outer one's -- the same thing FixBranches gets by counting gp.if against gp.endif as it
;		scans. GP.ELSEIF pushes nothing: it continues the chain its GP.IF started.
;
; ************************************************************************************************

IfOpen:
		lda 	ifDepth
		cmp 	#BLOCK_MAX_NEST
		bcs 	IfFailNest
		asl 	a
		tax
		jsr 	BlockOpen 					; a new block ordinal, in blockIndex
		lda 	blockIndex
		sta 	ifOrdinals,x
		lda 	blockIndex+1
		sta 	ifOrdinals+1,x
		lda 	#$FF 						; nothing inside it is waiting for a target yet
		sta 	ifPending,x
		sta 	ifPending+1,x
		inc 	ifDepth
		rts

;
;		.ifnext -- the test came out false. It takes an alternative of its own and becomes this
;		IF's pending one; whatever alternative follows says where it lands.
;
IfWriteNext:
		jsr 	IfIndex
		jsr 	BlockAltOpen
		lda 	blockAlt
		sta 	ifPending,x
		lda 	blockAlt+1
		sta 	ifPending+1,x
		;
		lda 	passNumber
		beq 	_IWNPlaceholder
		jsr 	BlockAltRead 				; where the next alternative starts
		lda 	#PCD_CMD_IFNEXT
		jsr 	WriteBranchToAddress
		clc
		rts
_IWNPlaceholder:
		lda 	#PCD_CMD_IFNEXT
		jsr 	WriteCodeByte
		jmp 	IfWritePlaceholder

;
;		.ifelse -- a body finished, so out to the gp.endif. Every one of them in an IF goes to
;		the same place, which is why they read the block's end rather than an alternative.
;
IfWriteElse:
		lda 	passNumber
		beq 	_IWEPlaceholder
		jsr 	IfIndex
		lda 	ifOrdinals,x
		sta 	blockIndex
		lda 	ifOrdinals+1,x
		sta 	blockIndex+1
		jsr 	BlockEndTarget
		lda 	#PCD_CMD_IFELSE
		jsr 	WriteBranchToAddress
		clc
		rts
_IWEPlaceholder:
		lda 	#PCD_CMD_IFELSE
		jsr 	WriteCodeByte
		jmp 	IfWritePlaceholder

;
;		The pending .ifnext, if there is one, lands where the cursor stands. After a GP.ELSE
;		there is none -- it opens the last body and writes no test.
;
IfAltHere:
		jsr 	IfIndex
		lda 	ifPending,x
		sta 	blockAlt
		lda 	ifPending+1,x
		sta 	blockAlt+1
		jsr 	BlockAltHere
		jsr 	IfIndex 					; X again: the write above goes through a bank window
		lda 	#$FF 						; resolved, so no longer pending
		sta 	ifPending,x
		sta 	ifPending+1,x
		rts

;
;		GP.ENDIF. Where the block ends is where the cursor stands, and the stack gives the level
;		back.
;
IfClose:
		jsr 	IfIndex
		lda 	ifOrdinals,x
		sta 	blockIndex
		lda 	ifOrdinals+1,x
		sta 	blockIndex+1
		jsr 	BlockEndHere
		dec 	ifDepth
		rts


		.send code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		30/08/26		Written.
;
; ************************************************************************************************
