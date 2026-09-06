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
;		SEVERAL REGIONS A PROGRAM, each in its own bank, up to GPBANK_MAXREGIONS. What they may
;		NOT do is call each other: two regions live at the same $A000 in different banks, so a
;		branch from one to the other has no distance to travel and GPBankMakeOffset refuses it.
;		Everything reaches everything else the way it already does -- out to a low-memory shim
;		and back in.
;
;		EIGHT IS THE LIMIT and it comes from the bootstrap extension page, whose own table is
;		that long. A ninth GP.BANKED is refused rather than overrunning it.
;
; ************************************************************************************************

GPBANK_MAXREGIONS = 8 						; and eight is what the extension page's table holds

; ************************************************************************************************
;
;		PASS TWO NEITHER RECORDS NOR RE-VALIDATES. It is handed pass one's finished region table
;		before it starts -- it is being steered by it, main/compiler.asm moves the write cursor
;		from it -- so recording would overwrite the very thing in use. Re-validating would be
;		worse than useless: the count is already final, so a program with the full eight regions
;		would fail the max-regions test, and this region's own bank is already in the list, which
;		reads as a duplicate. Pass one checked both, on the same source, and refused there.
;
;		What pass two must still do is read the operand -- it is in the source either way -- and
;		keep gpBankState, which is what pairs GP.BANKED with GP.ENDBANKED.
;
; ************************************************************************************************

CommandGPBankedCompile:
		stz 	deferErrors 				; a block opener must never defer -- see the header
		lda 	gpBankState 				; 0 = never seen, 1 = open, 2 = closed
		cmp 	#1
		beq 	GPBankStructure 			; a GP.BANKED inside a region that is still open
		lda 	passNumber
		beq 	_CGBCRecord
		jmp 	GPBankOpenPassTwo 			; jmp, not a branch: the recording block is in between
_CGBCRecord:
		lda 	gpBankCount
		cmp 	#GPBANK_MAXREGIONS
		bcs 	GPBankStructure 			; ...or one region more than the table holds
		jsr 	GPBankCheckAlone 			; first on its line, and outside every block
		jsr 	GPBankReadNumber 			; the bank, into gpBankNumber
		jsr 	GPBankCheckBankFree 		; ...which no other region may already own
		lda 	#1
		sta 	gpBankState
		ldx 	gpBankCount
		lda 	gpBankNumber
		sta 	gpBankBanks,x
		txa 								; the two-byte tables want the subscript doubled
		asl 	a
		tax
		lda 	zTemp0 						; THE REGION STARTS AT ITS OWN LINE MARKER, so the line
		sta 	gpBankStarts,x 				; table entry for this line moves with it -- which is
		lda 	zTemp0+1 					; what lets the bridge below be an ordinary GOTO to an
		sta 	gpBankStarts+1,x 			; ordinary line number
		lda 	currentLineNumber 			; ...and this is the line number it goes to
		sta 	gpBankLinesIn,x
		lda 	currentLineNumber+1
		sta 	gpBankLinesIn+1,x
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
		lda 	passNumber 					; pass two keeps pass one's table -- see the note on
		bne 	GPBankClosePassTwo 			; CommandGPBankedCompile above
		lda 	gpBankCount
		asl 	a
		tax
		lda 	zTemp0 						; THE REGION ENDS AT THIS LINE'S MARKER, which stays
		sta 	gpBankEnds,x 				; behind in low memory: it is the first byte of what
		lda 	zTemp0+1 					; follows the region, not the last byte of it
		sta 	gpBankEnds+1,x
		lda 	currentLineNumber
		sta 	gpBankLinesOut,x
		lda 	currentLineNumber+1
		sta 	gpBankLinesOut+1,x
		inc 	gpBankCount 				; ONLY NOW is the region a region: an unclosed one is
		clc 								; a structure error and must not reach the relocator
		rts

;
;		A GLOBAL label, not a _ local one: 64tass scopes a _ label to the enclosing global, so a
;		local defined under the first routine cannot be branched to from the second.
;
GPBankStructure:
		.error_structure

;
;		The pass-two halves of the two generators, BELOW GPBankStructure rather than inside the
;		routines they belong to. Above it they pushed it out of branch range of the checks at the
;		head of CommandGPBankedCompile, which is a long routine already. Global names for the
;		same reason the label above is one: 64tass scopes a _ label to the enclosing global.
;
;		Both do what pass two still owes -- consume the operand, keep gpBankState -- and nothing
;		else. See the note on CommandGPBankedCompile.
;

GPBankOpenPassTwo:
		jsr 	GPBankCheckAlone
		jsr 	GPBankReadNumber
		lda 	#1
		sta 	gpBankState
		clc
		rts

GPBankClosePassTwo:
		clc
		rts

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
		cmp 	#1
		beq 	_GBRUnclosed 				; a GP.BANKED that was never closed
		lda 	gpBankCount
		bne 	_GBRHaveRegion
		rts 								; no GP.BANKED in this program at all
_GBRUnclosed:
		jmp 	GPBankStructure
_GBRHaveRegion:
		;
		;		SHARED MODE ONLY. The correction below needs to know where the p-code will RUN,
		;		and in shared mode that is the constant PCODE_PAGE. Embedded, it depends on
		;		ScanGPUsage, which has not happened yet -- and there is no bootstrap there to do
		;		the copying either. Refusing is honest; guessing would miscompile silently.
		;
		lda 	gpBankShared
		bne 	_GBRPasses
		.error_unimplemented
;
;		ONE PASS A REGION, LAST REGION FIRST, AND EACH ONE LANDS BELOW THE LAST. gpBankCeiling
;		is the bottom of what earlier passes have already placed, and no pass touches a byte
;		above it: the rotation runs from the region up to the ceiling, and the placed block is
;		lifted bodily out of the way first. So the regions come to rest in SOURCE order, R0
;		lowest, each one starting on a page boundary and padded out to a whole number of pages
;		-- which is what lets the bootstrap copy the lot with one running source address.
;
;		A PASS MUST NOT DISTURB WHAT AN EARLIER PASS ALIGNED, and that is the whole reason for
;		the ceiling. Rotating each region to the top of the OBJECT instead would shift every
;		region already placed down by (3 - its length), which is not a whole number of pages, so
;		the second region to be moved would knock the first one off its page boundary and the
;		bootstrap would copy it from the wrong address. The block is lifted by a multiple of 256
;		here precisely so that cannot happen.
;
_GBRPasses:
		lda 	objPtr 						; nothing is placed yet, so the ceiling is the top
		sta 	gpBankCeiling
		lda 	objPtr+1
		sta 	gpBankCeiling+1
		lda 	gpBankCount
		sta 	gpBankPass
_GBRPass:
		dec 	gpBankPass
		jsr 	_GBRLoadRegion 				; the table -> the scalars this pass works in
		lda 	gpBankCeiling 				; Q, one past the tail -- NOT one past the object
		sta 	gpBankTailEnd
		lda 	gpBankCeiling+1
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
		;		FILLER ABOVE THE END MARKER, so the region's SPAN is a whole number of pages and
		;		the region above it starts exactly where this one's pages stop. The span is the
		;		region, its exit bridge and the marker: L + 4. Nothing walks past the marker, so
		;		the filler is only ever copied into the bank and never read.
		;
		;		NONE OF IT FOR THE TOPMOST REGION, which is the one the FIRST pass places and the
		;		only one a program with a single region has. Nothing sits above it to be pushed
		;		off a page boundary, so writing up to 255 bytes to reach one would grow every
		;		banked object for no reason. Its last page is short and the bootstrap copies a
		;		few bytes of whatever follows into the bank behind it, which is what it has
		;		always done and what nothing ever reads.
		;
		stz 	gpBankFill
		lda 	gpBankPass
		inc 	a
		cmp 	gpBankCount
		bcs 	_GBRNoFill
		clc
		lda 	gpBankLength
		adc 	#4
		sta 	gpBankTemp
		sec
		lda 	#0
		sbc 	gpBankTemp
		sta 	gpBankFill
_GBRNoFill:
		;
		;		Room for the whole insertion: entry bridge, alignment padding, exit bridge, end
		;		marker and that filler. IT CAN PASS 256 -- padding and filler are a byte each and
		;		both can be 255 -- so the count is sixteen bits and not the X register.
		;
		;		Taken through WriteCodeByte rather than by moving objPtr, because that is the only
		;		place the object ceiling is tested. A program that no longer fits has to say
		;		PROGRAM TOO BIG here, not run off the top of the buffer.
		;
		lda 	objPtr
		sta 	gpBankOldTop
		lda 	objPtr+1
		sta 	gpBankOldTop+1
		clc
		lda 	gpBankPad
		adc 	#7
		sta 	gpBankRoom
		lda 	#0
		adc 	#0
		sta 	gpBankRoom+1
		clc
		lda 	gpBankRoom
		adc 	gpBankFill
		sta 	gpBankRoom
		lda 	gpBankRoom+1
		adc 	#0
		sta 	gpBankRoom+1
_GBRoom:
		lda 	gpBankRoom
		ora 	gpBankRoom+1
		beq 	_GBRoomDone
		lda 	#0
		jsr 	WriteCodeByte
		lda 	gpBankRoom
		bne 	_GBRoomNoBorrow
		dec 	gpBankRoom+1
_GBRoomNoBorrow:
		dec 	gpBankRoom
		bra 	_GBRoom
_GBRoomDone:
		;
		;		The three deltas every recorded address is corrected by. The tail moves from
		;		gpBankEnd down to start+3; the region moves to gpBankNewBase; and the block of
		;		regions an earlier pass placed moves UP, by the whole insertion.
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

		sec 								; objPtr has already grown by the insertion
		lda 	objPtr
		sbc 	gpBankOldTop
		sta 	gpBankDelta+4
		lda 	objPtr+1
		sbc 	gpBankOldTop+1
		sta 	gpBankDelta+5
		;
		;		Lift the placed block out of the way, by exactly that. It is a whole number of
		;		pages -- the region's base is aligned and its span is whole pages, so what is
		;		inserted below the block has to be too -- which is what keeps every region an
		;		earlier pass aligned still aligned.
		;
		;		A no-op on the first pass, where the block is empty and the two ends meet.
		;
		lda 	gpBankCeiling
		sta 	gpBankMoveLow
		lda 	gpBankCeiling+1
		sta 	gpBankMoveLow+1
		lda 	gpBankOldTop
		sta 	zTemp0
		lda 	gpBankOldTop+1
		sta 	zTemp0+1
		lda 	objPtr
		sta 	zTemp1
		lda 	objPtr+1
		sta 	zTemp1+1
		jsr 	_GBShiftUp
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
_GBRFixUp:
		;
		;		Everything that recorded a position in the buffer now has to be told.
		;
		jsr 	_GBFixLineTable
		jsr 	_GBFixRegions 				; BEFORE the .fngosub walk, which reads the new bases
		jsr 	_GBFixFnCalls
		jsr 	_GBFixAsmCalls
		jsr 	_GBFixPoolBase
		;
		;		WHERE THE WALK LEAVES OFF TO REACH THE REGION ABOVE THIS ONE. The walkers run to
		;		this region's own end marker and stop; one past it is where they must be sent on,
		;		and what they must be sent to is the next region's base -- which is exactly the
		;		page boundary the filler above reaches. The topmost region has nothing above it
		;		and so opens no hop.
		;
		;		RECORDED AFTER THE FIX-UPS, not before them. _GBFixRegions corrects every table
		;		entry an EARLIER pass wrote, and hops[pass+1] is one of them -- so writing this
		;		pass's own hop first would have it corrected a second time. The region it names
		;		is placed by a LATER pass, and its own base is written by that pass.
		;
		lda 	gpBankPass
		inc 	a
		cmp 	gpBankCount
		bcs 	_GBROnlyHop
		asl 	a
		tax
		clc
		lda 	gpBankHigh 					; the exit bridge is 3 and the marker 1
		adc 	#4
		sta 	gpBankHops,x
		lda 	gpBankHigh+1
		adc 	#0
		sta 	gpBankHops+1,x
_GBROnlyHop:
		;
		;		Leave the region's new bounds behind.
		;
		lda 	gpBankNewBase
		sta 	gpBankStart
		lda 	gpBankNewBase+1
		sta 	gpBankStart+1
		clc 								; one past the exit bridge
		lda 	gpBankHigh
		adc 	#3
		sta 	gpBankEnd
		lda 	gpBankHigh+1
		adc 	#0
		sta 	gpBankEnd+1
		;
		;		And how much the bootstrap has to move: the region, its exit bridge and the end
		;		marker, rounded up to whole pages. Any filler is inside that rounding rather than
		;		added to it -- it exists precisely to fill the part page this counts.
		;
		;		NOT objPtr MINUS THE BASE any more. That worked while the region was the last
		;		thing in the object, and with several it is only the topmost that still is.
		;
		clc
		lda 	gpBankLength
		adc 	#4
		sta 	gpBankTemp
		lda 	gpBankLength+1
		adc 	#0
		sta 	gpBankPages
		lda 	gpBankTemp 					; a part page needs one more
		beq 	_GBRWholePages
		inc 	gpBankPages
_GBRWholePages:
		;
		;		A REGION HAS TO FIT THE WINDOW. 32 pages is the whole of $A000-$BFFF, and nothing
		;		up to here has said no to a bigger one: the copy would simply run past $BFFF into
		;		the I/O page. It is checked HERE rather than at GP.ENDBANKED because this is where
		;		the padding and the two bridges are counted, and they are part of what has to fit.
		;
		lda 	gpBankPages
		cmp 	#33
		bcs 	_GBRTooBig
		jsr 	_GBRSaveRegion 				; ...and back into the table
		lda 	gpBankStart 				; the ceiling comes down onto it: the next pass may
		sta 	gpBankCeiling 				; not touch a byte from here up
		lda 	gpBankStart+1
		sta 	gpBankCeiling+1
		lda 	gpBankPass
		beq 	_GBRPlaced
		jmp 	_GBRPass
_GBRTooBig:
		.error_range
_GBRPlaced:
		;
		;		Nothing moves again, so the two things that had to wait for that can be settled:
		;		what a branch crossing into each region is out by, and where the whole run of
		;		them starts once the program is loaded.
		;
		;		THE CROSS-BOUNDARY CORRECTION. A branch offset is target minus source computed in
		;		BUFFER addresses, which works because every byte has the same buffer-to-run delta
		;		and the two cancel in the subtraction. A region's delta is different -- buffer to
		;		$A000, not buffer to the p-code base -- so a branch with one end each side comes
		;		out wrong by exactly the difference, and only such a branch does.
		;
		;		It is a whole number of PAGES: both bases are page aligned and so is every region.
		;		So the correction is one byte, added to or taken off the offset's high half.
		;
		ldx 	#0
_GBRCross:
		txa
		asl 	a
		tay
		clc
		lda 	gpBankStarts+1,y 			; the page this region WOULD have run at in low memory
		adc 	gpBankRunPage
		inc 	a 							; ...plus one, for the BOOTSTRAP EXTENSION PAGE. Only a
											; banked program carries it, and this routine only runs
											; for a banked program, so the +1 is unconditional:
											; low p-code starts at $0A00 here, not $0900.
		sta 	gpBankTemp
		sec
		lda 	#$A0 						; ...against the page it is actually going to -- and
		sbc 	gpBankTemp 					; every region goes to $A000, in its own bank
		sta 	gpBankCrossings,x
		inx
		cpx 	gpBankCount
		bcc 	_GBRCross
		;
		;		...and where the whole run of them sits once the program is loaded. That is the
		;		LOWEST region, which is region 0: the passes go downwards and each one lands
		;		below the last, so the regions end up in source order with R0 at the bottom. One
		;		address is enough because they are contiguous in whole pages.
		;
		clc
		lda 	gpBankStarts+1
		adc 	gpBankRunPage
		inc 	a
		sta 	gpBankRunBase
		jsr 	_GBRFindLowEnd
		lda 	#1
		sta 	gpBankActive
		rts

; ************************************************************************************************
;
;		Where the walk leaves LOW MEMORY, which is hops[0]: the first region is reached from
;		there and every other one from the region below it.
;
;		FOUND BY WALKING, not by arithmetic. It used to be "one past the tail", and with a single
;		region that was the same thing -- the tail ended at the low code's own end marker. With
;		several it is not: each pass leaves its alignment padding behind in what the NEXT pass
;		treats as tail, so one past the tail is one past a stretch of padding the walkers stop
;		short of. They stop at the marker, so this stops where they do.
;
;		gpBankActive is still 0 here, so the walk cannot hop -- which is the point. objPtr is the
;		end of the object and WriteObjectCode streams up to it, so it is put back.
;
;		THE PADDING BELOW THE FIRST REGION IS DEAD SPACE, up to 255 bytes for every region after
;		the first. It sits below the region and so counts as low p-code. Worth reclaiming if a
;		program ever gets close enough to the ceiling to care.
;
; ************************************************************************************************

_GBRFindLowEnd:
		lda 	objPtr
		sta 	gpBankSave
		lda 	objPtr+1
		sta 	gpBankSave+1
		lda 	#BLC_RESETOUT 				; the compiler library cannot name FreeMemory -- the
		jsr 	CallAPIHandler 				; same reason FixBranches rewinds this way
_GBRFLELoop:
		jsr 	MoveObjectForward
		bcc 	_GBRFLELoop
		lda 	objPtr
		sta 	gpBankHops
		lda 	objPtr+1
		sta 	gpBankHops+1
		lda 	gpBankSave
		sta 	objPtr
		lda 	gpBankSave+1
		sta 	objPtr+1
		rts

;
;		The pass's region, out of the table and back into it. X indexes the byte tables and the
;		two-byte ones want it doubled, so the subscript is built once rather than at every field.
;
;		LOAD IS BEFORE THE ROTATION and SAVE IS AFTER, and in between gpBankStart and gpBankEnd
;		mean what they meant when they went in -- where the region was. GPBankAdjust reads them
;		that whole time to decide which side of the move an address was on, which is why the
;		post-move values go back through here at the end and not the moment they are known.
;
_GBRLoadRegion:
		ldx 	gpBankPass
		lda 	gpBankBanks,x
		sta 	gpBankNumber
		txa
		asl 	a
		tax
		lda 	gpBankStarts,x
		sta 	gpBankStart
		lda 	gpBankStarts+1,x
		sta 	gpBankStart+1
		lda 	gpBankEnds,x
		sta 	gpBankEnd
		lda 	gpBankEnds+1,x
		sta 	gpBankEnd+1
		lda 	gpBankLinesIn,x
		sta 	gpBankLineIn
		lda 	gpBankLinesIn+1,x
		sta 	gpBankLineIn+1
		lda 	gpBankLinesOut,x
		sta 	gpBankLineOut
		lda 	gpBankLinesOut+1,x
		sta 	gpBankLineOut+1
		rts

_GBRSaveRegion:
		ldx 	gpBankPass
		lda 	gpBankPages
		sta 	gpBankPageCounts,x
		txa
		asl 	a
		tax
		lda 	gpBankStart
		sta 	gpBankStarts,x
		lda 	gpBankStart+1
		sta 	gpBankStarts+1,x
		lda 	gpBankEnd
		sta 	gpBankEnds,x
		lda 	gpBankEnd+1
		sta 	gpBankEnds+1,x
		rts

; ************************************************************************************************
;
;		The regions an EARLIER pass already placed. Each of them sits above the region this pass
;		took, so this pass's rotation moved every one of them, and their recorded base, end and
;		hop are ordinary buffer addresses that move like any other -- GPBankAdjust knows what by.
;
;		A program with one region never enters the loop.
;
; ************************************************************************************************

_GBFixRegions:
		lda 	gpBankPass
		sta 	gpBankTemp
_GBFRNext:
		inc 	gpBankTemp
		lda 	gpBankTemp
		cmp 	gpBankCount
		bcs 	_GBFRDone
		asl 	a
		sta 	gpBankTemp2 				; the doubled subscript, for all three tables
		.set16 	zTemp0, gpBankStarts
		jsr 	_GBFRField
		.set16 	zTemp0, gpBankEnds
		jsr 	_GBFRField
		.set16 	zTemp0, gpBankHops
		jsr 	_GBFRField
		bra 	_GBFRNext
_GBFRDone:
		rts

;
;		One two-byte table entry, through GPBankAdjust: the table's base in zTemp0 and the
;		doubled subscript in gpBankTemp2. Written once and called three times rather than
;		spelled out three times, which is 50 bytes of a compiler that is measured against the
;		object buffer it shares a page boundary with -- see [[compiler-must-not-cap-program-size]].
;
;		GPBankAdjust reads and writes zTemp1 and corrupts X, and touches nothing else.
;
_GBFRField:
		ldy 	gpBankTemp2
		lda 	(zTemp0),y
		sta 	zTemp1
		iny
		lda 	(zTemp0),y
		sta 	zTemp1+1
		jsr 	GPBankAdjust
		ldy 	gpBankTemp2
		lda 	zTemp1
		sta 	(zTemp0),y
		iny
		lda 	zTemp1+1
		sta 	(zTemp0),y
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
		lda 	gpBankNewBase 				; ...then the region this pass just moved
		sta 	objPtr
		lda 	gpBankNewBase+1
		sta 	objPtr+1
		jsr 	_GBFFCRange
		;
		;		...and then every region an earlier pass placed. They moved too, _GBFixRegions
		;		has just said where to, and a DEF FN inside one is as legal as anywhere else.
		;
		lda 	gpBankPass
		sta 	gpBankTemp
_GBFFCRegion:
		inc 	gpBankTemp
		lda 	gpBankTemp
		cmp 	gpBankCount
		bcs 	_GBFFCEnd
		asl 	a
		tax
		lda 	gpBankStarts,x
		sta 	objPtr
		lda 	gpBankStarts+1,x
		sta 	objPtr+1
		jsr 	_GBFFCRange
		bra 	_GBFFCRegion
_GBFFCEnd:
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
;		TWO REGIONS IN ONE BANK would put the second at $A000 on top of the first, and the only
;		symptom would be the first one's code running as whatever the second one's is. The bank
;		is a constant read at compile time, so this costs one walk of a table that is at most
;		eight long, once per GP.BANKED.
;
;		BAD VALUE, reported at the GP.BANKED whose operand is the repeat -- which is the second
;		of the two, and the one the user can move.
;
; ************************************************************************************************

GPBankCheckBankFree:
		ldx 	#0
_GBCBFNext:
		cpx 	gpBankCount
		bcs 	_GBCBFOkay
		lda 	gpBankBanks,x
		cmp 	gpBankNumber
		beq 	_GBCBFTaken
		inx
		bra 	_GBCBFNext
_GBCBFOkay:
		rts
_GBCBFTaken:
		.error_value

; ************************************************************************************************
;
;		zTemp1 holds an address recorded before the move. Replace it with where that byte is
;		now. Four cases and three deltas: below the region nothing moved, inside it everything
;		moved to the new base, after it everything moved down by the region minus the bridge,
;		and above the ceiling -- the regions an earlier pass already placed -- everything moved
;		UP by the whole insertion.
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
		ldx 	#2 							; ...or after it, in the tail
		lda 	zTemp1+1
		cmp 	gpBankCeiling+1
		bcc 	_GBAAdd
		bne 	_GBAPlaced
		lda 	zTemp1
		cmp 	gpBankCeiling
		bcc 	_GBAAdd
_GBAPlaced:
		ldx 	#4 							; ...or up in a region an earlier pass placed, which
											; this pass lifted bodily rather than rotating
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
		ldx 	#0
_GBHNext:
		cpx 	gpBankCount
		bcs 	_GBHEnd
		txa
		asl 	a
		tay
		lda 	objPtr
		cmp 	gpBankHops,y
		bne 	_GBHSkip
		lda 	objPtr+1
		cmp 	gpBankHops+1,y
		bne 	_GBHSkip
		lda 	gpBankStarts,y 				; the hop lands on the region itself
		sta 	objPtr
		lda 	gpBankStarts+1,y
		sta 	objPtr+1
		clc
		rts
_GBHSkip:
		inx
		bra 	_GBHNext
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
		sta 	gpBankSideTo
		cmp 	gpBankSideFrom
		beq 	_GBMOOut 					; the same side: the deltas cancel as they always did
		;
		;		ONE END IN A REGION AND THE OTHER IN LOW MEMORY is what the correction is for.
		;		ONE END IN EACH OF TWO REGIONS cannot be corrected at all: both regions run at
		;		$A000, in different banks, so the branch has no distance to travel and no offset
		;		describes it. Refused here rather than miscompiled -- and it is the same rule the
		;		library already works to, where everything reaches everything else by going out
		;		to a low-memory shim and back in.
		;
		lda 	gpBankSideFrom
		beq 	_GBMOInto 					; 0 = low memory, so this one goes INTO a region
		ldx 	gpBankSideTo
		bne 	_GBMOCross 					; both ends in regions, and not the same one
		ldx 	gpBankSideFrom 				; out of a region, into low memory
		dex
		sec
		lda 	gpBankOffset+1
		sbc 	gpBankCrossings,x
		sta 	gpBankOffset+1
		bra 	_GBMOOut
_GBMOInto:
		ldx 	gpBankSideTo 				; out of low memory, into a region
		dex
		clc
		lda 	gpBankOffset+1
		adc 	gpBankCrossings,x
		sta 	gpBankOffset+1
_GBMOOut:
		lda 	gpBankOffset
		ldy 	gpBankOffset+1
		rts

_GBMOCross:
		.error_unimplemented

;
;		YA is an address in the object buffer. A comes back 0 if it is in low memory, or the
;		region's number PLUS ONE if it is inside one -- so that "same side" is still a single
;		compare, and which region it was is still in hand for the correction.
;
;		The regions are the last things in the buffer, in source order with a few bytes of page
;		filler between them. Nothing branches at filler, so an address in none of them is in
;		low memory.
;
_GBMOSide:
		sta 	gpBankTemp
		sty 	gpBankTemp2
		ldx 	#0
_GBMOSNext:
		cpx 	gpBankCount
		bcs 	_GBMOLow
		txa
		asl 	a
		tay
		lda 	gpBankTemp2 				; below this region ? then it is not this one
		cmp 	gpBankStarts+1,y
		bcc 	_GBMOSSkip
		bne 	_GBMOSNotBelow
		lda 	gpBankTemp
		cmp 	gpBankStarts,y
		bcc 	_GBMOSSkip
_GBMOSNotBelow:
		lda 	gpBankTemp2 				; ...and before its end ?
		cmp 	gpBankEnds+1,y
		bcc 	_GBMOHigh
		bne 	_GBMOSSkip
		lda 	gpBankTemp
		cmp 	gpBankEnds,y
		bcc 	_GBMOHigh
_GBMOSSkip:
		inx
		bra 	_GBMOSNext
_GBMOHigh:
		txa
		inc 	a
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
gpBankDelta:									; three 16 bit deltas, and GPBankAdjust indexes them:
		.fill 	6 								; inside the region, after it, and the placed block
gpBankCeiling:									; where the regions an earlier pass placed begin --
		.fill 	2 								; the top of what this pass is allowed to move
gpBankFill:										; bytes of filler above the region's end marker, to
		.fill 	1 								; make its span a whole number of pages
gpBankRoom:										; the whole insertion, which can pass 256
		.fill 	2
gpBankOldTop:									; objPtr before the insertion was reserved
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
gpBankTemp2:									; ...and a second, for the table walks
		.fill 	1
gpBankSideTo:									; which region a branch points AT, 0 for low memory
		.fill 	1

;
;		THE REGION TABLE. One entry a GP.BANKED, in SOURCE order. Everything above is either
;		global to the compile or the WORKING COPY of whichever region GPBankRelocate has in
;		hand: the rotation happens once per region and each pass wants the same values the
;		single-region version always wanted, so the pass loads them out of here and puts the
;		results back.
;
;		EIGHT, because eight is what the bootstrap extension page's own table holds. A ninth
;		GP.BANKED is refused rather than overrunning either of them.
;
gpBankCount:									; how many regions the program has
		.fill 	1
gpBankPass:										; which one GPBankRelocate is moving
		.fill 	1
gpBankBanks:									; the bank each one named
		.fill 	GPBANK_MAXREGIONS
gpBankStarts:									; where each starts -- in the object buffer while
		.fill 	GPBANK_MAXREGIONS * 2 			; compiling, and where it ended up once its pass ran
gpBankEnds:										; ...and one past where each ends
		.fill 	GPBANK_MAXREGIONS * 2
gpBankLinesIn:									; the GP.BANKED line, for the entry bridge
		.fill 	GPBANK_MAXREGIONS * 2
gpBankLinesOut:									; the GP.ENDBANKED line, for the exit bridge
		.fill 	GPBANK_MAXREGIONS * 2
gpBankPageCounts:								; pages of each, for the bootstrap's table
		.fill 	GPBANK_MAXREGIONS
gpBankCrossings:								; what a branch crossing INTO each one is out by
		.fill 	GPBANK_MAXREGIONS
gpBankHops:										; where the walk leaves off to reach each one
		.fill 	GPBANK_MAXREGIONS * 2
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
