; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		symfile.asm
;		Purpose:	Translate a GP.ASM {VAR} name through BASLOAD's #SYMFILE.
;		Created:	30th August 2026
;
; ************************************************************************************************
; ************************************************************************************************
;
;		BASLOAD RENAMES EVERY VARIABLE. N% becomes A%, which is how it offers 64 character
;		names on a two character BASIC -- and it stores REM text byte for byte, which is the
;		very property that lets a GP.ASM body survive tokenisation at all. So {N%} in a REM
;		names a variable the compiled code no longer calls N%, and an assembly block written
;		against the source spelling would read and write a slot BASIC never touches.
;
;		#SYMFILE is BASLOAD's own answer, and it is the only one that does not change the
;		syntax: it writes source name -> crunched name for every variable and label. This
;		reads it.
;
;		THE FILE FORMAT, as BASLOAD 0.2.1 writes it:
;
;			BASLOAD 0.2.1 SYMBOL FILE
;
;			LABELS
;			------
;			FILE: PROG.BASL
;			 000076 READLINE                 =160;
;
;			VARIABLES
;			---------
;			FILE: PROG.BASL
;			 000030 PR                       =A;
;			 000031 NM                       =A0;
;
;		Two things about it matter. The LABELS section has the same line shape but its values
;		are BASIC line numbers, so the scan must not start until VARIABLES has gone past or a
;		label could answer for a variable of the same name. And THE SIGIL IS NOT RECORDED --
;		PR$ is filed as PR -- because BASLOAD crunches the identifier and the $ or % rides
;		along separately, which is exactly what lets one entry serve N, N$ and N%.
;
;		The name column is padded, but nothing here assumes its width: the name ends at the
;		first space and the value runs from the "=" to the ";".
;
;		WHERE THE FILE NAME COMES FROM. It is derived from GPC.INPUT's source line, extension
;		replaced by .SYM -- so compiling PROG.PRG reads PROG.SYM. That is the convention
;		source/gpc/build_basl.py already follows ("a #SYMFILE, if any, sits beside the PRG"),
;		and it means nothing new has to be typed or carried in GPC.INPUT. The source file has
;		to say
;
;			#SYMFILE "@:PROG.SYM"
;
;		at the top, which is where BASLOAD requires it anyway.
;
;		IT IS READ WHILE THE SOURCE FILE IS OPEN, because {VAR} is resolved mid-compile. Hence
;		its own logical file and a CHKIN back to 3 on the way out -- the compiler is part way
;		through reading a line and would otherwise carry on reading the symbol file instead.
;
; ************************************************************************************************

		.section code

IO_SYM_FILE = 5 							; 3 is the source, 4 the runtime image, 6 the object

; ************************************************************************************************
;
;		Look AsmSymName up. CC and AsmSymCrunched set if found; CS with A=0 if there is no
;		symbol file at all and A=1 if the name is not in it.
;
; ************************************************************************************************

SymbolLookup:
		jsr 	SymBuildName 				; <source>.SYM -> SymFileName
		lda 	#IO_SYM_FILE
		sta 	ioFileNo
		lda 	#'R'
		ldx 	#SymFileName & $FF
		ldy 	#SymFileName >> 8
		jsr 	IOSetFileName 				; carry comes back from OPEN
		ldy 	#3
		sty 	ioFileNo 					; put the default back for every other caller
		bcc 	_SLOpened
		lda 	#0 							; no symbol file at all -- the caller says which
		sec 								; of the two errors that is
		rts
_SLOpened:
		ldx 	#IO_SYM_FILE
		jsr 	$FFC6 						; CHKIN
		stz 	symInVariables
		;
		;		THE OPEN TELLS YOU NOTHING. CMDR-DOS, like every CBM DOS before it, opens a file
		;		that is not there quite happily and only reports it on the first read -- so a
		;		missing symbol file arrives here looking exactly like an empty one, and would
		;		be reported as "the name is not in it" rather than "there isn't one".
		;
		;		The banner settles it: every symbol file starts "BASLOAD n.n.n SYMBOL FILE", so
		;		a first line that does not begin BASLOAD means there is no symbol file to read
		;		-- whether because it is absent, empty, or is some other file entirely.
		;
		jsr 	SymReadLine
		bcs 	_SLNotSymFile
		ldx 	#0
_SLBanner:
		lda 	_SLBaslText,x
		beq 	_SLIsSymFile 				; matched the whole word
		cpx 	symLineLen
		bcs 	_SLNotSymFile
		cmp 	symLine,x
		bne 	_SLNotSymFile
		inx
		bra 	_SLBanner
_SLNotSymFile:
		jsr 	SymClose
		lda 	#0
		sec
		rts
_SLBaslText:
		.text 	"BASLOAD", 0
_SLIsSymFile:
_SLLine:
		jsr 	SymReadLine 				; CS at end of file
		bcc 	_SLHaveLine
		jmp 	_SLNotFound 				; past the end of the parse, so out of branch range
_SLHaveLine:
		lda 	symLineLen
		beq 	_SLLine 					; blank
		lda 	symLine 					; a data line starts with a space, a section
		cmp 	#' ' 						; heading does not
		beq 	_SLData
		ldx 	#0 							; is it the VARIABLES heading ?
_SLHeading:
		lda 	_SLVariablesText,x
		beq 	_SLIsVariables 				; matched the whole word
		cmp 	symLine,x
		bne 	_SLLine 					; some other heading -- LABELS, FILE:, the banner
		inx
		bra 	_SLHeading
_SLIsVariables:
		lda 	#1
		sta 	symInVariables
		bra 	_SLLine
		;
		;		Every rejection below goes back through here: the head of the loop is out of
		;		branch range from the far end of the parse.
		;
_SLNextLine:
		jmp 	_SLLine
		;
		;		" 000030 PR                       =A;"  -- skip the space and the line number,
		;		compare the name, then take what lies between = and ;.
		;
_SLData:
		lda 	symInVariables
		beq 	_SLNextLine 					; still in LABELS, where the values are line numbers
		ldx 	#1 							; past the leading space
_SLSkipNum:
		lda 	symLine,x
		cmp 	#' '
		beq 	_SLAtName
		inx
		cpx 	symLineLen
		bcc 	_SLSkipNum
		bra 	_SLNextLine 					; malformed -- no second space
_SLAtName:
		inx 								; first character of the name
		ldy 	#0
_SLCompare:
		lda 	symLine,x
		cmp 	#' '
		beq 	_SLNameEnd 					; the file's name has ended
		cmp 	AsmSymName,y
		bne 	_SLNextLine 					; differs
		inx
		iny
		cpx 	symLineLen
		bcc 	_SLCompare
		bra 	_SLNextLine
_SLNameEnd:
		lda 	AsmSymName,y 				; ...and ours must end in the same place, or PR
		bne 	_SLNextLine 					; would answer for PRINTER
		;
		;		Matched. The crunched name is between the "=" and the ";".
		;
_SLFindEquals:
		lda 	symLine,x
		cmp 	#'='
		beq 	_SLAtValue
		inx
		cpx 	symLineLen
		bcc 	_SLFindEquals
		bra 	_SLNextLine 					; malformed -- no value
_SLAtValue:
		inx
		ldy 	#0
_SLValue:
		lda 	symLine,x
		cmp 	#';'
		beq 	_SLGotValue
		cpy 	#2 							; BASLOAD crunches to one or two characters; more
		bcs 	_SLNextLine 					; than that is not a name this BASIC could hold
		sta 	AsmSymCrunched,y
		iny
		inx
		cpx 	symLineLen
		bcc 	_SLValue
		bra 	_SLNextLine
_SLGotValue:
		cpy 	#0
		beq 	_SLNextLine 					; "=;" -- nothing there
		lda 	#0
		sta 	AsmSymCrunched,y 			; terminate: one character leaves the second zero
		jsr 	SymClose
		clc
		rts

_SLNotFound:
		jsr 	SymClose
		lda 	#1 							; there is a symbol file, the name is not in it
		sec
		rts

_SLVariablesText:
		.text 	"VARIABLES", 0

; ************************************************************************************************
;
;		Close the symbol file and give the source file the input channel back -- the compiler
;		is part way through reading a line and everything after this reads from it again.
;
; ************************************************************************************************

SymClose:
		lda 	#IO_SYM_FILE
		jsr 	$FFC3 						; CLOSE
		ldx 	#3
		jmp 	$FFC6 						; CHKIN the source

; ************************************************************************************************
;
;		Read one line into symLine, length in symLineLen, CS at end of file. Anything past the
;		buffer is dropped rather than wrapped -- a symbol file line is a number, a name and a
;		short value, and a longer one cannot be a variable this BASIC could hold anyway.
;
; ************************************************************************************************

SymReadLine:
		stz 	symLineLen
_SRLByte:
		jsr 	IOReadByte
		bcs 	_SRLEnd
		cmp 	#13 						; CR or LF ends it -- written on the X16, but a
		beq 	_SRLDone 					; symbol file that has been through a host tool
		cmp 	#10 						; should still read
		beq 	_SRLDone
		ldx 	symLineLen
		cpx 	#SYM_LINE_MAX
		bcs 	_SRLByte 					; over length: keep reading, stop storing
		sta 	symLine,x
		inc 	symLineLen
		bra 	_SRLByte
_SRLDone:
		clc
		rts
_SRLEnd:
		lda 	symLineLen 					; a last line with no terminator is still a line
		beq 	_SRLReallyEnd
		clc
		rts
_SRLReallyEnd:
		sec
		rts

; ************************************************************************************************
;
;		SourceFile with its extension replaced by .SYM. No extension, and .SYM is appended --
;		which is what a source called PROG (no dot) would want.
;
; ************************************************************************************************

SymBuildName:
		ldx 	#0
		ldy 	#0 							; Y = length up to and including the last dot, 0 = none
_SBNCopy:
		lda 	SourceFile,x
		beq 	_SBNEnd
		sta 	SymFileName,x
		cmp 	#'.'
		bne 	_SBNNext
		txa
		tay
		iny 								; keep the dot itself
_SBNNext:
		inx
		cpx 	#CFLineSize
		bne 	_SBNCopy
_SBNEnd:
		cpy 	#0
		beq 	_SBNAppend 					; no dot at all -- append ".SYM" to the whole name
		tya
		tax
		bra 	_SBNSuffix
_SBNAppend:
		lda 	#'.'
		sta 	SymFileName,x
		inx
_SBNSuffix:
		ldy 	#0
_SBNCopySuffix:
		lda 	_SBNSymText,y
		sta 	SymFileName,x
		beq 	_SBNDone
		inx
		iny
		bra 	_SBNCopySuffix
_SBNDone:
		rts

_SBNSymText:
		.text 	"SYM", 0

SYM_LINE_MAX = 96 							; number, name and value; the name column is padded

symLine: 									; code section, like everything else the compiler
		.fill 	SYM_LINE_MAX 				; owns -- thrown away with it, so it costs a
symLineLen: 								; compiled program nothing. See file-io/read.asm.
		.fill 	1
symInVariables: 							; past the VARIABLES heading, where the values stop
		.fill 	1 						; being line numbers and start being names
SymFileName:
		.fill 	CFLineSize+8

		.send code

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
