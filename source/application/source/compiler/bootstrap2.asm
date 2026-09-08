; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		bootstrap2.asm
;		Purpose:	Bootstrap EXTENSION page -- LOADs every GP.BANKED region into its bank.
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
;		This loads the regions and then does that jmp itself.
;
;		THE REGIONS ARE NOT IN THE PROGRAM ANY MORE. They used to be: compiled into the object,
;		loaded at $0801 with everything else, and copied up to $A000 from there. That made a
;		banked byte pay full FILE price to arrive, and the object file has to end below the
;		resident runtime -- 24,063 bytes for the whole thing, regions included. Eight regions of
;		8K is 64K against that, so the eight the tables allow could never have been used.
;
;		Now each region is a file of its own beside the program, named for its bank -- PROG.B09
;		for GP.BANKED 9 -- with $A000 in its own two-byte header. Secondary address 1 makes the
;		KERNAL honour that header, so selecting the bank is the whole of the work: no address
;		arithmetic, no copy loop, and the region never enters low memory at all.
;
;		WHY IT CANNOT LIVE IN THE P-CODE. The workspace starts where the regions would have run,
;		so by the time any p-code executes those addresses are variables. The bootstrap is the
;		one moment before that, and this page is part of the bootstrap.
;
;		WHY NOT SIMPLY GROW THE BOOTSTRAP. Because then every program pays. The bootstrap ends at
;		$08FF with a handful of bytes spare; the p-code base page is handed to the runtime in A at
;		run time rather than baked into it, so a SECOND page costs a patched operand and nothing
;		else.
;
;		ONCE PER LOAD, NOT PER RUN. The workspace starts where the regions were, and a second RUN
;		would reload files it already has in the banks. Zeroing the first table entry makes a
;		second RUN skip the lot. This page is never written over -- p-code starts at $0A00 and
;		the frame stack is far above -- so the zero sticks.
;
;		A MISSING OVERLAY STOPS, and that is the point of checking the carry. The bank holds
;		whatever the last program to use it left there, and running that is the one failure this
;		must not have. The programmer owns the overlay files: nothing pairs a .Bnn to the .PRG
;		that wants it, by decision, so a stale one is a stale one.
;
;		EVERY LABEL HERE IS GLOBAL AND PREFIXED BX. 64tass scopes a "_" label to the enclosing
;		global, and this file sits in the same section as bootstrap.asm; a local here would bind
;		to whatever global preceded it. See bootstrap.asm's own note.
;
; ************************************************************************************************

BXMAXREGIONS = 63 							; GPBANK_MAXREGIONS -- the machine's bank count now. One
											; byte a region here, and this page is what binds NEXT: the
											; pad below had 79 spare at sixteen, so 95 is its ceiling
BXNAMEMAX = 48 								; the overlay name the compiler bakes in below. The
											; compiler refuses a longer one rather than truncating
											; it -- see ObjBuildOverlayName.

		.section code

ProgramBootExt: 							; PHYSICAL label -- object.asm streams from here
		.logical $0900

; ------------------------------------------------------------------------------------------------
;		Entered from the bootstrap's patched jmp, with the three values it was about to hand the
;		runtime already in the registers: A = p-code base page ($0A here), X = workspace start
;		page, Y = workspace end page. Put them down, load the regions, pick them back up.
; ------------------------------------------------------------------------------------------------
BXEntry:
		sta 	BXBase
		stx 	BXWS
		sty 	BXWSEnd

		ldx 	#0 							; X walks the table, one byte an entry
BXNext:
		lda 	BXTable,x 					; the bank this region lives in, 0 = end of the table
		beq 	BXDone
		stx 	BXIndex
		sta 	$00 						; LOAD writes $A000-$BFFF through the current bank

; ------------------------------------------------------------------------------------------------
;		ONE NAME, PATCHED, not one name a region. Sixteen names at sixteen characters would be
;		256 bytes of a page with under 200 spare, so the compiler bakes the base name with "B00"
;		on the end and the two digits are poked in from the bank byte already in hand.
;
;		A is the bank, 1..99 -- the compiler refuses anything higher precisely because two digits
;		is what this template holds.
; ------------------------------------------------------------------------------------------------
		ldx 	#'0' 						; X counts tens, A comes out as the units
BXTens:
		cmp 	#10
		bcc 	BXUnits
		sbc 	#10 						; carry is set -- the compare above put it there
		inx
		bra 	BXTens
BXUnits:
		clc
		adc 	#'0'
		ldy 	BXNameLen 					; the two digits are the last two characters
		dey
		sta 	BXName,y
		dey
		txa
		sta 	BXName,y

		lda 	BXNameLen 					; SETNAM wants length in A, address in X/Y
		ldx 	#<BXName
		ldy 	#>BXName
		jsr 	BBTryLoad 					; secondary address 1: the file's own header says $A000
		bcs 	BXFail

		ldx 	BXIndex
		inx
		bne 	BXNext 						; always taken -- the table is far shorter than 256

BXDone:
		stz 	BXTable 					; a second RUN finds bank 0 and skips the lot
		;
		;		NOTHING IS DONE HERE FOR GP.BSTR ANY MORE. Which bank each of its slots reads is a
		;		table at the top of this very page, at the fixed address GPBSTRBANKS, and the runtime
		;		reads it where it lies -- so the handover is the page arriving, and there is no code.
		;		It was one byte copied into the runtime's divider padding when there was one bank.
		;
		lda 	BXBase
		ldx 	BXWS
		ldy 	BXWSEnd
		jmp 	RT_ENTRY

; ------------------------------------------------------------------------------------------------
;		An overlay that is not on the disk. Say so and drop back to BASIC READY -- the SYS return
;		address is still on the stack, exactly as it is on the bootstrap's own ?RT path.
;
;		SHORT, because a full sentence would wrap in 40 columns, and because this page is spent
;		on the loader. "?OVL" and the bank number would be better and costs a digit routine that
;		is right there above -- but the routine has already run and A is gone by here, so it
;		would have to be kept, and what the programmer does next is the same either way: look at
;		which .Bnn files are beside the program.
; ------------------------------------------------------------------------------------------------
BXFail:
		ldx 	#0
BXErr:
		lda 	BXErrText,x
		beq 	BXErrDone
		phx
		jsr 	X16_CHROUT
		plx
		inx
		bne 	BXErr
BXErrDone:
		rts 								; return to the SYS caller -> BASIC READY

; ------------------------------------------------------------------------------------------------
;		The region table: ONE BYTE A REGION -- the bank it loads into -- terminated by a zero.
;		Written by object.asm from the compiler's region list.
;
;		IT LOST ITS PAGE COUNTS when the regions became files. LOAD knows how long a file is, so
;		the only thing left to say is where it goes, and bank 0 is refused everywhere else in the
;		compiler -- it is the KERNAL's -- which is what makes it free to use as the terminator.
;		Sixty-three regions cost 64 bytes here; eight used to cost 18, with their page counts.
; ------------------------------------------------------------------------------------------------
BXTable:
		.fill 	BXMAXREGIONS + 1, 0

BXNameLen:
		.byte 	0 							; PATCHED -- the overlay name and its length, with the
BXName: 									; bank's two digits at the end of it
		.fill 	BXNAMEMAX, 0

BXBase:
		.byte 	0 							; the three the runtime is waiting for
BXWS:
		.byte 	0
BXWSEnd:
		.byte 	0
BXIndex:
		.byte 	0 							; where the table walk had got to

BXErrText:
		.text 	"?OVL", 13, 0

; ------------------------------------------------------------------------------------------------
;		WHICH RAM BANK EACH GP.BSTR SLOT READS -- one byte a slot, written by object.asm out of the
;		compiler's text-bank list, and read by the RUNTIME where it lies. There is no copy and no
;		code: the handover is this page arriving with the program.
;
;		AT THE TOP OF THE PAGE AND NOT WHEREVER IT FELL, because the runtime has to know the
;		address and cannot be told one -- it is SHARED, so one image serves every program. The
;		address is GPBSTRBANKS in common.inc, the .cerror below is what stops the loader growing
;		into it, and the table ending exactly at $0A00 is what keeps the p-code where it was.
;
;		A slot with no bank stays zero and is never read: the compiler only ever emits a slot it
;		has filled in.
; ------------------------------------------------------------------------------------------------
		.cerror * > GPBSTRBANKS, "bootstrap extension page has grown into the GP.BSTR bank table"
		.fill 	GPBSTRBANKS - *, 0 			; pad up to the table
BXBStrBanks:
		.fill 	BSTR_MAX_BANKS, 0 			; PATCHED -- and it ends exactly at $0A00, where the p-code
											; starts

		.here
ProgramBootExtEnd: 							; PHYSICAL end -- (End - Start) == 256 bytes

; ------------------------------------------------------------------------------------------------
;		Offsets of the bytes object.asm patches, within the streamed template.
; ------------------------------------------------------------------------------------------------
BootExtTableOffset = BXTable - $0900
BootExtNameLenOffset = BXNameLen - $0900
BootExtNameOffset = BXName - $0900
BootExtBStrOffset = BXBStrBanks - $0900 	; the GP.BSTR slot -> bank table, BSTR_MAX_BANKS long
BootExtEntry = BXEntry 						; the address the bootstrap's jmp is patched to

		.send code
