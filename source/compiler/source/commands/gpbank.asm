; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpbank.asm
;		Purpose:	GP.BANKED / GP.ENDBANKED -- mark p-code that belongs in a RAM bank
;		Created:	5th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;		GP.BANKED <bank>
;		...
;		GP.ENDBANKED
;
;		Marks a run of p-code as belonging at $A000 in the given RAM bank rather than in low
;		memory. Both are alone on their line; only GP.BANKED takes an operand, and it is a
;		DECIMAL CONSTANT, not an expression -- the number is patched into the program's
;		bootstrap at compile time, so there is nothing there to evaluate it.
;
;		THE TWO HANDLERS ONLY RECORD THE REGION. GPBankRelocate, further down this file, is what
;		acts on it: called from SaveCodeAndExit once the whole object is laid out, it lifts the
;		region out of the middle and puts it at the end, past the GP.ASM pool.
;
;		NAMED BANKED AND NOT BANK. BANK is the runtime statement that selects one, and this does
;		not select anything -- it is a compile time marker. Two keywords one letter apart, one of
;		which changes the hardware and one of which does not, is a trap not worth setting.
;
;		NO "T" ON EITHER, in commands.def. They write no keyword token, so ScanGPUsage cannot
;		see them and a program whose only GP.BASIC keyword is GP.BANKED stays GP OUT and pays
;		nothing for the GP runtime block -- the argument GP.ASM already makes for itself.
;
;		BOTH DISARM deferErrors FIRST. A block opener that fails with a SYNTAX error while the
;		deferral is armed is rolled back and replaced with a runtime throw-stub, so its opener
;		vanishes while the closer on a later line still compiles. The block is left with a
;		closer and no opener and the enclosing nesting is corrupted silently.
;
;		BOTH MUST RETURN CARRY CLEAR. A .def helper returning carry set makes the generator drop
;		every table element after it, with no error and no clue.
;
;		ONE REGION A PROGRAM, for now. A second GP.BANKED is a structure error rather than a
;		second region: one bank holds the whole GUI stack with room to spare, and the machinery
;		for several is not worth carrying until something needs it.
;
; ************************************************************************************************

CommandGPBankedCompile:
		stz 	deferErrors 				; a block opener must never defer -- see the header
		lda 	gpBankState 				; 0 = never seen, 1 = open, 2 = closed
		bne 	GPBankStructure 			; a second GP.BANKED, or one after a closed region
		jsr 	GPBankCheckAlone 			; first on its line, and outside every block
		jsr 	GPBankReadNumber 			; the bank, into gpBankNumber
		lda 	#1
		sta 	gpBankState
		lda 	zTemp0 						; THE REGION STARTS AT ITS OWN LINE MARKER, so the line
		sta 	gpBankStart 				; table entry for this line moves with it -- which is
		lda 	zTemp0+1 					; what lets the bridge below be an ordinary GOTO to an
		sta 	gpBankStart+1 				; ordinary line number
		lda 	currentLineNumber 			; ...and this is the line number it goes to
		sta 	gpBankLineIn
		lda 	currentLineNumber+1
		sta 	gpBankLineIn+1
		clc
		rts

CommandGPEndBankedCompile:
		stz 	deferErrors
		lda 	gpBankState
		cmp 	#1 							; only a region that is open can be closed
		bne 	GPBankStructure
		jsr 	GPBankCheckAlone
		lda 	#2
		sta 	gpBankState
		lda 	zTemp0 						; THE REGION ENDS AT THIS LINE'S MARKER, which stays
		sta 	gpBankEnd 					; behind in low memory: it is the first byte of what
		lda 	zTemp0+1 					; follows the region, not the last byte of it
		sta 	gpBankEnd+1
		lda 	currentLineNumber
		sta 	gpBankLineOut
		lda 	currentLineNumber+1
		sta 	gpBankLineOut+1
		clc
		rts

;
;		A GLOBAL label, not a _ local one: 64tass scopes a _ label to the enclosing global, so a
;		local defined under the first routine cannot be branched to from the second.
;
GPBankStructure:
		.error_structure

; ************************************************************************************************
;
;		Read GP.BANKED's operand: a decimal constant, 1 to 255.
;
;		BANK 0 IS REFUSED. It is the KERNAL's -- its FAT32 buffers live there -- so a program
;		that put its code in it would work until the first file operation and then not.
;
;		No upper check beyond the byte. A 512K machine has banks 0..63 and a 2MB machine 0..255,
;		and which one this will run on is not a compile time fact.
;
; ************************************************************************************************

GPBankReadNumber:
		stz 	gpBankNumber
		jsr 	GetNextNonSpace 			; the first digit
		jsr 	CharIsDigit
		bcc 	GPBankBadNumber 			; no operand at all
_GBRNDigit:
		sec 								; gpBankNumber = gpBankNumber * 10 + digit
		sbc 	#"0"
		pha
		lda 	gpBankNumber
		asl 	a
		bcs 	GPBankBadNumber 			; over 255 at any point is not a bank
		sta 	gpBankNumber 				; n*2
		asl 	a
		bcs 	GPBankBadNumber
		asl 	a 							; n*8
		bcs 	GPBankBadNumber
		clc
		adc 	gpBankNumber 				; n*8 + n*2
		bcs 	GPBankBadNumber
		sta 	gpBankNumber
		pla
		clc
		adc 	gpBankNumber
		bcs 	GPBankBadNumber
		sta 	gpBankNumber
		jsr 	LookNext 					; another digit ?
		jsr 	CharIsDigit
		bcc 	_GBRNDone
		jsr 	GetNext
		bra 	_GBRNDigit
_GBRNDone:
		lda 	gpBankNumber
		beq 	GPBankBadNumber 			; bank 0 belongs to the KERNAL
		rts

GPBankBadNumber:
		.error_value

; ************************************************************************************************
;
;		Both markers have to be the FIRST statement on their line, and both have to be outside
;		every open block. Returns the address of this line's PCD_NEWCMD_LINE byte in zTemp0.
;
;		FIRST ON THE LINE, because that byte is the boundary. The compile loop writes one
;		PCD_NEWCMD_LINE per source line before dispatching any of its statements, so if the
;		marker is first then objPtr-1 is that byte -- and a region that begins and ends on a
;		line marker is a region whose two line table entries can move with it and be used as
;		branch targets. Written after another statement, objPtr-1 is the tail of that statement
;		and the boundary lands in the middle of it. Testing the byte is both the check and the
;		answer.
;
;		OUTSIDE EVERY BLOCK, because the region is spliced out with two plain GOTOs, and a GOTO
;		compiled inside a GP.DO or a GP.SELECT needs an .unwind in front of it to release the
;		frames it leaves. These two are written after compilation, where there is no such
;		machinery -- so require that there is nothing to unwind.
;
; ************************************************************************************************

GPBankCheckAlone:
		lda 	blockDepth 					; GP.DO nesting
		ora 	SelectDepth 				; ...and GP.SELECT
		bne 	GPBankStructure
		sec
		lda 	objPtr
		sbc 	#1
		sta 	zTemp0
		lda 	objPtr+1
		sbc 	#0
		sta 	zTemp0+1
		lda 	(zTemp0)
		cmp 	#PCD_NEWCMD_LINE
		bne 	GPBankStructure
		rts

; ************************************************************************************************
;
;		Lift the GP.BANKED region out of the middle of the object and put it at the end, past
;		the GP.ASM pool, on a page boundary.
;
;		Called from SaveCodeAndExit after AsmFlushPool and BEFORE FixBranches, so every branch is
;		still an unresolved line number and the only things that have to be corrected are the
;		line number table and the three places that hold a buffer ADDRESS.
;
;		BEFORE                                AFTER
;		+---------------------------------+   +---------------------------------+
;		| A   code before GP.BANKED       |   | A                               |
;		| B   the region     (gpBankStart)|   | GOTO the GP.BANKED line   3 bytes|
;		| C   code after     (gpBankEnd)  |   | C                               |
;		| $FF                             |   | $FF        <- low code ends here|
;		| the GP.ASM pool                 |   | the GP.ASM pool                 |
;		+---------------------------------+   | pad to a page boundary          |
;		                                      | B   the region                  |
;		                                      | GOTO the GP.ENDBANKED line      |
;		                                      | $FF                             |
;		                                      +---------------------------------+
;
;		THE TWO BRIDGES ARE ORDINARY GOTOs TO ORDINARY LINE NUMBERS, and that is the whole
;		trick. The region begins on the GP.BANKED line's marker byte and ends on the
;		GP.ENDBANKED line's, so both lines have a table entry pointing exactly at a boundary.
;		Correct the table and FixBranches -- which runs next, and knows nothing about any of
;		this -- resolves both bridges by the path it resolves every other GOTO. No new opcode,
;		no absolute operand, no back-patching.
;
;		THE POOL STAYS IN LOW MEMORY and the region goes ABOVE it. A blob is 65C02 code, and a
;		blob that changes the RAM bank -- STASH does -- must not itself be executing out of one.
;		Putting the pool below the region is also what lets the region's low memory copy be
;		reclaimed: the workspace can start where the region starts, because everything the
;		program still needs is underneath it.
;
;		THE REGION IS PAGE ALIGNED so the bootstrap's copy is a page loop rather than a byte
;		loop -- one byte of source page, one of page count, one of bank. There are 33 spare
;		bytes in the bootstrap and a byte loop does not fit in them.
;
;		THE FIRST $FF IS STILL THE LOW CODE'S END MARKER, so nothing downstream had to change
;		about where the pool goes. What did change is that two walkers now HOP over the pool to
;		reach the region -- see GPBankHop.
;
;		THE MOVE IS A ROTATION, done in place: shift the region and the whole tail up by three
;		to open the gap for the first bridge, reverse the region, reverse the tail, reverse the
;		pair -- which leaves the tail followed by the region -- then lift the region again by
;		the padding. No second buffer. The object buffer is the largest thing in low RAM
;		precisely because there is no room for one.
;
; ************************************************************************************************

GPBankRelocate:
		stz 	deferErrors
		lda 	gpBankState
		beq 	_GBRNothing 				; no GP.BANKED in this program at all
		cmp 	#2
		beq 	_GBRHaveRegion
		jmp 	GPBankStructure 			; a GP.BANKED that was never closed
_GBRNothing:
		rts
_GBRHaveRegion:
		;
		;		SHARED MODE ONLY. The correction below needs to know where the p-code will RUN,
		;		and in shared mode that is the constant PCODE_PAGE. Embedded, it depends on
		;		ScanGPUsage, which has not happened yet -- and there is no bootstrap there to do
		;		the copying either. Refusing is honest; guessing would miscompile silently.
		;
		lda 	gpBankShared
		bne 	_GBRShared
		.error_unimplemented
_GBRShared:
		lda 	objPtr 						; Q, one past everything including the pool
		sta 	gpBankTailEnd
		lda 	objPtr+1
		sta 	gpBankTailEnd+1
		;
		;		The region's length, the tail's length, and where the region ends up.
		;
		sec
		lda 	gpBankEnd
		sbc 	gpBankStart
		sta 	gpBankLength 				; L
		lda 	gpBankEnd+1
		sbc 	gpBankStart+1
		sta 	gpBankLength+1

		sec
		lda 	gpBankTailEnd
		sbc 	gpBankEnd
		sta 	gpBankTailLen 				; TL
		lda 	gpBankTailEnd+1
		sbc 	gpBankEnd+1
		sta 	gpBankTailLen+1

		clc 								; R0 = start + 3 + TL, before padding
		lda 	gpBankStart
		adc 	#3
		sta 	gpBankMid
		lda 	gpBankStart+1
		adc 	#0
		sta 	gpBankMid+1
		clc
		lda 	gpBankMid
		adc 	gpBankTailLen
		sta 	gpBankMid
		lda 	gpBankMid+1
		adc 	gpBankTailLen+1
		sta 	gpBankMid+1

		sec 								; pad up to the next page. FreeMemory is page aligned
		lda 	#0 							; and so is the run base, so aligning in the buffer
		sbc 	gpBankMid 					; aligns it at run time.
		sta 	gpBankPad

		clc 								; R = R0 + pad
		lda 	gpBankMid
		adc 	gpBankPad
		sta 	gpBankNewBase
		lda 	gpBankMid+1
		adc 	#0
		sta 	gpBankNewBase+1
		;
		;		Reserve what the move needs -- two bridges, the padding and the new end marker --
		;		through WriteCodeByte rather than by moving objPtr, because that is the only
		;		place the object ceiling is tested. A program that no longer fits has to say
		;		PROGRAM TOO BIG here, not run off the top of the buffer.
		;
		lda 	gpBankPad
		clc
		adc 	#7
		tax
_GBRoom:
		lda 	#0
		jsr 	WriteCodeByte
		dex
		bne 	_GBRoom
		;
		;		The two deltas every recorded address is corrected by. The tail moves from
		;		gpBankEnd down to start+3; the region moves to gpBankNewBase.
		;
		sec
		lda 	#3
		sbc 	gpBankLength
		sta 	gpBankDelta+2
		lda 	#0
		sbc 	gpBankLength+1
		sta 	gpBankDelta+3

		sec
		lda 	gpBankNewBase
		sbc 	gpBankStart
		sta 	gpBankDelta
		lda 	gpBankNewBase+1
		sbc 	gpBankStart+1
		sta 	gpBankDelta+1
		;
		;		Step one: shift the region and the tail up by three, to open the gap the entry
		;		bridge goes in.
		;
		lda 	gpBankStart
		sta 	gpBankMoveLow
		lda 	gpBankStart+1
		sta 	gpBankMoveLow+1
		lda 	gpBankTailEnd
		sta 	zTemp0
		lda 	gpBankTailEnd+1
		sta 	zTemp0+1
		clc
		lda 	gpBankTailEnd
		adc 	#3
		sta 	zTemp1
		lda 	gpBankTailEnd+1
		adc 	#0
		sta 	zTemp1+1
		jsr 	_GBShiftUp
		;
		;		Step two: rotate, so the tail comes first and the region follows it.
		;
		clc
		lda 	gpBankStart
		adc 	#3
		sta 	gpBankLow
		lda 	gpBankStart+1
		adc 	#0
		sta 	gpBankLow+1

		clc
		lda 	gpBankLow
		adc 	gpBankLength
		sta 	gpBankMid
		lda 	gpBankLow+1
		adc 	gpBankLength+1
		sta 	gpBankMid+1

		clc
		lda 	gpBankTailEnd
		adc 	#3
		sta 	gpBankHigh
		lda 	gpBankTailEnd+1
		adc 	#0
		sta 	gpBankHigh+1

		lda 	gpBankLow 					; reverse the region
		ldy 	gpBankLow+1
		ldx 	gpBankMid
		stx 	gpBankRevEnd
		ldx 	gpBankMid+1
		stx 	gpBankRevEnd+1
		jsr 	_GBReverse

		lda 	gpBankMid 					; reverse the tail
		ldy 	gpBankMid+1
		ldx 	gpBankHigh
		stx 	gpBankRevEnd
		ldx 	gpBankHigh+1
		stx 	gpBankRevEnd+1
		jsr 	_GBReverse

		lda 	gpBankLow 					; and the pair, leaving tail then region
		ldy 	gpBankLow+1
		ldx 	gpBankHigh
		stx 	gpBankRevEnd
		ldx 	gpBankHigh+1
		stx 	gpBankRevEnd+1
		jsr 	_GBReverse
		;
		;		Step three: lift the region again by the padding, so it starts on a page. The
		;		rotation left it at gpBankHigh - length; it has to end at newBase + length.
		;
		lda 	gpBankPad
		beq 	_GBRPadded 					; already aligned
		sec
		lda 	gpBankHigh
		sbc 	gpBankLength
		sta 	gpBankMoveLow 				; where the region sits now
		lda 	gpBankHigh+1
		sbc 	gpBankLength+1
		sta 	gpBankMoveLow+1
		lda 	gpBankHigh 					; ...and one past its last byte
		sta 	zTemp0
		lda 	gpBankHigh+1
		sta 	zTemp0+1
		clc
		lda 	gpBankHigh
		adc 	gpBankPad
		sta 	zTemp1
		lda 	gpBankHigh+1
		adc 	#0
		sta 	zTemp1+1
		jsr 	_GBShiftUp
_GBRPadded:
		;
		;		gpBankHigh is now one past the region: where the exit bridge goes.
		;
		clc
		lda 	gpBankNewBase
		adc 	gpBankLength
		sta 	gpBankHigh
		lda 	gpBankNewBase+1
		adc 	gpBankLength+1
		sta 	gpBankHigh+1
		;
		;		The two bridges, and the end marker of the whole object.
		;
		lda 	gpBankStart
		sta 	zTemp0
		lda 	gpBankStart+1
		sta 	zTemp0+1
		lda 	gpBankLineIn
		ldy 	gpBankLineIn+1
		jsr 	_GBWriteGoto

		lda 	gpBankHigh
		sta 	zTemp0
		lda 	gpBankHigh+1
		sta 	zTemp0+1
		lda 	gpBankLineOut
		ldy 	gpBankLineOut+1
		jsr 	_GBWriteGoto

		lda 	#$FF
		ldy 	#3
		sta 	(zTemp0),y
		;
		;		Where the walkers hop FROM: one past the low code's own $FF, which is where the
		;		pool starts if there is one and the end of everything if there is not. Recorded
		;		before it moves, then corrected with everything else.
		;
		lda 	AsmPoolLen
		ora 	AsmPoolLen+1
		beq 	_GBRNoPool
		lda 	AsmPoolBase
		sta 	gpBankHopFrom
		lda 	AsmPoolBase+1
		sta 	gpBankHopFrom+1
		bra 	_GBRFixUp
_GBRNoPool:
		lda 	gpBankTailEnd
		sta 	gpBankHopFrom
		lda 	gpBankTailEnd+1
		sta 	gpBankHopFrom+1
_GBRFixUp:
		;
		;		Everything that recorded a position in the buffer now has to be told.
		;
		jsr 	_GBFixLineTable
		jsr 	_GBFixFnCalls
		jsr 	_GBFixAsmCalls
		jsr 	_GBFixPoolBase
		jsr 	_GBFixHopFrom
		;
		;		Leave the region's new bounds behind, and open the hop.
		;
		lda 	gpBankNewBase
		sta 	gpBankStart
		sta 	gpBankHopTo
		lda 	gpBankNewBase+1
		sta 	gpBankStart+1
		sta 	gpBankHopTo+1
		clc 								; one past the exit bridge
		lda 	gpBankHigh
		adc 	#3
		sta 	gpBankEnd
		lda 	gpBankHigh+1
		adc 	#0
		sta 	gpBankEnd+1
		;
		;		THE CROSS-BOUNDARY CORRECTION. A branch offset is target minus source computed in
		;		BUFFER addresses, which works because every byte has the same buffer-to-run delta
		;		and the two cancel in the subtraction. The region's delta is different -- buffer
		;		to $A000, not buffer to $0900 -- so a branch with one end each side comes out
		;		wrong by exactly the difference, and only such a branch does.
		;
		;		It is a whole number of PAGES: both bases are page aligned and so is the region.
		;		So the correction is one byte, added to or taken off the offset's high half.
		;
		clc
		lda 	gpBankNewBase+1 			; the page the region WOULD have run at
		adc 	gpBankRunPage
		sta 	gpBankRunBase
		sec
		lda 	#$A0 						; ...against the page it is actually going to
		sbc 	gpBankRunBase
		sta 	gpBankCrossHigh
		;
		;		And how much the bootstrap has to move: the region, its exit bridge and the end
		;		marker, rounded up to whole pages. It starts on a page boundary, so the low byte
		;		of the difference is objPtr's own.
		;
		sec
		lda 	objPtr
		sbc 	gpBankNewBase
		sta 	gpBankTemp
		lda 	objPtr+1
		sbc 	gpBankNewBase+1
		sta 	gpBankPages
		lda 	gpBankTemp 					; a part page needs one more
		beq 	_GBRWholePages
		inc 	gpBankPages
_GBRWholePages:
		lda 	#1
		sta 	gpBankActive
		rts

_GBFixPoolBase:
		lda 	AsmPoolLen
		ora 	AsmPoolLen+1
		beq 	_GBFPBOut
		lda 	AsmPoolBase
		sta 	zTemp1
		lda 	AsmPoolBase+1
		sta 	zTemp1+1
		jsr 	GPBankAdjust
		lda 	zTemp1
		sta 	AsmPoolBase
		lda 	zTemp1+1
		sta 	AsmPoolBase+1
_GBFPBOut:
		rts

_GBFixHopFrom:
		lda 	gpBankHopFrom
		sta 	zTemp1
		lda 	gpBankHopFrom+1
		sta 	zTemp1+1
		jsr 	GPBankAdjust
		lda 	zTemp1
		sta 	gpBankHopFrom
		lda 	zTemp1+1
		sta 	gpBankHopFrom+1
		rts

; ************************************************************************************************
;
;		Write .goto <line YA> at zTemp0.
;
; ************************************************************************************************

_GBWriteGoto:
		pha 								; line low
		phy 								; line high
		lda 	#PCD_CMD_GOTO
		sta 	(zTemp0)
		pla 								; high comes back off first
		tax
		pla 								; low
		ldy 	#1
		sta 	(zTemp0),y
		txa
		iny
		sta 	(zTemp0),y
		rts

; ************************************************************************************************
;
;		Move the bytes in [gpBankMoveLow, zTemp0) up so that they end at zTemp1. Copied from the
;		top down, so the source and the destination may overlap.
;
; ************************************************************************************************

_GBShiftUp:
		lda 	zTemp0
		cmp 	gpBankMoveLow
		bne 	_GBSUByte
		lda 	zTemp0+1
		cmp 	gpBankMoveLow+1
		beq 	_GBSUDone
_GBSUByte:
		lda 	zTemp0
		bne 	_GBSUNoBorrow0
		dec 	zTemp0+1
_GBSUNoBorrow0:
		dec 	zTemp0
		lda 	zTemp1
		bne 	_GBSUNoBorrow1
		dec 	zTemp1+1
_GBSUNoBorrow1:
		dec 	zTemp1
		lda 	(zTemp0)
		sta 	(zTemp1)
		bra 	_GBShiftUp
_GBSUDone:
		rts

; ************************************************************************************************
;
;		Reverse the bytes from YA up to gpBankRevEnd, which is one past the last. An empty range
;		and a range of one byte both fall straight out.
;
; ************************************************************************************************

_GBReverse:
		sta 	zTemp0 						; zTemp0 = the first byte
		sty 	zTemp0+1
		lda 	gpBankRevEnd 				; zTemp1 = the LAST byte, one below the end
		sta 	zTemp1
		lda 	gpBankRevEnd+1
		sta 	zTemp1+1
		lda 	zTemp1
		bne 	_GBRevNoBorrow
		dec 	zTemp1+1
_GBRevNoBorrow:
		dec 	zTemp1
_GBRevLoop:
		lda 	zTemp0+1 					; done once the two pointers meet or cross
		cmp 	zTemp1+1
		bcc 	_GBRevSwap
		bne 	_GBRevDone
		lda 	zTemp0
		cmp 	zTemp1
		bcs 	_GBRevDone
_GBRevSwap:
		lda 	(zTemp0)
		tax
		lda 	(zTemp1)
		sta 	(zTemp0)
		txa
		sta 	(zTemp1)
		inc 	zTemp0
		bne 	_GBRevNoCarry
		inc 	zTemp0+1
_GBRevNoCarry:
		lda 	zTemp1
		bne 	_GBRevNoBorrow2
		dec 	zTemp1+1
_GBRevNoBorrow2:
		dec 	zTemp1
		bra 	_GBRevLoop
_GBRevDone:
		rts

; ************************************************************************************************
;
;		Every entry in the line number table holds the compile time address of the line it
;		names, and the whole point of moving the region on line boundaries is that these stay
;		usable: FixBranches resolves both bridges through them a moment from now, and the map
;		file is written from them afterwards.
;
;		The table is walked exactly as WriteMapFile walks it -- 4 byte entries growing DOWN from
;		compilerEndHigh:$00 to lineNumberTable -- and the window is opened and closed once per
;		entry rather than held across the loop, for the reason x16_storage.inc gives.
;
; ************************************************************************************************

_GBFixLineTable:
		lda 	compilerEndHigh
		sta 	gpBankWalk+1
		stz 	gpBankWalk
_GBFLTLoop:
		sec 								; down one entry
		lda 	gpBankWalk
		sbc 	#4
		sta 	gpBankWalk
		lda 	gpBankWalk+1
		sbc 	#0
		sta 	gpBankWalk+1
		lda 	gpBankWalk+1 				; stop below the last (lowest) entry
		cmp 	lineNumberTable+1
		bcc 	_GBFLTDone
		bne 	_GBFLTEntry
		lda 	gpBankWalk
		cmp 	lineNumberTable
		bcc 	_GBFLTDone
_GBFLTEntry:
		lda 	gpBankWalk
		sta 	zTemp0
		lda 	gpBankWalk+1
		sta 	zTemp0+1
		.storage_access
		ldy 	#2 							; the address is at +2,+3
		lda 	(zTemp0),y
		sta 	zTemp1
		iny
		lda 	(zTemp0),y
		sta 	zTemp1+1
		.storage_release
		jsr 	GPBankAdjust
		.storage_access
		ldy 	#2
		lda 	zTemp1
		sta 	(zTemp0),y
		iny
		lda 	zTemp1+1
		sta 	(zTemp0),y
		.storage_release
		bra 	_GBFLTLoop
_GBFLTDone:
		rts

; ************************************************************************************************
;
;		.fngosub is the one p-code operand that is an absolute buffer address at this point --
;		FixBranches turns it into an offset a moment later, but it is not one yet, so a body or
;		a call that moved has to be corrected first.
;
;		The walk is MoveObjectForward's, which steps by real instruction size, so an operand
;		byte that happens to equal PCD_CMD_FNGOSUB is never read as one. It runs BEFORE the hop
;		is opened, so it stops at the low code's $FF -- and then does the region as a second
;		range, because a DEF FN inside one is perfectly legal.
;
;		objPtr is put back afterwards: it is the end of the object, and WriteObjectCode streams
;		up to it.
;
; ************************************************************************************************

_GBFixFnCalls:
		lda 	objPtr
		sta 	gpBankSave
		lda 	objPtr+1
		sta 	gpBankSave+1
		lda 	#BLC_RESETOUT 				; the compiler library cannot name FreeMemory -- the
		jsr 	CallAPIHandler 				; same reason FixBranches rewinds this way
		jsr 	_GBFFCRange 				; the low code
		lda 	gpBankNewBase 				; ...then the region
		sta 	objPtr
		lda 	gpBankNewBase+1
		sta 	objPtr+1
		jsr 	_GBFFCRange
		lda 	gpBankSave
		sta 	objPtr
		lda 	gpBankSave+1
		sta 	objPtr+1
		rts

_GBFFCRange:
		lda 	(objPtr)
		cmp 	#PCD_CMD_FNGOSUB
		bne 	_GBFFCNext
		ldy 	#1
		lda 	(objPtr),y
		sta 	zTemp1
		iny
		lda 	(objPtr),y
		sta 	zTemp1+1
		jsr 	GPBankAdjust
		ldy 	#1
		lda 	zTemp1
		sta 	(objPtr),y
		iny
		lda 	zTemp1+1
		sta 	(objPtr),y
_GBFFCNext:
		jsr 	MoveObjectForward
		bcc 	_GBFFCRange
		rts

; ************************************************************************************************
;
;		GP.ASM's blob calls are the other absolute address, and they are not in the object at
;		all -- a blob call's fixup records WHERE IN THE BUFFER its .word operand sits, so that
;		AsmPatchAll can fill it in once the run base is known. That target is a buffer address
;		like any other and moves with the byte it names. The other two fixup kinds hold pool and
;		workspace offsets, which this does not touch.
;
; ************************************************************************************************

_GBFixAsmCalls:
		lda 	AsmFixupCount
		beq 	_GBFACDone
		stz 	gpBankIdx
_GBFACLoop:
		lda 	gpBankIdx
		asl 	a
		tax 								; the two byte arrays index by count*2
		ldy 	gpBankIdx 					; ...and the kind array by count
		.asm_access
		lda 	AsmFixKind,y
		sta 	gpBankKind
		lda 	AsmFixTarget,x
		sta 	zTemp1
		lda 	AsmFixTarget+1,x
		sta 	zTemp1+1
		.asm_release
		lda 	gpBankKind
		cmp 	#AFIX_CALL 					; only a blob call's target is a buffer address
		bne 	_GBFACNext
		jsr 	GPBankAdjust 				; corrupts X, so rebuild the subscript after it
		lda 	gpBankIdx
		asl 	a
		tax
		.asm_access
		lda 	zTemp1
		sta 	AsmFixTarget,x
		lda 	zTemp1+1
		sta 	AsmFixTarget+1,x
		.asm_release
_GBFACNext:
		inc 	gpBankIdx
		lda 	gpBankIdx
		cmp 	AsmFixupCount
		bcc 	_GBFACLoop
_GBFACDone:
		rts

; ************************************************************************************************
;
;		EVERY GLOBAL BELOW THIS LINE, AND NOWHERE ELSE.
;
;		64tass scopes a "_" label to the enclosing GLOBAL, so a global dropped in among another
;		routine's locals starts a new scope and every branch to a local defined after it stops
;		resolving -- "not defined symbol '_GBShiftUp'", and so on down the file. GPBankRelocate's
;		helpers run from _GBWriteGoto to _GBFixAsmCalls; put a new global in the middle of them
;		and the build breaks in six places that have nothing to do with what was added. Twice, so
;		far.
;
; ************************************************************************************************

; ************************************************************************************************
;
;		zTemp1 holds an address recorded before the move. Replace it with where that byte is
;		now. Three cases and two deltas: below the region nothing moved, inside it everything
;		moved to the new base, and after it everything moved by the bridge minus the region.
;
;		Corrupts X.
;
; ************************************************************************************************

GPBankAdjust:
		lda 	zTemp1+1 					; below the region ? then it did not move
		cmp 	gpBankStart+1
		bcc 	_GBADone
		bne 	_GBANotBelow
		lda 	zTemp1
		cmp 	gpBankStart
		bcc 	_GBADone
_GBANotBelow:
		ldx 	#0 							; inside the region
		lda 	zTemp1+1
		cmp 	gpBankEnd+1
		bcc 	_GBAAdd
		bne 	_GBAAfter
		lda 	zTemp1
		cmp 	gpBankEnd
		bcc 	_GBAAdd
_GBAAfter:
		ldx 	#2 							; ...or after it
_GBAAdd:
		clc
		lda 	zTemp1
		adc 	gpBankDelta,x
		sta 	zTemp1
		lda 	zTemp1+1
		adc 	gpBankDelta+1,x
		sta 	zTemp1+1
_GBADone:
		rts

; ************************************************************************************************
;
;		The walk over the object runs out of low memory at the $FF that ends it, and the region
;		is on the far side of the GP.ASM pool. Called by everything that walks the whole object
;		-- FixBranches' main loop and its unwind-depth walk, and ScanGPUsage -- when
;		MoveObjectForward has just said "end".
;
;		Carry CLEAR means it hopped and there is more to walk; carry SET means that really was
;		the end. A program with no GP.BANKED always gets carry set, so nothing changes for it.
;
; ************************************************************************************************

GPBankHop:
		lda 	gpBankActive
		beq 	_GBHEnd
		lda 	objPtr
		cmp 	gpBankHopFrom
		bne 	_GBHEnd
		lda 	objPtr+1
		cmp 	gpBankHopFrom+1
		bne 	_GBHEnd
		lda 	gpBankHopTo
		sta 	objPtr
		lda 	gpBankHopTo+1
		sta 	objPtr+1
		clc
		rts
_GBHEnd:
		sec
		rts


; ************************************************************************************************
;
;		STRMakeOffset, plus the correction a branch needs when exactly one of its ends is in the
;		banked region. YA is the target on the way in and the finished offset on the way out, so
;		it drops straight into FixBranches' two patch tails in place of STRMakeOffset.
;
;		Both ends the same side and nothing changes -- which is every branch in a program with no
;		GP.BANKED in it, and almost every branch in one that has.
;
; ************************************************************************************************

GPBankMakeOffset:
		sta 	gpBankTarget
		sty 	gpBankTarget+1
		jsr 	STRMakeOffset 				; YA = the offset, objPtr = the branch it sits at
		sta 	gpBankOffset
		sty 	gpBankOffset+1
		lda 	gpBankActive
		beq 	_GBMOOut
		lda 	objPtr 						; which side is the branch on ?
		ldy 	objPtr+1
		jsr 	_GBMOSide
		sta 	gpBankSideFrom
		lda 	gpBankTarget 				; ...and the target ?
		ldy 	gpBankTarget+1
		jsr 	_GBMOSide
		cmp 	gpBankSideFrom
		beq 	_GBMOOut 					; the same side: the deltas cancel as they always did
		cmp 	#1
		beq 	_GBMOInto
		sec 								; out of the bank, into low memory
		lda 	gpBankOffset+1
		sbc 	gpBankCrossHigh
		sta 	gpBankOffset+1
		bra 	_GBMOOut
_GBMOInto:
		clc 								; out of low memory, into the bank
		lda 	gpBankOffset+1
		adc 	gpBankCrossHigh
		sta 	gpBankOffset+1
_GBMOOut:
		lda 	gpBankOffset
		ldy 	gpBankOffset+1
		rts

;
;		YA is an address in the object buffer; A comes back 1 if it is in the region and 0 if it
;		is not. The region is the last thing in the buffer, so one comparison settles it.
;
_GBMOSide:
		cpy 	gpBankStart+1
		bcc 	_GBMOLow
		bne 	_GBMOHigh
		cmp 	gpBankStart
		bcc 	_GBMOLow
_GBMOHigh:
		lda 	#1
		rts
_GBMOLow:
		lda 	#0
		rts


; ************************************************************************************************
;
;		BANK <n> INSIDE A GP.BANKED REGION IS REFUSED, and this is the whole of that check.
;
;		Banked p-code is FETCHED from $A000, so the bank it lives in has to be selected at every
;		fetch. BANK writes the hardware register and leaves it there (x16_peekpoke.asm), so a
;		BANK compiled into the region kills the very next instruction -- not at the BANK, at
;		whatever followed it, which is the worst possible place to be told.
;
;		PEEK and POKE are NOT affected and need no check: they save the selected bank, switch,
;		access, and put it straight back, so they work from banked code unchanged. BANK is the
;		one statement that leaves the register somewhere else.
;
;		NOT IMPLEMENTED rather than a new error text. Every error string is shared with the
;		RUNTIME image, so a message for this would be about twenty bytes off every compiled
;		program's workspace to name a compile-time mistake. The line number points at the BANK.
;
;		The consequence for the library is worth stating: A MODULE THAT DRIVES BANKS STAYS IN
;		LOW MEMORY. STASH is the one that does, and it is 376 bytes.
;
; ************************************************************************************************

CommandBankGuard:
		lda 	gpBankState 				; 1 = a region is open, so this BANK is inside it
		cmp 	#1
		beq 	_CBGInside
		clc 								; a .def helper returning carry set makes the generator
		rts 								; drop every table element after it, silently
_CBGInside:
		.error_unimplemented


		.send 	code

		.section storage
gpBankState:									; 0 none, 1 open, 2 closed. Reset in compiler.asm
		.fill 	1
gpBankActive:									; 1 once the region has been relocated -- opens the hop
		.fill 	1
gpBankNumber:									; the bank GP.BANKED named
		.fill 	1
gpBankStart:									; where the region starts in the object buffer -- and
		.fill 	2 								; where it ended up, once GPBankRelocate has run
gpBankEnd:										; and one past where it ends
		.fill 	2
gpBankLineIn:									; the GP.BANKED line, which the entry bridge targets
		.fill 	2
gpBankLineOut:									; the GP.ENDBANKED line, for the exit bridge
		.fill 	2
gpBankLength:									; the region's size in bytes
		.fill 	2
gpBankTailLen:									; and the size of everything that followed it
		.fill 	2
gpBankTailEnd:									; one past the whole object, before the move
		.fill 	2
gpBankNewBase:									; where the region is moved to, page aligned
		.fill 	2
gpBankPad:										; bytes of padding that alignment needed
		.fill 	1
gpBankDelta:									; two 16 bit deltas: inside the region, then after it
		.fill 	4
gpBankHopFrom:									; the walkers leave low memory here...
		.fill 	2
gpBankHopTo:									; ...and carry on there
		.fill 	2
gpBankLow:										; the three boundaries of the rotation
		.fill 	2
gpBankMid:
		.fill 	2
gpBankHigh:
		.fill 	2
gpBankMoveLow:									; the bottom of the range _GBShiftUp is moving
		.fill 	2
gpBankRevEnd:									; one past the last byte of the range being reversed
		.fill 	2
gpBankWalk:										; cursor into the line number table
		.fill 	2
gpBankSave:										; objPtr, held across the .fngosub walk
		.fill 	2
gpBankIdx:										; cursor into the GP.ASM fixup list
		.fill 	1
gpBankKind:										; the kind byte of the fixup in hand
		.fill 	1
gpBankShared:									; 1 in SHARED mode. Set by CompileCode before the
		.fill 	1 								; compile, because FixBranches needs it
gpBankRunPage:									; buffer page -> run page, which shared mode knows
		.fill 	1 								; up front and embedded mode does not
gpBankRunBase:									; the page the region would have run at in low memory
		.fill 	1
gpBankCrossHigh:								; what a branch crossing the boundary is out by,
		.fill 	1 								; in pages -- see GPBankMakeOffset
gpBankPages:									; pages for the bootstrap to move into the bank
		.fill 	1
gpBankTarget:									; a branch target, held across STRMakeOffset
		.fill 	2
gpBankOffset:									; ...and the offset it turned into
		.fill 	2
gpBankSideFrom:									; 1 if the branch itself is in the region
		.fill 	1
gpBankTemp:										; scratch
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
;		05/09/26		Written. Records the region only.
;		05/09/26		GPBankRelocate: the region moves to the end of the object, spliced back in
;						with two GOTOs, and every recorded address is corrected.
;		05/09/26		GP.BANKED takes the bank number. The region now moves PAST the GP.ASM pool
;						and onto a page boundary, and the object walkers hop over the pool.
;
; ************************************************************************************************
