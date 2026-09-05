; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		bootstrap2.asm
;		Purpose:	Bootstrap EXTENSION page -- copies every GP.BANKED region into its bank.
;		Created:	5th September 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		ONLY A BANKED PROGRAM CARRIES THIS. A program with no GP.BANKED region gets the 255-byte
;		bootstrap it always got, with its p-code at $0900, and its object is byte for byte what it
;		was before this file existed. A banked program gets this page as well: the bootstrap runs
;		to its end as usual, and its closing "jmp RT_ENTRY" has been patched to come here instead.
;		This copies the regions and then does that jmp itself.
;
;		So the price -- 256 bytes of low RAM, and p-code starting at $0A00 rather than $0900 -- is
;		paid by the programs that bank and by nobody else. Against the 6,400 bytes the bench moves
;		out of low memory it is not a close call.
;
;		WHY IT CANNOT LIVE IN THE P-CODE. The region's loaded image sits at exactly
;		PCODE_PAGE + pages(low p-code), which is where the 4K frame stack begins. The frame stack
;		is ON the region, deliberately -- that is what banking reclaims. So the first frame push
;		lands on the region's first byte, and any p-code that runs has a frame stack. The bootstrap
;		is the only moment the bytes are still there, and this page is part of the bootstrap.
;
;		WHY NOT SIMPLY GROW THE BOOTSTRAP. Because then every program pays. The bootstrap ends at
;		$08FF with two bytes spare, so the multi-region loop would have had to go somewhere; the
;		p-code base page is handed to the runtime in A at run time and is not baked into it, so a
;		SECOND page costs a patched operand and nothing else.
;
;		ONCE PER LOAD, NOT PER RUN, for the bootstrap's own reason: the workspace starts where the
;		regions were, so by the time a second RUN reaches here those bytes are variables. Zeroing
;		the first table entry makes a second RUN skip the copy and use what is already in the bank,
;		which is still what the first one put there. This page is never written over -- p-code
;		starts at $0A00 and the frame stack is far above -- so the zero sticks.
;
;		HOW MANY REGIONS. Eight is arbitrary and costs 18 bytes of a page that has 130 spare;
;		the compiler refuses a ninth rather than overrunning the table.
;
;		EVERY LABEL HERE IS GLOBAL AND PREFIXED BX. 64tass scopes a "_" label to the enclosing
;		global, and this file sits in the same section as bootstrap.asm; a local here would bind
;		to whatever global preceded it. See bootstrap.asm's own note.
;
; ************************************************************************************************

BXMAXREGIONS = 8

		.section code

ProgramBootExt: 							; PHYSICAL label -- object.asm streams from here
		.logical $0900

; ------------------------------------------------------------------------------------------------
;		Entered from the bootstrap's patched jmp, with the three values it was about to hand the
;		runtime already in the registers: A = p-code base page ($0A here), X = workspace start
;		page, Y = workspace end page. Put them down, do the copies, pick them back up.
; ------------------------------------------------------------------------------------------------
BXEntry:
		sta 	BXBase
		stx 	BXWS
		sty 	BXWSEnd

		ldx 	#0 							; X walks the table, two bytes an entry
BXNext:
		lda 	BXTable,x 					; pages in this region, 0 = end of the table
		beq 	BXDone
		sta 	BXCount
		lda 	BXTable+1,x 				; ...and the bank it belongs in
		sta 	$00
		stx 	BXIndex

		ldx 	BXCount 					; whole pages, and Y stays 0 between them
		ldy 	#0
BXSrc:
		lda 	$FF00,y 					; source page -- PATCHED, and it RUNS ON across
BXDst: 										; regions, because they are contiguous in the object
		sta 	$A000,y
		iny
		bne 	BXSrc
		inc 	BXSrc+2
		inc 	BXDst+2
		dex
		bne 	BXSrc

		lda 	#$A0 						; every region lands at $A000 in its own bank, so the
		sta 	BXDst+2 					; destination goes back to the top of the window

		ldx 	BXIndex
		inx
		inx
		bne 	BXNext 						; always taken -- the table is far shorter than 256

BXDone:
		stz 	BXTable 					; a second RUN finds 0 pages and skips the lot
		lda 	BXBase
		ldx 	BXWS
		ldy 	BXWSEnd
		jmp 	RT_ENTRY

; ------------------------------------------------------------------------------------------------
;		The region table: (pages, bank) a region, terminated by a zero page count. Written by
;		object.asm from the compiler's region list. BXMAXREGIONS entries plus the terminator.
;
;		PAGES IS A BYTE AND A BANK IS 32 PAGES, so a region larger than 8K cannot be described
;		here -- which is why the compiler refuses one rather than letting the copy run past $BFFF.
; ------------------------------------------------------------------------------------------------
BXTable:
		.fill 	BXMAXREGIONS * 2 + 2, 0

BXBase:
		.byte 	0 							; the three the runtime is waiting for
BXWS:
		.byte 	0
BXWSEnd:
		.byte 	0
BXCount:
		.byte 	0 							; pages left in the region being copied
BXIndex:
		.byte 	0 							; where the table walk had got to

		.fill 	$0A00 - *, 0 				; pad through $09FF so the p-code starts at $0A00

		.here
ProgramBootExtEnd: 							; PHYSICAL end -- (End - Start) == 256 bytes

; ------------------------------------------------------------------------------------------------
;		Offsets of the bytes object.asm patches, within the streamed template. The source page is
;		an instruction OPERAND, as it is in the bootstrap, which is what keeps the loop tight.
; ------------------------------------------------------------------------------------------------
BootExtSrcOffset = BXSrc+2 - $0900
BootExtTableOffset = BXTable - $0900
BootExtEntry = BXEntry 						; the address the bootstrap's jmp is patched to

		.send code
