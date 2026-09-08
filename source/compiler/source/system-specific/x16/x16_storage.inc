; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_storage.inc
;		Purpose:	Storage access macros
;		Created:	15th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************
;
;		These two macros bracket every access to the compiler's two work tables -- the variable
;		name list and the line-number table (see storage/reset.asm for the layout). They were
;		EMPTY, which meant the tables had to live in ordinary low RAM, sharing it with the
;		object code being emitted. They did, at $8000-$9F00, and the object code grew up into
;		them: past 12,032 bytes of p-code the head of the variable list was overwritten,
;		FindVariable then missed on every lookup, and each reference to an existing variable
;		created a new one. No error -- the compiler printed OK and emitted a program in which
;		the same name on two lines was two different variables.
;
;		Filling them in is what lets the tables move to BANKED RAM at $A000-$BFFF, which both
;		gives them a window of their own (8K, slightly more than the 7,936 bytes they had) and
;		hands the whole of $5100-$9EFF back to the object code -- 19,968 bytes instead of 12,032.
;		See ObjectCeiling / CompilerWorkspaceStart in application/source/compiler/start.asm.
;
;		Rules these macros must obey, because of where they are used:
;
;		* Preserve A, X, Y AND the flags. STRMarkLine (storage/mark_line.asm) opens its window
;		  with the line number live in A and Y; FindVariable closes one with the variable's
;		  address live in A, X and Y; and STRFindLine's search closes one over the carry of the
;		  16-bit compare it just made. Hence the php/pha ... pla/plp wrapper -- the macros are
;		  stack-neutral, so the pha/pla pairs already in that code still line up.
;
;		* Restore the CALLER's bank, not a hardcoded 0. The compiler is entered from GPC.PRG and
;		  has no business assuming what was selected.
;
;		* Never hold the bank across a KERNAL call. Bank 0 is the KERNAL's (its FAT32 buffers
;		  live there), so any window that wants to do file I/O has to close first. Every window
;		  in the tree is a short run of loads and stores with no jsr into the KERNAL --
;		  WriteMapFile (application/source/compiler/object.asm) is the one that reads the table
;		  and writes a file, and it already pulls each entry out through zTemp0 BEFORE it starts
;		  emitting bytes, so the window closes before the first IOWriteByte.
;
;		* No nesting, and no jsr at all. Verified: none of the windows contains another, and
;		  every one of them is now a straight run of loads and stores. STRFindLine used to
;		  hold one open across its whole search and call _STRPrevLine inside it; the line
;		  table spanning two banks ended that, because the bank has to be re-chosen per entry.
;
; ************************************************************************************************

;
;		$0000 is the X16's RAM bank register (the runtime calls the same address SelectRAMBank;
;		it is spelled out again here because the compiler library also builds on its own, without
;		the runtime's includes -- and defining the same name twice would clash when the
;		application assembles both).
;
CompilerRAMBankReg	= $0000

;
;		RAM BANK ALLOCATION AT COMPILE TIME. Everything below lives at $A000-$BFFF and is told
;		apart ONLY by this register, so the numbers matter:
;
;			0	the KERNAL's (FAT32 buffers and friends). Never ours.
;			1	the NATIVE TEST HARNESS's p-code buffer. source/compiler/testing/api/api.asm
;				does "lda #1 / sta 0" in _TAResetOut and then writes the object from $A000 up.
;			2	the LINE NUMBER TABLE, first half.
;			3	GP.ASM's blob pool and fixup list (see the second pair of macros below).
;			4	the VARIABLE NAME LIST.
;			5	the BLOCK DEPTH of each line, one byte per line-table entry -- first half.
;			6	WHERE EACH BLOCK ENDS, and where each of its alternatives goes next.
;			7	the OBJECT BUFFER -- the application's, not the compiler's.
;			8	the ONE scratch bank EVERY region shares -- cleared as each one opens, and
;				emptied to that region's own .Bnn file as it closes.
;			9	the LINE NUMBER TABLE, second half.
;			10	the BLOCK DEPTH, second half. It follows the line table's split exactly.
;			63	the GP.BANKEDSTR pool, growing DOWN from the top bank a 512K machine has.
;
;		BANKS 2 AND 4 WERE ONE BANK, and that was the wall. The two tables shared 8K, growing
;		towards each other, and samples/editor had used 7,981 bytes of it -- 1,461 line entries
;		at 4 bytes plus 356 variable records at 6 -- leaving 211. Fifty-two more lines of source
;		and the tables touched, and the compiler said PROGRAM TOO BIG with 7,106 bytes of the
;		OBJECT budget still free. Same message, wrong limit: three sites raise it (STRMarkLine,
;		CreateVariableRecord and _CAWriteByte) and only the last one is about the object. A bank
;		each takes the tables to 2,048 lines and 1,365 variables, so the limit a program meets
;		is the object ceiling -- the one that is really there.
;
;		AND 2,048 LINES WAS THE WALL AGAIN, at samples/GPB-MODS-TESTING/GPBMODS.BASL, which
;		marks about 2,200. Same message, same wrong limit, one table further along. The line
;		table has a SECOND bank under it now and its pointers are virtual addresses covering
;		both -- see STRPageLine in storage/mark_line.asm, which is the only thing that knows.
;		4,096 lines, and the depth table splits with it because its byte for a record is at the
;		record's own address.
;
;		This was bank 1 for one build, and the compiler-runtime `variables` and `arrays` suites
;		hung: the harness's object code and the variable name list were overwriting each other,
;		same addresses, same bank. Nothing detected it -- both were doing exactly what they had
;		been told. Every X16 has these banks (the 512K minimum is 64 of them). If you add a
;		third banked user, add it to this list first.
;
CompilerStorageBank	= 2 					; line number table, grows DOWN from $C000
CompilerVarBank		= 4 					; variable name list, grows UP from $A000
CompilerDepthBank	= 5 					; block depth per line, alongside the line table
CompilerBlockBank	= 6 					; where each block ends, and its alternatives
CompilerStorageBank2 = 9 					; the second 8K the line table runs on down into
CompilerDepthBank2	= 10 					; ...and the second 8K of depth bytes shadowing it

;
;		THE FLOOR OF THE LINE TABLE'S VIRTUAL ADDRESS SPACE. It starts at compilerEndHigh:$00,
;		which is CompilerWorkspaceEnd ($C000, application/source/compiler/start.asm), and runs
;		down through two banks of $2000 -- so $8000, and 4,096 four-byte entries. Change either
;		of those and this moves with them.
;
LineTableFloorHigh	= $80

BlockEndTable		= $A000 				; 2,048 entries of 2 bytes: where block N ends
BlockAltTable		= $B000 				; ...and the same for its alternatives
BLOCK_MAX 			= 2048

;
;		THE BANK IS A VARIABLE HERE, not a constant, because the line table spans two of them:
;		STRPageLine writes storageBankNow as it translates a virtual table address, and nothing
;		else ever writes it. Open a window without having paged a record first and you get
;		whichever segment the last call left selected -- which is why every walk of the table
;		calls STRPageLine immediately before its .storage_access, with nothing in between.
;
storage_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	storageSavedBank
		lda 	storageBankNow
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

storage_release .macro
		php
		pha
		lda 	storageSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
storageSavedBank: 							; caller's RAM bank, saved across a storage window
		.fill 	1
storageBankNow: 							; which half of the line table is being reached --
		.fill 	1 							; STRReset seeds it, STRPageLine keeps it right
		.send 	storage

;
;		The same again for the VARIABLE NAME LIST, which is now a different bank. Same rules.
;		The two windows are never nested -- nothing that walks the variable list touches a line
;		number, or the other way about -- but the separate saved-bank byte means nesting would
;		still restore correctly rather than quietly leave the wrong bank selected.
;

varstore_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	varSavedBank
		lda 	#CompilerVarBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

varstore_release .macro
		php
		pha
		lda 	varSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
varSavedBank: 								; caller's RAM bank, saved across a variable window
		.fill 	1
		.send 	storage

;
;		And a third, for the BLOCK DEPTH TABLE -- one byte saying how many GP.DO blocks are open
;		at the start of each source line. A GOTO out of a block emits an .unwind saying how many
;		frames it closes, which is the depth where it stands minus the depth where it lands, and
;		the second half of that is a fact about a line the compiler may not have reached yet.
;		Pass one writes it down; pass two reads it back and answers at emit.
;
;		A WHOLE BANK FOR ONE BYTE IN FOUR. The depth for the line record at address P is at the
;		SAME address P in this bank, so there is no arithmetic to get wrong -- and the line
;		table's own window is 8K, exactly one bank, so the three bytes in four that go unused
;		cost nothing that was ever available. Widening the line record to carry the byte instead
;		would have cost real ground: 5 bytes an entry drops the limit from 2,048 lines to 1,638.
;
;		IT IS TWO BANKS NOW, in the same halves as the line table and for the same reason, and
;		the bank is a variable here for the same reason as well. STRPageLine writes both.
;

depth_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	depthSavedBank
		lda 	depthBankNow
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

depth_release .macro
		php
		pha
		lda 	depthSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
depthSavedBank: 							; caller's RAM bank, saved across a depth window
		.fill 	1
depthBankNow: 								; which half of the depth table is being reached --
		.fill 	1 							; STRReset seeds it, STRPageLine keeps it right
		.send 	storage

;
;		And a fourth, for the BLOCK END tables -- where a GP.DO, a GP.IF or a GP.SELECT finishes,
;		and where each alternative inside one hands on to the next. Every branch in that family
;		points FORWARDS, at a place the compiler has not reached, which is what made them
;		FixBranches' work: it resolved them by scanning the finished object for the closing
;		token. Pass one writes each answer down as it passes it; pass two reads it back and
;		resolves the branch where it writes it.
;
;		Two tables of 2,048 entries, 4K each and 8K together, which is the bank exactly. Indexed
;		by ORDINAL -- the n'th block the pass opened, the n'th alternative it wrote -- because
;		both passes compile the same source in the same order and so number them the same way.
;		NOT by nesting depth: two sibling loops share a depth, and the second would overwrite an
;		answer the first still needs.
;

block_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	blockSavedBank
		lda 	#CompilerBlockBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

block_release .macro
		php
		pha
		lda 	blockSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
blockSavedBank: 							; caller's RAM bank, saved across a block window
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
;		02/08/26		Implemented (were no-ops); tables moved to banked RAM $A000-$BFFF.
;		01/09/26		Split: the line table keeps bank 2, the variable list moves to bank 4,
;						so neither table bounds the other.
;		06/09/26		Bank 5 added for the per-line block depth, and bank 6 for the block
;						end tables (the two-pass compiler).
;		08/09/26		Banks 9 and 10 added: a second half for the line table and for the
;						depth table, reached through STRPageLine. 4,096 lines.
;
; ************************************************************************************************

; ************************************************************************************************
;
;		The same thing again for GP.ASM's blob pool and its fixup list (commands/gpasmcode.asm).
;		A SECOND window, not a second user of the first: these are written all through a compile
;		while the storage tables are not, and keeping them apart means neither can be corrupted
;		by a bug in the other's bookkeeping.
;
;		Same rules as above, and the same reasoning. In particular the windows here are never
;		nested inside a storage window -- nothing in the assembler touches a variable name or a
;		line number -- and none of them holds the bank across a KERNAL call. AsmFlushPool is the
;		one that could be tempted to: it reads the pool and writes it to the object, so it opens
;		and closes ONCE PER BYTE rather than holding the window across WriteCodeByte, whose
;		ObjectCeiling check can raise PROGRAM TOO BIG and leave through the error handler --
;		which prints, through the KERNAL, in bank 0.
;
AsmStorageBank	= 3

asm_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	asmSavedBank
		lda 	#AsmStorageBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

asm_release .macro
		php
		pha
		lda 	asmSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
asmSavedBank: 								; caller's RAM bank, saved across an assembler window
		.fill 	1
		.send 	storage

;
;		BANK 63 -- the GP.BANKEDSTR group tables and string pool. Same rules again. These windows
;		are never nested inside any of the others: the block reads its own source lines and
;		touches no variable name, line number or block end while it is open. BStrFlush opens and
;		closes ONCE PER BYTE for the same reason AsmFlushPool does -- WriteCodeByte can raise
;		PROGRAM TOO BIG and leave through the error handler, which prints in bank 0.
;
;		THE TOP BANK, NOT A LOW ONE, AND THE OBJECT WRITER IS WHY. The banks listed above are the
;		COMPILER's, but the application takes two more that are not listed anywhere near them:
;		OBJ_BUF_BANK is 7 and OBJ_RGN_BANK is 8 (application/compiler/object.asm).
;
;		IT WAS 16, AND SIXTEEN IS EXACTLY WHERE EIGHT REGIONS STOPPED. OBJ_RGN_BANK used to take
;		ONE BANK A REGION growing upward, so banks 8 to 15 were the regions and 16 was the pool
;		-- adjacent, with nothing between them and nothing checking. A ninth region would have
;		written straight through the string pool, and the count that refused a ninth was the
;		extension page's table rather than this. Two limits, one number, by luck.
;
;		THE REGIONS SHARE ONE BANK NOW, so bank 8 is the whole of what the object writer takes
;		and the pool could sit almost anywhere. 63 stays regardless: it is where the text pools
;		grow DOWN from, it is the top bank a 512K X16 has, and a number that cannot collide with
;		anything at any region count is the one that never needs revisiting. Being right for a
;		second reason is not a reason to change it.
;
;		THE POOLS ARE NOT IN HERE ANY MORE, and that is Phase 3: this bank holds the four GROUP
;		tables and nothing else, and each text bank's records live in a bank of their own -- see
;		below. What it buys the single-bank program is the 768 bytes the tables used to take out
;		of its pool: the pool was 7,424 and is 8,192 now, and the region's own 8K check is the
;		only thing that stops it.
;
;		This cost most of a day when it was 7. Bank 7 held the string pool perfectly through
;		PASS ONE -- which writes no object -- and pass two then filled the same bank with the
;		object as it streamed it, so every length byte read back as zero. The symptom was not a
;		wrong string: it was INTERNAL ERROR from the two-pass agreement check, because the region
;		came out 44 bytes in pass two against 20 in pass one, with the page padding hiding it in
;		the total length.
;
BStrStorageBank	= 63

bstr_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	bstrSavedBank
		lda 	#BStrStorageBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

bstr_release .macro
		php
		pha
		lda 	bstrSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
bstrSavedBank: 								; caller's RAM bank, saved across a banked-string window
		.fill 	1
		.send 	storage

;
;		BANKS 62 DOWNWARD -- ONE A GP.BANKEDSTR TEXT BANK, holding that bank's records and nothing
;		else. Sixteen text banks reach 47, and the object writer's shared scratch bank is 8, so the
;		two grow towards each other and do not meet at any count either of them can have.
;
;		THE BANK IS A VARIABLE HERE AND A CONSTANT IN EVERY OTHER WINDOW, which is the whole of
;		the difference: the pool routines are written once and the slot says which bank they land
;		in. BStrSelectSlot is the only thing that writes bstrPoolBank, and it writes it whenever
;		the slot changes -- at a GP.BANKEDSTR header, and once per slot in the flush.
;
;		Same rules as the others: never nested inside another window, never held across a KERNAL
;		call, and opened and closed ONCE PER BYTE in the flush because WriteCodeByte can raise
;		PROGRAM TOO BIG and leave through an error handler that prints in bank 0.
;
BStrPoolBankTop	= 62

bpool_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	bpoolSavedBank
		lda 	bstrPoolBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

bpool_release .macro
		php
		pha
		lda 	bpoolSavedBank
		sta 	CompilerRAMBankReg
		pla
		plp
		.endm

		.section storage
bpoolSavedBank: 							; caller's RAM bank, saved across a string-pool window
		.fill 	1
bstrPoolBank: 								; which bank that is -- the selected slot's, not a constant
		.fill 	1
		.send 	storage
