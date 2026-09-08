; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpbstr.asm
;		Purpose:	GP.BANKEDSTR / GP.ENDBANKEDSTR -- literal text into a RAM bank
;		Created:	7th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		GP.BANKEDSTR <bank> <name>
;		"first"
;		"second"
;		GP.ENDBANKEDSTR
;
;		and then, anywhere:  A$ = GP.BSTR(<name>, n)   and   GP.BSTRCOUNT(<name>)
;
;		Text is the one thing in a program with no reason to be in low RAM: it is never executed,
;		never indexed by the interpreter, and read one item at a time. A string constant costs
;		2 + its length in RESIDENT p-code (evaluate/term/term.asm) and over half of a GUI
;		program's shell is literal text, which is what puts GPBFILES.BASL over the cap.
;
;		WHY THE BODY IS BARE QUOTED LINES, not REMs the way GP.ASM's is. BASLOAD UPPER-CASES REM
;		text -- zTemp0 reaches the object as ZTEMP0 -- so a REM body could only ever hold
;		upper-case strings. A line that is nothing but a quoted string passes through byte for
;		byte: case, leading and trailing spaces and all. Measured 7th September 2026, not
;		assumed -- " Open " tokenises to 22 20 4F 70 65 6E 20 22.
;
;		Neither delimiter has a "T", so neither writes a keyword token and neither makes the
;		program GP IN on its own -- GP.ASM's argument, for the same reason. GP.BSTR does, and
;		that is where the cost is.
;
;		NAMED GROUPS, RESOLVED AT COMPILE TIME. Several blocks a program, each named, each indexed
;		from ZERO within itself, all feeding one bank. Insert a line into one group and nothing
;		outside it moves. The name never reaches the object: BankedStrGroupCompile turns it into a
;		constant, so a group name costs no run-time bytes at all. A RUNTIME name index was costed
;		and refused -- it would put the name's letters back into resident p-code at every call
;		site, which is the very thing this exists to remove.
;
;		A NAME IS TWO BYTES, and that is not a shortcut: ExtractVariableName compresses every name
;		to two (variables/getname.asm), and BASLOAD has already crunched MENU.FILE to something
;		like A0 by the time we see it. The block header and the reference site are read by the
;		SAME routine, so the two spellings cannot diverge.
;
;		THE POOL IS IN A RAM BANK, rebuilt identically by both passes. It holds the strings back
;		to back as [len][chars] and nothing else -- the group tables slice that flat list by
;		index. The bank image is assembled from it at the end of the compile.
;
;		Errors are .error_structure and .error_syntax, reusing existing messages: errors.asm links
;		below GPBase and is copied into EVERY compiled object, so a new message would cost its
;		text in programs that never use this. Same rule as GP.ASM.
;
;		Both handlers MUST return carry clear -- a .def helper returning carry set makes the
;		generator silently drop every table element after it, with no error and no clue.
;
; ************************************************************************************************

;
;		The low byte of GP.ENDBANKEDSTR's keyword id (52818 = $CE52). GP keywords are two bytes,
;		$CE then this. Written as the id so it tracks c64tokens.py rather than a bare $52.
;
GP_TOKEN_ENDBANKEDSTR = 52818 & $FF

CommandGPBankedStrCompile:
		stz 	deferErrors 				; a block opener must never defer -- a rolled back
											; opener leaves its closer behind and corrupts the
											; nesting of any block enclosing it, silently.
		lda 	bstrState
		bne 	_CBSStructure 				; a GP.BANKEDSTR inside one still open
		stz 	bstrBodyLines
		jsr 	BStrReadHeader 				; the bank, then the name, then end of line
		lda 	#1
		sta 	bstrState

_CBSNextLine:
		lda 	#BLC_READIN 				; pull the next source line ourselves -- the main
		jsr 	CallAPIHandler 				; compile loop has no swallow-until-terminator mode
		bcc 	_CBSNoEnd 					; source ran out with the block still open
		jsr 	ProcessNewLine 				; srcPtr and currentLineNumber for the line just read

		jsr 	GetNextNonSpace 			; first thing on it
		beq 	_CBSNextLine 				; blank line inside the block, ignore it
		cmp 	#34 						; a double quote -- a body line
		beq 	_CBSBody
		cmp 	#$CE 						; the GP keyword prefix ?
		bne 	_CBSStructure
		jsr 	GetNext 					; which GP keyword
		cmp 	#GP_TOKEN_ENDBANKEDSTR
		beq 	_CBSClose
_CBSStructure: 								; anything else in here is not a string
		.error_structure

_CBSBody:
		jsr 	BStrAppendString 			; the opening quote is already consumed
		inc 	bstrBodyLines 				; a body line -- the block is not empty
		bne 	_CBSNextLine 				; (255 lines wraps to 0; the emptiness test only
		dec 	bstrBodyLines 				;  cares about zero, so stick at 255)
		bra 	_CBSNextLine

;
;		GP.ENDBANKEDSTR. An empty block is refused: a group with no strings makes GP.BSTRCOUNT
;		zero and every GP.BSTR on it read the next group's text.
;
_CBSClose:
		lda 	bstrBodyLines
		beq 	_CBSStructure
		jsr 	BStrCloseGroup 				; the count goes in, and the group becomes a group
		stz 	bstrState
		jmp 	BStrRequireEOL

_CBSNoEnd: 									; GP.BANKEDSTR with no GP.ENDBANKEDSTR
		.error_structure

;
;		A GP.ENDBANKEDSTR reached by the main compile loop had no opener -- the handler above
;		consumes its own, so this is only ever reached by a stray one.
;
CommandGPEndBankedStrCompile:
		stz 	deferErrors
		.error_structure

; ************************************************************************************************
;
;		The header:  GP.BANKEDSTR <bank> <name>
;
;		ANY BANK, AND AS MANY AS SIXTEEN. A block names the bank its text goes to and blocks need
;		not agree: each distinct bank becomes a SLOT, in first appearance order, and each slot
;		becomes a region and an overlay file of its own. It was one bank for the whole program,
;		which capped a program's literal text at the 8K one bank holds.
;
;		THE BANK IS STILL WRITTEN ON EVERY BLOCK, and now it has to be: a block should be readable
;		where it sits, and which bank this one goes to is no longer answerable by finding the
;		first block in the file.
;
;		THE NAME MAY NOT CARRY A TYPE. A group is not a variable, so a $, a % or a ( on it is a
;		syntax error rather than something quietly ignored -- NSSString, NSSIInt16 and NSSArray
;		all ride in the X byte ExtractVariableName returns, and any of them puts it above 31.
;
; ************************************************************************************************

BStrReadHeader:
		jsr 	GPBankReadNumber 			; the bank, into gpBankNumber -- shared with GP.BANKED
		lda 	gpBankNumber 				; find it among this program's text banks or add it, and make
		jsr 	BStrSelectBank 				; it the one the groups below go to
		jsr 	GetNextNonSpace 			; a name starts with a letter
		jsr 	CharIsAlpha
		bcc 	_BRHSyntax
		jsr 	ExtractVariableName 		; X = first char + type bits, Y = second
		cpx 	#32 						; any type bit at all is a syntax error
		bcs 	_BRHSyntax
		stx 	bstrName
		sty 	bstrName+1
		jsr 	BStrFindGroup 				; CS: this name is already a group
		bcs 	_BRHStructure
		jsr 	BStrOpenGroup
		jmp 	BStrRequireEOL

_BRHStructure:
		.error_structure
_BRHSyntax:
		.error_syntax

;
;		Nothing may follow either delimiter. With deferErrors already disarmed this aborts the
;		compile rather than quietly becoming a runtime throw-stub.
;
BStrRequireEOL:
		jsr 	LookNextNonSpace
		bne 	_BREBad
		clc 								; .def helpers MUST return carry clear
		rts
_BREBad:
		.error_syntax


; ************************************************************************************************
;
;		GP.BSTR(<name>, n)  and  GP.BSTRCOUNT(<name>)
;
;		The two argument helpers, and they are the whole of the naming. Each reads a bare
;		identifier straight out of the source -- exactly as AnyArrayCompile does for
;		GP.ARRPTR(A$()) (evaluate/term/gensupport.asm) -- looks it up in the GROUP table rather
;		than the variable table, and pushes a CONSTANT.
;
;		SO THE NAME NEVER REACHES THE OBJECT. GP.BSTR(MENU.FILE, I) compiles to a small constant
;		plus I plus the keyword; the letters M-E-N-U cost nothing at run time. That is the whole
;		reason the lookup is here and not in the bank.
;
;		AND NEITHER DOES THE BANK. The constant is slot<<12 + the group's first index IN ITS OWN
;		BANK, so which of the program's sixteen text banks to read comes out of bits that were
;		already spare -- the runtime turns the slot into a bank through GPBSTRBANKS. Sixteen text
;		banks therefore cost a call site NOTHING, and there are 250 of them in GPBMODS and 347 in
;		GPBFILES: a second operand would have been ~500 and ~700 bytes of RESIDENT p-code, which
;		is the side that is short of room.
;
;		THEY MUST NOT FALL THROUGH TO THE VARIABLE TABLE. A mistyped group name has to be a hard
;		error: silently finding a variable of the same name would compile clean and read the
;		wrong string, or string zero, for ever.
;
;		GP.BSTRCOUNT HAS NO "T" and so no runtime handler anywhere -- it is the GP.HIBYTE pattern
;		(evaluate/term/gpcomposite.asm). It emits the group's count as a plain integer constant,
;		which is what makes FOR I = 0 TO GP.BSTRCOUNT(X)-1 free.
;
; ************************************************************************************************

BankedStrGroupCompile:
		jsr 	BStrReadName 				; X = the doubled subscript of the group
		.bstr_access
		lda 	BStrBases,x
		sta 	bstrTemp
		lda 	BStrBases+1,x
		sta 	bstrTemp+1
		ldy 	bstrGroupIdx 				; ...and which text bank it is in, as a slot
		lda 	BStrSlots,y
		.bstr_release
		asl 	a 							; THE SLOT GOES IN THE TOP FOUR BITS, where the index cannot
		asl 	a 							; reach it: an 8K bank holds at most 2,730 strings and the
		asl 	a 							; twelve bits left over address 4,096, so the region's own 8K
		asl 	a 							; check always fires first
		ora 	bstrTemp+1
		tay
		lda 	bstrTemp
		jsr 	PushIntegerYA 				; slot<<12 + the group's first index in THAT BANK's flat list
		clc 								; carry CLEAR or the "N" after the X: is dropped
		rts

BankedStrCountCompile:
		jsr 	BStrReadName
		.bstr_access
		lda 	BStrCounts,x
		sta 	bstrTemp
		lda 	BStrCounts+1,x
		.bstr_release
		tay
		lda 	bstrTemp
		jsr 	PushIntegerYA 				; how many strings the group holds
		clc
		rts


;
;		The name at a reference site, into X as the doubled group subscript. Read with the SAME
;		ExtractVariableName the block header used, which is what stops the two spellings from
;		ever disagreeing -- BASLOAD has crunched the source name to two characters by now and
;		both sites see the same two.
;
BStrReadName:
		jsr 	GetNextNonSpace
		jsr 	CharIsAlpha
		bcc 	_BRNSyntax
		jsr 	ExtractVariableName 		; X = first char + type bits, Y = second
		cpx 	#32 						; a group name carries no $, % or ( -- see the header
		bcs 	_BRNSyntax
		stx 	bstrName
		sty 	bstrName+1
		jsr 	BStrFindGroup
		bcc 	_BRNSyntax 					; no GP.BANKEDSTR block ever declared this name
		rts
_BRNSyntax:
		;
		;		NOT DEFERRED. An expression statement arms deferErrors, which turns a compile error
		;		into a runtime throw-stub -- right for a keyword the runtime might not have, wrong
		;		for a name that is resolved entirely at compile time. A typo'd group name would
		;		otherwise compile clean and explode when that line ran.
		;
		stz 	deferErrors
		.error_syntax

;
;		And the add that turns (base, index) into the one flat index the handler takes. It sits after
;		the "#" in the .def line, which is where MID$'s OptionalParameterCompile sits, so by the time
;		it runs both halves are on the stack.
;
;		ONE P-CODE BYTE AT THE CALL SITE, and it buys the whole addition out of the runtime handler --
;		which is the side that is short of room, not the object.
;
BankedStrAddCompile:
		.keyword PCD_PLUS
		clc 								; carry CLEAR or the "S" after the X: is dropped
		rts

		.send code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		07/09/26		Written.
;
