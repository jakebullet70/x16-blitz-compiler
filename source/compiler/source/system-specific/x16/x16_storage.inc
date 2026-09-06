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
;		* Preserve A, X, Y AND the flags. STRFindLine (storage/mark_line.asm) opens its window
;		  as its very first instruction with the line number live in A and Y; FindVariable
;		  closes one with the variable's address live in A, X and Y; and STRFindLine closes over
;		  a php/plp pair carrying the found/not-found carry. Hence the php/pha ... pla/plp
;		  wrapper -- the macros are stack-neutral, so the pha/pla pairs already in that code
;		  still line up.
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
;		* No nesting. Verified: none of the windows contains another, and the only jsr inside
;		  any of them is STRFindLine's local _STRPrevLine.
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
;			2	the LINE NUMBER TABLE.
;			3	GP.ASM's blob pool and fixup list (see the second pair of macros below).
;			4	the VARIABLE NAME LIST.
;			5	the BLOCK DEPTH of each line, one byte per line-table entry.
;			6	WHERE EACH BLOCK ENDS, and where each of its alternatives goes next.
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

BlockEndTable		= $A000 				; 2,048 entries of 2 bytes: where block N ends
BlockAltTable		= $B000 				; ...and the same for its alternatives
BLOCK_MAX 			= 2048

storage_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	storageSavedBank
		lda 	#CompilerStorageBank
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

depth_access .macro
		php
		pha
		lda 	CompilerRAMBankReg 			; remember whatever the caller had selected
		sta 	depthSavedBank
		lda 	#CompilerDepthBank
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
