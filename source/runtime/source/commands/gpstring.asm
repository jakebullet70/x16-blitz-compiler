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
;						GP.FIND(haystack$, needle$ [,start]) -> position, 0 if absent
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

UnaryGPFind: ;; [gp.find]
		.entercmd
		phy 								; Y is the code pointer offset
		;
		jsr 	FloatIntegerPart 			; <start>, the last argument pushed
		lda 	NSMantissa0,x
		bne 	_GFHaveStart
		lda 	#1 							; 0 (or omitted) means from the beginning
_GFHaveStart:
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
		beq 	_GFNotFound 				; an empty needle never matches
		;
		dec 	gpsIndex 					; 0-based from here, and slide the pointer to it
		clc
		lda 	zTemp2
		adc 	gpsIndex
		sta 	zTemp2
		bcc 	_GFOuter
		inc 	zTemp2+1
		;
		;		Does the needle still fit in what is left? Carry out means the sum passed 255,
		;		which cannot fit either.
		;
_GFOuter:
		clc
		lda 	gpsIndex
		adc 	gpsNeedLen
		bcs 	_GFNotFound
		cmp 	gpsHayLen
		beq 	_GFTry 						; an exact fit is still a fit
		bcs 	_GFNotFound
_GFTry:
		ldy 	gpsNeedLen 					; compare backwards, 1 is the first data byte
_GFInner:
		lda 	(zTemp1),y
		cmp 	(zTemp2),y
		bne 	_GFAdvance
		dey
		bne 	_GFInner
		;
		inc 	gpsIndex 					; matched -- report it 1-based
		lda 	gpsIndex
		bra 	_GFResult

_GFAdvance:
		inc 	gpsIndex
		inc 	zTemp2
		bne 	_GFOuter
		inc 	zTemp2+1
		bra 	_GFOuter

_GFNotFound:
		lda 	#0
_GFResult:
		ply
		jsr 	FloatSetByte 				; X already addresses the result slot
		.exitcmd

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
