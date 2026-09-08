; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpbstr.asm
;		Purpose:	GP.BSTR -- one string out of the GP.BANKEDSTR bank
;		Created:	7th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;					GP.BSTR(<group>, n) -> string n of that group, as a string
;
;		The read side of GP.BANKEDSTR (compiler/commands/gpbstr.asm). The text lives at $A000 in
;		a RAM bank and is fetched one item at a time, which is what lets a GUI program's several
;		thousand bytes of literal text out of low RAM entirely.
;
;		IT TAKES ONE ARGUMENT BY THE TIME IT RUNS, not two. The group name is resolved at compile
;		time to a constant base and the compiler emits an ADD, so what reaches the stack is a
;		single flat index. That keeps the addition out of here -- it costs one p-code byte at the
;		call site and saves the handler doing it -- and it is why no letter of the group name
;		appears anywhere in this file.
;
;		THE BANK LAYOUT, all offsets from $A000:
;
;			+0		string count, 16 bit
;			+2		count * 16-bit offsets, each the offset of one record from $A000
;			...		the records, [length][characters] back to back
;
;		The count is not read here. The compiler knows every index it emits and there is nothing
;		a program can do at run time to produce one out of range, so a check would cost bytes on
;		every call to catch nothing.
;
;		IT PUTS THE CALLER'S BANK BACK, and that is not tidiness -- it is what lets a GP.BANKED
;		region call this. Control returns to $A000+n in the region's own bank, so leaving the text
;		bank selected would fetch the next instruction out of the wrong one: a silent hang nowhere
;		near the call. Same reason PEEK saves and restores it (x16_peekpoke.asm), and the same
;		mistake STASH made until it was fixed.
;
;		THE INDEX COMES OUT OF THE SLOT BEFORE StringAllocTemp IS CALLED, because that routine
;		writes the allocated block's address into NSMantissa0/1,x -- the very bytes the index
;		arrived in. Read it first or it is gone.
;
;		THE TEXT IS IN ONE OF SIXTEEN BANKS AND THE CONSTANT SAYS WHICH. The top four bits of the
;		index are a SLOT, and GPBSTRBANKS turns the slot into the RAM bank -- so a program's text
;		is no longer capped at one 8K bank, and it costs the call site nothing at all: the
;		constant was already being pushed and the bits were already spare.
;
;		TWELVE BITS ARE LEFT FOR THE INDEX, and they cap nothing. An 8K bank holds at most 2,730
;		strings -- two directory bytes and a length byte each -- so the compiler's 8K region check
;		stops a bank long before 4,096 could.
;
;		GPBSTRBANKS IS WRITTEN BY THE COMPILER AND READ WHERE IT LIES: it is the top sixteen
;		bytes of the program's bootstrap extension page, filled in as that page is built. The
;		runtime is SHARED, so one image serves every program and cannot know which banks any of
;		them chose -- and it is a FIXED address from common.inc, not a label in this file,
;		because this file is linked into two images with gp.library at opposite ends and a label
;		lands somewhere different in each. See the note beside GPBSTRBANKS.
;
; ************************************************************************************************

UnaryGPBStr: ;; [!gp.bstr]
		.entercmd
		phy
		;
		;		THE INDEX GOES THROUGH GetInteger16Bit, not straight out of NSMantissa0/1. The
		;		argument arrives as whatever the expression produced -- a constant base plus a
		;		FOR variable is a float -- and reading a float's mantissa as an address is a
		;		crash a long way from here. GP.ARRPTR can read the slot raw because its argument
		;		is an array reference and is int16 by construction; this one cannot.
		;
		jsr 	GetInteger16Bit 			; slot<<12 + the index within that slot's bank, into zTemp0
		;
		;		THE SLOT COMES OFF THE TOP FIRST, because everything below wants the index alone.
		;
		;		AND X GOES ON THE STACK ACROSS IT, because X is the EVALUATION STACK SLOT -- the same
		;		X the note above says StringAllocTemp writes NSMantissa0/1,x with. Indexing the bank
		;		table with it destroys it, and the value it destroys it with is the slot: text in the
		;		program's SECOND text bank then lands in the right place by coincidence and text in
		;		the first does not, which is what it did.
		;
		phx
		lda 	zTemp0+1
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		tax
		lda 	GPBSTRBANKS,x 				; ...and which RAM bank that slot's text is in
		sta 	gpbsBank
		plx
		lda 	zTemp0+1
		and 	#$0F 						; leaving twelve bits of index
		sta 	zTemp0+1
		;
		;		The directory entry for it: $A002 + index*2.
		;
		asl 	zTemp0
		rol 	zTemp0+1
		clc
		lda 	zTemp0
		adc 	#2
		sta 	zTemp0
		lda 	zTemp0+1
		adc 	#$A0
		sta 	zTemp0+1
		;
		lda 	SelectRAMBank 				; from here to the restore below, $A000-$BFFF is text
		sta 	gpbsSaved
		lda 	gpbsBank
		sta 	SelectRAMBank
		;
		;		...and the record it points at. The stored offset is from $A000 and a bank is 8K,
		;		so its high byte is 0..$1F and adding $A0 is the whole of the relocation.
		;
		lda 	(zTemp0)
		sta 	gpbsRec
		ldy 	#1
		lda 	(zTemp0),y
		clc
		adc 	#$A0
		sta 	gpbsRec+1
		;
		;		THE POINTER IS PARKED OUT OF ZERO PAGE ACROSS StringAllocTemp, which is entitled
		;		to whatever scratch it likes -- and then put back. The length is read first for
		;		the same reason, and because StringAllocTemp overwrites the very stack slot the
		;		index arrived in with the block's address.
		;
		lda 	gpbsRec
		sta 	zTemp1
		lda 	gpbsRec+1
		sta 	zTemp1+1
		lda 	(zTemp1)
		sta 	gpbsLen
		jsr 	StringAllocTemp 			; A = length. Allocates AND retypes the slot to a string
		lda 	gpbsRec
		sta 	zTemp1
		lda 	gpbsRec+1
		sta 	zTemp1+1
		;
		lda 	gpbsLen
		sta 	(zsTemp)
		beq 	_GBSRestore 				; an empty string is a length and nothing else
		tay
_GBSCopy:
		lda 	(zTemp1),y
		sta 	(zsTemp),y
		dey
		bne 	_GBSCopy 					; y = 0 is the length byte, already written

_GBSRestore:
		lda 	gpbsSaved
		sta 	SelectRAMBank
		ply
		.exitcmd

		.send 	code

		.section storage
gpbsSaved: 									; the caller's bank, held across the fetch
		.fill 	1
gpbsBank: 									; the slot's text bank, read before the index is unpacked
		.fill 	1
gpbsLen: 									; the record's length, held across StringAllocTemp
		.fill 	1
gpbsRec: 									; the record's address, held across it too -- zero page
		.fill 	2 							; is not ours to keep over a call
		.send 	storage

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
; ************************************************************************************************
