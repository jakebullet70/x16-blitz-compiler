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
;		  BStrBases    2 a group   the group's first index in the flat string list
;		  BStrCounts   2 a group   how many strings are in it
;		  BStrPool                 the records, back to back
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
BSTR_MAX_STRINGS = 1000 					; comfortably past what 7,424 bytes of pool can hold

BStrNames   = $A000 							; 2 each
BStrBases   = BStrNames   + 2*BSTR_MAX_GROUPS 	; 2 each
BStrCounts  = BStrBases   + 2*BSTR_MAX_GROUPS 	; 2 each
BStrPool    = BStrCounts  + 2*BSTR_MAX_GROUPS
BSTR_POOL_SIZE = $C000 - BStrPool 			; ...to the top of the window

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
		lda 	bstrStringCount 			; the group starts where the flat list has got to
		sta 	BStrBases,x
		lda 	bstrStringCount+1
		sta 	BStrBases+1,x
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
; ************************************************************************************************

BStrFindGroup:
		ldx 	#0
		lda 	bstrGroupCount
		beq 	_BFGMiss 					; no groups at all
		stz 	bstrTemp
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
		.error_memory
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
		.bstr_access
		sta 	(zTemp2)
		.bstr_release
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
		.bstr_access
		sta 	(zTemp2)
		.bstr_release
		rts

		.send code

		.section storage
bstrGroupCount: 							; named blocks closed so far
		.fill 	1
bstrStringCount: 							; strings in the flat list, across every group
		.fill 	2
bstrPoolLen: 								; bytes of [len][chars] records written
		.fill 	2
bstrBank: 									; the one bank every group in this program goes to
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
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		07/09/26		Written.
;
