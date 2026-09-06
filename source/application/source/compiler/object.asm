; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		object.asm
;		Purpose:	Write object code out.
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;									Write object code out.
;
; ************************************************************************************************

;
;		FrameStackPages -- the gap left below the workspace for the runtime (GOSUB/FOR) stack --
;		was defined here. It now lives in common-source/source/common.inc, because the runtime
;		needs the same number to know where the bottom of that gap is (StackOpenFrame).
;

; ************************************************************************************************
;
;		Write object code out.
;
;		In memory the layout is
;
;			$0801 [ runtime ] ObjectBase [ compiler ] FreeMemory [ object code ] objPtr
;
;		but a saved program never compiles anything, so the compiler is dead weight. The
;		file is therefore written in two pieces -- the runtime, then the object code -- so
;		that on reload the object code lands at ObjectBase, on top of where the compiler was.
;
;		That reclaims (FreeMemory-ObjectBase) bytes from every compiled program, and, more
;		importantly, lets the workspace start just above the object code instead of at a
;		hardcoded $8000 -- which is most of the useable memory a compiled program gets.
;
;		The two immediates in StartCode are patched as they stream past, rather than in RAM,
;		so the copy still in memory (RUN a second time) keeps running from FreeMemory.
;
; ************************************************************************************************

; ************************************************************************************************
;
;		HOW BIG IT IS, AND THEREFORE WHERE IT GOES. Called at the END OF PASS ONE, through
;		BLC_ENDPASS1, because pass one is where the object's length stops changing and
;		everything here follows from that length: how much of the runtime the program needs,
;		where the object code lands on reload, where the workspace starts.
;
;		PASS TWO NEEDS THE ANSWERS WHILE IT COMPILES. It was enough to work them out at the top
;		of WriteObjectCode while the finished object sat in a buffer waiting to be streamed;
;		pass two is about to write straight to the file instead, which means the file is opened
;		and the runtime written into it before pass two starts.
;
;		AND SO IS PROGRAM TOO BIG, which is the point of the exercise: a program with no room to
;		run is refused here, before a byte of it has been written, rather than after the whole
;		thing has been laid out.
;
;		Carry set = rejected, and the message has already been printed.
;
; ************************************************************************************************

PrepareObjectCode:
		lda 	ModeText 					; GPC.INPUT line 4 -- 'S' (SHARED) selects resident-runtime
		cmp 	#'S' 						; mode: emit a bootstrap + p-code, no embedded runtime
		bne 	_POCEmbedded 				; (see the shared branch below and compiler/bootstrap.asm).
		jmp 	ObjectPrepareShared 					; jmp, not a branch -- the embedded path is >127 bytes
_POCEmbedded:
		jsr 	ScanGPUsage 				; does anything reach a handler above GPBase ?
		lda 	gpUsed 						; TEMPORARY, while both routes to that answer exist:
		cmp 	gpStreamUsed 				; the walk and the stream have to agree, on every
		beq 	_WOCScanOK 					; program compiled. The walk goes when pass one stops
		jmp 	ObjectScanBad 				; storing the object and there is nothing left to walk.
_WOCScanOK:
		;
		;		The cut. A program using no GP.BASIC keyword takes the runtime as $0801..GPBase
		;		and puts its object code there; one that uses any takes the whole thing,
		;		$0801..ObjectBase, exactly as before. Both labels are page aligned, so a single
		;		page number says which -- and it is used THREE times below (the copy terminator,
		;		the RunCodePage patch and the workspace base), so it is settled once, here.
		;
		lda 	#GPBase >> 8
		ldx 	gpUsed
		beq 	_WOCCutSet
		lda 	#ObjectBase >> 8
_WOCCutSet:
		sta 	runtimeEndPage
		;
		;		zTemp1 = length of the object code.
		;
		sec
		lda 	objPtr
		sbc 	#FreeMemory & $FF
		sta 	zTemp1
		lda 	objPtr+1
		sbc 	#FreeMemory >> 8
		sta 	zTemp1+1
		;
		;		Round that up to whole pages.
		;
		lda 	zTemp1 						; any part page ?
		beq 	_WOCWholePages
		inc 	zTemp1+1 					; then it needs one more
_WOCWholePages:
		;
		;		newWorkspacePage = ObjectBase + pages(object code) + the frame stack gap.
		;
		;		...and then check the program can actually RUN, which the embedded path never
		;		did -- only the SHARED path had the equivalent test. That was survivable while
		;		the compiler itself capped p-code at 12,032 bytes; with the object buffer now
		;		reaching $9EFF it is not, because a program can be compiled successfully and
		;		still leave no room above itself for variables, arrays and strings. It would
		;		load, start, and then fail in some unrelated-looking way at run time.
		;
		;		The workspace runs from newWorkspacePage to $9F00, so require MIN_WS_PAGES (4K)
		;		of it, and reject a page count that overflowed a byte on the way -- the same two
		;		tests, in the same order, as ObjectWriteShared.
		;
		clc
		lda 	runtimeEndPage 				; where the object code will actually land
		adc 	zTemp1+1
		bcs 	_WOCTooBig
		adc 	#FrameStackPages
		bcs 	_WOCTooBig
		sta 	newWorkspacePage
		cmp 	#(ObjectCeiling >> 8) - MIN_WS_PAGES + 1
		bcc 	_POCFits
_WOCTooBig:
		jmp 	ObjectTooBig 					; shared with the SHARED path: prints PROGRAM TOO BIG,
_POCFits: 									; returns carry set, caller skips the map file and OK
		jsr 	AsmSetBases 				; as the shared path -- see AsmCloseBlock
		clc
		rts

; ************************************************************************************************
;
;		Write the object out, now that all of that has been settled.
;
; ************************************************************************************************

WriteObjectCode:
		lda 	ModeText
		cmp 	#'S'
		bne 	_WOCEmbedded
		jmp 	ObjectWriteShared
_WOCEmbedded:
		;
		;		THE RUNTIME IMAGE IS OPENED FIRST, before the object file is created. It is the
		;		one thing here that can fail for a reason outside this program, and a compile
		;		that dies after creating OBJECT.PRG leaves a truncated file that looks like a
		;		program. IODeleteOutputs has already removed the old one, so failing here leaves
		;		no object at all -- the only state that cannot be mistaken for a good one.
		;
		ldx 	#RTImageFileText & $FF
		ldy 	#RTImageFileText >> 8
		jsr 	IOOpenImage
		bcc 	_WOCImgOpened
		;
		;		Both failure paths are at the far end of this file, out of branch range from
		;		here -- the same trampoline _WOCSBigFar needs, for the same reason.
		;
_WOCImgNoneFar:
		jmp 	ObjectNoImage
_WOCImgBadFar:
		jmp 	ObjectBadImage
_WOCImgOpened:
		jsr 	IOImageIn
		jsr 	IOReadByte 					; the image's own two byte load address, which is
		bcs 	_WOCImgBadFar 				; not part of the runtime and must not be copied
		cmp 	#RTIMG_LOAD & $FF
		bne 	_WOCImgBadFar
		jsr 	IOReadByte
		bcs 	_WOCImgBadFar
		cmp 	#RTIMG_LOAD >> 8
		bne 	_WOCImgBadFar

		ldy 	#ObjectFile >> 8
		ldx 	#ObjectFile & $FF
		jsr 	IOOpenWrite 				; open write

		lda 	#RTIMG_LOAD & $FF 			; write out the load address $0801
		jsr 	IOWriteByte
		lda 	#RTIMG_LOAD >> 8
		jsr 	IOWriteByte
		;
		;		Part one : the runtime, $0801 up to the cut, streamed from GPC.IMG.nnn.BIN and
		;		patched as it goes past. A PAGE AT A TIME, not a byte at a time: both files are
		;		open together and the KERNAL has one input channel and one output channel, so
		;		every switch between them is a CHKIN/CHKOUT pair. Per byte that is 28,000 of
		;		them; per page it is 94.
		;
		;		imgCount is the size of the chunk in hand, with ZERO MEANING 256 -- which is
		;		what makes "cpy imgCount / bne" run a full page when the counter wraps back to
		;		its start. Only the last chunk is ever short.
		;
		sec 								; imgLeft = (runtimeEndPage:00) - RTIMG_LOAD
		lda 	#0
		sbc 	#RTIMG_LOAD & $FF
		sta 	imgLeft
		lda 	runtimeEndPage
		sbc 	#RTIMG_LOAD >> 8
		sta 	imgLeft+1
		stz 	imgPage
_WOCImgChunk:
		lda 	#0 							; a whole page, unless less than one is left
		ldx 	imgLeft+1
		bne 	_WOCImgHaveN
		lda 	imgLeft
_WOCImgHaveN:
		sta 	imgCount

		jsr 	IOImageIn 					; read the chunk in
		ldy 	#0
_WOCImgRead:
		jsr 	IOReadByte
		bcs 	_WOCImgBadFar 				; the image is shorter than ObjectBase says
		sta 	imageBuffer,y
		iny
		cpy 	imgCount
		bne 	_WOCImgRead
		;
		;		The two immediates. Chunks start on page boundaries of the STREAM (the load
		;		address was consumed before the first one), so "is this offset in this chunk"
		;		is a page compare and the offset within it is the low byte. Both live in the
		;		first page in practice; the test does not assume it.
		;
		lda 	imgPage
		cmp 	#RTIMG_CODEPOFS >> 8
		bne 	_WOCImgNoCode
		ldy 	#RTIMG_CODEPOFS & $FF
		lda 	runtimeEndPage 				; object code moves down to here
		sta 	imageBuffer,y
_WOCImgNoCode:
		lda 	imgPage
		cmp 	#RTIMG_WSPAGEOFS >> 8
		bne 	_WOCImgNoWS
		ldy 	#RTIMG_WSPAGEOFS & $FF
		lda 	newWorkspacePage 			; so the workspace can start much lower
		sta 	imageBuffer,y
_WOCImgNoWS:
		jsr 	IOObjectOut 				; and write it out
		ldy 	#0
_WOCImgWrite:
		lda 	imageBuffer,y
		jsr 	IOWriteByte
		iny
		cpy 	imgCount
		bne 	_WOCImgWrite

		inc 	imgPage
		lda 	imgCount 					; imgLeft -= imgCount, remembering the zero
		bne 	_WOCImgSubN
		dec 	imgLeft+1 					; a whole page
		bra 	_WOCImgMore
_WOCImgSubN:
		sec
		lda 	imgLeft
		sbc 	imgCount
		sta 	imgLeft
		bcs 	_WOCImgMore
		dec 	imgLeft+1
_WOCImgMore:
		lda 	imgLeft
		ora 	imgLeft+1
		bne 	_WOCImgChunk

		jsr 	IOCloseImage 				; CLRCHNs, so the object file has to be reselected
		jsr 	IOObjectOut
		;
		;		Part two : the object code itself, which lands at ObjectBase on reload.
		;
		.set16 	zTemp0,FreeMemory
_WOCCode:
		lda 	zTemp0 						; done ?
		cmp 	objPtr
		bne 	_WOCCodeByte
		lda 	zTemp0+1
		cmp 	objPtr+1
		beq 	_WOCDone
_WOCCodeByte:
		lda 	(zTemp0)
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCCode
		inc 	zTemp0+1
		bra 	_WOCCode
_WOCDone:
		jsr 	IOWriteClose 				; close the file.
		clc 								; success -- CompileCode reads the carry (set = rejected)
		rts

; ************************************************************************************************
;
;		Shared (resident-runtime) output: [$0801 bootstrap][$0900 p-code], no embedded runtime.
;		The bootstrap (compiler/bootstrap.asm) is streamed as the first 255 bytes with WS_START
;		patched in; the p-code follows and lands at $0900 on reload. A program whose p-code +
;		frame-stack gap + minimum workspace would not fit below RTBASE is rejected (carry set).
;
; ************************************************************************************************

ObjectPrepareShared:
		;
		;		p-code length -> whole pages (same as the embedded path)
		;
		;		...but only the LOW part of it. A GP.BANKED region sits at the top of the object,
		;		page aligned, and the bootstrap moves it into the bank before the runtime starts.
		;		So the workspace begins where the region begins: those bytes are in the file, and
		;		in memory for as long as it takes to copy them, and then they are workspace. That
		;		is the whole return on putting the region up there.
		;
		lda 	objPtr
		ldy 	objPtr+1
		ldx 	gpBankActive
		beq 	_WOCSLength
		lda 	gpBankStart 				; where the region ends up -- page aligned
		ldy 	gpBankStart+1
_WOCSLength:
		sec
		sbc 	#FreeMemory & $FF
		sta 	zTemp1
		tya
		sbc 	#FreeMemory >> 8
		sta 	zTemp1+1
		lda 	zTemp1
		beq 	_WOCSWhole
		inc 	zTemp1+1
_WOCSWhole:
		;
		;		WS_START = PCODE_PAGE + pages(p-code) + the frame-stack gap. Reject if that leaves
		;		fewer than MIN_WS_PAGES below RTBASE, or if the page count itself overflowed a byte.
		;
		jsr 	ScanGPUsage 				; the shared runtime is two files now -- see below
		lda 	gpUsed 						; ...and the same comparison as the embedded path
		cmp 	gpStreamUsed
		beq 	_WOCSScanOK
		jmp 	ObjectScanBad
_WOCSScanOK:
		;
		;		The workspace ends where the resident runtime starts, and that is no longer one
		;		address: a program using no GPB keyword loads the CORE-ONLY file at RTBASE and keeps
		;		everything below it, one using GPB loads the full file at RTGPBASE and stops there.
		;		2,560 bytes between them, so it is worth knowing which.
		;
		lda 	#RTBASE >> 8
		ldx 	gpUsed
		beq 	_WOCSCeiling
		lda 	#RTGPBASE >> 8
_WOCSCeiling:
		sta 	sharedCeilPage
		clc
		lda 	#PCODE_PAGE
		adc 	gpBankActive 				; ...plus the bootstrap extension page, which only a
											; banked program carries. Its p-code starts at $0A00.
		adc 	zTemp1+1
		bcs 	_WOCSBigFar
		adc 	#FrameStackPages
		bcs 	_WOCSBigFar
		sta 	newWorkspacePage 			; reuse this byte to carry WS_START
		;
		;		Reject unless MIN_WS_PAGES still fit below the ceiling. Computed as a THRESHOLD and
		;		compared, rather than subtracting the ceiling from the start page: the subtraction
		;		underflows when the p-code has already run past the ceiling, and an underflow reads as
		;		a small positive gap -- i.e. it accepts exactly the programs it exists to reject.
		;
		lda 	sharedCeilPage
		sec
		sbc 	#MIN_WS_PAGES - 1 			; the highest start page that still leaves a workspace
		sta 	zTemp1 						; (the low byte is spent -- only zTemp1+1 is still live)
		lda 	newWorkspacePage
		cmp 	zTemp1
		bcs 	_WOCSBigFar
		jsr 	AsmSetBasesShared 			; GP.ASM needs both of them, and pass two needs them
		clc 								; while it compiles -- see AsmCloseBlock
		rts
;
;		ObjectTooBig is at the far end of this file, out of branch range from here -- the same
;		trampoline FixBranches needs for its GP.EXITDO handler, for the same reason.
;
_WOCSBigFar:
		jmp 	ObjectTooBig

ObjectWriteShared:
		;
		;		Header: a normal PRG loading at $0801 -- the bootstrap sits there.
		;
		ldy 	#ObjectFile >> 8
		ldx 	#ObjectFile & $FF
		jsr 	IOOpenWrite
		lda 	#1
		jsr 	IOWriteByte
		lda 	#8
		jsr 	IOWriteByte
		;
		;		Part one: the bootstrap, ProgramBootstrap..ProgramBootstrapEnd, patching three operand
		;		bytes as they stream past. Build the table first -- the addresses are constants but all
		;		three VALUES are per-program, so it cannot be static data.
		;
		.set16 	BootPatchTable, ProgramBootstrap+BootWSPatchOffset
		lda 	newWorkspacePage 			; where this program's workspace starts
		sta 	BootPatchTable+2
		.set16 	BootPatchTable+3, ProgramBootstrap+BootWSEndPatchOffset
		lda 	sharedCeilPage 				; ... and where it ends: RTBASE or RTGPBASE
		sta 	BootPatchTable+5
		.set16 	BootPatchTable+6, ProgramBootstrap+BootGPPatchOffset
		lda 	gpUsed 						; ... and whether the handlers have to come with it
		beq 	_WOCSFlag
		lda 	#1 							; normalise: the bootstrap tests it with BEQ
_WOCSFlag:
		sta 	BootPatchTable+8
		;
		;		...and the three the handover needs: the p-code base page the runtime is given in
		;		A, and the two operand bytes of the closing jmp. A program with no region gets
		;		$09 and RT_ENTRY -- exactly the bytes already in the template, so patching them
		;		unconditionally costs it nothing and leaves its object byte for byte unchanged.
		;		A banked one gets $0A and $0900, which is the extension page: it does the copies
		;		and then repeats this handover itself.
		;
		.set16 	BootPatchTable+9, ProgramBootstrap+BootBasePageOffset
		clc
		lda 	#PCODE_PAGE 				; an instruction OPERAND, not a data byte
		adc 	gpBankActive
		sta 	BootPatchTable+11
		.set16 	BootPatchTable+12, ProgramBootstrap+BootRunJmpOffset
		.set16 	BootPatchTable+15, ProgramBootstrap+BootRunJmpOffset+1
		ldx 	#RT_ENTRY & $FF
		ldy 	#RT_ENTRY >> 8
		lda 	gpBankActive
		beq 	_WOCSJmpTo
		ldx 	#BootExtEntry & $FF
		ldy 	#BootExtEntry >> 8
_WOCSJmpTo:
		stx 	BootPatchTable+14
		sty 	BootPatchTable+17
		.set16 	zTemp0,ProgramBootstrap
_WOCSBoot:
		;
		;		SIX patched bytes now, not one, so the loop asks a table rather than growing a sixth
		;		copy of the same compare. Each entry is (address lo, hi, value): workspace START page,
		;		workspace END page -- which is the runtime base this program will use -- the flag
		;		saying whether it needs the GPB handlers at all, and then GP.BANKED's three.
		;
		ldx 	#0
_WOCSBootPatch:
		lda 	zTemp0
		cmp 	BootPatchTable,x
		bne 	_WOCSBootNext
		lda 	zTemp0+1
		cmp 	BootPatchTable+1,x
		bne 	_WOCSBootNext
		lda 	BootPatchTable+2,x 			; the byte to substitute
		bra 	_WOCSBootEmit
_WOCSBootNext:
		inx
		inx
		inx
		cpx 	#BootPatchEnd-BootPatchTable
		bne 	_WOCSBootPatch
		lda 	(zTemp0)
_WOCSBootEmit:
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCSBootNoHi
		inc 	zTemp0+1
_WOCSBootNoHi:
		lda 	zTemp0
		cmp 	#<ProgramBootstrapEnd
		bne 	_WOCSBoot
		lda 	zTemp0+1
		cmp 	#>ProgramBootstrapEnd
		bne 	_WOCSBoot
		;
		;		Part one and a half: the bootstrap EXTENSION page, and only for a banked program.
		;		It lands at $0900 and copies every region into its bank before handing over.
		;
		;		BUILT IN A BUFFER RATHER THAN PATCHED IN FLIGHT, unlike the bootstrap above. What
		;		goes into it is a TABLE -- two bytes a region -- so the address/value list the
		;		streaming loop asks would have to be as long as the table it was writing. Copying
		;		the template into a page of compiler RAM and poking it costs the compiled program
		;		nothing and stays one line of code per region.
		;
		;		imageBuffer IS THE RUNTIME IMAGE'S PAGE IN TRANSIT, and it is dead in shared mode:
		;		a shared object carries no runtime, which is the whole point of it. Same buffer,
		;		same job -- a page on its way into OBJECT.PRG.
		;
		lda 	gpBankActive
		beq 	_WOCSCodePart
		.set16 	zTemp0,ProgramBootExt
		.set16 	zTemp1,imageBuffer
		ldy 	#0 							; 256 bytes exactly, so Y wraps to end it
_WOCSExtCopy:
		lda 	(zTemp0),y
		sta 	(zTemp1),y
		iny
		bne 	_WOCSExtCopy
		;
		;		Where the regions sit once the program is loaded -- ONE address, because they are
		;		contiguous in whole pages and the copy loop runs on across them -- and then the
		;		(pages, bank) table. The terminating zero is already there: the template's table
		;		is a .fill of zeroes.
		;
		;		THE TABLE IS IN OBJECT ORDER, which is source order: GPBankRelocate moves the last
		;		region first and each one after that lands BELOW the last, so region 0 finishes
		;		at the bottom of the run. The copy walks straight on from one region to the next,
		;		so this has to be the order the pages actually sit in.
		;
		lda 	gpBankRunBase
		sta 	imageBuffer+BootExtSrcOffset
		ldx 	#0
		ldy 	#0
_WOCSExtTable:
		lda 	gpBankPageCounts,x
		sta 	imageBuffer+BootExtTableOffset,y
		iny
		lda 	gpBankBanks,x
		sta 	imageBuffer+BootExtTableOffset,y
		iny
		inx
		cpx 	gpBankCount
		bcc 	_WOCSExtTable
		ldy 	#0
_WOCSExtWrite:
		phy 								; IOWriteByte makes no promise about Y
		lda 	imageBuffer,y
		jsr 	IOWriteByte
		ply
		iny
		bne 	_WOCSExtWrite
_WOCSCodePart:
		;
		;		Part two: the p-code from FreeMemory..objPtr, which lands at $0900 on reload --
		;		or at $0A00, above the extension page, if this program has a region.
		;
		.set16 	zTemp0,FreeMemory
_WOCSCode:
		lda 	zTemp0
		cmp 	objPtr
		bne 	_WOCSCodeByte
		lda 	zTemp0+1
		cmp 	objPtr+1
		beq 	_WOCSCodeDone
_WOCSCodeByte:
		lda 	(zTemp0)
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCSCode
		inc 	zTemp0+1
		bra 	_WOCSCode
_WOCSCodeDone:
		jsr 	IOWriteClose
		clc 								; success
		rts
ObjectTooBig:
		ldx 	#ProgramTooBigText & $FF
		ldy 	#ProgramTooBigText >> 8
		bra 	ObjectFail
;
;		TEMPORARY. The two ways of deciding gpUsed disagreed, which means the byte stream was
;		decoded differently from the finished object -- and the answer says how much of the
;		runtime goes into the file, so getting it wrong writes a program with its handlers cut
;		out. Refusing is the only safe thing to do with it.
;
ObjectScanBad:
		ldx 	#ScanMismatchText & $FF
		ldy 	#ScanMismatchText >> 8
		bra 	ObjectFail

;
;		The runtime image is missing, or is not the file its name claims. Either way there is
;		no object: the image is opened before OBJECT.PRG is created precisely so that this
;		leaves nothing behind. The name carries the runtime build number, so "missing" is also
;		what a stale image from an older release looks like -- which is the point of numbering
;		it rather than trusting a fixed name to be the right one.
;
ObjectBadImage: 								; missing, wrong load address, or shorter than
ObjectNoImage: 								; ObjectBase says it should be
		jsr 	IOCloseImage 				; CLOSE on a logical file that was never opened is
											; harmless, and the OPEN may have half-registered it.
											; Leaving it would fail the NEXT compile's open, and
											; re-RUNning the compiler is now the only way to
											; retry -- PatchOutCompile used to make a second RUN
											; run the program instead.
		ldx 	#NoRuntimeImageText & $FF
		ldy 	#NoRuntimeImageText >> 8
ObjectFail:
		jsr 	PrintMessage
		sec 								; rejected -- CompileCode skips the map file and the OK
		rts

ProgramTooBigText:
		.text 	"PROGRAM TOO BIG", 13, 0

NoRuntimeImageText:
		.text 	"NO RUNTIME IMAGE", 13, 0

ScanMismatchText:
		.text 	"GP SCAN MISMATCH", 13, 0

; ************************************************************************************************
;
;		Write the debug MAP file, if GPC.INPUT gave a third line (its name). The map turns a
;		runtime error's "@ $XXXX" back into a source line, which is otherwise a hand decode of
;		the p-code. One text line per source line, in ascending code order:
;
;			0030 12
;
;		the 4-digit hex P-CODE OFFSET -- exactly what the runtime prints as "@ $0030" -- then a
;		space and the DECIMAL BASIC line number that begins there. To place an error, find the
;		largest offset that is <= the one reported.
;
;		ASCENDING CODE ORDER, EXCEPT AFTER A GP.BANKED. The table is walked in the order the
;		lines were marked, which is source order, and those two were the same thing until
;		GPBankRelocate started lifting a region out to the end of the object. A program with a
;		region in it has that region's lines carrying the HIGHEST offsets while still sitting
;		where they were written. Every entry is still right; the file is simply no longer
;		sorted, so the "largest offset <= the one reported" rule means reading the whole file
;		rather than reading down it. Sorting here instead would cost a sort of a 2,048 entry
;		banked table, and the reader can sort.
;
;		It is built straight from the compiler's line-number table (STRMarkLine): 4-byte entries
;		[line# lo, line# hi, addr lo, addr hi], growing DOWNWARD from compilerEndHigh:$00 to
;		lineNumberTable, walked here from the top down. The
;		stored addr is the compile-time position in the object buffer (based at FreeMemory), so
;		offset = addr - FreeMemory -- the same number the runtime reports, because the object is
;		copied verbatim from FreeMemory to its run address. The two synthetic lines the implicit
;		-DIM prologue adds show up as line 65024 ($FE00, the end marker) and 65535 ($FFFF, the
;		prologue); they are real code positions, just not the user's.
;
; ************************************************************************************************

WriteMapFile:
		lda 	OptionsText 				; no third line -> no map asked for.
		bne 	_WMFStart
		rts
_WMFStart:
		ldy 	#OptionsText >> 8 			; open the map file for write (logical file 3, as the
		ldx 	#OptionsText & $FF 			; object write already closed).
		jsr 	IOOpenWrite
		lda 	compilerEndHigh 			; walk from the top of the table ...
		sta 	mapWalk+1
		stz 	mapWalk
_WMFLoop:
		sec 								; ... down one 4-byte entry at a time.
		lda 	mapWalk
		sbc 	#4
		sta 	mapWalk
		lda 	mapWalk+1
		sbc 	#0
		sta 	mapWalk+1
		lda 	mapWalk+1 					; stop once below the last (lowest) entry.
		cmp 	lineNumberTable+1
		bcc 	_WMFDone
		bne 	_WMFEntry
		lda 	mapWalk
		cmp 	lineNumberTable
		bcc 	_WMFDone
_WMFEntry:
		jsr 	_WMFWriteEntry
		bra 	_WMFLoop
_WMFDone:
		jmp 	IOWriteClose

;
;		Write one entry: "<hhhh> <ddddd>",CR. Everything the line needs is pulled out through
;		zTemp0 up front, before any IOWriteByte -- CHROUT to a file is free to trash zero page,
;		but mapValue/mapOff are plain RAM and survive it.
;
_WMFWriteEntry:
		lda 	mapWalk 					; point zTemp0 at the entry.
		sta 	zTemp0
		lda 	mapWalk+1
		sta 	zTemp0+1
		;
		;		The table is in banked RAM now, so page it in for the four reads and page it back
		;		out again before any file I/O -- the KERNAL owns bank 0. That the entry is fully
		;		unpacked into mapValue/mapOff before the first IOWriteByte was already true (see
		;		the note above); it is now load-bearing rather than merely tidy.
		;
		.storage_access
		ldy 	#0 							; line number -> mapValue (consumed by the decimal print)
		lda 	(zTemp0),y
		sta 	mapValue
		ldy 	#1
		lda 	(zTemp0),y
		sta 	mapValue+1
		ldy 	#2 							; offset = stored address - FreeMemory (page aligned)
		lda 	(zTemp0),y
		sec
		sbc 	#FreeMemory & $FF
		sta 	mapOff
		ldy 	#3
		lda 	(zTemp0),y
		sbc 	#FreeMemory >> 8
		sta 	mapOff+1
		.storage_release
		lda 	mapOff+1 					; hex offset, high byte then low.
		jsr 	_WMFHexByte
		lda 	mapOff
		jsr 	_WMFHexByte
		lda 	#' '
		jsr 	IOWriteByte
		jsr 	_WMFDecimal 				; decimal line number.
		lda 	#10 						; LF ends the line -- this file is read on the host (grep,
		jmp 	IOWriteByte 				; VS Code), not the X16, so a Unix newline suits it best.

;
;		A (0..255) as two hex digits. Same trick as the runtime error handler.
;
_WMFHexByte:
		pha
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		jsr 	_WMFNibble
		pla
_WMFNibble:
		and 	#15
		cmp 	#10
		bcc 	_WMFDigit
		adc 	#6 							; carry set here: 10 -> +6+1 = 'A'
_WMFDigit:
		adc 	#48
		jmp 	IOWriteByte

;
;		mapValue (16 bit) as decimal, leading zeros suppressed but always at least one digit.
;		Subtract each power of ten as many times as it goes; the count is the digit.
;
_WMFDecimal:
		stz 	mapLead 					; 0 while we are still dropping leading zeros
		ldx 	#0
_WMFDPow:
		ldy 	#48 						; '0' + number of subtractions = the digit
_WMFDSub:
		sec
		lda 	mapValue
		sbc 	_WMFPow10L,x
		sta 	mapTemp
		lda 	mapValue+1
		sbc 	_WMFPow10H,x
		bcc 	_WMFDUnder 					; borrow -> this power no longer goes
		sta 	mapValue+1
		lda 	mapTemp
		sta 	mapValue
		iny
		bra 	_WMFDSub
_WMFDUnder:
		cpy 	#48 						; a zero digit ...
		bne 	_WMFDEmit
		lda 	mapLead 					; ... is dropped while still leading
		beq 	_WMFDNext
_WMFDEmit:
		lda 	#1
		sta 	mapLead
		tya
		jsr 	IOWriteByte
_WMFDNext:
		inx
		cpx 	#4 							; 10000, 1000, 100, 10
		bne 	_WMFDPow
		lda 	mapValue 					; the units digit is always written
		ora 	#48
		jmp 	IOWriteByte

_WMFPow10L:
		.byte 	<10000, <1000, <100, <10
_WMFPow10H:
		.byte 	>10000, >1000, >100, >10

BootPatchTable: 							; six (addr lo, addr hi, value) triples, built per program
		.fill 	18 							; by the shared path just above -- see the note there.
BootPatchEnd:
sharedCeilPage: 							; page the shared workspace stops at: RTBASE normally,
		.fill 	1 							; RTGPBASE when the GPB handlers sit below it.
runtimeEndPage: 							; first page ABOVE the runtime as written out: GPBase if the
		.fill 	1 							; GP block was dropped, ObjectBase if it was kept.
imgLeft: 									; bytes of the runtime image still to copy, and which
		.fill 	2 							; page of the stream the chunk in hand came from --
imgPage: 									; the patch test is a page compare, see part one.
		.fill 	1
imgCount: 									; size of the chunk in hand, ZERO MEANING 256.
		.fill 	1
newWorkspacePage: 							; first page of workspace in the saved file. In the code
		.fill 	1 							; section, not storage -- see the note in
											; file-io/read.asm.
mapWalk: 									; these too live in the code section, not storage -- they
		.fill 	2 							; belong to the compiler and are thrown away when the
mapValue: 									; object is written, so they cost a compiled program
		.fill 	2 							; nothing. See the note in file-io/read.asm.
mapOff:
		.fill 	2
mapTemp:
		.fill 	2
mapLead:
		.fill 	1

; ************************************************************************************************
;
;		GP.ASM's fixups need BOTH bases, and neither is settled until the two paths above have
;		got this far: where the object will RUN, and where the workspace will start. Patching
;		this late is free -- nothing here changes the object's length, and the buffer is not
;		streamed out until below.
;
;		FreeMemory and newWorkspacePage are application symbols and the assembler lives in the
;		compiler library, which also builds on its own, so the arithmetic has to happen on this
;		side of the line. Both ends are page aligned, so a byte each says all of it.
;
; ************************************************************************************************

AsmSetBases:
		sec 								; embedded: it runs at runtimeEndPage, it sits at
		lda 	runtimeEndPage 				; FreeMemory, and the difference is what every blob
		sbc 	#FreeMemory >> 8 			; address and label target has to move by
		sta 	AsmPageDelta
		lda 	newWorkspacePage
		sta 	AsmWorkspacePage
		rts

AsmSetBasesShared:
		clc
		lda 	#(PCODE_PAGE - (FreeMemory >> 8)) & $FF
		adc 	gpBankActive 				; shared p-code lands at $0900, or $0A00 for a banked
		sta 	AsmPageDelta 				; program -- the extension page is below it
		lda 	newWorkspacePage 			; ObjectPrepareShared carries WS_START in this byte
		sta 	AsmWorkspacePage
		rts

;
;		One page of the runtime image, in transit from GPC.IMG.nnn.BIN to OBJECT.PRG. It is in
;		the code section, so it is compiler space and costs a compiled program nothing -- and
;		it buys back 9,818 bytes of low RAM that used to hold the whole image, so it is the
;		cheapest 256 bytes in the build.
;
imageBuffer:
		.fill 	256

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
