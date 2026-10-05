; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		directives.asm
;		Purpose:	Read the program-wide #GPC directives before the compile starts
;		Created:	5th October 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		BASLOAD-GPC emits `#GPC <text>` as a BASIC line holding the REM token, "#GPC" and the
;		text as written. The program-wide words sit at the head of the program, before the
;		first statement that is not a REM. They replace GPC.INPUT lines:
;
;			SHARED, EMBEDDED		line 4, the mode
;			OBJECT "NAME"			line 2
;			MAP "NAME"				line 3
;			DEADLIST "NAME"			line 5
;			NOSTRIP					line 5 reading NOSTRIP: dead code is kept
;
;		Dead code is removed unless NOSTRIP is set, from either place. Line 5 empty removes it
;		and writes no list.
;
;		The compiler checks every #GPC line again as it compiles (commands/rem.asm). An unknown
;		word, a word too late and a bad name stop the compile there, so the prescan skips them.
;
; ************************************************************************************************

PDLineSize = 128 							; the most of a line kept; a longer one is cut

		.section code

; ************************************************************************************************
;
;		Read the head of SourceFile and write each program-wide directive over its GPC.INPUT
;		line. Run after ReadControlFile and before anything reads those lines.
;
;		A source that is missing or is not a program is left alone, for ValidateSourceFile to
;		report. Uses srcPtr, which the compile has not started using.
;
; ************************************************************************************************

PrescanDirectives:
		stz 	pdNoStrip
		ldy 	#SourceFile >> 8
		ldx 	#SourceFile & $FF
		jsr 	IOOpenRead
		jsr 	IOReadByte 					; the load address, $0801
		bcs 	_PDClose
		cmp 	#$01
		bne 	_PDClose
		jsr 	IOReadByte
		bcs 	_PDClose
		cmp 	#$08
		bne 	_PDClose

_PDLine:
		jsr 	IOReadByte 					; the link, zero at the end of the program
		bcs 	_PDClose
		tax
		jsr 	IOReadByte
		bcs 	_PDClose
		stx 	pdLink
		ora 	pdLink
		beq 	_PDClose
		jsr 	IOReadByte 					; the line number
		jsr 	IOReadByte
		ldx 	#0
_PDRead:
		jsr 	IOReadByte
		bcs 	_PDClose
		cmp 	#0
		beq 	_PDLineRead
		cpx 	#PDLineSize-1
		bcs 	_PDRead
		sta 	pdLineBuffer,x
		inx
		bra 	_PDRead
_PDLineRead:
		stz 	pdLineBuffer,x

		ldx 	#0
_PDLead: 									; past the spaces and colons in front of the statement
		lda 	pdLineBuffer,x
		beq 	_PDLine
		cmp 	#' '
		beq 	_PDLeadNext
		cmp 	#':'
		bne 	_PDFirst
_PDLeadNext:
		inx
		bra 	_PDLead
_PDFirst:
		cmp 	#C64_REM 					; the first statement that is not a REM ends the head
		bne 	_PDClose
		inx
		txa
		clc
		adc 	#pdLineBuffer & $FF
		sta 	srcPtr
		lda 	#pdLineBuffer >> 8
		adc 	#0
		sta 	srcPtr+1
		jsr 	GPCDirectiveWord
		jsr 	PDApply
		bra 	_PDLine

_PDClose:
		jsr 	IOReadClose
		ldx 	#0 							; line 5 reading NOSTRIP turns removal off too. A
_PDCompare: 								; DEADLIST in the source has already replaced it
		lda 	DeadListFile,x
		cmp 	PDNoStripText,x
		bne 	_PDCompared
		inx
		cmp 	#0
		bne 	_PDCompare
		inc 	pdNoStrip
_PDCompared:
		lda 	pdNoStrip
		beq 	_PDExit
		stz 	DeadListFile 				; no list, so nothing writes or scratches a file
_PDExit:
		rts

PDNoStripText:
		.text 	"NOSTRIP",0

; ************************************************************************************************
;
;		Apply the directive GPCDirectiveWord found: A = its kind, Y = the offset in the text at
;		srcPtr just past the word.
;
; ************************************************************************************************

PDApply:
		cmp 	#GPC_SHARED
		bne 	_PDANotShared
		lda 	#'S' 						; ModeText is read by its first byte
		sta 	ModeText
		stz 	ModeText+1
		rts
_PDANotShared:
		cmp 	#GPC_EMBEDDED
		bne 	_PDANotEmbedded
		stz 	ModeText
		rts
_PDANotEmbedded:
		cmp 	#GPC_NOSTRIP
		bne 	_PDANotNoStrip
		inc 	pdNoStrip
		rts
_PDANotNoStrip:
		cmp 	#GPC_OBJECT
		bcc 	_PDADone
		cmp 	#GPC_DEADLIST+1
		bcs 	_PDADone
		sbc 	#GPC_OBJECT-1 				; carry is clear, so this takes GPC_OBJECT
		asl 	a
		tax
		lda 	PDNameLines,x
		sta 	zTemp0
		lda 	PDNameLines+1,x
		sta 	zTemp0+1
		jsr 	GPCDirectiveName
		bcs 	_PDADone
		sta 	pdLength
		ldx 	#0
_PDACopy: 									; the name, case folded as ReadControlFile folds it
		lda 	(srcPtr),y
		jsr 	DCUpperCase
		phy
		phx
		ply
		sta 	(zTemp0),y
		ply
		iny
		inx
		cpx 	pdLength
		bne 	_PDACopy
		txa
		tay
		lda 	#0
		sta 	(zTemp0),y
_PDADone:
		rts

PDNameLines: 								; by kind - GPC_OBJECT
		.word 	ObjectFile
		.word 	OptionsText
		.word 	DeadListFile

pdLink: 									; the low byte of a line's link
		.fill 	1
pdNoStrip: 									; nonzero when NOSTRIP is set, from the source or line 5
		.fill 	1
pdLength: 									; the length of a name being copied
		.fill 	1
pdLineBuffer: 								; the line being read, zero terminated
		.fill 	PDLineSize

		.send code
