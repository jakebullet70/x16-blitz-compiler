; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpbstrpool.asm
;		Purpose:	GP.BANKEDSTR -- the group table and the string pool
;		Created:	7th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		A BANK OF ITS OWN, and its own window macros, for the same reason GP.ASM has bank 3: the
;		tables are far too big for the compiler's own low memory. WHICH bank is in
;		system-specific/x16/x16_storage.inc, beside the note on why it is not one of the low ones.
;
;		FOUR TABLES AND A POOL, all parallel arrays rather than arrays of records: a record index
;		would be count*n, which passes 255 long before the table is full and would need a sixteen
;		bit pointer at every touch. Indexed this way every subscript is count or count*2.
;
;		  BStrNames    2 a group   the compressed name, exactly as ExtractVariableName returns it
;		  BStrBases    2 a group   its first index in the flat list OF THE BANK IT IS IN
;		  BStrCounts   2 a group   how many strings are in it
;		  BStrSlots    1 a group   which text bank it is in, as a slot 0..BSTR_MAX_BANKS-1
;
;		AND THE RECORDS ARE NOT IN THIS BANK AT ALL. Each text bank has a pool bank of its own
;		(BStrPoolBankTop downward, x16_storage.inc), so the tables have this one to themselves and
;		a program's text is no longer one 8K bank in total. Only the SELECTED slot's pool is
;		reachable at a time, which is what lets every pool sit at $A000 and the routines below not
;		know there is more than one.
;
;		THERE IS NO TABLE OF POOL OFFSETS, and there was: the pool is SELF-DESCRIBING, because
;		every record starts with its own length, so the flush works the offsets out by walking it.
;		Keeping them in a parallel table meant the same fact written twice and two chances to
;		disagree -- which is exactly what happened, and cost an afternoon: every directory entry
;		but the first came out as zero while the records themselves were perfect.
;
;		THE GROUPS ARE A COMPILE-TIME SLICE OF ONE FLAT LIST, and that is what makes naming free.
;		The bank image knows nothing about groups: it is a count, a flat directory and the
;		records. A group name resolves to its base, the base is added to the index at the call
;		site, and no letter of the name and no group table reaches the object at all.
;
; ************************************************************************************************

;
;		BStrStorageBank and the two window macros are in system-specific/x16/x16_storage.inc,
;		beside the five that were already there.
;
;
;		128 GROUPS IS THE SHAPE'S OWN CEILING, not a guess: the subscript is doubled into X with a
;		single ASL, so group 128 would wrap to group 0. It was 32, which is plenty for a program
;		written by hand and NOT plenty for one converted from literals -- GPBMODS has 37 routines
;		carrying text, and a group per routine is the whole point. 128 groups costs 768 bytes of
;		the window, leaving 7,424 for text; the largest program measured needs 6,842.
;
BSTR_MAX_GROUPS  = 128
;
;		4,096 IS THE SLOT FIELD'S OWN CEILING and not a budget: a GP.BSTR call site pushes
;		slot<<12 + the index, so twelve bits are what is left for the index. It caps nothing --
;		an 8K bank holds at most 2,730 strings, two directory bytes and a length byte each, so
;		the region's 8K check always stops a bank first. It is here to keep the packing honest
;		rather than to refuse a program anything.
;
BSTR_MAX_STRINGS = 4096 					; strings in ONE bank -- the index field's range

BStrNames   = $A000 							; 2 each -- bank BStrStorageBank, the tables' own
BStrBases   = BStrNames   + 2*BSTR_MAX_GROUPS 	; 2 each
BStrCounts  = BStrBases   + 2*BSTR_MAX_GROUPS 	; 2 each
BStrSlots   = BStrCounts  + 2*BSTR_MAX_GROUPS 	; 1 each

BStrPool    = $A000 							; ...and the records, in the SELECTED SLOT's own bank
BSTR_POOL_SIZE = $2000 						; all 8K of it: nothing shares the bank with them now

; ************************************************************************************************
;
;		Start a group. The name is in bstrName and has already been checked for a duplicate.
;
; ************************************************************************************************

BStrOpenGroup:
		lda 	bstrGroupCount
		cmp 	#BSTR_MAX_GROUPS
		bcs 	_BOGFull
		asl 	a 							; the two-byte tables want the subscript doubled
		tax
		.bstr_access
		lda 	bstrName
		sta 	BStrNames,x
		lda 	bstrName+1
		sta 	BStrNames+1,x
		lda 	bstrStringCount 			; the group starts where its BANK's flat list has got to
		sta 	BStrBases,x
		lda 	bstrStringCount+1
		sta 	BStrBases+1,x
		ldy 	bstrGroupCount 				; ...and the bank it is in, undoubled: one byte a group
		lda 	bstrSlot
		sta 	BStrSlots,y
		.bstr_release
		rts
_BOGFull:
		.error_memory

; ************************************************************************************************
;
;		Close it: the count is what the flat list has advanced by, and ONLY NOW does the group
;		count go up. An unclosed group is a structure error and must never be findable.
;
; ************************************************************************************************

BStrCloseGroup:
		lda 	bstrGroupCount
		asl 	a
		tax
		.bstr_access
		sec
		lda 	bstrStringCount
		sbc 	BStrBases,x
		sta 	BStrCounts,x
		lda 	bstrStringCount+1
		sbc 	BStrBases+1,x
		sta 	BStrCounts+1,x
		.bstr_release
		inc 	bstrGroupCount
		rts

; ************************************************************************************************
;
;		Find the group named in bstrName. CS and X = the doubled subscript if it exists, CC if
;		not. Two bytes to compare, so this is a plain linear walk -- once a block and once a
;		reference, so even a full table is nothing beside reading the source line.
;
;		AND bstrGroupIdx IS THE SAME SUBSCRIPT UNDOUBLED, which BStrSlots wants: it is one byte a
;		group where the other three are two. It is written rather than derived because the caller
;		has its own use for bstrTemp the moment it gets here.
;
; ************************************************************************************************

BStrFindGroup:
		ldx 	#0
		lda 	bstrGroupCount
		beq 	_BFGMiss 					; no groups at all
		stz 	bstrTemp
		stz 	bstrGroupIdx
_BFGLoop:
		.bstr_access
		lda 	BStrNames,x
		cmp 	bstrName
		bne 	_BFGNext
		lda 	BStrNames+1,x
		cmp 	bstrName+1
_BFGNext:
		.bstr_release
		beq 	_BFGHit
		inx
		inx
		inc 	bstrGroupIdx
		inc 	bstrTemp
		lda 	bstrTemp
		cmp 	bstrGroupCount
		bcc 	_BFGLoop
_BFGMiss:
		clc
		rts
_BFGHit:
		sec
		rts

; ************************************************************************************************
;
;		Append the body line's string to the pool. The opening quote is already consumed; this
;		reads to the closing one and requires end of line after it.
;
;		THE LENGTH GOES IN FIRST AND IS PATCHED, not counted ahead: counting would mean walking
;		the source twice, and the source pointer is the only cursor there is.
;
;		A 255 CHARACTER LIMIT, because the record's length is one byte -- and because the runtime
;		hands the text to StringAllocTemp, which has the same limit. Refused here rather than
;		truncated there.
;
; ************************************************************************************************

BStrAppendString:
		lda 	bstrStringCount 			; room in the flat list ?
		cmp 	#BSTR_MAX_STRINGS & $FF
		lda 	bstrStringCount+1
		sbc 	#BSTR_MAX_STRINGS >> 8
		bcc 	_BASRoom
		jmp 	_BASFull 					; the error exits are past a branch's reach
_BASRoom:
		;
		;		Leave a byte for the length, and remember where it is.
		;
		lda 	bstrPoolLen 				; where the length byte itself goes, for the patch
		sta 	bstrLenAt
		lda 	bstrPoolLen+1
		sta 	bstrLenAt+1
		lda 	#0
		jsr 	BStrPoolWrite
		stz 	bstrLength
		;
_BASLoop:
		jsr 	LookNext 					; end of line inside an unterminated string
		beq 	_BASSyntax
		cmp 	#34 						; the closing quote
		beq 	_BASDone
		jsr 	BStrPoolWrite
		jsr 	GetNext 					; consume it
		inc 	bstrLength
		beq 	_BASTooLong 				; 256 characters wrapped the count
		bra 	_BASLoop
_BASDone:
		jsr 	GetNext 					; consume the closing quote
		lda 	bstrLength
		ldx 	bstrLenAt
		ldy 	bstrLenAt+1
		jsr 	BStrPoolPatch 				; ...and the length goes into the byte left for it
		inc 	bstrStringCount
		bne 	_BASNoCarry
		inc 	bstrStringCount+1
_BASNoCarry:
		jmp 	BStrRequireEOL 				; nothing may follow the string on its line

_BASFull:
		;
		;		IN COMPILER SPACE, not errors.asm: that table links below GPBase and is copied into
		;		every compiled program. It said OUT OF MEMORY, which sends the programmer to look at
		;		the size of the text -- and the size of the text is not what has run out. See
		;		gpasmcode.asm's _APBUnknown for the pattern.
		;
		jsr 	CallErrorHandler
		.text 	"GP.BANKEDSTR BANK OVER 4096 STRINGS", 0
_BASTooLong:
		.error_syntax
_BASSyntax:
		.error_syntax

; ************************************************************************************************
;
;		Append A to the pool, and patch a byte already in it. Both go through zTemp2 with the
;		window OPEN for one access only: the compiler's own code is not in that bank.
;
; ************************************************************************************************

BStrPoolWrite:
		pha
		lda 	bstrPoolLen+1 				; full ?
		cmp 	#BSTR_POOL_SIZE >> 8
		bcc 	_BPWSpace
		lda 	bstrPoolLen
		cmp 	#BSTR_POOL_SIZE & $FF
		bcs 	_BPWFull
_BPWSpace:
		clc
		lda 	#BStrPool & $FF
		adc 	bstrPoolLen
		sta 	zTemp2
		lda 	#BStrPool >> 8
		adc 	bstrPoolLen+1
		sta 	zTemp2+1
		pla
		.bpool_access
		sta 	(zTemp2)
		.bpool_release
		inc 	bstrPoolLen
		bne 	_BPWDone
		inc 	bstrPoolLen+1
_BPWDone:
		rts
_BPWFull:
		pla
		.error_memory

;
;		A = the byte, YX = the pool offset to put it at.
;
BStrPoolPatch:
		pha
		clc
		txa
		adc 	#BStrPool & $FF
		sta 	zTemp2
		tya
		adc 	#BStrPool >> 8
		sta 	zTemp2+1
		pla
		.bpool_access
		sta 	(zTemp2)
		.bpool_release
		rts

; ************************************************************************************************
;
;		Select the text bank in A: find it among the ones this program has already named, or add
;		it, and make it the bank the pool routines write to.
;
;		THE SLOT IS A POSITION IN THAT LIST AND NOT THE BANK NUMBER, which is what makes the
;		packing fit. A GP.BSTR call site pushes slot<<12 + index: four bits address sixteen slots
;		where a bank number would need six, and the twelve left over are more index than an 8K
;		bank can physically hold. The list itself is what the bootstrap extension page carries to
;		the runtime, sixteen bytes at GPBSTRBANKS.
;
;		FIRST APPEARANCE ORDER, so both passes number the slots identically. Pass two re-reads the
;		same blocks in the same order, and the constants pass one pushed for every GP.BSTR are
;		exactly what pass two has to push again.
;
; ************************************************************************************************

BStrSelectBank:
		ldx 	#0
_BSBFind:
		cpx 	bstrBankCount
		bcs 	_BSBNew
		cmp 	bstrBankNums,x
		beq 	_BSBHave
		inx
		bra 	_BSBFind
_BSBNew:
		cpx 	#BSTR_MAX_BANKS
		bcs 	BStrTooManyBanks
		sta 	bstrBankNums,x
		;
		;		AND THE LINE THAT OPENED IT, which is the only line a bank has. Two errors are about
		;		a whole bank rather than a statement -- its text overflowing 8K, and a GP.BANKED
		;		already owning it -- and both fire at the end of a pass, where currentLineNumber is
		;		the end of the program and names nothing. This is a real line carrying a real
		;		GP.BANKEDSTR header, and the bank number is written on it.
		;
		phx
		txa
		asl 	a
		tax
		lda 	currentLineNumber
		sta 	bstrBankLines,x
		lda 	currentLineNumber+1
		sta 	bstrBankLines+1,x
		plx
		inc 	bstrBankCount
_BSBHave:
		txa

; ************************************************************************************************
;
;		Make the slot in A the current one: the slot being left puts its two counters away and the
;		one arriving takes its own out.
;
;		SWAPPED THROUGH SCALARS RATHER THAN INDEXED IN PLACE, and that is the whole reason the
;		pool and group routines above do not know there is more than one bank. Every one of them
;		reads bstrStringCount and bstrPoolLen exactly as it did when there was one, and only this
;		routine and the flush ever change which bank those two describe.
;
; ************************************************************************************************

BStrSelectSlot:
		pha
		lda 	bstrSlot
		asl 	a 							; the two-byte tables want the slot doubled
		tax
		lda 	bstrStringCount
		sta 	bstrBankStrings,x
		lda 	bstrStringCount+1
		sta 	bstrBankStrings+1,x
		lda 	bstrPoolLen
		sta 	bstrBankPoolLens,x
		lda 	bstrPoolLen+1
		sta 	bstrBankPoolLens+1,x
		pla
		sta 	bstrSlot
		asl 	a
		tax
		lda 	bstrBankStrings,x
		sta 	bstrStringCount
		lda 	bstrBankStrings+1,x
		sta 	bstrStringCount+1
		lda 	bstrBankPoolLens,x
		sta 	bstrPoolLen
		lda 	bstrBankPoolLens+1,x
		sta 	bstrPoolLen+1
		ldx 	bstrSlot
		lda 	bstrBankNums,x 				; BStrRegister reads the bank as a scalar, as it always did
		sta 	bstrBank
		lda 	#BStrPoolBankTop 			; ...and the pool window reads ITS bank the same way
		sec
		sbc 	bstrSlot
		sta 	bstrPoolBank
		rts

;
;		In compiler space, by the rule above. The fix is to put two of the groups in one bank, so
;		the message says what has run out rather than how big anything is.
;
;		A GLOBAL NAME AND NOT A LOCAL ONE, because BStrSelectBank falls THROUGH into
;		BStrSelectSlot: 64tass scopes a local label to the global above it, so a message that has
;		to sit past the fall-through is out of the scope of the branch that reaches it.
;
BStrTooManyBanks:
		jsr 	CallErrorHandler
		.text 	"TOO MANY GP.BANKEDSTR TEXT BANKS", 0

; ************************************************************************************************
;
;		The per-pass reset, and the pass-one-only one.
;
;		THE BANK LIST SURVIVES INTO PASS TWO AND THE COUNTERS DO NOT, and the difference matters.
;		The bootstrap extension page carries the slot -> bank list and is written BEFORE pass two
;		reads a block, so clearing the list at the top of pass two would send an empty table out
;		to disk and every GP.BSTR would read whatever bank happened to be selected. The counters
;		are rebuilt from the source by each pass and must start at zero in both.
;
; ************************************************************************************************

; ************************************************************************************************
;
;		Point currentLineNumber at the GP.BANKEDSTR that opened the selected slot's bank, for the
;		two messages that are about the bank and not about a statement. WriteBranchTo's _WBTNoLine
;		(commands/goto.asm) is the same move made to name a missing line.
;
; ************************************************************************************************

BStrNameSlotLine:
		lda 	bstrSlot
		asl 	a
		tax
		lda 	bstrBankLines,x
		sta 	currentLineNumber
		lda 	bstrBankLines+1,x
		sta 	currentLineNumber+1
		rts

BStrResetPass:
		stz 	bstrBankCount 				; the list is re-found, in the same order, from the same source
		stz 	bstrSlot
		ldx 	#2*BSTR_MAX_BANKS-1
_BRPZero:
		stz 	bstrBankStrings,x
		stz 	bstrBankPoolLens,x
		dex
		bpl 	_BRPZero
		lda 	#BStrPoolBankTop
		sta 	bstrPoolBank
		rts

BStrResetBankList:
		ldx 	#BSTR_MAX_BANKS-1
_BRBZero:
		stz 	bstrBankNums,x
		dex
		bpl 	_BRBZero
		stz 	bstrBank
		rts

		.send code

		.section storage
bstrGroupCount: 							; named blocks closed so far
		.fill 	1
bstrStringCount: 							; strings in the SELECTED SLOT's flat list
		.fill 	2
bstrPoolLen: 								; bytes of [len][chars] records in the selected slot's pool
		.fill 	2
bstrBank: 									; the bank the selected slot is, for BStrRegister
		.fill 	1
bstrSlot: 									; which slot that is, 0..BSTR_MAX_BANKS-1
		.fill 	1
bstrBankCount: 								; distinct text banks this program names
		.fill 	1
bstrGroupIdx: 								; BStrFindGroup's hit, UNDOUBLED -- BStrSlots is one byte a group
		.fill 	1
bstrState: 									; 0 = no block open, 1 = one is
		.fill 	1
bstrBodyLines: 								; strings in the block being read, capped at 255
		.fill 	1
bstrName: 									; the name being opened or looked up, compressed
		.fill 	2
bstrLength: 								; characters in the string being read
		.fill 	1
bstrLenAt: 									; where its length byte sits in the pool
		.fill 	2
bstrTemp:
		.fill 	2
		.send storage

; ************************************************************************************************
;
;		THE PER-SLOT STATE, IN THE CODE SECTION and not in storage, for the reason gpbank.asm's
;		region tables are there: the code section is the compiler's own image, above ObjectBase,
;		thrown away when the object is written -- so a compiled program pays nothing for it. This
;		is 112 bytes and the storage hole is 1K holding everything else the compiler keeps between
;		statements.
;
;		Each slot's two counters are what BStrSelectSlot swaps through bstrStringCount and
;		bstrPoolLen; the records themselves are in the slot's own RAM bank and never here.
;
; ************************************************************************************************

		.section code
bstrBankNums: 								; the RAM bank each slot is -- THIS is what goes to the runtime
		.fill 	BSTR_MAX_BANKS
bstrBankStrings: 							; strings in each slot's flat list
		.fill 	2*BSTR_MAX_BANKS
bstrBankPoolLens: 							; bytes of records in each slot's pool
		.fill 	2*BSTR_MAX_BANKS
bstrBankLines: 								; the GP.BANKEDSTR line that first named each slot's bank
		.fill 	2*BSTR_MAX_BANKS
		.send code

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
