; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpbstrflush.asm
;		Purpose:	GP.BANKEDSTR -- the bank image, into the object as one more region
;		Created:	7th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		The finished text goes into the object as ONE MORE BANK REGION, above every GP.BANKED one,
;		and that is the whole of the placement. It needs none of GPBankRelocate's machinery --
;		no line table to fix, no block ends, no branch corrections, no entry or exit bridge --
;		because nothing ever branches into text. It is data.
;
;		WHY IT CAN JUST BE APPENDED. The bootstrap extension page copies the regions with ONE loop
;		that runs on from each to the next (application/compiler/bootstrap2.asm), so all it asks of
;		a region is that it be whole pages and contiguous with the one below it, and that the
;		(pages, bank) table be in object order. Appending above the topmost region satisfies all
;		three: it becomes the last entry and it is the last thing in the object.
;
;		AND IT IS A REGION TO THE OBJECT WRITER TOO, which is not a detail. Pass two streams the
;		low code through a buffer and each region into a bank of its own, and ObjStreamClose
;		writes the buffer, one gap of filler, then the regions (application/compiler/object.asm).
;		Written as low code this region's bytes go through the buffer at an objPtr far above where
;		the buffer has reached, and the streamer pads forward to it -- across the whole span the
;		GP.BANKED regions occupy, which it then writes AGAIN out of their banks. A 22K program
;		came out 88K, and neither the length check nor the checksum saw anything wrong, because
;		both passes did the identical thing and the padding is the streamer's, not the compiler's.
;
;		So it takes a LAYOUT slot like any other region. Its line numbers are $FFFE, which is not
;		a line: RegionSwitch walks the layout looking for the line that opens each region, and a
;		text region has none to find.
;
;		BOTH PASSES RUN IT, and they must produce byte for byte the same length -- pass one is only
;		counting, and the figure it counts is what PROGRAM TOO BIG is decided on and what pass two
;		then has to fill exactly. Everything it reads is rebuilt identically by each pass.
;
;		THE IMAGE, all offsets from $A000, which is where the bank window is:
;
;			+0		string count, 16 bit
;			+2		count * 16-bit offsets, each the offset of one record from $A000
;			...		the records, [length][characters] back to back
;
;		THE DIRECTORY IS BUILT BY WALKING THE POOL, not read out of a table beside it. Every record
;		starts with its own length, so the offsets follow from the records -- and a record's offset
;		from $A000 could not have been stored when it was appended anyway, because the directory it
;		sits behind is not sized until the last block has closed.
;
; ************************************************************************************************

BStrFlush:
		lda 	bstrGroupCount 				; no GP.BANKEDSTR in this program at all
		bne 	_BFGo
		rts
_BFGo:
		;
		;		SHARED MODE ONLY, the same rule GP.BANKED has and for the same reason: the region
		;		is moved into its bank by the program's BOOTSTRAP, and an embedded program has
		;		none. Refusing is honest; compiling it would produce a program whose text never
		;		reaches $A000 and which reads an empty bank at run time.
		;
		lda 	gpBankShared
		bne 	_BFShared
		.error_unimplemented
_BFShared:
		;
		;		BOTH PASSES EMIT THE IDENTICAL BYTE STREAM FROM THE IDENTICAL ADDRESS, and that is
		;		not tidiness: the compiler checks pass two's finished length AND its running
		;		checksum against pass one's and raises INTERNAL ERROR on either
		;		(main/compiler.asm). A pass two that skipped so much as the page padding fails it.
		;
		;		AND THEY START IN THE SAME PLACE, which is the only thing to arrange. Pass one
		;		arrives here straight after GPBankRelocate, with the cursor on top of the relocated
		;		regions, aligns it, and writes down where that came to. Pass two is put back there
		;		by ClaimRegionTop, which reads the same figure -- so pass two never moves the
		;		cursor here at all, and in particular never winds it BACKWARDS.
		;
		jsr 	BStrAlignPage 				; whole pages, so the bootstrap's copy loop can run on
											; into this region from the one below it
		lda 	objPtr+1 					; where the region sits in the buffer, page aligned
		sta 	bstrRegionPage
		lda 	passNumber
		bne 	_BFRegionOpen
		lda 	objPtr
		sta 	bstrStart
		lda 	objPtr+1
		sta 	bstrStart+1
		bra 	_BFCommon
		;
		;		PASS TWO WRITES IT INTO THE REGION'S OWN BANK, and says so: ObjStreamByte routes on
		;		regionOpen and works out which bank from nextRegion and the layout. Every GP.BANKED
		;		region has closed by now, so nextRegion is already this one -- set anyway, rather
		;		than depend on a count kept somewhere else.
		;
_BFRegionOpen:
		lda 	layoutCount
		dec 	a
		sta 	nextRegion
		lda 	#1
		sta 	regionOpen
_BFCommon:
		;
		;		The directory size, which every offset is shifted by: 2 for the count, then two
		;		bytes an entry.
		;
		lda 	bstrStringCount
		asl 	a
		sta 	bstrDirLen
		lda 	bstrStringCount+1
		rol 	a
		sta 	bstrDirLen+1
		clc
		lda 	bstrDirLen
		adc 	#2
		sta 	bstrDirLen
		bcc 	_BFNoCarry
		inc 	bstrDirLen+1
_BFNoCarry:
		;
		;		The count, then the directory.
		;
		lda 	bstrStringCount
		jsr 	WriteCodeByte
		lda 	bstrStringCount+1
		jsr 	WriteCodeByte

		stz 	bstrIdx 					; the cursor into the pool, which is also this
		stz 	bstrIdx+1 					; record's offset within it
_BFDirLoop:
		lda 	bstrIdx
		cmp 	bstrPoolLen 				; every record accounted for ?
		lda 	bstrIdx+1
		sbc 	bstrPoolLen+1
		bcs 	_BFDirDone
		clc 								; the offset from $A000: past the directory
		lda 	bstrIdx
		adc 	bstrDirLen
		sta 	bstrTemp
		lda 	bstrIdx+1
		adc 	bstrDirLen+1
		sta 	bstrTemp+1
		lda 	bstrTemp
		jsr 	WriteCodeByte
		lda 	bstrTemp+1
		jsr 	WriteCodeByte
		;
		jsr 	BStrPoolByte 				; the record's length byte, and step over the record
		sec
		adc 	bstrIdx 					; SEC, so this is length + 1: the length byte too
		sta 	bstrIdx
		bcc 	_BFDirLoop
		inc 	bstrIdx+1
		bra 	_BFDirLoop
_BFDirDone:
		;
		;		Then the records themselves, straight out of the pool. ONE BYTE AT A TIME with the
		;		window opened and closed around each, exactly as AsmFlushPool does and for the same
		;		reason: WriteCodeByte can raise PROGRAM TOO BIG and leave through the error handler,
		;		which prints, through the KERNAL, in bank 0.
		;
		stz 	bstrIdx
		stz 	bstrIdx+1
_BFPoolLoop:
		lda 	bstrIdx
		cmp 	bstrPoolLen
		lda 	bstrIdx+1
		sbc 	bstrPoolLen+1
		bcs 	_BFPoolDone
		jsr 	BStrPoolByte
		jsr 	WriteCodeByte
		inc 	bstrIdx
		bne 	_BFPoolLoop
		inc 	bstrIdx+1
		bra 	_BFPoolLoop
_BFPoolDone:
		jsr 	BStrAlignPage 				; and the region is whole pages too
		stz 	regionOpen 					; pass two is out of it; pass one never set it

		;
		;		PASS ONE WORKS OUT THE REGION'S SIZE AND ENTERS IT IN THE TABLE; PASS TWO IS TOLD
		;		BOTH. Pass two writes exactly what pass one wrote and ends in the same place, so it
		;		has nothing to measure -- and it must not enter the region here either, because by
		;		the time it reaches this point the bootstrap has already carried the table to disk.
		;		SaveLayout takes pass one's entry and RestoreLayout hands it back.
		;
		lda 	passNumber
		bne 	_BFDone
		sec 								; A REGION IS AT MOST 32 PAGES: that is the whole of
		lda 	objPtr+1 					; $A000-$BFFF, and a longer one would have the copy run
		sbc 	bstrRegionPage 				; past $BFFF into the I/O page
		cmp 	#33
		bcs 	_BFTooBig
		sta 	bstrPages
		jsr 	BStrRegister
_BFDone:
		rts

_BFTooBig:
		.error_range

; ************************************************************************************************
;
;		The region into the bank table, as the last entry. Called at the END of pass one, where
;		its size has just been worked out, and at the START of pass two, from ResetPerPass.
;
;		THE TIMING IS THE WHOLE POINT AND IT COST A DAY. The bootstrap extension page -- which
;		carries the (pages, bank) table and the GP.BSTR bank byte -- is written at the very
;		BEGINNING of pass two, before a line of the program is compiled. A region entered at the
;		end of pass two is entered after the table describing it has already gone out to disk: the
;		program then loads with an empty table, nothing is copied to $A000, and GP.BSTR reads an
;		empty bank. Everything compiles clean and the program dies at run time.
;
;		Pass two cannot re-derive any of this either -- it has not read the blocks yet -- so the
;		three facts are carried over from pass one in bstrPages, bstrBank and bstrRegionPage,
;		none of which is reset between passes.
;
;		It is NOT in the saved LAYOUT, deliberately: layoutCount is what RegionSwitch walks looking
;		for the line that opens each region, and a text region has no line.
;
; ************************************************************************************************

BStrRegister:
		ldx 	gpBankCount
		cpx 	#GPBANK_MAXREGIONS
		bcs 	_BRTooMany
		lda 	bstrPages
		sta 	gpBankPageCounts,x
		lda 	bstrBank
		sta 	gpBankBanks,x
		;
		;		AND ITS EXTENT IN THE BUFFER, which is not bookkeeping. GPBankMakeOffset asks
		;		_GBMOSide which region each end of a branch is in, and _GBMOSide walks
		;		gpBankCount entries of gpBankStarts/gpBankEnds. Raising the count without
		;		filling them leaves it reading a stale entry that any address can fall inside:
		;		the compile then stops with NOT IMPLEMENTED on an ordinary branch, because
		;		both ends were read as being in two different banks. Nothing branches into
		;		text, so with the real extent in place this entry never matches anything --
		;		which is also what keeps the two passes agreeing, one having registered the
		;		region at its end and the other before its first line.
		;
		txa
		asl 	a
		tay
		lda 	#0
		sta 	gpBankStarts,y
		sta 	gpBankEnds,y
		lda 	bstrRegionPage
		sta 	gpBankStarts+1,y
		clc
		adc 	bstrPages
		sta 	gpBankEnds+1,y
		;
		;		A LINE NUMBER THAT IS NOT A LINE. RegionSwitch walks the layout looking for the
		;		line each region opens and closes on, and text opens on none -- so it is given
		;		$FFFE, which is above every line BASLOAD writes and is neither the end marker
		;		($FE00) nor the implicit-DIM prologue ($FFFF).
		;
		lda 	#$FE
		sta 	gpBankLinesIn,y
		sta 	gpBankLinesOut,y
		lda 	#$FF
		sta 	gpBankLinesIn+1,y
		sta 	gpBankLinesOut+1,y
		lda 	#0 							; nothing branches into text, so nothing reads this --
		sta 	gpBankCrossings,x 			; but a stale byte in a table is a trap for later
		inc 	gpBankCount
		;
		;		A PROGRAM WITH TEXT AND NO GP.BANKED HAS NO RUN BASE YET, because GPBankRelocate
		;		is what sets one and it had nothing to relocate. This region is then also the
		;		lowest, so it is the one the bootstrap starts its copy from.
		;
		lda 	gpBankActive
		bne 	_BRDone
		clc
		lda 	bstrRegionPage
		adc 	gpBankRunPage 				; buffer page -> the page it loads at
		inc 	a 							; ...plus the bootstrap EXTENSION page, which a banked
		sta 	gpBankRunBase 				; program carries and this program now is
		;
		;		AND gpBankStart, WHICH IS THE FIT CHECK'S IDEA OF WHERE THE P-CODE STOPS.
		;		ObjectPrepareShared measures resident p-code as FreeMemory..gpBankStart once
		;		gpBankActive is set (application/compiler/object.asm), so setting the flag without
		;		this leaves it measuring against a stale zero -- which is PROGRAM TOO BIG on a
		;		six line program, and was.
		;
		stz 	gpBankStart
		lda 	bstrRegionPage
		sta 	gpBankStart+1
		lda 	#1
		sta 	gpBankActive
_BRDone:
		rts
_BRTooMany:
		.error_memory

;
;		Up to the next page boundary. It ADVANCES THE CURSOR RATHER THAN WRITING, and that is the
;		difference between a gap and a byte: ObjStreamClose fills the one gap below the first
;		region with $FF itself, and a region above the first has to start exactly where the one
;		below it ended, or the filler is written twice over. Nothing reads either -- the tail is
;		inside the region's page count and the head is below it.
;
;		Both passes take the same step, so neither the length nor the checksum notices.
;
BStrAlignPage:
		lda 	objPtr
		beq 	_BAPDone
		stz 	objPtr
		inc 	objPtr+1
_BAPDone:
		rts

;
;		The pool byte at bstrIdx, in A. The window is opened and closed around the one access:
;		the compiler's own code is not in that bank.
;
BStrPoolByte:
		clc
		lda 	#BStrPool & $FF
		adc 	bstrIdx
		sta 	zTemp2
		lda 	#BStrPool >> 8
		adc 	bstrIdx+1
		sta 	zTemp2+1
		.bstr_access
		lda 	(zTemp2)
		sta 	bstrByte
		.bstr_release
		lda 	bstrByte
		rts

		.send code

		.section storage
bstrRegionPage: 							; the page the region starts on, in the object buffer
		.fill 	1
bstrDirLen: 								; bytes of count and directory in front of the records
		.fill 	2
bstrIdx: 									; the flush loops' cursor
		.fill 	2
bstrByte: 									; one pool byte, out of the window before it is written
		.fill 	1
bstrPages: 									; whole pages the region takes, worked out by pass one
		.fill 	1 							; and handed to pass two
bstrStart: 									; where pass one began the region -- ClaimRegionTop
		.fill 	2 							; puts pass two back there, so neither pass moves the cursor
		.send storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		07/09/26		Written.
;
