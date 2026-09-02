; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpstring.asm
;		Purpose:	GP.FIND and GP.STRPTR
;		Created:	16th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;		Both of these rest on one fact, verified in memory/read_string.asm: ReadStringZTemp0Sub
;		reads a string variable's block address and ADDS 2 before pushing it. So a string on the
;		number stack is already the address of [ActLen][Data] -- length at the address itself,
;		first character at address+1, and the block's capacity two bytes BELOW:
;
;			PEEK(A-2) = MaxLen (capacity)      PEEK(A) = current length
;			PEEK(A-1) = control byte           A+1     = first character
;
; ************************************************************************************************

; ************************************************************************************************
;
;						GP.INSTR(haystack$, needle$ [,start]) -> position, 0 if absent
;
;		The gap this fills: GPC has no string search of any kind -- no INSTR, nothing. Done in
;		BASIC it is a MID$ loop, which allocates a temporary string per character compared.
;
;		START is optional and 0 means "from the beginning", so it shares OptionalZeroCompile with
;		GP.CALL's registers -- no sentinel needed, because 0 is not a legal 1-based position and
;		means the same thing as 1 anyway.
;
;		X is the number stack pointer and cannot be borrowed, so the outer index lives in memory
;		and Y does the inner compare, counting DOWN from the needle length -- which also makes the
;		mismatch exit the common case's fastest path.
;
; ************************************************************************************************

UnaryGPInstr: ;; [gp.instr]
		.entercmd
		phy 								; Y is the code pointer offset
		;
		jsr 	FloatIntegerPart 			; <start>, the last argument pushed
		lda 	NSMantissa0,x
		bne 	_GIHaveStart
		lda 	#1 							; 0 (or omitted) means from the beginning
_GIHaveStart:
		sta 	gpsIndex 					; 1-based for the moment
		dex
		;
		lda 	NSMantissa0,x 				; <needle>
		sta 	zTemp1
		lda 	NSMantissa1,x
		sta 	zTemp1+1
		dex 								; X now addresses <haystack>, where the result goes
		;
		lda 	NSMantissa0,x 				; <haystack> becomes the sliding compare pointer
		sta 	zTemp2
		lda 	NSMantissa1,x
		sta 	zTemp2+1
		;
		lda 	(zTemp2) 					; lengths
		sta 	gpsHayLen
		lda 	(zTemp1)
		sta 	gpsNeedLen
		beq 	_GINotFound 				; an empty needle never matches
		;
		dec 	gpsIndex 					; 0-based from here, and slide the pointer to it
		clc
		lda 	zTemp2
		adc 	gpsIndex
		sta 	zTemp2
		bcc 	_GIOuter
		inc 	zTemp2+1
		;
		;		Does the needle still fit in what is left? Carry out means the sum passed 255,
		;		which cannot fit either.
		;
_GIOuter:
		clc
		lda 	gpsIndex
		adc 	gpsNeedLen
		bcs 	_GINotFound
		cmp 	gpsHayLen
		beq 	_GITry 						; an exact fit is still a fit
		bcs 	_GINotFound
_GITry:
		ldy 	gpsNeedLen 					; compare backwards, 1 is the first data byte
_GIInner:
		lda 	(zTemp1),y
		cmp 	(zTemp2),y
		bne 	_GIAdvance
		dey
		bne 	_GIInner
		;
		inc 	gpsIndex 					; matched -- report it 1-based
		lda 	gpsIndex
		bra 	_GIResult

_GIAdvance:
		inc 	gpsIndex
		inc 	zTemp2
		bne 	_GIOuter
		inc 	zTemp2+1
		bra 	_GIOuter

_GINotFound:
		lda 	#0
_GIResult:
		ply
		jsr 	FloatSetByte 				; X already addresses the result slot
		.exitcmd

; ************************************************************************************************
;
;					GP.INSTRREV(haystack$, needle$ [,start]) -> position, 0 if absent
;
;		*** NOT BUILT. *** This block is a design note, not documentation of shipped code: there is
;		no handler below it, no vector marker, and no token in getGP(). It is written in the
;		present tense like the entries either side of it, which is exactly how it would come to be
;		mistaken for a keyword that exists -- so it says so here. Everything below is what it WOULD
;		do if built.
;
;		(And the marker is described in words rather than shown, for the reason spelled out in the
;		GP.COMP block below: pcode.py scans comments too, and a literal one here fails the build.)
;
;		The LAST occurrence rather than the first: the extension in a filename, the last space to
;		break a line at. Named and shaped after FreeBASIC's INSTRREV (VB spells it InStrRev), which
;		is a separate function rather than PowerBASIC's negative-start-on-INSTR, because
;		GP.INSTR(f$,".",-1) does not read as "find the last one" to anyone who has not used
;		PowerBASIC specifically.
;
;		START is where a match may START, and caps the search from above; 0 or omitted means from
;		the end, which is FreeBASIC's -1 default written in this table's usual way.
;
;		It shares the inner compare with GP.INSTR and differs only in the outer walk, which runs
;		DOWNWARD from the last index a match could possibly start at. That last index is computed
;		once, which is why -- unlike the forward scan -- there is no "does it still fit" test in
;		the loop: everything at or below it fits by construction.
;
;		SHIFTED. It walks a whole string, so the 17 extra cycles of a shifted dispatch amortise,
;		and searching backwards is the rarer direction. GP.INSTR keeps the unshifted slot.
;
; ************************************************************************************************
;
;					GP.COMP(a$, b$) -> -1, 0 or 1, comparing WITHOUT case
;
;		-1 if a$ sorts before b$, 0 if they match, 1 if a$ sorts after. Same shape as prog8's
;		compare_nocase and as strcmp everywhere else, and -1/0/1 is the natural set in BASIC
;		rather than the 255 the internal comparator hands back, because BASIC's own TRUE is -1.
;		SGN builds its result the same way: FloatSetByte, then stamp the sign into NSStatus.
;
;		This is a copy of CompareStrings (strings/compare.asm, the s.cmp opcode behind = < >) with
;		two changes: both characters are folded to upper case before the compare, and the result
;		is signed. Not shared with it -- the fold is in the inner loop, so hoisting it into
;		compare.asm would put a test on the hot path of every string comparison in every program
;		to save about forty bytes here.
;
;		(Do not write a marker in square brackets after a double semicolon in a comment, even in
;		prose: common-scripts/pcode.py scans for exactly that and will read it as a real opcode
;		declaration. It fails the build with "Bad line", which is how this note came to exist.)
;
;		LENGTH still breaks a tie, unfolded, and case never enters into that: "abc" vs "ABCD"
;		compares equal for three characters and then the shorter one sorts first.
;
;		SHIFTED. It walks a whole string, like the trims.
;
; ************************************************************************************************

UnaryGPComp: ;; [!gp.comp]
		.entercmd
		dex
		;
		lda 	NSMantissa0,x 				; a$ -> zTemp0
		sta 	zTemp0
		lda 	NSMantissa1,x
		sta 	zTemp0+1
		lda 	NSMantissa0+1,x 			; b$ -> zTemp1
		sta 	zTemp1
		lda 	NSMantissa1+1,x
		sta 	zTemp1+1
		;
		phx 								; X is the number stack pointer, and the count below
		phy 								; needs a register -- so borrow it and put it back
		;
		lda 	(zTemp0) 					; compare min(len(a$),len(b$)) characters
		cmp 	(zTemp1)
		bcc 	_GCShorter
		lda 	(zTemp1)
_GCShorter:
		tax
		beq 	_GCEqualSoFar 				; one of them is empty, so length decides
		ldy 	#0
_GCLoop:
		iny
		lda 	(zTemp1),y 					; fold b$'s character into scratch first, so that A
		jsr 	GPFoldUpper 				; still holds a$'s when the compare happens and the
		sta 	gpsNeedLen 					; carry means what it does in CompareStrings
		lda 	(zTemp0),y
		jsr 	GPFoldUpper
		cmp 	gpsNeedLen
		bne 	_GCDiffer
		dex
		bne 	_GCLoop
_GCEqualSoFar:
		sec 								; every common character matched, so the shorter
		lda 	(zTemp0) 					; string sorts first -- lengths decide, unfolded
		sbc 	(zTemp1)
		beq 	_GCSame
_GCDiffer:
		bcs 	_GCAfter
		;
		ply 								; a$ sorts BEFORE b$
		plx
		lda 	#1
		jsr 	FloatSetByte
		lda 	NSStatus,x 					; ... made negative, exactly as SGN does it
		ora 	#$80
		sta 	NSStatus,x
		.exitcmd
_GCAfter:
		ply 								; a$ sorts AFTER b$
		plx
		lda 	#1
		jsr 	FloatSetByte
		.exitcmd
_GCSame:
		ply
		plx
		lda 	#0
		jsr 	FloatSetByte
		.exitcmd

;
;		A -> upper case if it is a lower case letter, untouched otherwise. Clobbers A only, so
;		PETSCII graphics, digits and punctuation all pass straight through.
;
GPFoldUpper:
		cmp 	#'a'
		bcc 	_GFUOut
		cmp 	#'z'+1
		bcs 	_GFUOut
		and 	#$DF
_GFUOut:
		rts

; ************************************************************************************************
;
;								GP.STRPTR(a$) -> address of [ActLen][Data]
;
;		The address is ALREADY what the number stack carries, so this is a retype and nothing
;		else: clear the string bit and the unused mantissa bytes and the same value is a number.
;
;		Deliberately NOT X16's STRPTR shape (which returns the first character). GPC rejects that
;		one outright -- X:UnsupportedCompile -- because the CBM [len,lo,hi] descriptor does not
;		describe GPC's blocks. Exposing GPC's own layout is safe where exposing the ROM's was not,
;		and length-then-characters is a one line rule to learn.
;
;		CAVEAT: a string LITERAL is pushed by CommandPushS pointing into the p-code itself, so an
;		address from GP.STRPTR on a literal is read-only. Writing through it modifies the program.
;
; ************************************************************************************************

UnaryGPStrPtr: ;; [gp.strptr]
		.entercmd
		stz 	NSMantissa2,x 				; the address is already in mantissa 0/1
		stz 	NSMantissa3,x
		stz 	NSExponent,x
		stz 	NSStatus,x 					; NSSIFloat is $00 -- string bit cleared, now a number
		.exitcmd
; ************************************************************************************************
;
;		GP.UPPER / GP.LOWER / GP.TRIM / GP.LTRIM / GP.RTRIM WERE HERE, and are
;		GPC-BASIC/STRCASE.INC.BL now -- written in GP.ASM, one blob with a mode byte tested once
;		at entry. So was their shared GPStringAddress. 188 bytes, removed 1st September 2026.
;
;		The reason is the block, not the code: it is ALL OR NOTHING -- every byte written into
;		the object AND taken off the bottom of the workspace, for any program that uses one GP
;		keyword -- and outside their own example file these five had exactly ONE caller in the
;		whole tree. ObjectBase $3d00 -> $3c00, which is 512 bytes back for every GP program.
;
;		GP.STRPTR STAYED, and is now load-bearing rather than a curiosity: a BASL subroutine
;		cannot be passed a variable, so the module takes the block ADDRESS and rewrites it where
;		it lies. Copying the caller's string in and out instead would be two allocations and two
;		copies per call, which is the exact heap traffic these were assembly to avoid.
;
;		WHAT THE MOVE GIVES UP: StringVariableCompile enforced a string VARIABLE at the call
;		site, so a literal could never reach a handler. A GOSUB has no equivalent, and
;		GP.STRPTR("text") is the address of the literal inside the p-code -- upper-casing that
;		edits the program. The module's header says so; the compiler can no longer say it.
;
;		WHY THERE WAS NO GP.PAD AMONG THEM. It was written, it worked, and it was removed on
;		16/08/26. These five all SHRINK or rewrite a string in place, which needs nothing but the
;		block. Padding GROWS one -- and a handler only ever receives the block address, never the
;		variable slot, so it cannot repoint the variable at a bigger block. That capped GP.PAD at
;		the capacity the string was born with (StringConcrete: length+50%, min 10), so padding
;		"HI" to a 20 column field -- the entire point of the command -- raised OUT OF RANGE.
;		Padding is STR.PAD in GPC-BASIC/STRINGS.INC.BL, one line of BASL built on RPT$,
;		where an ordinary assignment reallocates for free.
;
; ************************************************************************************************

		.send 	code

		.section storage
gpsHayLen:									; the string being searched
		.fill 	1
gpsNeedLen: 								; what is being looked for
		.fill 	1
gpsIndex: 									; how far into the haystack the compare has reached
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
;		16/08/26		Written.
;
; ************************************************************************************************
