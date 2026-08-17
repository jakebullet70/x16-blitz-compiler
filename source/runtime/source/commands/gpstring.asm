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
;				GP.TRIM a$ / GP.UPPER a$ / GP.LOWER a$ -- modify in place
;
;		All three take a string VARIABLE, enforced at compile time by StringVariableCompile, so
;		none of them checks anything here: a literal cannot reach them, and a literal is the one
;		thing that would matter, because CommandPushS points literals into the p-code itself.
;
;		They are SHIFTED. Each walks a whole string, so the 17 extra cycles of a shifted dispatch
;		amortise over its length -- about 5% on a 20 character string -- and the unshifted slots
;		are the scarce ones. GP.A and friends are the opposite case and stayed unshifted.
;
;		WHY THERE IS NO GP.PAD HERE. It was written, it worked, and it was removed on 16/08/26.
;		These three all SHRINK or rewrite a string in place, which needs nothing but the block.
;		Padding GROWS one -- and a handler only ever receives the block address, never the
;		variable slot, so it cannot repoint the variable at a bigger block. That capped GP.PAD at
;		the capacity the string was born with (StringConcrete: length+50%, min 10), so padding
;		"HI" to a 20 column field -- the entire point of the command -- raised OUT OF RANGE.
;		Padding is now STRHELP.PAD in GPC-BASIC/STRHELP.INC.BL, one line of BASL built on RPT$,
;		where an ordinary assignment reallocates for free. See that file's header.
;
; ************************************************************************************************

;
;		Shared entry: TOS is the string. zTemp0 = its block, A = current length, Z set if empty.
;
GPStringAddress:
		lda 	NSMantissa0,x
		sta 	zTemp0
		lda 	NSMantissa1,x
		sta 	zTemp0+1
		dex 								; consume it -- these are statements, not functions
		lda 	(zTemp0)
		rts

; ************************************************************************************************
;
;		GP.UPPER / GP.LOWER. ASCII range only: 97-122 -> 65-90 and back, which is a bit 5 flip
;		once the range is known. Nothing outside that range is touched, so PETSCII graphics
;		characters and digits pass through untouched rather than being mangled.
;
; ************************************************************************************************

CommandGPUpper: ;; [!gp.upper]
		.entercmd
		phy
		jsr 	GPStringAddress
		beq 	_GUExit
		tay
_GULoop:
		lda 	(zTemp0),y
		cmp 	#'a'
		bcc 	_GUNext
		cmp 	#'z'+1
		bcs 	_GUNext
		and 	#$DF 						; clear bit 5
		sta 	(zTemp0),y
_GUNext:
		dey
		bne 	_GULoop
_GUExit:
		ply
		.exitcmd

CommandGPLower: ;; [!gp.lower]
		.entercmd
		phy
		jsr 	GPStringAddress
		beq 	_GLExit
		tay
_GLLoop:
		lda 	(zTemp0),y
		cmp 	#'A'
		bcc 	_GLNext
		cmp 	#'Z'+1
		bcs 	_GLNext
		ora 	#$20 						; set bit 5
		sta 	(zTemp0),y
_GLNext:
		dey
		bne 	_GLLoop
_GLExit:
		ply
		.exitcmd

; ************************************************************************************************
;
;		GP.TRIM strips spaces from BOTH ends, GP.RTRIM from the trailing end only, GP.LTRIM from
;		the leading end only. The two ends are not the same problem and that is why the split is
;		free: trailing is nearly so (move the length byte and the characters stay put), while
;		leading has to SLIDE the whole string down, which needs a second pointer because X is the
;		number stack pointer and can never be borrowed as an index.
;
;		Two helpers, three thin entry points. GP.TRIM is right-then-left, in that order
;		deliberately -- right first shortens the string the left pass has to walk, and if it
;		empties it the left pass falls straight out.
;
; ************************************************************************************************

CommandGPTrim: ;; [!gp.trim]
		.entercmd
		phy
		jsr 	GPStringAddress
		jsr 	GPTrimRight
		jsr 	GPTrimLeft
		ply
		.exitcmd

CommandGPRTrim: ;; [!gp.rtrim]
		.entercmd
		phy
		jsr 	GPStringAddress
		jsr 	GPTrimRight
		ply
		.exitcmd

CommandGPLTrim: ;; [!gp.ltrim]
		.entercmd
		phy
		jsr 	GPStringAddress
		jsr 	GPTrimLeft
		ply
		.exitcmd

;
;		Trailing spaces: walk back from the end and write the new length. Nothing moves. Y
;		falling to zero IS the all-spaces answer, no special case needed.
;
GPTrimRight:
		lda 	(zTemp0)
		beq 	_GTRExit 					; already empty
		tay
_GTRLoop:
		lda 	(zTemp0),y
		cmp 	#' '
		bne 	_GTRSet 					; Y is the last non-space
		dey
		bne 	_GTRLoop
_GTRSet:
		tya
		sta 	(zTemp0)
_GTRExit:
		rts

;
;		Leading spaces: find the first non-space, then slide everything from it down to offset 1.
;		gpsNeedLen counts DOWN as spaces are skipped, so when the scan stops it already holds the
;		kept length -- no subtraction, and reaching zero is exactly the all-spaces case.
;
GPTrimLeft:
		lda 	(zTemp0)
		beq 	_GTLExit 					; already empty
		sta 	gpsNeedLen
		ldy 	#1
_GTLScan:
		lda 	(zTemp0),y
		cmp 	#' '
		bne 	_GTLFound
		iny
		dec 	gpsNeedLen
		bne 	_GTLScan
		lda 	#0 							; all spaces (A holds a space here, so reload it)
		sta 	(zTemp0)
		rts
_GTLFound:
		cpy 	#1 							; nothing to slide if it already starts at 1
		beq 	_GTLSetLength
		;
		tya 								; zTemp1 = zTemp0 + (first - 1), so (zTemp1),1 is the
		dec 	a 							; first character being kept
		clc
		adc 	zTemp0
		sta 	zTemp1
		lda 	zTemp0+1
		adc 	#0
		sta 	zTemp1+1
		ldy 	#0
_GTLMove:
		iny
		lda 	(zTemp1),y
		sta 	(zTemp0),y
		cpy 	gpsNeedLen
		bne 	_GTLMove
_GTLSetLength:
		lda 	gpsNeedLen
		sta 	(zTemp0)
_GTLExit:
		rts

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
