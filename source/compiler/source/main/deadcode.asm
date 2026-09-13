; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		deadcode.asm
;		Purpose:	Dead-code removal: what pass zero records, the solve at its end, and the skip after it
;		Created:	13th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		Pass zero compiles every line exactly as pass one does and writes down, alongside, what
;		decides whether a line can be reached. The end of pass zero works out which lines nothing
;		reaches. See docs/blitz/DEAD-CODE-ELIMINATION.PLAN.md, sections 2 and 3.
;
;		EVERYTHING IS INDEXED BY LINE-TABLE ENTRY. Entry n is the n'th line MainCompileLoop read,
;		and STRMarkLine made the n'th record for it, so a line number or an address searched for
;		in the table comes back as an entry with no further arithmetic. The lines a GP.ASM or
;		GP.BANKEDSTR block reads for itself have no entry: they belong to the entry that read
;		them, and the swallow list says how many there were, so that a later pass which leaves
;		the opener out can read past them too.
;
;		Bank 11 holds four bit planes, one bit an entry, 512 bytes each. That is 4,096 entries,
;		the line table's own limit, so a plane is never what fills.
;
;			$A000	reached 	some path from the first line runs it
;			$A200	retained 	compiled although nothing runs it (DATA, DIM, GP.DEFPROC,
;								GP.BANKED, GP.ENDBANKED, GP.BANKEDSTR)
;			$A400	falls 		when reached, it reaches the next line
;			$A600	structure 	inside or on the edge of a GP.IF, GP.DO or GP.SELECT
;			$A800	swallow list: the entry (2), the lines it read past its own (2)
;
;		Bank 12 holds the edge list: the source entry (2, bit 15 set when the target is an
;		address) and the target (2). The target is a line number or an address until the solve
;		rewrites it as an entry, or as $FFFF when it lands on no source line.
;		Once the solve is done the edges are finished with, and pass one reuses the bank for
;		the numbers of the lines it leaves out, two bytes each. The application writes them to
;		the list file (application/source/compiler/deadlist.asm).
;
;		PASSES ONE AND TWO LEAVE OUT THE SAME LINES. Each counts the lines MainCompileLoop
;		reads, so the count is pass zero's entry for the line, and a line neither reached nor
;		retained is read past before it is marked: no line-table entry, no marker, no code, no
;		variables. The lines it swallowed in pass zero are read past with it.
;
;		A full list turns removal off for this compile. It never stops the compile.
;
;		A KEEP REGION makes every line between its two marker lines a root, reached from the
;		start like the first line. The marker lines are judged like any other line. CommandREM
;		calls DCKeepMarker, which reads the markers in pass zero only.
;
; ************************************************************************************************

DCPlaneReached 		= $A0
DCPlaneRetained 	= $A2
DCPlaneFalls 		= $A4
DCPlaneStructure 	= $A6

DCSwallowTable 		= $A800
DCSwallowMax 		= ($C000 - DCSwallowTable) / 4
DCEdgeTable 		= $A000
DCEdgeMax 			= ($C000 - DCEdgeTable) / 4
DCListTable 		= $A000
DCListMax 			= ($C000 - DCListTable) / 2

GP_TOKEN_DEFPROC 	= 52817 & $FF
GP_TOKEN_BANKED 	= 52823 & $FF
GP_TOKEN_ENDBANKED 	= 52822 & $FF
GP_TOKEN_BANKEDSTR 	= 52819 & $FF

DCKeepOpens 		= 1 							; the two kinds of keep marker
DCKeepCloses 		= 2

; ************************************************************************************************
;
;		Read the next source line, counting it. Every reader goes through here -- the main loop,
;		GP.ASM and GP.BANKEDSTR -- so the count is every line, whoever read it. CS = a line, in YX.
;
; ************************************************************************************************

ReadSourceLine:
		lda 	#BLC_READIN
		jsr 	CallAPIHandler
		bcc 	_RSLDone
		inc 	dcReads
		bne 	_RSLDone
		inc 	dcReads+1
_RSLDone:
		rts

; ************************************************************************************************
;
;		Start of a pass. Pass zero also empties the planes and the two lists.
;
; ************************************************************************************************

DCResetPass:
		stz 	dcEntry
		stz 	dcEntry+1
		stz 	dcReads
		stz 	dcReads+1
		stz 	dcLineOpen
		stz 	dcSwallowWalk
		stz 	dcSwallowWalk+1
		lda 	dcPass
		beq 	_DRPDone
		stz 	dcSkip
		stz 	dcListCount
		stz 	dcListCount+1
		stz 	dcEdgeCount
		stz 	dcEdgeCount+1
		stz 	dcSwallowCount
		stz 	dcSwallowCount+1
		stz 	dcFull
		stz 	dcKeepOpen

		stz 	zTemp0
		lda 	#DCPlaneReached
		sta 	zTemp0+1
		.dcplane_access
_DRPPage:
		lda 	#0
		tay
_DRPByte:
		sta 	(zTemp0),y
		iny
		bne 	_DRPByte
		inc 	zTemp0+1
		lda 	zTemp0+1
		cmp 	#DCSwallowTable >> 8
		bne 	_DRPPage
		.dcplane_release
_DRPDone:
		rts

; ************************************************************************************************
;
;		Between two lines, at the top of MainCompileLoop: close the line just compiled, then note
;		what the next one starts from. Pass zero only.
;
; ************************************************************************************************

DCLineBoundary:
		lda 	dcPass
		beq 	_DLBDone
		lda 	dcLineOpen
		beq 	_DLBOpen
		jsr 	DCCloseLine
		inc 	dcEntry
		bne 	_DLBOpen
		inc 	dcEntry+1
_DLBOpen:
		lda 	#1
		sta 	dcLineOpen
		lda 	blockDepth
		ora 	ifDepth
		ora 	SelectDepth
		sta 	dcStartDepth
		lda 	blockCount
		sta 	dcStartBlocks
		lda 	altCount
		sta 	dcStartAlts
		lda 	dcKeepOpen 					; ...and whether a keep region was open there
		sta 	dcKeepAtStart
		lda 	dcReads
		sta 	dcReadsAtLine
		lda 	dcReads+1
		sta 	dcReadsAtLine+1
		stz 	dcLastToken
		stz 	dcGotoZ
		stz 	dcRetain
_DLBDone:
		rts

;
;		The line in dcEntry is finished.
;
DCCloseLine:
		sec 								; lines read since it started, less itself
		lda 	dcReads
		sbc 	dcReadsAtLine
		sta 	dcExtra
		lda 	dcReads+1
		sbc 	dcReadsAtLine+1
		sta 	dcExtra+1
		lda 	dcExtra
		bne 	_DCLNoBorrow
		dec 	dcExtra+1
_DCLNoBorrow:
		dec 	dcExtra

		lda 	dcEntry
		sta 	dcIndex
		lda 	dcEntry+1
		sta 	dcIndex+1
		;
		;		In a structure: a block open where it starts or where it ends, or one opened or
		;		given an alternative on the way through.
		;
		stz 	dcInStructure
		lda 	dcStartDepth
		ora 	blockDepth
		ora 	ifDepth
		ora 	SelectDepth
		bne 	_DCLStructure
		lda 	blockCount
		cmp 	dcStartBlocks
		bne 	_DCLStructure
		lda 	altCount
		cmp 	dcStartAlts
		beq 	_DCLJudged
_DCLStructure:
		inc 	dcInStructure
		lda 	#DCPlaneStructure
		jsr 	DCSetBit
_DCLJudged:
		lda 	dcRetain
		beq 	_DCLKeep
		lda 	#DCPlaneRetained
		jsr 	DCSetBit
		;
		;		Inside a keep region: one was open where the line started and is still open where it
		;		ends. That leaves out both marker lines.
		;
_DCLKeep:
		lda 	dcKeepAtStart
		and 	dcKeepOpen
		beq 	_DCLFalls
		lda 	#DCPlaneReached
		jsr 	DCSetBit
		;
		;		It falls through unless its last statement starts with GOTO, RETURN, END or STOP.
		;		An IF ... THEN statement always does, and so does every line of a structure.
		;
_DCLFalls:
		lda 	dcInStructure
		ora 	dcGotoZ
		bne 	_DCLSetFalls
		lda 	dcLastToken
		cmp 	#C64_GOTO
		beq 	_DCLSwallow
		cmp 	#C64_RETURN
		beq 	_DCLSwallow
		cmp 	#C64_END
		beq 	_DCLSwallow
		cmp 	#C64_STOP
		beq 	_DCLSwallow
_DCLSetFalls:
		lda 	#DCPlaneFalls
		jsr 	DCSetBit

_DCLSwallow:
		lda 	dcExtra
		ora 	dcExtra+1
		beq 	_DCLDone
		lda 	dcSwallowCount+1
		cmp 	#DCSwallowMax >> 8
		bcc 	_DCLRoom
		lda 	#1
		sta 	dcFull
_DCLDone:
		rts
_DCLRoom:
		lda 	dcSwallowCount
		ldy 	dcSwallowCount+1
		jsr 	DCPointYA
		lda 	zTemp0+1
		clc
		adc 	#DCSwallowTable >> 8
		sta 	zTemp0+1
		.dcplane_access
		lda 	dcEntry
		sta 	(zTemp0)
		ldy 	#1
		lda 	dcEntry+1
		sta 	(zTemp0),y
		iny
		lda 	dcExtra
		sta 	(zTemp0),y
		iny
		lda 	dcExtra+1
		sta 	(zTemp0),y
		.dcplane_release
		inc 	dcSwallowCount
		bne 	_DCLCounted
		inc 	dcSwallowCount+1
_DCLCounted:
		rts

; ************************************************************************************************
;
;		A statement starts, first character in A, srcPtr just past it. Keeps A, X and Y.
;
; ************************************************************************************************

DCStatement:
		pha
		phy
		ldy 	dcPass
		beq 	_DSDone
		sta 	dcLastToken
		cmp 	#C64_DATA
		beq 	_DSRetain
		cmp 	#C64_DIM
		beq 	_DSRetain
		cmp 	#$CE 						; a GP keyword, whose second byte is still unread
		bne 	_DSDone
		lda 	(srcPtr)
		cmp 	#GP_TOKEN_DEFPROC
		beq 	_DSRetain
		cmp 	#GP_TOKEN_BANKED
		beq 	_DSRetain
		cmp 	#GP_TOKEN_ENDBANKED
		beq 	_DSRetain
		cmp 	#GP_TOKEN_BANKEDSTR
		bne 	_DSDone
_DSRetain:
		lda 	#1
		sta 	dcRetain
_DSDone:
		ply
		pla
		rts

; ************************************************************************************************
;
;		A REM statement starts, srcPtr just past the token. In pass zero a keep marker opens or
;		closes a region; anything else is an ordinary comment. Keeps X, Y and srcPtr, so
;		CommandREM still reads the rest of the line.
;
;		The word may follow any number of spaces and its letters may be in any case. It must end
;		the line or be followed by a space or a colon, so GP.KEEPER is a comment. The two #GPC
;		spellings take one or more spaces between their words.
;
; ************************************************************************************************

DCKeepMarker:
		lda 	dcPass
		bne 	_DKMRead
		rts
_DKMRead:
		phx
		phy
		ldy 	#0
_DKMSpace:
		lda 	(srcPtr),y
		cmp 	#' '
		bne 	_DKMWord
		iny
		bra 	_DKMSpace
_DKMWord:
		sty 	dcKeepFrom
		ldx 	#0
_DKMSpelling:
		lda 	DCKeepWords,x 				; which marker the spelling is, or 0 after the last
		beq 	_DKMDone
		sta 	dcKeepKind
		inx
		ldy 	dcKeepFrom
_DKMCompare:
		lda 	DCKeepWords,x
		beq 	_DKMWordEnd
		cmp 	#' '
		beq 	_DKMGap
		lda 	(srcPtr),y
		jsr 	DCUpperCase
		cmp 	DCKeepWords,x
		bne 	_DKMNext
		iny
		inx
		bra 	_DKMCompare
_DKMGap: 									; a space in the spelling is one or more in the line
		lda 	(srcPtr),y
		cmp 	#' '
		bne 	_DKMNext
_DKMGapMore:
		iny
		lda 	(srcPtr),y
		cmp 	#' '
		beq 	_DKMGapMore
		inx
		bra 	_DKMCompare
_DKMWordEnd:
		lda 	(srcPtr),y
		beq 	_DKMFound
		cmp 	#' '
		beq 	_DKMFound
		cmp 	#':'
		beq 	_DKMFound
_DKMNext: 									; on past the spelling's terminator
		inx
		lda 	DCKeepWords-1,x
		bne 	_DKMNext
		bra 	_DKMSpelling
_DKMFound:
		lda 	dcKeepKind
		cmp 	#DCKeepOpens
		bne 	_DKMCloses
		lda 	dcKeepOpen 					; a KEEP inside a region
		bne 	_DKMMismatch
		inc 	dcKeepOpen
		bra 	_DKMDone
_DKMCloses:
		lda 	dcKeepOpen 					; an ENDKEEP outside one
		beq 	_DKMMismatch
		stz 	dcKeepOpen
_DKMDone:
		ply
		plx
		rts
_DKMMismatch:
		.error_structure

DCKeepWords:
		.byte 	DCKeepOpens
		.text 	"GP.KEEP",0
		.byte 	DCKeepCloses
		.text 	"GP.ENDKEEP",0
		.byte 	DCKeepOpens
		.text 	"#GPC KEEP",0
		.byte 	DCKeepCloses
		.text 	"#GPC ENDKEEP",0
		.byte 	0

;
;		A letter that arrives as $61-$7A or $C1-$DA, to $41-$5A. Anything else is left alone.
;
DCUpperCase:
		cmp 	#$C1
		bcc 	_DUCAscii
		cmp 	#$DB
		bcs 	_DUCDone
		and 	#$7F
		rts
_DUCAscii:
		cmp 	#$61
		bcc 	_DUCDone
		cmp 	#$7B
		bcs 	_DUCDone
		and 	#$DF
_DUCDone:
		rts


; ************************************************************************************************
;
;		A branch is being written: opcode in branchOpcode, target in branchTarget. Keeps X and Y,
;		and zTemp0, which neither branch writer touches in pass one.
;
;		.gotoz is the skip over an IF ... THEN statement. It goes to the next line, which the
;		falls-through bit already says, so it is not an edge. Line $FFFF is the implicit-DIM
;		prologue, which is compiler output rather than a line anyone wrote.
;
; ************************************************************************************************

DCRecordLineBranch:
		lda 	dcPass
		beq 	_DRLDone
		lda 	branchOpcode
		cmp 	#PCD_CMD_GOTOCMD_Z
		bne 	_DRLEdge
		sta 	dcGotoZ
_DRLDone:
		rts
_DRLEdge:
		lda 	branchTarget
		and 	branchTarget+1
		cmp 	#$FF
		beq 	_DRLDone
		lda 	#$00
		bra 	DCAppendEdge

DCRecordAddressBranch:
		lda 	dcPass
		beq 	_DRADone
		lda 	#$80
		bra 	DCAppendEdge
_DRADone:
		rts

DCAppendEdge:
		sta 	dcFlag
		lda 	dcEdgeCount+1
		cmp 	#DCEdgeMax >> 8
		bcc 	_DAERoom
		lda 	#1
		sta 	dcFull
		rts
_DAERoom:
		phx
		phy
		lda 	zTemp0
		pha
		lda 	zTemp0+1
		pha
		lda 	dcEdgeCount
		ldy 	dcEdgeCount+1
		jsr 	DCEdgePointYA
		.dcedge_access
		lda 	dcEntry
		sta 	(zTemp0)
		ldy 	#1
		lda 	dcEntry+1
		ora 	dcFlag
		sta 	(zTemp0),y
		iny
		lda 	branchTarget
		sta 	(zTemp0),y
		iny
		lda 	branchTarget+1
		sta 	(zTemp0),y
		.dcedge_release
		inc 	dcEdgeCount
		bne 	_DAECounted
		inc 	dcEdgeCount+1
_DAECounted:
		pla
		sta 	zTemp0+1
		pla
		sta 	zTemp0
		ply
		plx
		rts

; ************************************************************************************************
;
;		The end of pass zero. Turn every target into an entry, spread "reached" until it stops
;		spreading, and count the lines that are left.
;
;		Bits only ever turn on, so the sweep ends. A backward branch costs one more sweep.
;
; ************************************************************************************************

DCSolve:
		lda 	dcKeepOpen 					; a keep region still open at the end of the source
		beq 	_DSClosed
		.error_structure
_DSClosed:
		lda 	objPtr 						; pass zero's length, which DCMeasure takes pass
		sta 	dcRemovedBytes 				; one's from
		lda 	objPtr+1
		sta 	dcRemovedBytes+1
		lda 	dcFull
		bne 	_DSFull
		lda 	dcEntry
		ora 	dcEntry+1
		beq 	_DSOut
		jsr 	DCResolveEdges
		stz 	dcIndex 					; the first line is where the program starts
		stz 	dcIndex+1
		jsr 	DCMarkReached
_DSSweep:
		stz 	dcChanged
		jsr 	DCSweepEdges
		jsr 	DCSweepFalls
		jsr 	DCSweepStructures
		lda 	dcChanged
		bne 	_DSSweep
		;
		;		Every line pass one will leave out, the swallowed ones too, has to fit the list.
		;
		jsr 	DCCountRemoved
		lda 	dcTally
		cmp 	#(DCListMax + 1) & $FF
		lda 	dcTally+1
		sbc 	#(DCListMax + 1) >> 8
		bcs 	_DSFull
		lda 	dcTally
		ora 	dcTally+1
		beq 	_DSOut
		inc 	dcSkip
_DSOut:
		rts
_DSFull:
		ldx 	#0
_DSFullText:
		lda 	DCFullText,x
		beq 	_DSOut
		jsr 	PrintCharacter
		inx
		bra 	_DSFullText

DCFullText:
		.text 	"DEAD CODE TABLE FULL, NOTHING REMOVED",13,0

;
;		Every edge's target, from a line number or an address to an entry.
;
DCResolveEdges:
		stz 	dcWalk
		stz 	dcWalk+1
_DREEdge:
		lda 	dcWalk
		cmp 	dcEdgeCount
		lda 	dcWalk+1
		sbc 	dcEdgeCount+1
		bcc 	_DRERead
		rts
_DRERead:
		lda 	dcWalk
		ldy 	dcWalk+1
		jsr 	DCEdgePointYA
		.dcedge_access
		lda 	(zTemp0)
		sta 	dcIndex
		ldy 	#1
		lda 	(zTemp0),y
		sta 	dcFlag
		iny
		lda 	(zTemp0),y
		sta 	dcKey
		iny
		lda 	(zTemp0),y
		sta 	dcKey+1
		.dcedge_release

		lda 	dcFlag 						; an edge written after the last line went nowhere a
		and 	#$7F 						; line could send it
		sta 	dcIndex+1
		jsr 	DCIndexAtEnd
		bcs 	_DRENone

		lda 	dcFlag
		bmi 	_DREAddress
		;
		;		A line: the first entry at or after it, since RESTORE and a missing line both
		;		mean that. The first entry above n-1, and entry 0 for line 0.
		;
		lda 	dcKey
		ora 	dcKey+1
		beq 	_DREFirst
		lda 	dcKey
		bne 	_DRENoBorrow
		dec 	dcKey+1
_DRENoBorrow:
		dec 	dcKey
		ldx 	#0
		jsr 	DCUpperBound
		bra 	_DREStore
_DREFirst:
		stz 	dcLow
		stz 	dcLow+1
		bra 	_DREStore
		;
		;		An address: the last entry that starts at or below it.
		;
_DREAddress:
		ldx 	#2
		jsr 	DCUpperBound
		lda 	dcLow
		ora 	dcLow+1
		beq 	_DRENone
		lda 	dcLow
		bne 	_DRELowOnly
		dec 	dcLow+1
_DRELowOnly:
		dec 	dcLow

_DREStore:
		lda 	dcLow 						; past the last source line: nothing to reach
		cmp 	dcEntry
		lda 	dcLow+1
		sbc 	dcEntry+1
		bcc 	_DREWrite
_DRENone:
		lda 	#$FF
		sta 	dcLow
		sta 	dcLow+1
_DREWrite:
		lda 	dcWalk
		ldy 	dcWalk+1
		jsr 	DCEdgePointYA
		.dcedge_access
		ldy 	#2
		lda 	dcLow
		sta 	(zTemp0),y
		iny
		lda 	dcLow+1
		sta 	(zTemp0),y
		.dcedge_release
		inc 	dcWalk
		bne 	_DRENext
		inc 	dcWalk+1
_DRENext:
		jmp 	_DREEdge

;
;		The first source entry whose field at offset X (0 the line number, 2 the address) is
;		above dcKey, into dcLow; dcEntry when there is none. Pass zero lays every line out in
;		source order, so both fields rise with the entry.
;
DCUpperBound:
		stx 	dcField
		stz 	dcLow
		stz 	dcLow+1
		lda 	dcEntry
		sta 	dcHigh
		lda 	dcEntry+1
		sta 	dcHigh+1
_DUBHalve:
		lda 	dcLow
		cmp 	dcHigh
		lda 	dcLow+1
		sbc 	dcHigh+1
		bcc 	_DUBProbe
		rts
_DUBProbe:
		clc
		lda 	dcLow
		adc 	dcHigh
		sta 	dcMid
		lda 	dcLow+1
		adc 	dcHigh+1
		ror 	a
		sta 	dcMid+1
		ror 	dcMid

		lda 	dcMid
		ldy 	dcMid+1
		jsr 	DCPageEntryYA
		.storage_access
		ldy 	dcField
		lda 	(zTemp0),y
		sta 	dcValue
		iny
		lda 	(zTemp0),y
		sta 	dcValue+1
		.storage_release

		lda 	dcKey
		cmp 	dcValue
		lda 	dcKey+1
		sbc 	dcValue+1
		bcc 	_DUBAbove
		clc
		lda 	dcMid
		adc 	#1
		sta 	dcLow
		lda 	dcMid+1
		adc 	#0
		sta 	dcLow+1
		jmp 	_DUBHalve
_DUBAbove:
		lda 	dcMid
		sta 	dcHigh
		lda 	dcMid+1
		sta 	dcHigh+1
		jmp 	_DUBHalve

;
;		An edge from a line that is reached or retained reaches its target.
;
DCSweepEdges:
		stz 	dcWalk
		stz 	dcWalk+1
_DSEEdge:
		lda 	dcWalk
		cmp 	dcEdgeCount
		lda 	dcWalk+1
		sbc 	dcEdgeCount+1
		bcc 	_DSERead
		rts
_DSERead:
		lda 	dcWalk
		ldy 	dcWalk+1
		jsr 	DCEdgePointYA
		.dcedge_access
		lda 	(zTemp0)
		sta 	dcIndex
		ldy 	#1
		lda 	(zTemp0),y
		and 	#$7F
		sta 	dcIndex+1
		iny
		lda 	(zTemp0),y
		sta 	dcTarget
		iny
		lda 	(zTemp0),y
		sta 	dcTarget+1
		.dcedge_release

		lda 	dcTarget+1
		cmp 	#$FF
		beq 	_DSENext
		lda 	#DCPlaneReached
		jsr 	DCTestBit
		bne 	_DSELive
		lda 	#DCPlaneRetained
		jsr 	DCTestBit
		beq 	_DSENext
_DSELive:
		lda 	dcTarget
		sta 	dcIndex
		lda 	dcTarget+1
		sta 	dcIndex+1
		jsr 	DCMarkReached
_DSENext:
		inc 	dcWalk
		bne 	_DSEEdge
		inc 	dcWalk+1
		bra 	_DSEEdge

;
;		A reached line that falls through reaches the next. Forward, so a run of them spreads in
;		one sweep.
;
DCSweepFalls:
		stz 	dcIndex
		stz 	dcIndex+1
_DSFLine:
		clc
		lda 	dcIndex
		adc 	#1
		sta 	dcNext
		lda 	dcIndex+1
		adc 	#0
		sta 	dcNext+1
		lda 	dcNext
		cmp 	dcEntry
		lda 	dcNext+1
		sbc 	dcEntry+1
		bcc 	_DSFTest
		rts
_DSFTest:
		stz 	dcFlag
		lda 	#DCPlaneReached
		jsr 	DCTestBit
		beq 	_DSFStep
		lda 	#DCPlaneFalls
		jsr 	DCTestBit
		beq 	_DSFStep
		inc 	dcFlag
_DSFStep:
		lda 	dcNext
		sta 	dcIndex
		lda 	dcNext+1
		sta 	dcIndex+1
		lda 	dcFlag
		beq 	_DSFLine
		jsr 	DCMarkReached
		bra 	_DSFLine

;
;		A run of structure lines with any line reached or retained is reached all through.
;		Structures on adjacent lines make one run, which keeps more and never less.
;
DCSweepStructures:
		stz 	dcIndex
		stz 	dcIndex+1
_DSSFind:
		jsr 	DCIndexAtEnd
		bcc 	_DSSTest
		rts
_DSSTest:
		lda 	#DCPlaneStructure
		jsr 	DCTestBit
		bne 	_DSSRun
		jsr 	DCNextIndex
		bra 	_DSSFind

_DSSRun:
		lda 	dcIndex
		sta 	dcRunStart
		lda 	dcIndex+1
		sta 	dcRunStart+1
		stz 	dcRunHit
_DSSInRun:
		jsr 	DCIndexAtEnd
		bcs 	_DSSRunEnd
		lda 	#DCPlaneStructure
		jsr 	DCTestBit
		beq 	_DSSRunEnd
		lda 	#DCPlaneReached
		jsr 	DCTestBit
		bne 	_DSSHit
		lda 	#DCPlaneRetained
		jsr 	DCTestBit
		beq 	_DSSStep
_DSSHit:
		inc 	dcRunHit
_DSSStep:
		jsr 	DCNextIndex
		bra 	_DSSInRun

_DSSRunEnd:
		lda 	dcRunHit
		beq 	_DSSFind
		lda 	dcIndex
		sta 	dcRunEnd
		lda 	dcIndex+1
		sta 	dcRunEnd+1
		lda 	dcRunStart
		sta 	dcIndex
		lda 	dcRunStart+1
		sta 	dcIndex+1
_DSSFill:
		lda 	dcIndex
		cmp 	dcRunEnd
		lda 	dcIndex+1
		sbc 	dcRunEnd+1
		bcs 	_DSSFind
		jsr 	DCMarkReached
		jsr 	DCNextIndex
		bra 	_DSSFill

;
;		How many lines pass one will leave out, into dcTally: each entry neither reached nor
;		retained, and the lines it read past its own.
;
DCCountRemoved:
		stz 	dcTally
		stz 	dcTally+1
		stz 	dcSwallowWalk
		stz 	dcSwallowWalk+1
		stz 	dcIndex
		stz 	dcIndex+1
_DCRLine:
		jsr 	DCIndexAtEnd
		bcs 	_DCRDone
		jsr 	DCIsRemoved
		bcc 	_DCRNext
		jsr 	DCExtraAt
		sec 								; the line itself, and what it swallowed
		lda 	dcTally
		adc 	dcExtra
		sta 	dcTally
		lda 	dcTally+1
		adc 	dcExtra+1
		sta 	dcTally+1
_DCRNext:
		jsr 	DCNextIndex
		bra 	_DCRLine
_DCRDone:
		rts

; ************************************************************************************************
;
;		Passes one and two, straight after GetLineNumber, line number in YA. CS when pass zero
;		found nothing reaches the line: it and every line it swallowed have been read past,
;		and pass one has listed their numbers. CC when it is kept, with A, X, Y and zTemp0
;		as they were.
;
;		Every line MainCompileLoop reads takes the next entry, so the count here is pass zero's
;		entry for the line -- which holds only because a skipped opener's swallowed lines are
;		read here, and never reach the loop to be counted.
;
; ************************************************************************************************

DCSkipLine:
		phx
		ldx 	dcSkip
		bne 	_DSLJudge
		plx
		clc
		rts
_DSLJudge:
		sta 	dcNumber
		sty 	dcNumber+1
		lda 	zTemp0
		pha
		lda 	zTemp0+1
		pha
		lda 	dcEntry
		sta 	dcIndex
		lda 	dcEntry+1
		sta 	dcIndex+1
		inc 	dcEntry
		bne 	_DSLCounted
		inc 	dcEntry+1
_DSLCounted:
		jsr 	DCIsRemoved
		bcc 	_DSLOut 					; kept
		jsr 	DCExtraAt
		jsr 	DCListLine
_DSLSwallowed:
		lda 	dcExtra
		ora 	dcExtra+1
		beq 	_DSLSkipped
		jsr 	ReadSourceLine
		bcc 	_DSLSkipped 				; the source ended first, which pass zero rules out
		jsr 	ProcessNewLine
		jsr 	GetLineNumber
		sta 	dcNumber
		sty 	dcNumber+1
		jsr 	DCListLine
		lda 	dcExtra
		bne 	_DSLOneLess
		dec 	dcExtra+1
_DSLOneLess:
		dec 	dcExtra
		bra 	_DSLSwallowed
_DSLSkipped:
		sec
_DSLOut: 									; nothing from here on touches the carry
		pla
		sta 	zTemp0+1
		pla
		sta 	zTemp0
		lda 	dcNumber
		ldy 	dcNumber+1
		plx
		rts

;
;		Pass one lists the line number in dcNumber. The solve made sure the list has room.
;
DCListLine:
		lda 	passNumber
		bne 	_DLLDone
		lda 	dcListCount
		asl 	a
		sta 	zTemp0
		lda 	dcListCount+1
		rol 	a
		clc
		adc 	#DCListTable >> 8
		sta 	zTemp0+1
		.dcedge_access
		lda 	dcNumber
		sta 	(zTemp0)
		ldy 	#1
		lda 	dcNumber+1
		sta 	(zTemp0),y
		.dcedge_release
		inc 	dcListCount
		bne 	_DLLDone
		inc 	dcListCount+1
_DLLDone:
		rts

;
;		Pass one, at the point pass zero stopped: what leaving the lines out saved.
;
DCMeasure:
		lda 	dcSkip
		bne 	_DMSaved
		stz 	dcRemovedBytes
		stz 	dcRemovedBytes+1
		rts
_DMSaved:
		sec
		lda 	dcRemovedBytes
		sbc 	objPtr
		sta 	dcRemovedBytes
		lda 	dcRemovedBytes+1
		sbc 	objPtr+1
		sta 	dcRemovedBytes+1
		rts

; ************************************************************************************************
;
;									Small pieces
;
; ************************************************************************************************

;
;		CS when dcIndex is neither reached nor retained.
;
DCIsRemoved:
		lda 	#DCPlaneReached
		jsr 	DCTestBit
		bne 	_DIRKept
		lda 	#DCPlaneRetained
		jsr 	DCTestBit
		bne 	_DIRKept
		sec
		rts
_DIRKept:
		clc
		rts

;
;		The lines dcIndex read past its own, into dcExtra: zero unless the swallow list names
;		it. The list is in entry order and so is every caller, so dcSwallowWalk only moves on.
;
DCExtraAt:
		stz 	dcExtra
		stz 	dcExtra+1
_DEALook:
		lda 	dcSwallowWalk
		cmp 	dcSwallowCount
		lda 	dcSwallowWalk+1
		sbc 	dcSwallowCount+1
		bcs 	_DEADone
		lda 	dcSwallowWalk
		ldy 	dcSwallowWalk+1
		jsr 	DCPointYA
		lda 	zTemp0+1
		clc
		adc 	#DCSwallowTable >> 8
		sta 	zTemp0+1
		.dcplane_access
		lda 	(zTemp0)
		sta 	dcKey
		ldy 	#1
		lda 	(zTemp0),y
		sta 	dcKey+1
		iny
		lda 	(zTemp0),y
		sta 	dcValue
		iny
		lda 	(zTemp0),y
		sta 	dcValue+1
		.dcplane_release
		lda 	dcKey
		cmp 	dcIndex
		lda 	dcKey+1
		sbc 	dcIndex+1
		bcs 	_DEAReached
		inc 	dcSwallowWalk
		bne 	_DEALook
		inc 	dcSwallowWalk+1
		jmp 	_DEALook
_DEAReached: 								; at or past it, and only an exact match is its own
		lda 	dcKey
		cmp 	dcIndex
		bne 	_DEADone
		lda 	dcKey+1
		cmp 	dcIndex+1
		bne 	_DEADone
		lda 	dcValue
		sta 	dcExtra
		lda 	dcValue+1
		sta 	dcExtra+1
_DEADone:
		rts

;
;		Mark dcIndex reached, noting in dcChanged when it was not already.
;
DCMarkReached:
		lda 	#DCPlaneReached
		jsr 	DCPointAt
		.dcplane_access
		lda 	(zTemp0)
		tay
		ora 	dcMask
		sta 	(zTemp0)
		.dcplane_release
		tya
		and 	dcMask
		bne 	_DMRAlready
		lda 	#1
		sta 	dcChanged
_DMRAlready:
		rts

;
;		dcIndex's bit in the plane whose page is in A: set it, or test it (NZ when set).
;
DCSetBit:
		jsr 	DCPointAt
		.dcplane_access
		lda 	(zTemp0)
		ora 	dcMask
		sta 	(zTemp0)
		.dcplane_release
		rts

DCTestBit:
		jsr 	DCPointAt
		.dcplane_access
		lda 	(zTemp0)
		.dcplane_release
		and 	dcMask
		rts

;
;		dcIndex in the plane whose page is in A -> zTemp0 at its byte, dcMask at its bit.
;
DCPointAt:
		sta 	dcPlane
		lda 	dcIndex+1
		sta 	zTemp0+1
		lda 	dcIndex
		lsr 	zTemp0+1
		ror 	a
		lsr 	zTemp0+1
		ror 	a
		lsr 	zTemp0+1
		ror 	a
		sta 	zTemp0
		lda 	zTemp0+1
		clc
		adc 	dcPlane
		sta 	zTemp0+1
		lda 	dcIndex
		and 	#7
		tax
		lda 	DCBitMasks,x
		sta 	dcMask
		rts

DCBitMasks:
		.byte 	1,2,4,8,16,32,64,128

;
;		YA times four into zTemp0; the edge list wants its table page added on top.
;
DCEdgePointYA:
		jsr 	DCPointYA
		lda 	zTemp0+1
		clc
		adc 	#DCEdgeTable >> 8
		sta 	zTemp0+1
		rts

DCPointYA:
		sty 	zTemp0+1
		asl 	a
		rol 	zTemp0+1
		asl 	a
		rol 	zTemp0+1
		sta 	zTemp0
		rts

;
;		Entry YA -> zTemp0 at its line record, with the storage bank chosen. Entry n is the
;		record n+1 steps of four below the top of the table.
;
DCPageEntryYA:
		sta 	dcValue
		sty 	dcValue+1
		inc 	dcValue
		bne 	_DPENoCarry
		inc 	dcValue+1
_DPENoCarry:
		asl 	dcValue
		rol 	dcValue+1
		asl 	dcValue
		rol 	dcValue+1
		sec
		lda 	#0
		sbc 	dcValue
		sta 	lineWalk
		lda 	compilerEndHigh
		sbc 	dcValue+1
		sta 	lineWalk+1
		jmp 	STRPageLine

;
;		CS when dcIndex has reached dcEntry, the number of source entries.
;
DCIndexAtEnd:
		lda 	dcIndex
		cmp 	dcEntry
		lda 	dcIndex+1
		sbc 	dcEntry+1
		rts

DCNextIndex:
		inc 	dcIndex
		bne 	_DNIDone
		inc 	dcIndex+1
_DNIDone:
		rts

; ************************************************************************************************
;
;		Working storage, in the code section for the reason select.asm gives: storage is a full
;		1K hole, and compiler code costs a compiled program nothing.
;
; ************************************************************************************************

dcPlaneSavedBank: 							; caller's RAM bank, across a plane window
		.fill 	1
dcEdgeSavedBank: 							; ...and across an edge window
		.fill 	1
dcEntry: 									; the entry the line being compiled will have; at the
		.fill 	2 							; end of the pass, how many source entries there are
dcReads: 									; source lines read this pass, by anyone
		.fill 	2
dcReadsAtLine: 								; ...as the count stood before this line was read
		.fill 	2
dcLineOpen: 								; nonzero once a line has been read this pass
		.fill 	1
dcExtra: 									; lines the line just closed read past its own
		.fill 	2
dcStartDepth: 								; the three block depths ORed, where the line started
		.fill 	1
dcStartBlocks: 								; blockCount's low byte there
		.fill 	1
dcStartAlts: 								; altCount's low byte there
		.fill 	1
dcInStructure: 								; nonzero when the line just closed is in a structure
		.fill 	1
dcLastToken: 								; the first byte of the line's last statement
		.fill 	1
dcGotoZ: 									; nonzero when the line wrote an IF ... THEN skip
		.fill 	1
dcRetain: 									; nonzero when the line holds a retained statement
		.fill 	1
dcFull: 									; nonzero when a list filled: nothing is removed
		.fill 	1
dcEdgeCount: 								; edges recorded
		.fill 	2
dcSwallowCount: 							; swallow entries recorded
		.fill 	2
dcFlag: 									; an edge's kind, or a sweep's bit in hand
		.fill 	1
dcIndex: 									; the entry a plane routine works on
		.fill 	2
dcNext: 									; the entry after it
		.fill 	2
dcPlane: 									; the plane page DCPointAt was given
		.fill 	1
dcMask: 									; ...and the bit it found
		.fill 	1
dcChanged: 									; nonzero when a sweep marked something new
		.fill 	1
dcWalk: 									; the edge a walk of the list is on
		.fill 	2
dcTarget: 									; that edge's target entry
		.fill 	2
dcKey: 										; what DCUpperBound searches for
		.fill 	2
dcField: 									; ...in which field of the line record
		.fill 	1
dcLow: 										; the search's bounds, and its answer in dcLow
		.fill 	2
dcHigh:
		.fill 	2
dcMid:
		.fill 	2
dcValue: 									; a field read back, or a scratch word
		.fill 	2
dcRunStart: 								; a structure run's first entry
		.fill 	2
dcRunEnd: 									; ...and one past its last
		.fill 	2
dcRunHit: 									; nonzero when a line in the run is reached or retained
		.fill 	1
dcNumber: 									; a line number being listed
		.fill 	2
dcSkip: 									; nonzero when passes one and two leave lines out
		.fill 	1
dcSwallowWalk: 								; the swallow entry a forward walk has reached
		.fill 	2
dcTally: 									; the lines the solve says pass one will leave out
		.fill 	2
dcListCount: 								; ...and the numbers pass one has listed so far
		.fill 	2
dcRemovedBytes: 							; pass zero's length, then what leaving lines out saved
		.fill 	2
dcKeepOpen: 								; nonzero inside a keep region
		.fill 	1
dcKeepAtStart: 								; ...as it stood where the line started
		.fill 	1
dcKeepFrom: 								; where a marker's word starts, past the spaces
		.fill 	1
dcKeepKind: 								; the marker a spelling being matched is
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
;		13/09/26		Written. Pass zero records and solves, and prints the removed lines.
;		13/09/26		Passes one and two leave the removed lines out, and pass one lists them.
;		13/09/26		Keep regions: every line between a KEEP and an ENDKEEP marker is a root.
;
; ************************************************************************************************
