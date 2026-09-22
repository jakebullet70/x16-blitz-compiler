; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		bootstrap2.asm
;		Purpose:	Bootstrap EXTENSION page -- reads NAME.OVL and fills the GP.BANKED banks.
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
;		This reads the regions in and then does that jmp itself.
;
;		THE REGIONS ARE NOT IN THE PROGRAM. They used to be: compiled into the object, loaded at
;		$0801 with everything else, and copied up to $A000 from there. That made a banked byte pay
;		full FILE price to arrive, and the object file has to end below the resident runtime, so the
;		eight regions the tables allowed could never have been used.
;
;		ONE FILE HOLDS ALL OF THEM, NAME.OVL, and it describes itself. Each region is a bank byte,
;		a page count, and that many pages of data, and a single BXOVLEND byte follows the last of
;		them. There is no directory, no length table and no bank map, so this page is told two
;		things about the regions: the name of the file to open, and the bank to leave selected
;		when it hands over (see BXRun). Read a header, select the bank, read the pages, repeat
;		until the marker. Which banks, in what order, and with what gaps between them are the
;		writer's business and none of this code's.
;
;		PADDING EVERY REGION UP TO A PAGE is what keeps the count in one byte. A region is capped at
;		8,188 bytes, so 32 pages covers the largest one that can exist.
;
;		IT USED TO BE A FILE A REGION, NAMED FOR ITS BANK -- PROG.009 for GP.BANKED 9 -- with $A000
;		in its own two-byte header and secondary address 1 to make the KERNAL honour it. That made
;		the loading free and the page expensive: a 32-byte bitmap saying which banks to walk, and
;		three digits poked into the name for every bank walked. All of it is now the two header
;		bytes in front of each region.
;
;		SO THE BYTES COME IN THROUGH ACPTR, one at a time, and that was measured before it was
;		written: 8,192 bytes in 17 jiffies, and the whole of GPBMODS -- 32,000 bytes in eight
;		regions -- in 75. It is slower than the eight LOADs it replaces and it is one file on the
;		disk instead of eight.
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
;		would re-read a file whose contents are already in the banks. BXHigh is the guard: the
;		template ships it zero, this page makes it nonzero once the overlay is in, and a RUN that
;		finds it set goes straight to the runtime. This page is never written over -- p-code starts
;		at $0A00 and the frame stack is far above -- so the flag sticks.
;
;		A MISSING OVERLAY STOPS, and so does a truncated one, wherever it was cut. The bank holds
;		whatever the last program to use it left there, and running that is the one failure this
;		must not have. THE END MARKER IS WHAT MAKES EVERY CUT VISIBLE: a whole file reaches end of
;		file only on the marker, so end of file at the end of any page means the file is short.
;		Before the marker, the last region's last byte was the end of the file. A file cut on a
;		region boundary, or inside a region's last page, then ended the way a whole file does,
;		and it ran. The programmer owns the overlay file: nothing pairs a .OVL to the .PRG that
;		wants it, by decision, so a stale one is a stale one.
;
;		EVERY LABEL HERE IS GLOBAL AND PREFIXED BX. 64tass scopes a "_" label to the enclosing
;		global, and this file sits in the same section as bootstrap.asm; a local here would bind
;		to whatever global preceded it. See bootstrap.asm's own note.
;
; ************************************************************************************************

;
;		BXNAMEMAX and BXFILE are in common.inc, with BXOVLEND and for the same reason: the
;		runtime image reads a .OVL of its own now, so both links need both numbers and neither
;		may drift from the other. The compiler refuses a name longer than BXNAMEMAX rather than
;		truncating it -- see ObjBuildOverlayName.
;
;		BXOVLEND, the byte after the last region, is there too, and is written by the same writer
;		for both readers.
;

		.section code

ProgramBootExt: 							; PHYSICAL label -- object.asm streams from here
		.logical $0900

; ------------------------------------------------------------------------------------------------
;		Entered from the bootstrap's patched jmp, with the three values it was about to hand the
;		runtime already in the registers: A = p-code base page ($0A here), X = workspace start
;		page, Y = workspace end page. Put them down, read the overlay, pick them back up.
; ------------------------------------------------------------------------------------------------
BXEntry:
		sta 	BXBase
		stx 	BXWS
		sty 	BXWSEnd
		;
		;		A SECOND RUN HAS ITS REGIONS ALREADY. Nothing has run over them -- the workspace is
		;		untouched until the runtime starts -- so there is nothing to do but hand over.
		;
		lda 	BXHigh
		bne 	BXRun
		;
		;		The highest bank this machine has, kept for the per-region check below. MEMTOP with
		;		carry set returns the bank COUNT in A, and 0 means 256, so DEC A is the highest bank
		;		and 0 wrapping to 255 is the right answer rather than a bug.
		;
		sec
		jsr 	X16_MEMTOP
		dec 	a
		sta 	BXTop
		;
		;		Open the overlay. A PLAIN NAME, with no ",S,R" on the end of it: Box16's hypercall
		;		path opens the raw SETNAM string and would go looking for a host file actually called
		;		"NAME.OVL,S,R", while a plain name reads on x16emu, Box16 and real CMDR-DOS alike.
		;		IOSetFileName has the same note and the same reason.
		;
		lda 	BXNameLen
		ldx 	#<BXName
		ldy 	#>BXName
		jsr 	X16_SETNAM
		lda 	#BXFILE
		ldx 	#8
		ldy 	#BXFILE
		jsr 	X16_SETLFS
		jsr 	X16_OPEN
		bcs 	BXFail
		ldx 	#BXFILE 					; CHKIN TAKES THE FILE NUMBER IN X. Given it in A it
		jsr 	X16_CHKIN 					; fails, and ACPTR then waits for a talker that was
		bcs 	BXFail 						; never commanded -- a hang with nothing printed.

; ------------------------------------------------------------------------------------------------
;		One region: a bank byte, a page count, and that many pages into $A000 in that bank. Or
;		the end marker, and the overlay is in.
;
;		THE MARKER IS TESTED BEFORE THE STATUS. It is the file's last byte, so reading it sets
;		end of file, and a status test first would call a whole file short.
;
;		A BANK BYTE READ AT END OF FILE MEANS AN EMPTY FILE. A file cut between two regions has
;		already failed at the page check below, so only the first read can get here. What it
;		read is not a bank number, and selecting it would put a page of rubbish in that bank.
; ------------------------------------------------------------------------------------------------
BXRegion:
		jsr 	X16_ACPTR 					; the region's bank, or the end marker
		cmp 	#BXOVLEND
		beq 	BXAllDone
		tax 								; READST leaves X alone; ACPTR is not asked to
		jsr 	X16_READST
		bne 	BXFail 						; an empty file
		;
		;		?RAM IS PER REGION NOW, and stricter for being so: the bank actually asked for against
		;		the highest bank actually fitted, one region at a time. It used to be a single check of
		;		the top of a bitmap, made before anything loaded.
		;
		cpx 	BXTop
		beq 	BXBankOK 					; the highest bank is a legal bank
		bcs 	BXNoRam
BXBankOK:
		stx 	$00 						; the banked window is this region's from here
		jsr 	X16_ACPTR 					; and this is how many pages of it to fill
		sta 	BXPages
		;
		;		THE DESTINATION IS THE STORE'S OWN OPERAND rather than a zero page pointer. Every
		;		region starts at $A000 and only the high byte ever moves, so patching it costs three
		;		bytes where a pointer costs ten -- and it borrows no zero page from a runtime that has
		;		not started yet.
		;
		lda 	#$A0
		sta 	BXStore+2
BXPage:
		ldy 	#0
BXByteIn:
		jsr 	X16_ACPTR
BXStore:
		sta 	$A000,y 					; PATCHED, a page at a time
		iny
		bne 	BXByteIn
		inc 	BXStore+2
		;
		;		END OF FILE IS CHECKED ONCE A PAGE, and at the end of any page it is an error. A
		;		whole file reaches it only on the marker, so a cut anywhere -- inside a page, on a
		;		page boundary, on a region boundary -- is found within a page. It costs nothing
		;		inside the byte loop.
		;
		jsr 	X16_READST
		bne 	BXFail 						; the file is short
		dec 	BXPages
		bne 	BXPage
		bra 	BXRegion

; ------------------------------------------------------------------------------------------------
;		Every region is in its bank. Close, set the guard, and do the handover the bootstrap was
;		about to do when its jmp was patched to come here.
; ------------------------------------------------------------------------------------------------
BXAllDone:
		jsr 	BXClose
		inc 	BXHigh 						; a second RUN finds this set and skips the lot
BXRun:
		;
		;		WHICH BANK EACH GP.BSTR SLOT READS, into the place the runtime looks. The table is
		;		patched into this page by object.asm and copied to GPBSTRBANKS, $07F0, the top of
		;		the storage hole -- see common.inc, which has the whole of why it is there and not
		;		here. It used to be read where it lay, at the top of this page, and that address is
		;		the runtime image in an embedded program.
		;
		;		ON THE RE-RUN PATH, not inside BXAllDone, because a second RUN reaches here without
		;		reading the overlay again. Nothing clears $07F0 between the two, so this is putting
		;		back what is already there -- eleven bytes not to have to know that.
		;
		ldx 	#BSTR_MAX_BANKS-1
BXBStrCopy:
		lda 	BXBStrBanks,x
		sta 	GPBSTRBANKS,x
		dex
		bpl 	BXBStrCopy
		;
		;		THE BANK IS SET HERE, NOT LEFT WHERE THE LOADING LEFT IT. A program that falls into
		;		a GP.BANKED region from the line above reaches it by a plain GOTO, which selects no
		;		bank, so the region runs in whatever bank the program started in. That used to be
		;		the bank of the last region read, which was the last GP.BANKED region. GP.BANKEDSTR
		;		text banks are read after every region, so they took its place, and falling in ran
		;		text as p-code. The compiler patches in the last GP.BANKED region's bank instead.
		;		A second RUN, which reads nothing, now starts in the same bank as the first.
		;
		lda 	BXStartBank
		sta 	$00
		lda 	BXBase
		ldx 	BXWS
		ldy 	BXWSEnd
		jmp 	RT_ENTRY

BXClose:
		jsr 	X16_CLRCHN
		lda 	#BXFILE
		jmp 	X16_CLOSE 					; its return is this routine's return

; ------------------------------------------------------------------------------------------------
;		An overlay that is not on the disk, or is short, or wants a bank this machine does not
;		have. Say so and drop back to BASIC READY -- the SYS return address is still on the stack,
;		exactly as it is on the bootstrap's own ?RT path.
;
;		THE FILE IS CLOSED FIRST, on both paths and whether or not the OPEN got anywhere. A
;		logical file left open fails the OPEN of the next RUN, so the run after a ?OVL would say
;		?OVL as well, about a file that was there all along.
;
;		SHORT, because a full sentence would wrap in 40 columns, and because this page is spent
;		on the reader. "?OVL" and the bank number would be better, but the page has no bytes for
;		it, and what the programmer does next is the same either way: look at whether the .OVL is
;		beside the program, and whether it is the one that program was built with. ?RAM shares
;		the print loop, starting at its own text.
; ------------------------------------------------------------------------------------------------
BXNoRam:
		ldx 	#BXRamText - BXErrText
		bra 	BXErrClose
BXFail:
		ldx 	#0
BXErrClose:
		phx 								; CLOSE and CLRCHN have an X of their own
		jsr 	BXClose
		plx
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
;		The page's own state.
;
;		BXHIGH IS THE RE-RUN GUARD AND NOTHING ELSE. It was the highest bank in a bitmap that no
;		longer exists, and the name is the one thing about it that did not change. The compiler
;		does not patch it any more: the template's zero is what every program wants to ship with.
; ------------------------------------------------------------------------------------------------
BXHigh:
		.byte 	0 							; 0 = the overlay has not been read in yet
BXTop:
		.byte 	0 							; the highest bank this machine has
BXPages:
		.byte 	0 							; pages still to come in the region being read

BXNameLen:
		.byte 	0 							; PATCHED -- the overlay's name and its length, whole
BXName: 									; and complete: this page pokes nothing into it
		.fill 	BXNAMEMAX, 0

BXBase:
		.byte 	0 							; the three the runtime is waiting for
BXWS:
		.byte 	0
BXWSEnd:
		.byte 	0
BXStartBank:
		.byte 	0 							; PATCHED -- the bank selected at the handover

BXErrText:
		.text 	"?OVL", 13, 0
BXRamText:
		.text 	"?RAM", 13, 0

; ------------------------------------------------------------------------------------------------
;		WHICH RAM BANK EACH GP.BSTR SLOT READS -- one byte a slot, written by object.asm out of the
;		compiler's text-bank list, and copied to GPBSTRBANKS at BXRun.
;
;		WHEREVER IT FALLS NOW. It was pinned to the top of this page and read where it lay, which
;		is what made it free; the cost of that was an address an embedded program has its runtime
;		image at, and so no GP.BANKEDSTR in an embedded program at all. The eleven bytes of copy
;		at BXRun bought the feature in the other build. common.inc has the reasoning.
;
;		A slot with no bank stays zero and is never read: the compiler only ever emits a slot it
;		has filled in.
; ------------------------------------------------------------------------------------------------
BXBStrBanks:
		.fill 	BSTR_MAX_BANKS, 0 			; PATCHED -- sixteen slots, most of them usually zero

		.cerror * > $0A00, "bootstrap extension page has overflowed its 256 bytes"
		.fill 	$0A00 - *, 0 				; and the page is 256 bytes whatever is in it

		.here
ProgramBootExtEnd: 							; PHYSICAL end -- (End - Start) == 256 bytes

; ------------------------------------------------------------------------------------------------
;		Offsets of the bytes object.asm patches, within the streamed template.
; ------------------------------------------------------------------------------------------------
BootExtNameLenOffset = BXNameLen - $0900
BootExtNameOffset = BXName - $0900
BootExtBStrOffset = BXBStrBanks - $0900 	; the GP.BSTR slot -> bank table, BSTR_MAX_BANKS long
BootExtStartBankOffset = BXStartBank - $0900
BootExtEntry = BXEntry 						; the address the bootstrap's jmp is patched to

		.send 	code
