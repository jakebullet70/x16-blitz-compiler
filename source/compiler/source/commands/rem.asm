; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		rem.asm
;		Purpose:	Handle remark (ignore to EOL)
;		Created:	20th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								REM consumes the rest of the line.
;
; ************************************************************************************************

CommandREM: 
		jsr 	DCKeepMarker 				; pass zero: a dead-code keep marker (main/deadcode.asm)
		jsr 	GPCDirectiveCheck 			; every pass: a #GPC word the compiler does not know
_CRNext:
		jsr 	LookNext
		beq 	_CRExit
		jsr 	GetNext
		bra 	_CRNext
_CRExit:		
		rts

; ************************************************************************************************
;
;		A REM statement starts, srcPtr just past the token. A #GPC line must name a word in
;		GPCDirectiveWords, a program-wide word must come before the first statement that is not a
;		REM, and a name argument must be a quoted name. DEBUG_ON and DEBUG_OFF open and close a
;		debug region and must pair. Keeps X, Y and srcPtr.
;
;		The program-wide words take effect in the prescan (application, compiler/directives.asm).
;		Here they are only checked.
;
; ************************************************************************************************

GPCDirectiveCheck:
		phx
		phy
		jsr 	GPCDirectiveWord
		cmp 	#0
		beq 	_GDCDone
		cmp 	#GPC_UNKNOWN
		beq 	_GDCUnknown
		cmp 	#GPC_DEBUG_ON
		beq 	_GDCDebugOn
		cmp 	#GPC_DEBUG_OFF
		beq 	_GDCDebugOff
		cmp 	#GPC_REGION 				; a keep word is paired by DCKeepMarker
		bcs 	_GDCDone
		ldx 	gpcCodeSeen
		bne 	_GDCLate
		cmp 	#GPC_OBJECT 				; the words before OBJECT take no argument
		bcc 	_GDCDone
		jsr 	GPCDirectiveName
		bcs 	_GDCBadName
_GDCDone:
		ply
		plx
		rts
_GDCDebugOn:
		lda 	gpcDebugOpen 				; a DEBUG_ON inside a region
		bne 	_GDCUnpaired
		inc 	gpcDebugOpen
		bra 	_GDCDone
_GDCDebugOff:
		lda 	gpcDebugOpen 				; a DEBUG_OFF outside one
		beq 	_GDCUnpaired
		stz 	gpcDebugOpen
		bra 	_GDCDone
_GDCUnpaired:
		.error_structure
_GDCUnknown:
		jsr 	CallErrorHandler
		.text 	"UNKNOWN DIRECTIVE",0
_GDCLate:
		jsr 	CallErrorHandler
		.text 	"DIRECTIVE TOO LATE",0
_GDCBadName: 								; a SYNTAX error defers to run time unless disarmed
		stz 	deferErrors
		.error_syntax

; ************************************************************************************************
;
;		Which #GPC word the REM text at srcPtr holds. Keeps X.
;
;		Out:	A = 0 when the text is not a #GPC line, GPC_UNKNOWN when the word is not in the
;				table, else the word's kind. Y = the offset just past the word.
;
;		Spaces may come before #GPC, and one or more come between #GPC and the word. Letters
;		match in any case. The word must end the line or be followed by a space or a colon.
;		#GPC followed by any other character is a plain comment.
;
; ************************************************************************************************

GPC_SHARED = 1 								; the program-wide words, in GPC.INPUT order
GPC_EMBEDDED = 2
GPC_NOSTRIP = 3
GPC_OBJECT = 4 								; OBJECT, MAP and DEADLIST take a quoted name and
GPC_MAP = 5 								; must stay consecutive and in this order: the prescan
GPC_DEADLIST = 6 							; indexes a table by kind - GPC_OBJECT
GPC_REGION = $40 							; this kind and above go anywhere
GPC_KEEP = $40
GPC_ENDKEEP = $41
GPC_DEBUG_ON = $42
GPC_DEBUG_OFF = $43
GPC_UNKNOWN = $FF

GPC_NAME_MAX = 63 							; one GPC.INPUT line less its terminator

GPCDirectiveWord:
		phx
		ldy 	#0
_GDWSpace:
		lda 	(srcPtr),y
		cmp 	#' '
		bne 	_GDWTag
		iny
		bra 	_GDWSpace
_GDWTag:
		ldx 	#0
_GDWTagCompare:
		lda 	GPCTagText,x
		beq 	_GDWTagEnd
		lda 	(srcPtr),y
		jsr 	DCUpperCase
		cmp 	GPCTagText,x
		bne 	_GDWNone
		iny
		inx
		bra 	_GDWTagCompare
_GDWTagEnd:
		lda 	(srcPtr),y
		beq 	_GDWUnknown
		cmp 	#':'
		beq 	_GDWUnknown
		cmp 	#' '
		bne 	_GDWNone
_GDWGap:
		iny
		lda 	(srcPtr),y
		cmp 	#' '
		beq 	_GDWGap
		sty 	gpcWordAt
		ldx 	#0
_GDWTry:
		lda 	GPCDirectiveWords,x 		; the word's kind, or 0 after the last
		beq 	_GDWUnknown
		sta 	gpcWordKind
		inx
		ldy 	gpcWordAt
_GDWCompare:
		lda 	GPCDirectiveWords,x
		beq 	_GDWWordEnd
		lda 	(srcPtr),y
		jsr 	DCUpperCase
		cmp 	GPCDirectiveWords,x
		bne 	_GDWSkip
		iny
		inx
		bra 	_GDWCompare
_GDWWordEnd:
		lda 	(srcPtr),y
		beq 	_GDWFound
		cmp 	#' '
		beq 	_GDWFound
		cmp 	#':'
		beq 	_GDWFound
_GDWSkip: 									; on past the spelling's terminator
		lda 	GPCDirectiveWords,x
		beq 	_GDWSkipped
		inx
		bra 	_GDWSkip
_GDWSkipped:
		inx
		bra 	_GDWTry
_GDWFound:
		lda 	gpcWordKind
		plx
		rts
_GDWNone:
		lda 	#0
		plx
		rts
_GDWUnknown:
		lda 	#GPC_UNKNOWN
		plx
		rts

; ************************************************************************************************
;
;		The quoted name after a word, Y = the offset just past the word.
;
;		Out:	CC, Y = the offset of the name's first character, A = its length.
;				CS when there is no opening quote, no closing quote, an empty name or one longer
;				than GPC_NAME_MAX.
;
; ************************************************************************************************

GPCDirectiveName:
		lda 	(srcPtr),y
		cmp 	#' '
		bne 	_GDNQuote
		iny
		bra 	GPCDirectiveName
_GDNQuote:
		cmp 	#'"'
		bne 	_GDNBad
		iny
		sty 	gpcWordAt
_GDNScan:
		lda 	(srcPtr),y
		beq 	_GDNBad
		cmp 	#'"'
		beq 	_GDNClosed
		iny
		bra 	_GDNScan
_GDNClosed:
		tya
		sec
		sbc 	gpcWordAt
		beq 	_GDNBad
		cmp 	#GPC_NAME_MAX+1
		bcs 	_GDNBad
		ldy 	gpcWordAt
		clc
		rts
_GDNBad:
		sec
		rts

GPCTagText:
		.text 	"#GPC",0

GPCDirectiveWords:
		.byte 	GPC_SHARED
		.text 	"SHARED",0
		.byte 	GPC_EMBEDDED
		.text 	"EMBEDDED",0
		.byte 	GPC_NOSTRIP
		.text 	"NOSTRIP",0
		.byte 	GPC_OBJECT
		.text 	"OBJECT",0
		.byte 	GPC_MAP
		.text 	"MAP",0
		.byte 	GPC_DEADLIST
		.text 	"DEADLIST",0
		.byte 	GPC_KEEP
		.text 	"KEEP",0
		.byte 	GPC_ENDKEEP
		.text 	"ENDKEEP",0
		.byte 	GPC_DEBUG_ON
		.text 	"DEBUG_ON",0
		.byte 	GPC_DEBUG_OFF
		.text 	"DEBUG_OFF",0
		.byte 	0

gpcCodeSeen: 								; nonzero once a statement other than REM is compiled
		.fill 	1
gpcDebugOpen: 								; nonzero inside a debug region
		.fill 	1
gpcDebugLine: 								; nonzero when the line being compiled started inside one
		.fill 	1
gpcWordAt: 									; where the word or the name being matched starts
		.fill 	1
gpcWordKind: 								; the kind of the spelling being matched
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
;		13/09/26		Reads a dead-code keep marker in pass zero.
;
; ************************************************************************************************
