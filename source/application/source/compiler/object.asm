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
		;
		;		AND THE WHOLE FILE HAS TO FIT UNDER IT.
		;
		;		THE REGIONS ARE NO LONGER IN IT. They used to be -- compiled into the object,
		;		loaded at $0801 with everything else, copied up to $A000 from there -- so the file
		;		test had to count them and the workspace test did not, and the two measured
		;		different lengths. Now each region is a .Bnn file of its own that loads straight
		;		into its bank, so the file ends where the low code ends, which is exactly what the
		;		workspace test already measured into zTemp1. THAT IS THE WHOLE RETURN on the
		;		overlays: a banked byte stops paying file price to arrive.
		;
		;		SO THE TEST IS NOW IMPLIED by the one below -- same length, and below adds the
		;		frame stack and a minimum workspace on top of it before comparing. It stays
		;		because it is the check that names the failure the file has, it costs a compiled
		;		program nothing, and the day something is written after the low code again it is
		;		the one that notices.
		;
		;		NOTHING REPORTED THIS AT ALL until 7th September 2026, when GPBMODS compiled clean
		;		703 bytes over and read machine code out of its own text bank -- the directory
		;		intact, the records past the overlap replaced.
		;
		lda 	zTemp1 						; the low code, which is now the whole file
		sta 	zTemp0
		lda 	zTemp1+1
		sta 	zTemp0+1
		;
		;		THE SAME BASE THE WORKSPACE IS COUNTED FROM, and it has to be: the file loads at
		;		$0801 but its p-code does not start there. PCODE_PAGE is where that lands, plus
		;		the bootstrap extension page a banked program carries -- 511 bytes of prefix in
		;		GPBMODS's case, which is two pages, which is exactly the margin this test was
		;		wrong by when it counted from page 8 instead.
		;
		clc
		lda 	#PCODE_PAGE
		adc 	gpBankActive
		adc 	zTemp0+1
		bcs 	_WOCSBigFar
		cmp 	sharedCeilPage 				; ending exactly ON the ceiling is fine: the last
		beq 	_WOCSFileFits 				; byte written is the one below it
		bcs 	_WOCSBigFar
_WOCSFileFits:
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
;		trampoline the embedded path needs for its image failures, for the same reason.
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
		bne 	_WOCSExtPage 				; jmp: the page is built and patched below, which the two
		jmp 	_WOCSCodePart 				; tables put out of a branch's reach
_WOCSExtPage:
		.set16 	zTemp0,ProgramBootExt
		.set16 	zTemp1,imageBuffer
		ldy 	#0 							; 256 bytes exactly, so Y wraps to end it
_WOCSExtCopy:
		lda 	(zTemp0),y
		sta 	(zTemp1),y
		iny
		bne 	_WOCSExtCopy
		;
		;		The bank table -- ONE BYTE A REGION now, and no page counts: each region is a file
		;		of its own and LOAD knows how long a file is. The terminating zero is already
		;		there, because the template's table is a .fill of zeroes and bank 0 is refused
		;		everywhere else in the compiler.
		;
		;		ORDER DOES NOT MATTER ANY MORE, which it used to: the copy loop ran on from one
		;		region into the next and so needed the pages in the order they sat in. Each file
		;		carries its own load address now, so the table is only a list of banks.
		;
		;		AND THE NAME THE LOADER ASKS FOR, once, with "B00" on the end -- the extension
		;		page pokes the bank's two digits into it per region. See ObjBuildOverlayName.
		;
		;
		;		AND WHICH BANK EACH GP.BSTR SLOT READS ITS TEXT OUT OF -- the whole table, not the
		;		slots in use, because a slot the program never filled is zero and never read: the
		;		compiler only ever emits a slot it has filled in. Copying all of it means nothing
		;		here has to know how many there are.
		;
		ldx 	#BSTR_MAX_BANKS-1
_WOCSExtBStr:
		lda 	bstrBankNums,x
		sta 	imageBuffer+BootExtBStrOffset,x
		dex
		bpl 	_WOCSExtBStr
		;
		ldx 	#0
_WOCSExtTable:
		lda 	gpBankBanks,x
		sta 	imageBuffer+BootExtTableOffset,x
		inx
		cpx 	gpBankCount
		bcc 	_WOCSExtTable
		;
		lda 	#0 							; bank 0, so the template comes out as "...B00"
		jsr 	ObjBuildOverlayName
		ldx 	ovlNameLen
		cpx 	#BXNAMEMAX+1
		bcs 	_WOCSExtNameLong
		stx 	imageBuffer+BootExtNameLenOffset
_WOCSExtName:
		dex
		lda 	OvlFileName,x
		sta 	imageBuffer+BootExtNameOffset,x
		txa
		bne 	_WOCSExtName
		bra 	_WOCSExtWrite2
;
;		THE NAME IS BOUNDED BY THE PAGE, and only here. GPC.INPUT allows 63 characters and the
;		extension page has room for BXNAMEMAX, so a longer object name has nowhere to put the
;		template the loader reads. It is the file NAME that is bounded and never the program --
;		and only a program with a region ever asks, which is why the test is here and not in the
;		name builder.
;
;		COMPILER SPACE, not errors.asm: that table links below GPBase and is copied into every
;		compiled program, so a message there would cost bytes to every program that never writes
;		a GP.BANKED. Same trick as gpasmcode.asm's _APBUnknown.
;
_WOCSExtNameLong:
		jsr 	CallErrorHandler
		.text 	"OBJECT NAME TOO LONG FOR AN OVERLAY", 0
_WOCSExtWrite2:
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
;		share one forward-only stream. One bank per region makes a region random access, so a
;		rollback inside one simply gets written over.
;
;		ONE SCRATCH BANK SERVES THEM ALL, and that is why the region count is not bounded by
;		banks. It used to be a bank a region, justified as costing nothing because "a region is
;		at most 8K by definition, and there are at most eight" -- which is circular: it is only
;		cheap while the count is small, and the count is what the compiler is meant to stop
;		capping. Sixteen regions took banks 8 to 23, and sixty-three would have run off the top.
;
;		ONLY ONE REGION IS EVER OPEN. regionOpen is a boolean and nextRegion a single index, and
;		gpbank.asm refuses a GP.BANKED inside an open region. Nothing writes into a region after
;		it closes either -- the exit bridge and the $FF end marker go in while the cursor is
;		still inside it, the entry bridge lands in low memory before the cursor moves, and pass
;		two never goes back over what it has written. So the bank is cleared as a region opens
;		and emptied to the region's own .Bnn as it closes, and the next region has it.
;
;		THE OBJECT GOES OUT IN FILE ORDER: the low code and the GP.ASM pool as they are
;		compiled, then the alignment padding, then each region out of its bank. That is what
;		lets the checksum stay what it was -- a Fletcher-16 over the finished object -- with
;		pass one summing its buffer and pass two summing what it writes.
;
; ************************************************************************************************

OBJ_BUF_BANK = 7 							; the low code, waiting to go out
OBJ_RGN_BANK = 8 							; ...and the one scratch bank every region shares
OBJ_WINDOW   = $A000
OBJ_BUF_SIZE = $2000

; ************************************************************************************************
;
;		Start of pass two: an empty buffer and an empty sum. The scratch bank is NOT filled
;		here -- ObjStreamRegionFill does that as each region opens.
;
; ************************************************************************************************

ObjStreamReset:
		.set16 	objBufBase, FreeMemory
		.set16 	objBufTop, FreeMemory
		.set16 	objStmtAt, FreeMemory
		stz 	objHold
		rts

; ************************************************************************************************
;
;		A region is opening: clear the shared scratch bank to the padding byte. BLC_REGIONOPEN.
;
;		THE FILL IS NOT WASTE, AND IT IS PER REGION BECAUSE THE BANK IS SHARED. Above each
;		region's end marker sits filler that carries it up to a page boundary, and pass two
;		writes none of it -- there is nothing to write. Pass one's relocator fills the same bytes
;		with the same $FF, so the two objects agree. Leave the PREVIOUS region's bytes sitting
;		there and they do not, and the two-pass check reports an internal error a long way from
;		the cause.
;
; ************************************************************************************************

ObjStreamRegionFill:
		lda 	#OBJ_RGN_BANK
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
		;		A statement that has armed itself: remember where it begins. Nothing from there on
		;		can go out until it has compiled, because a SYNTAX error rolls the write cursor
		;		back to it and puts a throw-stub in its place.
		;
		;		ONLY IF IT BEGINS IN THE LOW BUFFER. A region is a bank of its own and therefore
		;		random access, so a rollback inside one is written over where it stands and
		;		nothing has to be held for it -- and holding a REGION address as the low buffer's
		;		high-water mark makes the flush length a subtraction of two unrelated addresses.
		;
		lda 	deferErrors
		bne 	_OSWArming
		stz 	objHold 					; the statement compiled: nothing is held back now
		bra 	_OSWPlace
_OSWArming:
		lda 	objHold 					; already holding for this one
		bne 	_OSWPlace
		lda 	regionOpen
		bne 	_OSWPlace
		lda 	objPtr
		sta 	objStmtAt
		lda 	objPtr+1
		sta 	objStmtAt+1
		inc 	objHold
_OSWPlace:
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
		bcc 	_OSWDiverged 				; below the region, or past $BFFF -- and neither happens
		cmp 	#OBJ_BUF_SIZE >> 8 			; unless pass two wrote more than pass one did
		bcs 	_OSWDiverged
		lda 	#OBJ_RGN_BANK 				; one bank, shared -- only one region is ever open
		jsr 	ObjStreamWindow
		lda 	objByte
		sta 	(zTemp0)
_OSWClose:
		lda 	objSaveBank
		sta 	CompilerRAMBankReg
		rts

;
;		PASS TWO WROTE MORE THAN PASS ONE DID, which is the only way to get here: an oversized
;		region is stopped at the end of pass one by GPBankRelocate, and pass two is never reached.
;		The two-pass agreement check finds this too, but not until the end of the pass -- and by
;		then the stores have landed. Past 8K they go to $C000, which is ROM and discards them
;		silently; past 24K the add above wraps and they go to ZERO PAGE and low RAM, corrupting
;		the compiler that is meant to report it. Four instructions, and it says so instead.
;
;		TESTED BEFORE ObjStreamWindow, deliberately: that leaves the region's bank selected for
;		the caller to put back, and an error raised with it open would run all the way out --
;		handler, ExitCompiler, caller -- in the wrong bank. ObjStreamOffset tests in the same
;		place, for the same reason.
;
_OSWDiverged:
		.error_internal

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
		lda 	objHold
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
		jsr 	IOWriteByte
		inc 	objBufIdx
		bne 	_OSFLoop
		inc 	objBufIdx+1
		bra 	_OSFLoop
_OSFWritten:
		lda 	objHold 					; nothing was held back, so nothing has to move
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
;		END OF PASS TWO: everything the buffer still holds, and then each region out of its bank
;		into a file of its own. After this the object and its overlays are complete on disk.
;
;		THE ALIGNMENT PADDING IS GONE WITH THE REGIONS. It existed only because the regions
;		followed the low code in one file and had to start on a page boundary within it; nothing
;		follows the low code now, so there is nothing to align to. Its loop compared for EQUALITY
;		only, so a cursor that had run past layoutStart wrapped and padded forward with 65,535
;		bytes of filler, with nothing saying so. It bit twice. See
;		docs/memory/object-writer-regions-vs-low-code.md.
;
;		HERE AND NOT AT REGION CLOSE, deliberately, and the difference is IO rather than layout.
;		By here the source has been read to its end, so opening and filling a second output file
;		cannot interleave with reading it -- and IOSelectObject / IOSelectSource invalidate each
;		other on every flip, which is the trap that cost an afternoon on 06/09/26. What is
;		already proven is that an output file can be HELD open across source reads: the object
;		is. That a second one can be WRITTEN mid-compile is not, and this does not need it.
;
;		THE EMIT IS A ROUTINE TAKING ONE REGION so that it can move later. Sharing one scratch
;		bank between regions means flushing each as it closes, and then what moves to _RSClosing
;		is a CALL and this loop is what stops existing.
;
; ************************************************************************************************

ObjStreamClose:
		stz 	objHold 					; nothing is in flight at the end of a compile, so the
		jmp 	ObjStreamFlush 				; flush empties the buffer -- and every region has already
											; gone out, each one as it closed

; ************************************************************************************************
;
;		The region in nextRegion is finished: work out how long it is and send it out to its own
;		overlay file. BLC_REGIONDONE, from both of the close sites.
;
;		THE SPAN IS PASS ONE'S ARITHMETIC, AND IT IS SETTLED THE WHOLE TIME. A region runs from
;		its own layoutStart to where the NEXT one starts, or to pass1Len for the topmost, and all
;		of those are known before pass two writes a byte. So this asks at region close exactly
;		what the end-of-compile loop used to ask afterwards, and gets the same answer.
;
; ************************************************************************************************

ObjEmitRegion:
		lda 	nextRegion 					; the one that has just closed
		sta 	objRgnNo
		asl 	a
		tax
		lda 	objRgnNo
		inc 	a
		cmp 	layoutCount
		bcs 	_OERTop
		lda 	layoutStart+2,x
		sta 	objSpan
		lda 	layoutStart+3,x
		sta 	objSpan+1
		bra 	_OERSpan
_OERTop:
		lda 	pass1Len
		sta 	objSpan
		lda 	pass1Len+1
		sta 	objSpan+1
_OERSpan:
		sec
		lda 	objSpan
		sbc 	layoutStart,x
		sta 	objSpan
		lda 	objSpan+1
		sbc 	layoutStart+1,x
		sta 	objSpan+1
		jmp 	ObjEmitOverlay

; ************************************************************************************************
;
;		Region objRgnNo, objSpan bytes of it, out to <object>.Bnn -- nn being the bank it will
;		load into. Two bytes of header saying $A000 and then the bytes, so the KERNAL's LOAD
;		with secondary address 1 puts it where it belongs and the bootstrap does no arithmetic
;		at all.
;
;		SCRATCHED BEFORE IT IS OPENED. "name,S,W" refuses to open over a file that already
;		exists -- which is what IODeleteOutputs is for -- and quite apart from that, a stale
;		overlay beside a fresh program is the one pairing that loads, runs, and is wrong.
;
; ************************************************************************************************

ObjEmitOverlay:
		ldx 	objRgnNo 					; the bank this region belongs in, which is what names
		lda 	gpBankBanks,x 				; the file. Pass two neither records nor revalidates
		jsr 	ObjBuildOverlayName 		; the bank table, so this is still pass one's.
		ldx 	#OvlFileName & $FF
		ldy 	#OvlFileName >> 8
		jsr 	IOScratchFile
		ldx 	#OvlFileName & $FF
		ldy 	#OvlFileName >> 8
		jsr 	IOOpenOverlay
		lda 	#1
		sta 	ovlStreamLive 				; from here on a failure has this to tidy away too
		jsr 	IOSelectOverlay
		lda 	#OBJ_WINDOW & $FF 			; the load address, low byte first
		jsr 	IOWriteByte
		lda 	#OBJ_WINDOW >> 8
		jsr 	IOWriteByte
		;
		stz 	objBufIdx
		stz 	objBufIdx+1
_OEOByte:
		lda 	objBufIdx
		cmp 	objSpan
		lda 	objBufIdx+1
		sbc 	objSpan+1
		bcs 	_OEODone
		lda 	#OBJ_RGN_BANK 				; the window closes again before every write: the
		jsr 	ObjStreamWindow 				; KERNAL's own buffers live in bank 0
		lda 	(zTemp0)
		ldx 	objSaveBank
		stx 	CompilerRAMBankReg
		jsr 	IOWriteByte
		inc 	objBufIdx
		bne 	_OEOByte
		inc 	objBufIdx+1
		bra 	_OEOByte
_OEODone:
		stz 	ovlStreamLive
		jmp 	IOOverlayClose

; ************************************************************************************************
;
;		ObjectFile with its extension replaced by ".Bnn", nn being the bank in A. Modelled on
;		SymBuildName, which does the same job for the .SYM -- and like it, a name with no dot at
;		all gets the suffix appended rather than nothing.
;
;		BOTH DIGITS, ALWAYS, and that is not cosmetic: the bootstrap holds ONE name and pokes the
;		bank into the last two characters of it, because sixteen names at sixteen characters
;		would be 256 bytes of a page with under 200 spare. A fixed width is what lets one
;		template serve every region.
;
;		WHICH IS WHY THE BANK STOPS AT 99. GPBankReadNumber refuses higher and says so, rather
;		than letting bank 100 come out as ".B:0" -- see commands/gpbank.asm.
;
;		NO LENGTH CHECK HERE. It is the extension page's TEMPLATE that the page has to hold, so
;		that is where the bound is tested -- see _WOCSExtNameLong. This buffer is CFLineSize+8
;		and a name cannot outgrow it.
;
; ************************************************************************************************

ObjBuildOverlayName:
		sta 	ovlBank
		ldx 	#0
		ldy 	#0 							; Y = length up to and including the last dot, 0 = none
_OBONCopy:
		lda 	ObjectFile,x
		beq 	_OBONEnd
		sta 	OvlFileName,x
		cmp 	#'.'
		bne 	_OBONNext
		txa
		tay
		iny 								; keep the dot itself
_OBONNext:
		inx
		cpx 	#CFLineSize
		bne 	_OBONCopy
_OBONEnd:
		cpy 	#0
		beq 	_OBONAppend 				; no dot at all -- append ".Bnn" to the whole name
		tya
		tax
		bra 	_OBONSuffix
_OBONAppend:
		lda 	#'.'
		sta 	OvlFileName,x
		inx
_OBONSuffix:
		lda 	#'B'
		sta 	OvlFileName,x
		inx
		lda 	ovlBank 					; the bank in decimal, tens in Y and units in A
		ldy 	#'0'
_OBONTens:
		cmp 	#10
		bcc 	_OBONUnits
		sbc 	#10 						; carry is set -- the compare above put it there
		iny
		bra 	_OBONTens
_OBONUnits:
		clc
		adc 	#'0'
		pha
		tya
		sta 	OvlFileName,x
		inx
		pla
		sta 	OvlFileName,x
		inx
		stz 	OvlFileName,x 				; ASCIIZ, for IOScratchFile and IOSetFileName
		stx 	ovlNameLen
		rts

ovlBank: 									; the region's bank, across the name build
		.fill 	1
ovlNameLen: 								; ...and how long the name came out
		.fill 	1
ovlStreamLive: 								; nonzero while there is a half written overlay
		.fill 	1
OvlFileName: 								; code section, like every other compiler buffer -- see
		.fill 	CFLineSize+8 				; the note in file-io/read.asm


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
objSpan: 									; the region being written out
		.fill 	2
objByte: 									; the byte in hand, across the zTemp save
		.fill 	1
objHold: 									; nonzero while the low buffer is holding a statement
		.fill 	1 							; back, because it might yet be rolled back
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
		;
		;		THE OVERLAY IN FLIGHT FIRST, if there is one -- OvlFileName still holds its name,
		;		because ObjEmitOverlay is the only thing that writes it and it had not finished.
		;		A truncated region is worse than a truncated object: the object is at least short
		;		against a length the loader knows, and a short overlay simply loads and runs.
		;
		lda 	ovlStreamLive
		beq 	_OSAObject
		stz 	ovlStreamLive
		jsr 	IOOverlayClose
		ldx 	#OvlFileName & $FF
		ldy 	#OvlFileName >> 8
		jsr 	IOScratchFile
_OSAObject:
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
