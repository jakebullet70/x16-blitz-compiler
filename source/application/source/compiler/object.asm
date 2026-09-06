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
		jmp 	ObjStreamOpen

; ************************************************************************************************
;
;		OPEN THE OBJECT FILE AND PUT THE RUNTIME IN IT -- everything that goes into the file
;		BEFORE the p-code, and all of it known by the end of pass one.
;
;		ON A LOGICAL FILE OF ITS OWN, because it stays open for the whole of pass two while the
;		source is being read on file 3. See IOOpenObject in file-io/read.asm.
;
;		Carry set = it failed, and it has said why.
;
; ************************************************************************************************

ObjStreamOpen:
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
		jsr 	IOOpenObject 				; open write, on its own logical file
		jsr 	IOSelectObject
		lda 	#1
		sta 	objStreamLive 				; from here on a failure has a file to tidy away

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
		jmp 	ObjStreamReady

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
		jmp 	ObjStreamOpen 				; while it compiles -- see AsmCloseBlock
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
		jsr 	IOOpenObject 				; open write, on its own logical file
		jsr 	IOSelectObject
		lda 	#1
		sta 	objStreamLive 				; from here on a failure has a file to tidy away
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
		;		Part two -- the p-code itself -- follows, and pass two is what writes it.
		;
ObjStreamReady:
		lda 	#$FF 						; the image left CLRCHN behind it, so neither channel
		sta 	ioInSel 					; is known any more
		sta 	ioOutSel
		jsr 	ObjStreamReset 				; an empty buffer for pass two to fill
		clc
		rts


; ************************************************************************************************
;
;		PASS TWO WRITES THE OBJECT AS IT COMPILES IT.
;
;		THE BUFFER IS IN A BANK, and it is there for one reason: a statement that fails to
;		compile with a SYNTAX error is rolled back to where it started and a runtime throw-stub
;		is put in its place (DeferStatementToRuntime). Bytes already sent to the file cannot be
;		taken back, so nothing goes out until the statement that wrote it has compiled. Flushing
;		8K at a time also means the write channel is selected once per 8K rather than once per
;		source line, which is the same trick the runtime image already uses a page at a time.
;
;		A REGION IS A BANK OF ITS OWN. Pass two writes each GP.BANKED region straight to its
;		final address, which is ABOVE the low code it is still emitting -- so the two cannot
;		share one forward-only stream. One bank per region costs nothing (a region is at most
;		8K by definition, and there are at most eight) and makes a region random access, so a
;		rollback inside one simply gets written over.
;
;		THE OBJECT GOES OUT IN FILE ORDER: the low code and the GP.ASM pool as they are
;		compiled, then the alignment padding, then each region out of its bank. That is what
;		lets the checksum stay what it was -- a Fletcher-16 over the finished object -- with
;		pass one summing its buffer and pass two summing what it writes.
;
; ************************************************************************************************

OBJ_BUF_BANK = 7 							; the low code, waiting to go out
OBJ_RGN_BANK = 8 							; ...and one bank per region, 8 upwards
OBJ_WINDOW   = $A000
OBJ_BUF_SIZE = $2000

; ************************************************************************************************
;
;		Start of pass two: an empty buffer, an empty sum, and every region's bank filled with
;		the padding byte.
;
;		THE FILL IS NOT WASTE. Above each region's end marker sits filler that carries it up to
;		a page boundary, and pass two writes none of it -- there is nothing to write. Pass one's
;		relocator fills the same bytes with the same $FF, so the two objects agree.
;
; ************************************************************************************************

ObjStreamReset:
		.set16 	objBufBase, FreeMemory
		.set16 	objBufTop, FreeMemory
		.set16 	objStmtAt, FreeMemory
		stz 	objDeferWas
		stz 	objSum
		stz 	objSum+1
		lda 	#3 							; _variable.space and its operand: the one place the
		sta 	objSumSkip 					; two passes are meant to differ
		;
		lda 	layoutCount
		beq 	_OSRDone
		stz 	objRgnNo
_OSRBank:
		clc
		lda 	objRgnNo
		adc 	#OBJ_RGN_BANK
		jsr 	ObjStreamBank
		lda 	#OBJ_WINDOW >> 8
		sta 	zTemp0+1
		stz 	zTemp0
		lda 	#$FF
_OSRPage:
		ldy 	#0
_OSRByte:
		sta 	(zTemp0),y
		iny
		bne 	_OSRByte
		inc 	zTemp0+1
		ldx 	zTemp0+1
		cpx 	#(OBJ_WINDOW + OBJ_BUF_SIZE) >> 8
		bcc 	_OSRPage
		ldx 	objSaveBank
		stx 	CompilerRAMBankReg
		inc 	objRgnNo
		lda 	objRgnNo
		cmp 	layoutCount
		bcc 	_OSRBank
_OSRDone:
		rts

; ************************************************************************************************
;
;		One object byte, in A, belonging at objPtr. Called from _CAWriteByte in pass two.
;
;		zTemp0 AND zTemp1 ARE BORROWED AND GIVEN STRAIGHT BACK. This runs between two
;		instructions of whatever generator is emitting, and they hold live pointers in both of
;		them.
;
; ************************************************************************************************

ObjStreamByte:
		sta 	objByte
		lda 	zTemp0
		pha
		lda 	zTemp0+1
		pha
		lda 	zTemp1
		pha
		lda 	zTemp1+1
		pha
		jsr 	ObjStreamWork
		pla
		sta 	zTemp1+1
		pla
		sta 	zTemp1
		pla
		sta 	zTemp0+1
		pla
		sta 	zTemp0
		rts

ObjStreamWork:
		;
		;		A statement that has just armed itself: remember where it begins. Nothing from
		;		there on can go out until it has compiled, because a SYNTAX error rolls the write
		;		cursor back to it and puts a throw-stub in its place.
		;
		lda 	deferErrors
		beq 	_OSWKeep
		ldx 	objDeferWas
		bne 	_OSWArmed
		lda 	objPtr
		sta 	objStmtAt
		lda 	objPtr+1
		sta 	objStmtAt+1
_OSWArmed:
		lda 	#1
_OSWKeep:
		sta 	objDeferWas
		;
		lda 	regionOpen 					; inside a GP.BANKED region ?
		bne 	_OSWRegion
		jsr 	ObjStreamOffset 			; where in the buffer it goes
		bcs 	_OSWLow
		jsr 	ObjStreamFlush 				; full: send out what can go, and ask again
		jsr 	ObjStreamOffset
		bcc 	_OSWLost
_OSWLow:
		lda 	#OBJ_BUF_BANK
		jsr 	ObjStreamWindow
		lda 	objByte
		sta 	(zTemp0)
		clc 								; the buffer now holds everything up to here, and a
		lda 	objPtr 						; statement rolled back lowers this with it
		adc 	#1
		sta 	objBufTop
		lda 	objPtr+1
		adc 	#0
		sta 	objBufTop+1
		bra 	_OSWClose
;
;		A single statement whose p-code is longer than the whole buffer, which no BASIC line can
;		produce: a tokenised source line is 252 bytes at most.
;
_OSWLost:
		.error_internal
;
;		Inside a region, which is a bank of its own -- random access, so a rollback here is
;		simply written over and there is nothing to hold back.
;
_OSWRegion:
		lda 	nextRegion
		asl 	a
		tax
		sec
		lda 	objPtr
		sbc 	layoutStart,x
		sta 	objBufIdx
		lda 	objPtr+1
		sbc 	layoutStart+1,x
		sta 	objBufIdx+1
		clc
		lda 	nextRegion
		adc 	#OBJ_RGN_BANK
		jsr 	ObjStreamWindow
		lda 	objByte
		sta 	(zTemp0)
_OSWClose:
		lda 	objSaveBank
		sta 	CompilerRAMBankReg
		rts

;
;		objBufIdx = objPtr - objBufBase, with carry set if that is inside the window.
;
ObjStreamOffset:
		sec
		lda 	objPtr
		sbc 	objBufBase
		sta 	objBufIdx
		lda 	objPtr+1
		sbc 	objBufBase+1
		sta 	objBufIdx+1
		bcc 	_OSOOut 					; below it: rolled back past what is still held
		cmp 	#OBJ_BUF_SIZE >> 8
		bcs 	_OSOOut
		sec
		rts
_OSOOut:
		clc
		rts

;
;		Select bank A, remembering the caller's, and point zTemp0 at OBJ_WINDOW + objBufIdx.
;
ObjStreamWindow:
		jsr 	ObjStreamBank
		lda 	objBufIdx
		sta 	zTemp0
		clc
		lda 	objBufIdx+1
		adc 	#OBJ_WINDOW >> 8
		sta 	zTemp0+1
		rts

ObjStreamBank:
		pha
		lda 	CompilerRAMBankReg
		sta 	objSaveBank
		pla
		sta 	CompilerRAMBankReg
		rts

; ************************************************************************************************
;
;		Send what the buffer holds to the file -- everything, or everything below the statement
;		in flight, which then moves down to the bottom of the window so the buffer is empty
;		behind it.
;
; ************************************************************************************************

ObjStreamFlush:
		lda 	deferErrors
		beq 	_OSFAll
		lda 	objStmtAt
		ldy 	objStmtAt+1
		bra 	_OSFTo
_OSFAll:
		lda 	objBufTop
		ldy 	objBufTop+1
_OSFTo:
		sec 								; how many bytes can go
		sbc 	objBufBase
		sta 	objFlushLen
		tya
		sbc 	objBufBase+1
		sta 	objFlushLen+1
		lda 	objFlushLen
		ora 	objFlushLen+1
		bne 	_OSFSome
		rts 								; nothing can go yet
_OSFSome:
		jsr 	IOSelectObject
		stz 	objBufIdx
		stz 	objBufIdx+1
_OSFLoop:
		lda 	objBufIdx
		cmp 	objFlushLen
		lda 	objBufIdx+1
		sbc 	objFlushLen+1
		bcs 	_OSFWritten
		lda 	#OBJ_BUF_BANK 				; the window closes again before every write: the
		jsr 	ObjStreamWindow 			; KERNAL's own buffers live in bank 0
		lda 	(zTemp0)
		ldx 	objSaveBank
		stx 	CompilerRAMBankReg
		jsr 	ObjEmit
		inc 	objBufIdx
		bne 	_OSFLoop
		inc 	objBufIdx+1
		bra 	_OSFLoop
_OSFWritten:
		lda 	deferErrors 				; nothing was held back, so nothing has to move
		beq 	_OSFRebase
		sec
		lda 	objBufTop
		sbc 	objStmtAt
		sta 	objMoveLen
		lda 	objBufTop+1
		sbc 	objStmtAt+1
		sta 	objMoveLen+1
		ora 	objMoveLen
		beq 	_OSFRebase
		;
		lda 	#OBJ_BUF_BANK
		jsr 	ObjStreamBank
		clc
		lda 	objFlushLen
		sta 	zTemp0
		lda 	objFlushLen+1
		adc 	#OBJ_WINDOW >> 8
		sta 	zTemp0+1
		.set16 	zTemp1, OBJ_WINDOW
_OSFMove:
		lda 	(zTemp0)
		sta 	(zTemp1)
		inc 	zTemp0
		bne 	_OSFMSrc
		inc 	zTemp0+1
_OSFMSrc:
		inc 	zTemp1
		bne 	_OSFMDst
		inc 	zTemp1+1
_OSFMDst:
		lda 	objMoveLen
		bne 	_OSFMLow
		dec 	objMoveLen+1
_OSFMLow:
		dec 	objMoveLen
		lda 	objMoveLen
		ora 	objMoveLen+1
		bne 	_OSFMove
		lda 	objSaveBank
		sta 	CompilerRAMBankReg
_OSFRebase:
		clc
		lda 	objBufBase
		adc 	objFlushLen
		sta 	objBufBase
		lda 	objBufBase+1
		adc 	objFlushLen+1
		sta 	objBufBase+1
_OSFNone:
		rts

; ************************************************************************************************
;
;		One byte into the file, and into the running Fletcher-16 of the object. The first three
;		-- _variable.space and its operand -- are written but not summed: they are the one place
;		the two passes are meant to differ, and ObjectChecksum skips them on the other side.
;
; ************************************************************************************************

ObjEmit:
		pha
		lda 	objSumSkip
		beq 	_OEMSum
		dec 	objSumSkip
		bra 	_OEMWrite
_OEMSum:
		pla
		pha
		clc
		adc 	objSum 						; sum1 += byte
		sta 	objSum
		clc
		adc 	objSum+1 					; sum2 += sum1, so a reordering shows up too
		sta 	objSum+1
_OEMWrite:
		pla
		jmp 	IOWriteByte

; ************************************************************************************************
;
;		END OF PASS TWO: everything the buffer still holds, then the alignment padding below the
;		first GP.BANKED region, then each region out of its bank.
;
;		THE SUM COMES BACK IN YA with carry set, and the compiler compares it against pass one's.
;		Carry clear would mean "no sum, walk the object yourself", which is what the native test
;		harness answers -- it keeps its object in a bank and the walk still works there.
;
; ************************************************************************************************

ObjStreamClose:
		jsr 	ObjStreamFlush 				; deferErrors is zero at the end of a compile, so
											; this empties it
		lda 	layoutCount
		bne 	_OSCPlaced
		jmp 	_OSCSum 					; no regions: the buffer was the whole object
_OSCPlaced:
		jsr 	IOSelectObject
		;
		;		The padding. One gap only: every region above the first starts exactly where the
		;		one below it ends, which is what the filler is for.
		;
		lda 	objBufTop
		sta 	objPadAt
		lda 	objBufTop+1
		sta 	objPadAt+1
_OSCPad:
		lda 	objPadAt
		cmp 	layoutStart
		bne 	_OSCPadByte
		lda 	objPadAt+1
		cmp 	layoutStart+1
		beq 	_OSCRegions
_OSCPadByte:
		lda 	#$FF
		jsr 	ObjEmit
		inc 	objPadAt
		bne 	_OSCPad
		inc 	objPadAt+1
		bra 	_OSCPad
;
;		...and the regions, in source order, which is the order they sit in. A region's span is
;		where the next one starts, or the object's own end for the topmost.
;
_OSCRegions:
		stz 	objRgnNo
_OSCRegion:
		lda 	objRgnNo
		cmp 	layoutCount
		bcc 	_OSCMore
		jmp 	_OSCSum
_OSCMore:
		asl 	a
		tax
		lda 	objRgnNo
		inc 	a
		cmp 	layoutCount
		bcs 	_OSCTop
		lda 	layoutStart+2,x
		sta 	objSpan
		lda 	layoutStart+3,x
		sta 	objSpan+1
		bra 	_OSCSpan
_OSCTop:
		lda 	pass1Len
		sta 	objSpan
		lda 	pass1Len+1
		sta 	objSpan+1
_OSCSpan:
		sec
		lda 	objSpan
		sbc 	layoutStart,x
		sta 	objSpan
		lda 	objSpan+1
		sbc 	layoutStart+1,x
		sta 	objSpan+1
		;
		stz 	objBufIdx
		stz 	objBufIdx+1
_OSCByte:
		lda 	objBufIdx
		cmp 	objSpan
		lda 	objBufIdx+1
		sbc 	objSpan+1
		bcs 	_OSCNext
		clc
		lda 	objRgnNo
		adc 	#OBJ_RGN_BANK
		jsr 	ObjStreamWindow
		lda 	(zTemp0)
		ldx 	objSaveBank
		stx 	CompilerRAMBankReg
		jsr 	ObjEmit
		inc 	objBufIdx
		bne 	_OSCByte
		inc 	objBufIdx+1
		bra 	_OSCByte
_OSCNext:
		inc 	objRgnNo
		bra 	_OSCRegion
_OSCSum:
		lda 	objSum
		ldy 	objSum+1
		sec 								; the sum is here -- see BLC_ENDPASS2
		rts

objBufBase: 								; the objPtr of the first byte still in the buffer
		.fill 	2
objBufTop: 									; ...and one past the last
		.fill 	2
objStmtAt: 									; where the statement in flight began
		.fill 	2
objBufIdx: 									; an offset into whichever window is open
		.fill 	2
objFlushLen: 								; how many bytes this flush is sending
		.fill 	2
objMoveLen: 								; ...and how many it is shuffling down afterwards
		.fill 	2
objPadAt: 									; the alignment gap being filled
		.fill 	2
objSpan: 									; the region being written out
		.fill 	2
objSum: 									; Fletcher-16 over what has gone into the file
		.fill 	2
objSumSkip: 								; bytes still to be written but not summed
		.fill 	1
objByte: 									; the byte in hand, across the zTemp save
		.fill 	1
objDeferWas: 								; deferErrors as it stood at the last byte
		.fill 	1
objRgnNo: 									; the region being filled or written
		.fill 	1
objSaveBank: 								; the caller's RAM bank, across a window
		.fill 	1

; ************************************************************************************************
;
;		A COMPILE THAT STOPS LEAVES NO OBJECT. The file is created before pass two starts now,
;		so a failure anywhere in pass two would otherwise leave a truncated one behind -- and at
;		the filesystem level that is indistinguishable from a program.
;
; ************************************************************************************************

ObjStreamAbort:
		lda 	objStreamLive
		beq 	_OSADone
		stz 	objStreamLive
		jsr 	IOObjectClose
		ldx 	#ObjectFile & $FF
		ldy 	#ObjectFile >> 8
		jmp 	IOScratchFile
_OSADone:
		rts

objStreamLive: 								; nonzero while there is a half written object file
		.fill 	1
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
		jsr 	ObjStreamAbort 				; the object file may already exist -- see above
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
