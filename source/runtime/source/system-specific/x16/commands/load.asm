; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		load.asm
;		Purpose:	LOAD "<name>" -- chain-load and run another program
;		Created:	16th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		LOAD "<name>" loads another program over this one and runs it -- program chaining, the
;		same thing stock BASIC does when a LOAD is executed from a running program.
;
;		We do this the way it demonstrably works: by building a real one-line BASIC program
;
;			10 LOAD "<name>"
;
;		at the start of BASIC ($0801) and handing it to the ROM's RUN. LOAD, executed under a
;		genuine RUN (proper stack, CLR done, program-mode line number), loads the file over $0801
;		and chain-runs it exactly as the interpreter does -- which a synthetic single-statement
;		dispatch does NOT (the ROM's post-load rerun needs the full RUN context to land in the
;		interpreter loop; without it the load happens but nothing runs).
;
;		Layout built here (see the R49 ROM's newstt/RUN, disassembled to get this right):
;
;			$0800 : $00                the leading zero every BASIC program sits behind
;			$0801 : <link>             two bytes -> the $00 $00 end-of-program marker
;			$0803 : 10  0              line number, low/high
;			$0805 : $93 $22 <name> $22 $00     LOAD "<name>" , end of line
;			      : $00 $00            end of program
;
;		vartab is pointed just past that so RUN's CLR has an empty variable space, and txttab is
;		pinned to $0801.  RUN (.runc) sets TXTPTR = txttab-1, does CLR, resets the stack and RTSes
;		to the interpreter's per-statement loop at $CC60 (JMP newstt) -- so we push $CC5F for it
;		to return through.  Command_LOAD itself lives far above $0801, so writing the little
;		program here never touches the code doing the writing; and by the time RUN's LOAD
;		overwrites $0801 we are running in the ROM.
;
;		Variables carry across the chain, like stock's LOAD-in-a-program. RUN would normally CLR,
;		but the compiled runtime keeps its variables and strings in high RAM ($8100+), not BASIC's
;		variable space, and RUN's CLR does not touch that. What WOULD wipe them is the loaded
;		program's own StartRuntime, which clears memory -- so LOAD arms a signature (see below and
;		00runtime.asm) that tells StartRuntime this is a chain and to skip that clear. This only
;		makes sense when the two programs share a variable layout (the compiler assigns addresses
;		by first appearance, so declare the shared variables in the same order in both).
;
;		Zero page is clear: the runtime's ZP tops out around $79, well below txttab ($DF) and the
;		CHRGET/TXTPTR area ($E7/$EE), and it never touches $0200-$0800 or $03E1/$03EB.
;
; ************************************************************************************************

		.section 	code

LD_LOADTOK = $93 							; CBM BASIC token for LOAD
LD_PROG    = $0801 							; start of BASIC program space
LD_TXTTAB  = $00DF 							; ROM: start-of-program pointer
LD_VARTAB  = $03E1 							; ROM: start of variables (= end of program) -- CLR reads it
LD_RUN     = $CD30 							; ROM: the RUN statement
LD_RUNLOOP = $CC60 							; ROM: the "JMP newstt" a statement handler returns to

Command_LOAD: ;; [!load]
		.entercmd
		;
		;		zTemp0 -> filename string: a length byte followed by the characters.
		;
		lda 	NSMantissa0+0
		sta 	zTemp0
		lda 	NSMantissa1+0
		sta 	zTemp0+1
		;
		;		Arm the chain signature. The loaded program's StartRuntime sees it and skips its
		;		memory clear, so our variables (and strings) carry across the chain. It lives in
		;		low RAM, below $0801, so neither the load nor RUN's CLR disturbs it.
		;
		ldx 	#3
_LDArm:
		lda 	LoadChainMagic,x
		sta 	loadChainSig,x
		dex
		bpl 	_LDArm
		;
		;		Fixed part of the little program.
		;
		stz 	LD_PROG-1 					; $0800 = 0, the leading zero
		lda 	#10 						; line number 10
		sta 	LD_PROG+2
		stz 	LD_PROG+3
		lda 	#LD_LOADTOK 				; LOAD token
		sta 	LD_PROG+4
		lda 	#$22 						; opening quote
		sta 	LD_PROG+5
		;
		;		Copy the filename in, then close the quote, end the line, and mark end of program.
		;
		lda 	(zTemp0) 					; filename length
		sta 	ldNameLen
		ldy 	#0
_LDCopy:
		cpy 	ldNameLen
		beq 	_LDCopyDone
		iny
		lda 	(zTemp0),y 					; character i (1..len)
		sta 	LD_PROG+5,y 				; -> $0807 upward
		bra 	_LDCopy
_LDCopyDone:
		iny 								; closing quote
		lda 	#$22
		sta 	LD_PROG+5,y
		iny 								; end-of-line
		lda 	#0
		sta 	LD_PROG+5,y
		iny 								; end-of-program marker (two zero bytes)
		sta 	LD_PROG+5,y
		iny
		sta 	LD_PROG+5,y
		;
		;		Y = namelen+4.  The link at $0801 points to the first end-of-program byte, which is
		;		$0805 + Y; vartab is two past it (the byte after the second marker).
		;
		tya
		clc
		adc 	#$05 						; low of $0805 + Y
		sta 	LD_PROG 					; link low
		lda 	#$08
		adc 	#0
		sta 	LD_PROG+1 					; link high
		;
		lda 	LD_PROG 					; vartab = link + 2
		clc
		adc 	#2
		sta 	LD_VARTAB
		lda 	LD_PROG+1
		adc 	#0
		sta 	LD_VARTAB+1
		;
		lda 	#<LD_PROG 					; txttab = $0801
		sta 	LD_TXTTAB
		lda 	#>LD_PROG
		sta 	LD_TXTTAB+1
		;
		;		Enter RUN. Its CLR resets the stack and RTSes to $CC60 (JMP newstt); push $CC5F so
		;		it returns there and runs our one-line program -- which LOADs and chains.
		;
		lda 	#>(LD_RUNLOOP-1)
		pha
		lda 	#<(LD_RUNLOOP-1)
		pha
		lda 	#0 							; RUN's first act is to test Z: set => "RUN" (from the
		jmp 	LD_RUN 						; start), clear => "RUN <line>" (which would hunt for a
											; bogus line and raise UNDEF'D STATEMENT). Enter with Z=1.

		.send 	code

		.section storage
ldNameLen: 									; filename length, held across the copy loop
		.fill 	1
		.send storage

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;
; ************************************************************************************************
