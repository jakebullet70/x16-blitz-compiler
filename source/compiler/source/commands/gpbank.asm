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
;		NO "T" ON EITHER, in commands.def. They write no keyword token, so the GP usage scan
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
;		SEVERAL REGIONS A PROGRAM, each in its own bank, up to GPBANK_MAXREGIONS. A GOSUB or an
;		FN call into a region from outside it is written as a .bgosub, which selects the region's
;		bank on the way in, and RETURN puts the caller's bank back -- see GPBankLineCall. That
;		holds from low memory and from another region alike. A GOTO has no bank to select, so a
;		GOTO from one region into another is still refused, in GPBankMakeOffset.
;
;		BANKS 2 TO 255, every bank a 2MB X16 has less bank 0, the KERNAL's, and bank 1,
;		HANDLER_BANK. The number a program writes is the bank its region loads into, so a program
;		may count down from 255. A machine without that bank stops in the bootstrap with ?RAM.
;
;		THE TABLES ARE IN THE CODE SECTION, not the 1K storage hole at $0400-$0801, which once
;		capped the count at 23. Here and in the layout copy in main/compiler.asm they come to 19
;		bytes a region, 2,413 at the cap. The region table below has the reasoning.
;
;		127 IS THE CAP, AND THE BANKS DO NOT SET IT. Seven of the tables are two bytes a region
;		and are read with the region doubled into X or Y, and 127 is the most that fits doubled
;		in a byte. A 128th region, code or text, is refused by name. Past it each of those tables
;		would need a low half and a high half, indexed by the region itself.
;
; ************************************************************************************************

GPBANK_MAXREGIONS = 127 					; the most a doubled subscript reaches in a byte

; ************************************************************************************************
;
;		PASS TWO NEITHER RECORDS NOR RE-VALIDATES. It is handed pass one's finished region table
;		before it starts -- it is being steered by it, main/compiler.asm moves the write cursor
;		from it -- so recording would overwrite the very thing in use. Re-validating would be
;		worse than useless: the count is already final, so a program with every region it can have
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
		bcc 	_CGBCRoom
		jmp 	GPBankTooMany 				; ...or one region more than the tables hold
_CGBCRoom:
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
		jsr 	GPBankAsmClose 				; the GP.ASM this region carries in its own bank
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
;		Read GP.BANKED's operand: a decimal constant, 2 to 255.
;
;		BANK 0 IS REFUSED. It is the KERNAL's -- its FAT32 buffers live there -- so a program
;		that put its code in it would work until the first file operation and then not.
;
;		AND BANK 1, HANDLER_BANK, where the runtime keeps its rarely used handlers. GP.BANKEDSTR
;		reads its bank here too, so the check in GPBankCheckBankNumber refuses both.
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
;
;		THE BANK 1 CHECK IS A jmp TO THE BOTTOM OF THE FILE, and it is worth knowing why rather
;		than tidying it back inline. GPBankStructure sits above here and GPBankCheckAlone below,
;		and three of its branches reach BACK to it -- so anything added between the two costs
;		branch range. A test and its message inline were 40 bytes and broke all three. Two is
;		what a jmp costs over the rts it replaced.
;
_GBRNDone:
		lda 	gpBankNumber
		beq 	GPBankBadNumber 			; bank 0 belongs to the KERNAL
		jmp 	GPBankCheckBankNumber 		; ...and bank 1 is HANDLER_BANK's

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
		lda 	zTemp0 						; THE BYTE ITSELF IS NOT THERE TO READ any more, so the
		cmp 	lineMarkerAt 				; question is asked of the address instead: is
		bne 	GPBankStructure 			; objPtr-1 the marker this line began with, or has
		lda 	zTemp0+1 					; something been compiled on top of it since ?
		cmp 	lineMarkerAt+1
		bne 	GPBankStructure
		rts

; ************************************************************************************************
;
;		Lift the GP.BANKED region out of the middle of the object and put it at the end, past
;		the GP.ASM pool, on a page boundary.
;
;		Called from SaveCodeAndExit after AsmFlushPool, at the end of PASS ONE, where nothing
;		has been resolved yet -- so the only things to correct are the tables pass two will
;		resolve from.
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
;		Correct the table and pass two resolves both bridges by the path it resolves every other
;		GOTO. No new opcode, no absolute operand, no back-patching.
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
;		NOTHING IS ACTUALLY MOVED. It used to be a rotation done in place -- shift the region
;		and the whole tail up by three, reverse the region, reverse the tail, reverse the pair,
;		then lift the region again by the padding -- because the object was sitting in a buffer
;		and had to end up in the right order in it. There is no buffer now: pass one only
;		counts, and pass two writes each region into a bank of its own and sends it out after
;		the low code. What is left here is the arithmetic -- where every region lands, and what
;		that does to every address written down before it.
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
		clc 								; ...and its GP.ASM, above the end marker
		adc 	gpBankAsmLen
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
		clc 								; and the region's GP.ASM, which pass two copies in as
		lda 	gpBankRoom 					; each blob closes
		adc 	gpBankAsmLen
		sta 	gpBankRoom
		lda 	gpBankRoom+1
		adc 	gpBankAsmLen+1
		sta 	gpBankRoom+1
		lda 	gpBankRoom 					; PASS ONE'S BOOKKEEPING, not p-code: pass two writes
		ldy 	gpBankRoom+1 				; the bridges and the markers instead, and neither is
		jsr 	SumSkipYA 					; summed on either side
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
		;		WHERE THE REGION ENDS UP is all that is left of the move: one past it is where the
		;		exit bridge goes, and the region above starts a whole number of pages further on,
		;		which is what keeps every region an earlier pass aligned still aligned.
		;
		clc
		lda 	gpBankNewBase
		adc 	gpBankLength
		sta 	gpBankHigh
		lda 	gpBankNewBase+1
		adc 	gpBankLength+1
		sta 	gpBankHigh+1
		;
		;		Everything that recorded a position now has to be told where it went.
		;
		jsr 	_GBFixLineTable
		jsr 	_GBFixBlockEnds
		jsr 	_GBFixBlockAlts
		jsr 	_GBFixRegions
		jsr 	_GBFixPoolBase
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
		clc 								; the region's GP.ASM is in its pages too
		lda 	gpBankTemp
		adc 	gpBankAsmLen
		sta 	gpBankTemp
		lda 	gpBankPages
		adc 	gpBankAsmLen+1
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
		;
		;		NAME THE REGION. This runs at the END of pass one, so currentLineNumber is the last
		;		line of the program and the handler's " @ nnnnn" would point at a line that has
		;		nothing to do with the fault -- which identifies nothing at all in a program with ten
		;		banks. _GBRLoadRegion has already put this region's GP.BANKED line in gpBankLineIn,
		;		so the right answer is one copy away. WriteBranchTo names a missing line the same way.
		;
		;		Relocate never sees a text region -- BStrFlush runs after it -- so this is always a
		;		real line and never BStrRegister's $FFFE sentinel.
		;
		;		THE TEXT SITS HERE RATHER THAN IN THE SHARED ERROR TABLE. errors.asm is in
		;		common-source, which links BELOW GPBase and is therefore copied into every compiled
		;		program, so a message there would cost bytes to every program that never writes a
		;		GP.BANKED. Up here it costs nothing. Same trick as gpasmcode.asm's _APBUnknown.
		;
		lda 	gpBankLineIn
		sta 	currentLineNumber
		lda 	gpBankLineIn+1
		sta 	currentLineNumber+1
		jsr 	CallErrorHandler
		.text 	"GP.BANKED REGION OVER 8K", 0
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
		adc 	gpBankRunPage 				; buffer page -> run page, the WHOLE delta: CompileCode folds
											; the bootstrap extension page into it for a shared program,
											; because an embedded one has no such page and this routine
											; cannot tell the two apart
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
		sta 	gpBankRunBase
		lda 	#1
		sta 	gpBankActive
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
		lda 	gpBankAsmLens,x
		sta 	gpBankAsmLen
		lda 	gpBankAsmLens+1,x
		sta 	gpBankAsmLen+1
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
;		Every entry in the line number table holds the compile time address of the line it
;		names, and the whole point of moving the region on line boundaries is that these stay
;		usable: pass two resolves both bridges through them, and the map file is written from
;		them afterwards.
;
;		The table is walked exactly as WriteMapFile walks it -- 4 byte entries growing DOWN from
;		compilerEndHigh:$00 to lineNumberTable -- and the window is opened and closed once per
;		entry rather than held across the loop, for the reason x16_storage.inc gives.
;
;		Those addresses are VIRTUAL and the table is two banks; STRPageLine is what turns one
;		into a real address and a bank. The compare that ends the walk is a plain 16-bit
;		compare of two virtual addresses either way.
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
		lda 	gpBankWalk 					; gpBankWalk is a VIRTUAL address covering both banks
		sta 	lineWalk 					; of the table -- STRPageLine turns it into the real
		lda 	gpBankWalk+1 				; one in zTemp0 and selects the bank it is in
		sta 	lineWalk+1
		jsr 	STRPageLine
		.storage_access
		ldy 	#2 							; the address is at +2,+3
		lda 	(zTemp0),y
		sta 	zTemp1
		iny
		lda 	(zTemp0),y
		sta 	zTemp1+1
		.storage_release
		jsr 	GPBankAdjust 				; which works on zTemp1 and leaves zTemp0 alone, so
		.storage_access 					; the paged pointer and the bank both still stand
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
;		...and the same for the block-end table. Every entry is an address in the object recorded
;		before the move, so every one of them moves with it -- a GP.DO inside a region is as legal
;		as anywhere else.
;
;		Entries for blocks that are still OPEN hold nothing yet and are adjusted along with the
;		rest, which is harmless: an unclosed GP.DO is a structure error and its entry is never
;		read.
;
; ************************************************************************************************

_GBFixBlockEnds:
		stz 	blockWalk
		stz 	blockWalk+1
_GBFBELoop:
		lda 	blockWalk+1 				; done them all ?
		cmp 	blockCount+1
		bcc 	_GBFBEEntry
		bne 	_GBFBEDone
		lda 	blockWalk
		cmp 	blockCount
		bcs 	_GBFBEDone
_GBFBEEntry:
		lda 	blockWalk
		sta 	blockIndex
		lda 	blockWalk+1
		sta 	blockIndex+1
		jsr 	BlockEndRead
		lda 	blockValue
		sta 	zTemp1
		lda 	blockValue+1
		sta 	zTemp1+1
		jsr 	GPBankAdjust
		lda 	zTemp1
		sta 	blockValue
		lda 	zTemp1+1
		sta 	blockValue+1
		jsr 	BlockEndWrite
		inc 	blockWalk
		bne 	_GBFBELoop
		inc 	blockWalk+1
		bra 	_GBFBELoop
_GBFBEDone:
		rts

;
;		...and the alternative table, which holds the same kind of address and moves the same way.
;

_GBFixBlockAlts:
		stz 	blockWalk
		stz 	blockWalk+1
_GBFBALoop:
		lda 	blockWalk+1
		cmp 	altCount+1
		bcc 	_GBFBAEntry
		bne 	_GBFBADone
		lda 	blockWalk
		cmp 	altCount
		bcs 	_GBFBADone
_GBFBAEntry:
		lda 	blockWalk
		sta 	blockIndex
		lda 	blockWalk+1
		sta 	blockIndex+1
		jsr 	BlockAltFetch
		lda 	blockValue
		sta 	zTemp1
		lda 	blockValue+1
		sta 	zTemp1+1
		jsr 	GPBankAdjust
		lda 	zTemp1
		sta 	blockValue
		lda 	zTemp1+1
		sta 	blockValue+1
		jsr 	BlockAltWrite
		inc 	blockWalk
		bne 	_GBFBALoop
		inc 	blockWalk+1
		bra 	_GBFBALoop
_GBFBADone:
		rts

; ************************************************************************************************
;
;		EVERY GLOBAL BELOW THIS LINE, AND NOWHERE ELSE.
;
;		64tass scopes a "_" label to the enclosing GLOBAL, so a global dropped in among another
;		routine's locals starts a new scope and every branch to a local defined after it stops
;		resolving -- "not defined symbol '_GBFRField'", and so on down the file. GPBankRelocate's
;		helpers run from _GBFixRegions to _GBFixBlockAlts; put a new global in the middle of them
;		and the build breaks in six places that have nothing to do with what was added. Twice, so
;		far.
;
; ************************************************************************************************

; ************************************************************************************************
;
;		TWO REGIONS IN ONE BANK would put the second at $A000 on top of the first, and the only
;		symptom would be the first one's code running as whatever the second one's is. The bank
;		is a constant read at compile time, so this costs one walk of a table that is at most
;		GPBANK_MAXREGIONS long, once per GP.BANKED.
;
;		BAD VALUE, reported at the GP.BANKED whose operand is the repeat -- which is the second
;		of the two, and the one the user can move.
;
;		IT DOES NOT SEE THE GP.BANKEDSTR TEXT BANK, and cannot: a text region does not enter
;		gpBankBanks until BStrRegister runs, at the end of pass one, long after the last
;		GP.BANKED was parsed. That collision is checked in BStrRegister instead, which is the
;		one place that can see both -- commands/gpbstrflush.asm.
;
; ************************************************************************************************

;		THE MESSAGES BELOW ARE IN COMPILER SPACE rather than errors.asm: that table links below
;		GPBase and is copied into every compiled program, so a message there would cost bytes to
;		every program that never writes a GP.BANKED.
;
;		EVERY BANK FROM 2 TO 255 CAN HOLD A REGION, so the bank number check refuses only
;		HANDLER_BANK. The bank is not in a file name any more: every region of the program goes
;		into one <object>.OVL, each introduced by its own bank byte and page count, so nothing
;		here has to spell a number out. ObjBuildOverlayName builds that one name, from the
;		object's, and the bootstrap extension page carries it whole.
;
; ************************************************************************************************

;		ITS OWN MESSAGE, for the same reason and in the same place as the one below. BLOCK
;		MISMATCH is what this used to say -- .error_structure, shared with a GP.BANKED inside an
;		open region and with a GP.ENDBANKED that has no opener. The structure is not what is
;		wrong here: the program is perfectly well formed and there is simply one region more
;		than the compiler's tables hold, which is a number a programmer can act on and a block
;		mismatch is not. The line is already right -- currentLineNumber is the offending
;		GP.BANKED, measured at the ninth of nine before this was raised to sixteen.
;
GPBankTooMany:
		jsr 	CallErrorHandler
		.text 	"TOO MANY GP.BANKED REGIONS", 0

; ************************************************************************************************

GPBankCheckBankNumber:
		lda 	gpBankNumber
		cmp 	#HANDLER_BANK
		beq 	_GBCBNReserved
		rts
_GBCBNReserved:
		jsr 	CallErrorHandler
		.text 	"BANK 1 IS RESERVED", 0

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
;		GP.ENDBANKED: the region's banked GP.ASM is complete. Pass one records its length for
;		GPBankRelocate, which puts it above the region's end marker; both passes start the next
;		region's count from zero. See AsmBankBlob in commands/gpasmcode.asm.
;
; ************************************************************************************************

GPBankAsmClose:
		lda 	passNumber
		bne 	_GBAKZero
		lda 	gpBankCount
		asl 	a
		tax
		lda 	AsmRgnLen
		sta 	gpBankAsmLens,x
		lda 	AsmRgnLen+1
		sta 	gpBankAsmLens+1,x
_GBAKZero:
		stz 	AsmRgnLen
		stz 	AsmRgnLen+1
		rts

; ************************************************************************************************
;
;		STRMakeOffset, plus the correction a branch needs when exactly one of its ends is in the
;		banked region. YA is the target on the way in and the finished offset on the way out, so
;		it drops straight into the branch writer in place of STRMakeOffset.
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
		jsr 	GPBankSide
		sta 	gpBankSideFrom
		lda 	gpBankTarget 				; ...and the target ?
		ldy 	gpBankTarget+1
		jsr 	GPBankSide
		sta 	gpBankSideTo
		cmp 	gpBankSideFrom
		beq 	_GBMOOut 					; the same side: the deltas cancel as they always did
		;
		;		EACH END IN A REGION IS OUT BY THAT REGION'S CROSSING, a whole number of pages:
		;		the branch's own is taken off and the target's is put on. Low memory has none.
		;
		;		ONE END IN EACH OF TWO REGIONS IS FOR A .bgosub ONLY. Both regions run at $A000,
		;		so the offset is right only once the target's bank is selected, and a .bgosub is
		;		the branch that selects it. Any other branch would land in the caller's own bank,
		;		so it is refused here rather than miscompiled.
		;
		lda 	gpBankSideFrom
		beq 	_GBMOInto 					; 0 = low memory, so this one goes INTO a region
		lda 	gpBankSideTo
		beq 	_GBMOOutOf 					; out of a region, into low memory
		lda 	branchOpcode 				; out of one region and into another
		cmp 	#PCD_CMD_BGOSUB
		bne 	_GBMOCross
_GBMOOutOf:
		ldx 	gpBankSideFrom
		dex
		sec
		lda 	gpBankOffset+1
		sbc 	gpBankCrossings,x
		sta 	gpBankOffset+1
		lda 	gpBankSideTo
		beq 	_GBMOOut
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
;		IN PASS ONE ONLY THE REGIONS ALREADY CLOSED ARE COUNTED, and they are still where pass
;		one compiled them, which is where its addresses are too. An address in the region still
;		open comes back as low memory. Corrupts X and Y.
;
GPBankSide:
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

; ************************************************************************************************
;
;		A GOTO INTO A GP.BANKED REGION FROM OUTSIDE IT IS REFUSED. branchTarget is the line it
;		goes to. Called for GOTO, GO TO, IF .. THEN <line> and ON .. GOTO. Corrupts X and Y.
;
;		A GOTO selects no bank, so it lands at $A0xx in whatever bank is selected. From low
;		memory that is the region's bank only by luck -- the bootstrap leaves the last region it
;		loaded selected, which is why a GOTO into a one-region program ran. Selecting the bank
;		here instead would break every plain GOSUB still open whose RETURN lands in another
;		region, so a region is entered by a call or not at all.
;
;		DECIDED FROM LINE NUMBERS, which GPBankScanLines read before the first pass, so pass one
;		refuses it before anything is written. That covers a GOTO from one region into another
;		as well, which GPBankMakeOffset used to catch only in pass two.
;
;		THE COMPILER'S OWN GOTOs NEVER COME HERE: the two bridges round a region and the jump
;		to the implicit-DIM prologue go straight to WriteBranchTo. So falling into a region from
;		the line above it is not caught -- it goes through the entry bridge -- and neither is a
;		false IF on that line, whose .gotoz lands on the GP.BANKED line.
;
; ************************************************************************************************

GPBankGotoGuard:
		lda 	branchTarget 				; the bank of the line it goes to
		ldy 	branchTarget+1
		jsr 	GPBankLineBank
		beq 	_GBGGDone 					; low memory: any line may GOTO it
		pha
		lda 	currentLineNumber 			; ...against the bank of the line it is on
		ldy 	currentLineNumber+1
		jsr 	GPBankLineBank
		sta 	gpBankTemp
		pla
		cmp 	gpBankTemp
		bne 	_GBGGRefused 				; not the region this line is in already
_GBGGDone:
		rts
_GBGGRefused:
		.error_unimplemented

; ************************************************************************************************
;
;		A CALL INTO A REGION SELECTS THE REGION'S BANK. The call is written as .bgosub <offset>
;		<bank>, and RETURN puts the caller's bank back, so no low-memory shim has to do either.
;
;		GPBankLineCall 		a GOSUB, whose target is a LINE. It is decided from the line ranges
;							GPBankScanLines read before the first pass, so pass one decides a
;							forward GOSUB exactly as pass two does.
;		GPBankAddressCall 	a DEF FN, GP.FN or GP.SUB call, whose target is an ADDRESS. The body is
;							always behind the call, so every pass already knows which region
;							holds it. In pass one the region still open reads as low memory, and
;							only a call from inside that same region can reach it, which is left
;							plain anyway.
;
;		Either one leaves branchOpcode as PCD_CMD_BGOSUB and the bank in branchBank, or changes
;		nothing. NOTHING CHANGES FOR A CALL INSIDE ONE REGION: its bank is selected already, and
;		a plain call is a byte shorter.
;
;		A CALL OUT OF A REGION TO LOW MEMORY IS A .bgosub WITH THE REGION'S OWN BANK. Selecting
;		it costs nothing, and RETURN puts it back, so a low routine that does BANK n returns
;		into the region under the right bank.
;
;		THE CALLER'S REGION IS FOUND BY ITS LINE NUMBER, in the same table, and not by
;		gpBankState and gpBankNumber. GP.BANKEDSTR reads its own bank into gpBankNumber, so a
;		text block inside a region would leave the wrong bank there.
;
;		ON ... GOSUB refuses the result -- see CommandON.
;
; ************************************************************************************************

GPBankLineCall:
		lda 	branchOpcode
		cmp 	#PCD_CMD_GOSUB
		bne 	GPBankCallOut
		lda 	branchTarget
		ldy 	branchTarget+1
		jsr 	GPBankLineBank
		bra 	GPBankCallInto

GPBankAddressCall:
		lda 	branchOpcode
		cmp 	#PCD_CMD_FNGOSUB
		bne 	GPBankCallOut
		lda 	branchTarget
		ldy 	branchTarget+1
		jsr 	GPBankSide 					; the region + 1, or 0
		tax
		beq 	_GBACOpen
		lda 	gpBankBanks-1,x
		bra 	GPBankCallInto
;
;		PASS ONE CANNOT SEE THE REGION STILL OPEN, so GPBankSide calls a body in it low memory.
;		Pass two sees every region, so a body at or above the open region's start is in it.
;
_GBACOpen:
		lda 	passNumber
		bne 	_GBACLow
		lda 	gpBankState
		cmp 	#1
		bne 	_GBACLow
		lda 	gpBankCount
		asl 	a
		tax
		lda 	branchTarget+1
		cmp 	gpBankStarts+1,x
		bcc 	_GBACLow
		bne 	_GBACInOpen
		lda 	branchTarget
		cmp 	gpBankStarts,x
		bcc 	_GBACLow
_GBACInOpen:
		ldx 	gpBankCount
		lda 	gpBankBanks,x
		bra 	GPBankCallInto
_GBACLow:
		lda 	#0
;
;		A is the target's bank, 0 for low memory.
;
GPBankCallInto:
		sta 	branchBank
		lda 	currentLineNumber 			; the caller's own region, whose bank is already the
		ldy 	currentLineNumber+1 		; one selected
		jsr 	GPBankLineBank
		cmp 	branchBank
		beq 	GPBankCallOut 				; the same bank, or low memory to low memory
		ldx 	branchBank
		bne 	_GBCIBank 					; into a region: its bank
		sta 	branchBank 					; out of a region into low memory: the caller's own
_GBCIBank:
		lda 	#PCD_CMD_BGOSUB
		sta 	branchOpcode
GPBankCallOut:
		rts

; ************************************************************************************************
;
;		YA is a line number. A comes back as the bank of the region that holds it, or 0 if no
;		region does. A region holds its GP.BANKED line and every line after it, up to but not
;		including its GP.ENDBANKED line. Corrupts X and Y.
;
; ************************************************************************************************

GPBankLineBank:
		sta 	gpBankTemp
		sty 	gpBankTemp2
		ldx 	#0
_GBLBNext:
		cpx 	gpScanCount
		bcs 	_GBLBLow
		txa
		asl 	a
		tay
		lda 	gpBankTemp2 				; before the GP.BANKED line ? then not this region
		cmp 	gpBankLinesIn+1,y
		bcc 	_GBLBSkip
		bne 	_GBLBNotBelow
		lda 	gpBankTemp
		cmp 	gpBankLinesIn,y
		bcc 	_GBLBSkip
_GBLBNotBelow:
		lda 	gpBankTemp2 				; ...and before the GP.ENDBANKED line ?
		cmp 	gpBankLinesOut+1,y
		bcc 	_GBLBInside
		bne 	_GBLBSkip
		lda 	gpBankTemp
		cmp 	gpBankLinesOut,y
		bcc 	_GBLBInside
_GBLBSkip:
		inx
		bra 	_GBLBNext
_GBLBInside:
		lda 	gpBankBanks,x
		rts
_GBLBLow:
		lda 	#0
		rts

; ************************************************************************************************
;
;		WHICH LINES EVERY REGION HOLDS, read once, before the first pass compiles anything.
;
;		A .bgosub is a byte longer than a .gosub, and every pass must emit the same bytes. Pass
;		one reaches a forward GOSUB before it reaches the GP.BANKED line that holds its target,
;		so the line ranges have to be known before pass one starts. Pass zero needs them too,
;		because it lays the program out the same way.
;
;		THE RANGES GO INTO gpBankLinesIn, gpBankLinesOut and gpBankBanks, the tables the
;		GP.BANKED generator fills. Every pass writes the same values over them in the same
;		order, so what is read here still stands. gpScanCount is how many there are: gpBankCount
;		is cleared for every pass, and the text regions are added past the code regions at the
;		end of pass one.
;
;		ONLY THE FIRST STATEMENT OF A LINE IS LOOKED AT, because that is the only place pass one
;		accepts either keyword. Anything malformed is left for pass one to refuse, except a bank
;		number GPBankReadNumber cannot read, which it refuses here with the same message.
;
; ************************************************************************************************

GPBankScanLines:
		stz 	deferErrors 				; nothing read here may defer
		stz 	gpScanCount
		lda 	#BLC_OPENIN
		jsr 	CallAPIHandler
_GBSLLine:
		jsr 	ReadSourceLine 				; CS = a line, in YX
		bcc 	_GBSLDone
		jsr 	ProcessNewLine
_GBSLFirst:
		jsr 	GetNextNonSpace
		cmp 	#":" 						; leading colons, which the main loop skips too
		beq 	_GBSLFirst
		cmp 	#$CE 						; a GP keyword, whose second byte is still unread
		bne 	_GBSLLine
		lda 	gpScanCount 				; the tables are full, and pass one says so by name
		cmp 	#GPBANK_MAXREGIONS
		bcs 	_GBSLLine
		asl 	a
		tax
		lda 	(srcPtr)
		cmp 	#GP_TOKEN_ENDBANKED
		beq 	_GBSLClose
		cmp 	#GP_TOKEN_BANKED
		bne 	_GBSLLine
		lda 	currentLineNumber
		sta 	gpBankLinesIn,x
		lda 	currentLineNumber+1
		sta 	gpBankLinesIn+1,x
		jsr 	GetNext 					; past the keyword's second byte
		jsr 	GPBankReadNumber 			; the bank, into gpBankNumber
		ldx 	gpScanCount
		lda 	gpBankNumber
		sta 	gpBankBanks,x
		bra 	_GBSLLine
_GBSLClose:
		lda 	currentLineNumber 			; a region is counted once it is closed
		sta 	gpBankLinesOut,x
		lda 	currentLineNumber+1
		sta 	gpBankLinesOut+1,x
		inc 	gpScanCount
		bra 	_GBSLLine
_GBSLDone:
		lda 	#BLC_CLOSEIN
		jmp 	CallAPIHandler

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
gpBankMid:										; start + header + tail, before page padding
		.fill 	2
gpBankHigh:										; ...and one past the region once it has moved
		.fill 	2
gpBankWalk:										; cursor into the line number table
		.fill 	2
gpBankShared:									; 1 in SHARED mode. Set by CompileCode before the
		.fill 	1 								; compile. Embedded still refuses GP.BANKEDSTR
gpBankRunPage:									; buffer page -> run page: the WHOLE delta for this
		.fill 	1 								; mode, set up front by CompileCode
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
		.send 	storage

; ************************************************************************************************
;
;		THE REGION TABLE. One entry a GP.BANKED, in SOURCE order. Everything above is either
;		global to the compile or the WORKING COPY of whichever region GPBankRelocate has in
;		hand: the rotation happens once per region and each pass wants the same values the
;		single-region version always wanted, so the pass loads them out of here and puts the
;		results back.
;
;		IT IS IN THE CODE SECTION, NOT IN STORAGE, and that is what lets the count be 127. These
;		are 13 bytes a region and the layout copy in main/compiler.asm is another 6, so 127 costs
;		2,413 -- against a 1K storage hole that already holds everything else the compiler keeps
;		between statements. They could never have fitted there.
;
;		THE CODE SECTION IS THE COMPILER'S OWN IMAGE, above ObjectBase, and it is thrown away
;		when the object code is written -- so a compiled program pays nothing for these, exactly
;		as it pays nothing for the compiler around them. It is what the hole's own .cerror tells
;		you to do when it overflows, and IONameBuffer (application/source/file-io/read.asm) is
;		the same move made for the same reason.
;
;		WHAT IT COSTS IS GPC.BIN, and nothing else. FreeMemory is page aligned after the code
;		(main/zzfree.footer) and is only the ORIGIN objPtr counts from -- the object itself has
;		lived in a bank since the compiler went two-pass. Moving FreeMemory up moves the
;		numbering with it, so every length, offset and page delta derived from it comes out
;		unchanged.
;
; ************************************************************************************************

		.section code
gpBankCount:									; how many regions the program has
		.fill 	1
gpBankPass:										; which one GPBankRelocate is moving
		.fill 	1
gpScanCount:									; the regions GPBankScanLines found before the
		.fill 	1 								; first pass
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
gpBankAsmLens:									; bytes of GP.ASM each carries above its end marker
		.fill 	GPBANK_MAXREGIONS * 2
gpBankAsmLen:									; ...and the one GPBankRelocate is moving
		.fill 	2
		.send 	code

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
;		13/09/26		A GOSUB or an FN call into a region from outside it is a .bgosub, and may
;						come from another region. GPBankScanLines reads the line ranges first.
;		14/09/26		GPBankGotoGuard: a GOTO into a region from outside it is refused in pass
;						one, from line numbers.
;		14/09/26		An embedded compile stops at the first GP.BANKED with GP.BANKED NEEDS
;						SHARED, at its own line rather than NOT IMPLEMENTED at the last one.
;
; ************************************************************************************************
