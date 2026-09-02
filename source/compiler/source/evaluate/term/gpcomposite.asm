; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpcomposite.asm
;		Purpose:	COMPOSITE GP keywords -- keywords with no p-code of their own
;		Created:	19th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;		WHAT A COMPOSITE KEYWORD IS, since this file is the first of them.
;
;		A normal keyword's .def entry ends with "T", which emits its own p-code token, and a
;		handler in the runtime answers that token. That handler is linked into EVERY compiled
;		program whether it is called or not.
;
;		A composite keyword has NO "T". It emits nothing of its own; a routine in here writes a
;		sequence of tokens that ALREADY EXIST instead. So the keyword is a name for a byte
;		sequence and costs the runtime nothing at all -- no handler, no vector slot, no opcode,
;		no RT_ABI bump. Think of it as an inline function that lives in the compiler: the
;		definition never ships, only the expansion does.
;
;		IT IS THE ABSENCE OF "T" THAT MAKES IT COMPOSITE, NOT THE PRESENCE OF "X:". GP.TRIM is
;		"X:StringVariableCompile T N" and is emphatically not composite -- its X: is an ARGUMENT
;		PARSER (it insists on a plain string variable), and it still emits gp.trim and still has
;		a real handler in gpstring.asm. NOT and FN in unary.def are the shape to copy: X: with
;		no T.
;
;		WHAT CAN BE ONE. Only a keyword that is a rearrangement of things that already exist AND
;		uses each argument EXACTLY ONCE. The p-code stack has SWAP but no DUP, so an argument
;		needed twice cannot be had -- which is why GP.ENDSWITH is not in here (it wants
;		RIGHT$(a$,LEN(b$))=b$, and b$ appears twice). Anything needing a branch or a loop is out
;		for the same reason.
;
;		THE clc BEFORE EVERY rts IS NOT OPTIONAL. GeneratorExecute reads carry as "keep going";
;		return with it SET and every table element after the X: is silently dropped, including
;		the "N" that types the result. No error is raised -- the compiler just emits garbage.
;
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;						GP.CONTAINS(a$, b$) -- does b$ occur anywhere in a$ ?
;
;		Compiles to exactly what GP.INSTR(a$,b$) <> 0 compiles to, five bytes past the two string
;		expressions the table has already compiled for us:
;
;			<a$> <b$> 00 gp.instr 00 f.cmp <>
;
;		The two constants are one byte each -- PushIntegerA writes anything under 64 as a bare
;		byte -- and gp.instr is unshifted, so nothing here costs two.
;
;		The f.cmp/<> PAIR is how a comparison between numbers is spelt in p-code; f.cmp leaves
;		255/0/1 and the comparator reads it. CompileCaseTest in commands/select.asm emits the
;		same pair by hand for the same reason, and the expression compiler itself emits it for
;		any "=" you write (evaluate/expression.asm).
;
;		CASE SENSITIVE, because gp.instr compares raw bytes. GP.COMP is the case folding one and
;		is a whole-string compare, not a search, so it cannot serve here; a case insensitive
;		search would need a folding loop, which is real machine code and not a composite.
;
;		AN EMPTY NEEDLE IS FALSE. gp.instr returns 0 for a zero length needle ("an empty needle
;		never matches", gpstring.asm), so GP.CONTAINS(a$,"") is 0 even though every string
;		trivially contains "". Correcting it needs a branch, which a composite cannot express.
;
; ************************************************************************************************

GPContainsCompile:
		lda 	#0 							; gp.instr's optional start -- 0 is "from the beginning"
		jsr 	PushIntegerA
		.keyword PCD_GPCMD_INSTR 			; -> the 1-based position, or 0 if it is not there
		;
		lda 	#0 							; found ANYWHERE at all is "the position is not zero"
		jsr 	PushIntegerA
		.keyword PCD_FCMD_CMP 				; compare the two numbers -> 255/0/1 ...
		.keyword PCD_LESSGREATER 			; ... which "<>" turns into BASIC's -1 or 0
		clc 								; carry CLEAR or the "N" after the X: is dropped
		rts


; ************************************************************************************************
;
;			GP.HIBYTE(n) / GP.LOBYTE(n) -- an address split into the two bytes a 6502 takes
;
;		A 6502 address is sixteen bits and everything that consumes one -- GP.CALL's registers,
;		VERA's $9F20/$9F21 -- takes eight at a time. So every address that leaves BASIC for machine
;		code gets split, and GP.STRPTR / GP.ARRPTR exist precisely to hand one over.
;
;			GP.HIBYTE(n)  =  INT(n / 256)      which 256 byte page
;			GP.LOBYTE(n)  =  MOD(n, 256)       offset within it
;
;		WHY THESE EARN A KEYWORD when the expressions are short. The obvious low byte, "n AND 255",
;		is a LIVE BUG in GPC: AND is 16 bit SIGNED, and every address worth splitting is above
;		32767 -- the string heap always is -- so it raises OUT OF RANGE rather than masking. The
;		tree currently writes the long form out by hand in four places, each with a warning comment
;		nailed beside it (ARRAYS.EXP.BL, BMX.INC.BL, MENUVERT.INC.BL, GPB.INC.BL). A keyword makes
;		the correct form the short one and the wrong form unreachable.
;
;		MOD rather than the subtraction the docs currently recommend, because MOD uses the whole
;		argument ONCE. "n - INT(n/256)*256" needs it twice, and a composite has no DUP -- so the
;		spelling is not a preference here, it is the only one that fits. Measured 2026-08-19:
;		MOD(1000000,256) = 64 and MOD(40693,256) = 245, agreeing with the subtraction form, so
;		UnaryMOD's Int32Divide really is clear of the 16 bit signed path AND takes.
;
;		DOMAIN is 0..65535, which is every address on this machine. A negative argument is not
;		rejected: INT rounds toward minus infinity while MOD works on magnitudes, so the two would
;		stop being a matched pair. Nothing that produces an address can produce a negative.
;
; ************************************************************************************************

GPHiByteCompile:
		jsr 	GPPush256
		.keyword PCD_DIVIDE
		.keyword PCD_INT 					; INT after the divide, not a shift -- n may be a float
		clc 								; carry CLEAR or the "N" after the X: is dropped
		rts

GPLoByteCompile:
		jsr 	GPPush256
		.keyword PCD_MOD 					; MOD(n,256): dividend pushed first, divisor on top
		clc
		rts

;
;		256 will not fit the one byte constant path, so PushIntegerYA emits a two byte .word --
;		the same shape OptionalColourCompile uses for its 256 sentinel.
;
GPPush256:
		lda 	#0
		ldy 	#1
		jmp 	PushIntegerYA


; ************************************************************************************************
;
;								GP.ISEMPTY(a$) -- is the string zero length ?
;
;			<a$> len 0 f.cmp =        four bytes past the string expression
;
;		READABILITY ONLY, and it is worth saying so plainly because the obvious guess is that a
;		keyword must be faster. It is not: this compiles to exactly what LEN(a$)=0 compiles to, and
;		IF a$="" costs about the same again -- CommandPushS points a literal INTO the p-code, so
;		even the empty string literal allocates nothing. All three are the same price. This one just
;		states the question rather than leaving the reader to infer it from the shape of a test.
;
;		Returns BASIC's -1 / 0, like every other comparison in the language.
;
; ************************************************************************************************

GPIsEmptyCompile:
		.keyword PCD_LEN
		lda 	#0
		jsr 	PushIntegerA
		.keyword PCD_FCMD_CMP 				; the number comparison pair, as GP.CONTAINS above
		.keyword PCD_EQUAL
		clc 								; carry CLEAR or the "N" after the X: is dropped
		rts

		.send 	code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		19/08/26		Written.
;
; ************************************************************************************************
