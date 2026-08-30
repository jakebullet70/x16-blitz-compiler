; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		common.inc
;		Purpose:	Common includes/defines/setups
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;										Configuration options
;
;			  Addresses should be on page boundaries (except for ZeroPageMandatory)
;
; ************************************************************************************************
;
;		Where to assemble the runnable code. Happy now , Dave ?
;
;		Weak so the standalone resident-runtime build (GPC.RT.nnn.BIN) can override it to RTBASE
;		with -D CodeStart on the command line; every other build keeps $801.
;
		.weak
CodeStart = $801
		.endweak
;
;		Variables that have to be in zero page because it's used in (xx),y
;
ZeroPageMandatory = $22
;
;		Variables that can go anywhere
;
MemoryStorage = $400
;
;		Resident-runtime (GPC.RT.nnn.BIN) ABI -- see application/source/compiler/bootstrap.asm and
;		runtime/source/main/00rt.header. RTBASE is the fixed home the standalone runtime is linked
;		at and loaded to; a shared-mode program's bootstrap checks the magic there, loads it if
;		absent, and enters at RT_ENTRY. RTBASE is PINNED (baked into every shared program's
;		bootstrap), so it is an ABI constant, not auto-computed; zzrt.footer guards it against the
;		runtime outgrowing $9F00.
;
;
;		RTBASE moved $7300 -> $7000 on 31st July 2026 (RT_ABI 1 -> 2). The runtime had outgrown the
;		$9F00 I/O page by 447 bytes and zzrt.footer's guard had been failing the gpc-rt link for
;		some time -- shared mode could not be built at all. Three pages down frees 768 bytes and
;		leaves ~320 spare, at the cost of the same 768 bytes of per-program workspace (~3% of the
;		~26K a shared program gets). If it happens again, lower this and bump RT_ABI together.
;
;
;		AND AGAIN on 16th August 2026, exactly as warned above. The runtime had crept to $9EFF --
;		ONE byte under the ceiling -- so the ~200 bytes added by ReuseForFrame, GP.EXITDO and
;		GP.CALL overflowed it.
;
;		EIGHT pages down this time, not the three that just proved too timid. Every move of RTBASE
;		costs an RT_ABI bump (a resident runtime is keyed on the ordinal, and one built at another
;		base is not interchangeable), so the cheap moment to take the room is while a bump is
;		already happening -- RT_ABI was going 5 -> 6 for GP.CALL's opcodes regardless. Four pages
;		would have left 940 bytes, which does NOT cover the ~1,545 GP.BASIC still has to add;
;		eight leaves ~1,960 and ends the matter. Cost is 2K of the ~26K a shared program gets.
;
; ************************************************************************************************
;
;		AND A THIRD TIME on 17th August 2026: $6800 -> $6400, four pages, BEFORE hitting the wall
;		rather than after. The runtime had 1,061 bytes left under the ceiling and the rest of
;		GP.BASIC (stash/restore, drawing, the menu loop) projects to ~1,400 -- measured, not
;		guessed: the estimates in GP-BASIC.TIERS.md have run 1.62x over on average, with GP.SORT
;		at 2.55x and GP.ARRPTR at 3.27x.
;
;		Four pages, not the two that would just cover the projection, for the reason written twice
;		above: three pages "proved too timid" and the note then said take the room while a bump is
;		already free. Leaves ~690 bytes of margin after everything planned. Costs 1K of the ~26K a
;		shared program gets, about 4%.
;
; ************************************************************************************************
; ************************************************************************************************
;
;		SPLIT IN TWO on 18th August 2026 (RT_ABI 18 -> 19), so a shared program that uses no GPB
;		keyword does not have to keep the GPB handlers out of its workspace.
;
;		The GPB block is now linked at the BOTTOM of the shared image and the interpreter core
;		above it, at a base that does not move:
;
;			RTGPBASE  $6600   [ GPB handlers ..................... ][ GP magic ]
;			RTBASE    $6E00   [ magic ][ jmp StartRuntime ][ core ... ] up to ~$9D00
;
;		ONE assembly still, and one vector table -- the two FILES rtname.py installs are slices
;		of the same image, so the core's bytes are identical in both and there is no second
;		build to keep in step:
;
;			GPC.RT.nnn.BIN   loads at RTGPBASE -- GPB handlers AND core
;			GPC.RC.nnn.BIN   loads at RTBASE   -- core only
;
;		A program's workspace then ends at RTBASE if it uses no GPB keyword and at RTGPBASE if it
;		does, which is 2,560 bytes back for the first kind and no change at all for the second.
;
;		WHY THE CORE IS ON TOP and not the other way round: the core has to sit at ONE address
;		whichever file was loaded, or a program could not enter a runtime the previous program
;		brought up. Only the OPTIONAL half can be the half that moves the boundary, so the
;		optional half has to be the low one.
;
;		RTGPMAGIC is how a GPB program tells the two apart. The core magic at RTBASE says "a
;		runtime is up"; it cannot also say "and the handlers are with it", because a core-only
;		load leaves the core magic looking exactly the same. So the GPB half carries its own
;		magic in the four bytes immediately below RTBASE, and a GPB program checks both. It sits
;		THERE rather than at RTGPBASE so a core-only program's workspace -- which runs up to
;		RTBASE -- overwrites it as a matter of course, and the next GPB program correctly finds
;		the handlers gone and reloads them.
;
; ************************************************************************************************
RTGPBASE = $6600 							; GPB handler block + load address of the FULL file
RTBASE = $6E00 								; interpreter core home -- the base that never moves
RT_ENTRY = RTBASE+4 						; 4-byte magic at RTBASE, then jmp StartRuntime
RTGPMAGIC = RTBASE-4 						; 4-byte "handlers are loaded too" magic
PCODE_PAGE = $09 							; shared-mode p-code base page ($0900, page-aligned)
MIN_WS_PAGES = 16 							; smallest workspace a shared program keeps (4K)
;
;		Pages left free between the end of the object code and the start of the workspace, for
;		the runtime (FOR/GOSUB) frame stack. clr.asm puts runtimeStackPtr at storeStartHigh-1:$FF
;		and grows it DOWNWARD, so without a gap here a deep call chain walks back into the code.
;
;		BOTH ends need this number and they must agree, which is why it lives here rather than
;		with either of them. The COMPILER spends it -- object.asm adds it when it works out where
;		a program's workspace starts, in both embedded and shared modes. The RUNTIME polices it --
;		StartRuntime turns storeStartHigh minus this into the floor StackOpenFrame refuses to go
;		below. Change it in one place and a program compiled by the old engine, running under a
;		new runtime, gets a floor that is not where its gap is.
;
FrameStackPages = 16 						; 4K, ~250 frames
;
;		RT_ABI is the runtime's ABI ordinal, and it is the ONE place it is written down. It drives
;		the 4-byte magic at RTBASE ("GPC" + the digit), which the bootstrap compares to answer a
;		single question: is a runtime already resident, and is it one I can safely enter? So bump
;		it whenever the runtime layout or entry contract changes -- and only then. A resident
;		runtime from a DIFFERENT engine build but the same ABI is deliberately still reused.
;
;		The runtime's FILE NAME does not come from here. It carries the engine's BUILD number
;		(source/application/buildnum.txt) -- see scripts/rtname.py, which names the built file,
;		and bootstrap.asm, which formats the same number into the name a compiled program looks
;		for. That is a different question: which runtime file is mine? It pins a program to the
;		exact runtime it was built against, and since the build number bumps on every engine
;		build, shared programs must be recompiled whenever the engine is rebuilt.
;
;		2 -> 3 on 16th August 2026: PCD_ARRAY1 joined the table, and p-code IDs are handed out in
;		the order the ;; [name] markers are scanned, so every opcode after "array1" shifted up by
;		one. A resident runtime of the same ABI is deliberately reused across engine builds --
;		and with renumbered opcodes that would dispatch most of the table to the wrong handler.
;		This is the guard that stops it.
;
;		3 -> 4 on 16th August 2026: GP.DO / GP.LOOP joined the table. Same mechanism as the 2 -> 3
;		bump above -- "do.asm" sorts ahead of "for.asm" in the commands directory, so the two new
;		markers landed at $96/$97 and shifted every opcode from "for" upward by two.
;
;		4 -> 5 on 16th August 2026: GP.EXITDO joined the table as the system token ".exitdo". This
;		one is NOT a renumbering -- it was appended after ".deferror" precisely so that every
;		existing opcode keeps its ID. The bump is still required in the other direction: an object
;		using $DF would dispatch off the end of an ABI 4 runtime's vector table.
;
;		5 -> 6 on 16th August 2026: GP.CALL and the GP.A/GP.X/GP.Y/GP.C value words. This one IS a
;		renumbering -- "gpcall.asm" sorts mid-list in the commands directory, so the four unshifted
;		markers shifted every opcode above them, and the shifted gp.call did the same to the
;		shifted range.
;
;		6 -> 7 on 16th August 2026: GP.FIND and GP.STRPTR. "gpstring.asm" sorts after "gpcall.asm",
;		so the two new unshifted markers shifted every opcode above them again.
;
;		7 -> 8 on 16th August 2026: GP.TRIM / GP.UPPER / GP.LOWER / GP.PAD joined gpstring.asm.
;
;		8 -> 9 on 16th August 2026: GP.PAD REMOVED again -- see gpstring.asm for why. Dropping a
;		marker renumbers exactly as adding one does, so every shifted opcode above gp.pad moved
;		back down. ABI 8 was never committed, so this bump is belt and braces rather than
;		necessity -- but GPC.RT.*.BIN files built during the day are still lying about on this
;		machine carrying the "GPC8" magic and the OLD opcode map, and the bootstrap would accept
;		one for a new ABI 8 object without a word. That is the silent-mismatch class this ordinal
;		exists to prevent, so it gets spent rather than argued with. Rebuild the resident runtime.
;
;		9 -> 10 on 17th August 2026: the magic at RTBASE widened from "GPC"+one digit to "GP"+TWO
;		digits. It is still exactly 4 bytes (a 5th would have overwritten the RT_ENTRY jmp at
;		RTBASE+4, which is what the .cerror in 00rt.header and bootstrap.asm was guarding), and it
;		now has room to ABI 99. GP.INSTRREV was added and then removed again under this same
;		ordinal; neither state was committed, so 10 means the two-digit magic and nothing else.
;
;		10 -> 11 on 17th August 2026: GP.COMP joined gpstring.asm -- a shifted marker, so every
;		shifted opcode above it moved up one.
;
;		11 -> 12 on 17th August 2026: GP.SORT, in its own gpsort.asm. That file sorts between
;		"gpstring.asm" and "gpcall.asm" in the commands directory, so it renumbered from there up.
;
;		12 -> 13 on 17th August 2026: GP.ARRPTR joined gpsort.asm, a shifted marker.
;
;		13 -> 14 on 17th August 2026: RTBASE moved $6800 -> $6400. Every move of the base costs a
;		bump -- a resident runtime linked at another address is not interchangeable, and the base is
;		baked into every shared program's bootstrap.
;
;		14 -> 15 on 17th August 2026: GP.STASH / GP.RESTR joined the x16 commands directory.
;
;		15 -> 16 on 17th August 2026: GP.BOX / GP.FILL / GP.PRINTAT, in gpdraw.asm. That leafname
;		sorts BEFORE gpsort.asm and gpstash.asm, so the three new shifted markers were inserted
;		below theirs rather than appended, and everything from gp.sort upwards moved by three.
;
;		16 -> 17 on 17th August 2026: GP.MENU / GP.SEL, in gpmenu.asm. "gpmenu" sorts between
;		"gpdraw" and "gpsort", so the two new shifted markers were inserted rather than appended
;		and everything from gp.sort upwards moved by two.
;
;		17 -> 18 on 17th August 2026: GP.SELECT / GP.CASE / GP.ELSE / GP.ENDSEL, in commands/
;		select.asm. This is the biggest renumbering since GP.CALL: four UNSHIFTED markers, and
;		"select.asm" sorts mid-list in the commands directory, so every unshifted opcode above
;		them moved by four -- which moved PCD_STARTSYSTEM, so the whole system-token block and
;		with it the shifted base ($D780 -> $DB80) moved too. Two system tokens (.casenext,
;		.caseend) were appended after .exitdo on top of that.
;
;		20 -> 21 on 30th August 2026: GP.IF / GP.ELSEIF / GP.ELSE / GP.ENDIF, and GP.SELECT's
;		GP.ELSE renamed GP.OTHER to free the spelling. Two UNSHIFTED markers (gp.if, gp.endif)
;		go in commands/goto.asm -- deliberately the CORE, not gp-runtime, so ScanGPUsage does
;		not drag the 2K GP block into a program whose only GP keyword is an IF. "goto.asm"
;		sorts early, so every unshifted opcode above it moved by two, which moved
;		PCD_STARTSYSTEM and with it the shifted base ($DB80 -> $DD80). Two system tokens
;		(.ifnext, .ifelse) were appended after .caseend on top of that. The gp.else -> gp.other
;		rename moved nothing: same position, same id.
;
RT_ABI = 21 								; runtime ABI ordinal -> "GP21" magic (NOT the file name)

; ************************************************************************************************
;
;									Set up code and data sections
;
; ************************************************************************************************

		* = ZeroPageMandatory 				; *must* be in zero page
		.dsection zeropage

		* = MemoryStorage 					; doesn't matter if zero page or not
		.dsection storage
StorageEnd:

		* = CodeStart
		.dsection code

;
;		storage is a 1K hole -- $0400 to $0801, and no further, because the code starts there.
;		Nothing warns you when it runs out: the section simply carries on over the top of the
;		BASIC stub, and the program corrupts itself the first time it writes to the buffer that
;		spilled. It HAD run out, silently, and only survived because the one buffer hanging over
;		the edge was never filled past its fifteenth byte. So say so, loudly.
;
		.cerror StorageEnd > CodeStart, "storage has overflowed into the code - put compiler-only buffers in the code section (see application/source/file-io/read.asm)"

; ************************************************************************************************
;
;										Zero Page Common Usage
;
; ************************************************************************************************

		.section zeropage

codePtr:	 								; address of current line.
		.fill 	2

objPtr: 									; address in code. 
		.fill 	2 							

zTemp0: 									; temporary words used in the interpreter.
		.fill 	2
zTemp1:
		.fill 	2
zTemp2:
		.fill 	2

		.endsection

; ************************************************************************************************
;
;							Insert an Emulator Breakpoint
;
; ************************************************************************************************

debug 		.macro
		.byte 	$DB 						; causes a break in the emulator
		.endm

; ************************************************************************************************
;
;								Set a 2 byte value in memory
;
; ************************************************************************************************

set16 		.macro
		lda 	#((\2) & $FF)
		sta 	0+\1
		lda 	#((\2) >> 8) & $FF
		sta 	1+\1
		.endm

; ************************************************************************************************
;
;										Exit emulation
;
; ************************************************************************************************

exitemu .macro
		stx 	zTemp0
		jmp 	$FFFF
		.endm

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
