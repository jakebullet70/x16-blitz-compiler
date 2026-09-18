; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpbstr.asm
;		Purpose:	GP.BSTR / GP.BSTRSET -- one string out of, or into, a GP.BANKEDSTR bank
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
;					GP.BSTRSET <group>, n, A$ -> A$ into string n, cut to fit
;
;		The run-time side of GP.BANKEDSTR (compiler/commands/gpbstr.asm). The text lives at $A000
;		in a RAM bank and is fetched one item at a time, which is what lets a GUI program's several
;		thousand bytes of literal text out of low RAM entirely.
;
;		EACH GETS ONE INDEX BY THE TIME IT RUNS, not a group and a number. The group name is
;		resolved at compile time to a constant base and the compiler emits an ADD, so what reaches
;		the stack is a single flat index. That keeps the addition out of here -- it costs one p-code
;		byte at the call site and saves the handler doing it -- and it is why no letter of the group
;		name appears anywhere in this file.
;
;		THE BANK LAYOUT, all offsets from $A000:
;
;			+0		string count, 16 bit
;			+2		count * 16-bit offsets, each the offset from $A000 of one record's LENGTH byte
;			...		the records, [capacity][length][capacity bytes] back to back
;
;		The directory names the length, so GP.BSTR finds it where it always did, and the capacity
;		is the byte below it.
;
;		ONLY THE WRITE CHECKS THE COUNT. A read past it returns whatever the garbage it takes for an
;		offset points at. A write past it would store there, and the I/O page at $9Fxx is one of
;		the places -- so GP.BSTRSET writes nothing when n is not below the count. Nor when the slot
;		has no bank: object.asm leaves an unused slot at 0, and bank 0 is the KERNAL's.
;
;		BOTH PUT THE CALLER'S BANK BACK, and that is not tidiness -- it is what lets a GP.BANKED
;		region call them. Control returns to $A000+n in the region's own bank, so leaving the text
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
;		TWELVE BITS ARE LEFT FOR THE INDEX, and they cap nothing. An 8K bank holds at most 2,047
;		strings -- two directory bytes and a capacity and a length byte each -- so the compiler's
;		8K region check stops a bank long before 4,096 could.
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
		jsr 	GPBStrRecord 				; the text bank selected, and the length byte in zTemp1
		;
		;		THE RECORD IS PARKED ON THE STACK ACROSS StringAllocTemp, which is entitled to
		;		whatever scratch it likes -- zero page is not ours to keep over a call. The length
		;		goes too, read first, because StringAllocTemp takes it in A and spends A.
		;
		lda 	zTemp1+1
		pha
		lda 	zTemp1
		pha
		lda 	(zTemp1)
		pha
		jsr 	StringAllocTemp 			; A = length. Allocates AND retypes the slot to a string
		ply 								; the length, and where the copy starts
		pla
		sta 	zTemp1
		pla
		sta 	zTemp1+1
		tya
		sta 	(zsTemp)
		beq 	GPBStrRestore 				; an empty string is a length and nothing else
_GBSCopy:
		lda 	(zTemp1),y
		sta 	(zsTemp),y
		dey
		bne 	_GBSCopy 					; y = 0 is the length byte, already written
		;
		;		Both handlers leave through here.
		;
GPBStrRestore:
		lda 	gpbsSaved
		sta 	SelectRAMBank
		ply
		.exitcmd

; ************************************************************************************************
;
;								GP.BSTRSET <group>, n, A$
;
;		A statement. The flat index is pushed first and A$ second, so X arrives as 1, and the
;		stack is left empty. A$ is [length][text] in low memory: the compiler copies a literal out
;		of a GP.BANKED region before this runs ("@" in commands.def), because from GPBStrRecord to
;		GPBStrRestore the region's bank is not the one at $A000. An empty A$ is a zero length byte
;		and never a null address -- ReadStringZTemp0Sub puts one in for an unassigned variable.
;
;		CUT, NOT REFUSED. A string longer than the slot keeps its first capacity characters and
;		raises nothing, and the next record's capacity byte is never reached.
;
; ************************************************************************************************

CommandGPBStrSet: ;; [!gp.bstrset]
		.entercmd
		phy
		dex 								; X = 0, the flat index. A$ is on top, in slot 1
		jsr 	GPBStrRecord
		dex 								; X = $FF, as POKE leaves it -- DEX keeps the carry
		bcs 	GPBStrRestore 				; n is not below the bank's count: write nothing
		lda 	SelectRAMBank 				; ...nor into a slot with no bank
		beq 	GPBStrRestore
		lda 	NSMantissa0+1
		sta 	zTemp0
		lda 	NSMantissa1+1
		sta 	zTemp0+1
		;
		;		THE CAPACITY IS THE BYTE BEFORE THE LENGTH, reached through its own pointer. The
		;		shorter trick -- a page down and (zp),y with Y = $FF -- puts the base in $9Fxx for a
		;		record in the bank's first page, and a page-crossing dummy read there is I/O.
		;
		sec
		lda 	zTemp1
		sbc 	#1
		sta 	zTemp2
		lda 	zTemp1+1
		sbc 	#0
		sta 	zTemp2+1
		lda 	(zTemp2)
		cmp 	(zTemp0) 					; the shorter of the capacity and A$ is the new length
		bcc 	_GBSSLength
		lda 	(zTemp0)
_GBSSLength:
		sta 	(zTemp1)
		tay 								; STA sets no flags: TAY is what tests the length for zero
		beq 	GPBStrRestore
_GBSSCopy:
		lda 	(zTemp0),y
		sta 	(zTemp1),y
		dey
		bne 	_GBSSCopy
		bra 	GPBStrRestore

; ************************************************************************************************
;
;		The flat index in stack slot X, to the record it names -- the walk both handlers share.
;		Returns with the TEXT BANK SELECTED and the caller's in gpbsSaved, for GPBStrRestore; the
;		record's length byte in zTemp1; and CS when the index is not below the bank's count,
;		which only the write looks at. X is kept.
;
; ************************************************************************************************

GPBStrRecord:
		;
		;		THE INDEX GOES THROUGH GetInteger16Bit, not straight out of NSMantissa0/1. The
		;		argument arrives as whatever the expression produced -- a constant base plus a
		;		FOR variable is a float -- and reading a float's mantissa as an address is a
		;		crash a long way from here. GP.ARRPTR can read the slot raw because its argument
		;		is an array reference and is int16 by construction; this one cannot.
		;
		jsr 	GetInteger16Bit 			; slot<<12 + the index within that slot's bank, into zTemp0
		;
		;		THE SLOT COMES OFF THE TOP, AND Y INDEXES THE BANK TABLE WITH IT. Not X: X is the
		;		EVALUATION STACK SLOT, the same X StringAllocTemp writes NSMantissa0/1,x with. The
		;		read once indexed with X and lost it -- text in the program's SECOND text bank then
		;		landed in the right place by coincidence and text in the first did not.
		;
		lda 	zTemp0+1
		lsr 	a
		lsr 	a
		lsr 	a
		lsr 	a
		tay
		lda 	SelectRAMBank 				; from here to GPBStrRestore, $A000-$BFFF is text
		sta 	gpbsSaved
		lda 	GPBSTRBANKS,y 				; ...in the RAM bank that slot's text is in
		sta 	SelectRAMBank
		;
		;		The directory entry is at $A002 + index*2: zTemp2 is $A000 + index*2, and the 2
		;		rides in Y. NO CLC before either add of $A0. The ROL shifts out bit 15, which the AND
		;		has cleared, and index*2 is below $2000, so the first add carries nothing out.
		;
		lda 	zTemp0
		asl 	a
		sta 	zTemp2
		lda 	zTemp0+1
		and 	#$0F 						; twelve bits of index, with the slot left behind
		rol 	a
		adc 	#$A0
		sta 	zTemp2+1
		;
		;		...and the record it points at. The stored offset is from $A000 and a bank is 8K,
		;		so its high byte is 0..$1F and adding $A0 is the whole of the relocation.
		;
		ldy 	#2
		lda 	(zTemp2),y
		sta 	zTemp1
		iny
		lda 	(zTemp2),y
		adc 	#$A0
		sta 	zTemp1+1
		;
		lda 	zTemp0 						; the index against the count
		cmp 	$A000
		lda 	zTemp0+1
		and 	#$0F
		sbc 	$A001
		rts

		.send 	code

		.section storage
gpbsSaved: 									; the caller's bank, held until GPBStrRestore
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
;		07/09/26		Written.
;		18/09/26		GP.BSTRSET, the capacity byte, and the walk shared as GPBStrRecord.
;
; ************************************************************************************************
