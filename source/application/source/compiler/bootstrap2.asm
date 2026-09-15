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
;		Now each region is a file of its own beside the program, named for its bank -- PROG.009
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
;		would reload files it already has in the banks. Zeroing the highest bank makes a second
;		RUN skip the lot. This page is never written over -- p-code starts at $0A00 and the frame
;		stack is far above -- so the zero sticks.
;
;		A MISSING OVERLAY STOPS, and that is the point of checking the carry. The bank holds
;		whatever the last program to use it left there, and running that is the one failure this
;		must not have. The programmer owns the overlay files: nothing pairs a .nnn to the .PRG
;		that wants it, by decision, so a stale one is a stale one.
;
;		EVERY LABEL HERE IS GLOBAL AND PREFIXED BX. 64tass scopes a "_" label to the enclosing
;		global, and this file sits in the same section as bootstrap.asm; a local here would bind
;		to whatever global preceded it. See bootstrap.asm's own note.
;
; ************************************************************************************************

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

; ------------------------------------------------------------------------------------------------
;		NOT ENOUGH BANKS STOPS before anything loads. MEMTOP with carry set returns the bank count
;		in A, and 0 means 256, so DEC A is the highest bank the machine has and 0 wraps to 255.
;		A second RUN has BXHigh zeroed and always passes.
; ------------------------------------------------------------------------------------------------
		sec
		jsr 	X16_MEMTOP
		dec 	a
		cmp 	BXHigh
		bcc 	BXNoRam 					; the program wants a bank above the machine's highest

; ------------------------------------------------------------------------------------------------
;		THE WALK. X is the bank, counting up from 0 to BXHigh. At the first bank of each map byte
;		the byte is copied to BXByte, and every bank shifts one bit out of the copy. The map itself
;		is never changed, so a load that fails part way leaves every bit for the next RUN.
; ------------------------------------------------------------------------------------------------
		ldx 	#0
BXNext:
		txa
		and 	#7
		bne 	BXBit 						; still inside the byte in hand
		txa
		lsr 	a
		lsr 	a
		lsr 	a
		tay
		lda 	BXMap,y 					; byte bank / 8
		sta 	BXByte
BXBit:
		lsr 	BXByte 						; bank X's bit into the carry
		bcc 	BXSkip
		stx 	BXIndex
		stx 	$00 						; LOAD writes $A000-$BFFF through the current bank

; ------------------------------------------------------------------------------------------------
;		ONE NAME, PATCHED, not one name a region. The compiler bakes the base name with "000" on
;		the end and the bank's three digits are poked over them: each is set to "0", then counted
;		up once for every 100, 10 or 1 the bank still holds.
; ------------------------------------------------------------------------------------------------
		txa 								; A is the bank, 2..255
		ldx 	BXNameLen 					; BXName-3,x is the hundreds digit
		ldy 	#0 							; Y walks the powers
BXDigit:
		pha
		lda 	#'0'
		sta 	BXName-3,x
		pla
BXCount:
		cmp 	BXPow10,y
		bcc 	BXPlace
		sbc 	BXPow10,y 					; carry is set -- the compare above put it there
		inc 	BXName-3,x
		bra 	BXCount
BXPlace:
		inx
		iny
		cpy 	#3
		bne 	BXDigit

		lda 	BXNameLen 					; SETNAM wants length in A, address in X/Y
		ldx 	#<BXName
		ldy 	#>BXName
		jsr 	BBTryLoad 					; secondary address 1: the file's own header says $A000
		bcs 	BXFail

		ldx 	BXIndex
BXSkip:
		cpx 	BXHigh 						; carry set at the highest bank,
		inx 								; and INX leaves the carry alone
		bcc 	BXNext

		stz 	BXHigh 						; a second RUN looks at bank 0 and stops
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
;		on the loader. "?OVL" and the bank number would be better, but the page has no bytes for
;		it, and what the programmer does next is the same either way: look at which .nnn files
;		are beside the program. ?RAM shares the print loop, starting at its own text.
; ------------------------------------------------------------------------------------------------
BXNoRam:
		ldx 	#BXRamText - BXErrText
		bra 	BXErr
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
;		The bank map: ONE BIT A BANK, bank n in byte n/8 at bit (n AND 7), bit 0 worth 1 -- the
;		order BANKMGR uses. Written by object.asm from the compiler's bank list, text banks
;		included, with the highest bank set in BXHigh.
;
;		32 BYTES FOR ANY PROGRAM, where the table it replaced was one byte a region. LOAD knows how
;		long a file is and the file's header says where it goes, so which banks is all the page
;		needs. BXHigh ends the walk, and bank 0 is the KERNAL's and never in the map, which is what
;		makes a zero there the re-run guard.
; ------------------------------------------------------------------------------------------------
BXMap:
		.fill 	32, 0 						; PATCHED
BXHigh:
		.byte 	0 							; PATCHED -- the highest bank in the map
BXByte:
		.byte 	0 							; the map byte being shifted out

BXNameLen:
		.byte 	0 							; PATCHED -- the overlay name and its length, with the
BXName: 									; bank's three digits at the end of it
		.fill 	BXNAMEMAX, 0

BXBase:
		.byte 	0 							; the three the runtime is waiting for
BXWS:
		.byte 	0
BXWSEnd:
		.byte 	0
BXIndex:
		.byte 	0 							; the bank being loaded
BXPow10:
		.byte 	100, 10, 1

BXErrText:
		.text 	"?OVL", 13, 0
BXRamText:
		.text 	"?RAM", 13, 0

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
BootExtMapOffset = BXMap - $0900
BootExtHighOffset = BXHigh - $0900
BootExtNameLenOffset = BXNameLen - $0900
BootExtNameOffset = BXName - $0900
BootExtBStrOffset = BXBStrBanks - $0900 	; the GP.BSTR slot -> bank table, BSTR_MAX_BANKS long
BootExtEntry = BXEntry 						; the address the bootstrap's jmp is patched to

		.send code
