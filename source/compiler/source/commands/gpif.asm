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
		lda 	#PCD_GPCMD_IF 				; the marker FixBranches counts nesting on
		jsr 	WriteCodeByte
		lda 	#PCD_CMD_IFNEXT 			; false -> the next alternative, or the gp.endif
		jsr 	WriteCodeByte
		jmp 	IfWritePlaceholder

;
;		GP.ELSEIF is a closer and an opener in one: the .ifelse leaves the body above, then the
;		test opens the next. It writes NO gp.if -- an ELSEIF does not deepen the nesting, it
;		continues the chain the GP.IF started, and the scans depend on that.
;
CommandElseIfCompile:
		stz 	deferErrors
		lda 	#PCD_CMD_IFELSE 			; out of the body above, to the gp.endif
		jsr 	WriteCodeByte
		jsr 	IfWritePlaceholder
		jsr 	CompileExpressionAt0
		and 	#NSSTypeMask
		cmp 	#NSSIFloat
		bne 	IfFailType
		jsr 	IfRequireThenEOL
		lda 	#PCD_CMD_IFNEXT
		jsr 	WriteCodeByte
		jmp 	IfWritePlaceholder

CommandElseCompile:
		stz 	deferErrors
		lda 	#PCD_CMD_IFELSE
		jsr 	WriteCodeByte
		jsr 	IfWritePlaceholder
		jmp 	IfRequireEOL

;
;		GP.ENDIF is a marker and nothing else. Every .ifnext that ran out of alternatives lands
;		ON it and every .ifelse lands ON it, which costs nothing because it does nothing.
;
CommandEndIfCompile:
		stz 	deferErrors
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
;		Two placeholder bytes. The value is never read: FixBranches overwrites both
;		unconditionally, and errors out rather than leaving them if it cannot resolve the branch.
;
IfWritePlaceholder:
		lda 	#0
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte
		clc
		rts

IfFailType:
		.error_type

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
