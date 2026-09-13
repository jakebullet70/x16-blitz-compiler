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
;		IT IS READ ONCE A COMPILE. The first {VAR} copies every VARIABLES entry into banks 13
;		and 14 and every lookup after it searches those. Reading the file for each lookup cost
;		0.28 s of emulator time for every 10K of file ahead of the name, in every pass:
;		GPBMODS's 111 references read its 73K symbol file 222 times, 301 s of a 317 s compile.
;
;		An entry in the banks is the name, a zero, and the two bytes of the crunched name, the
;		second zero for a one character name. A zero where a name would start ends a bank.
;		Names that outgrow both banks are not an error: the lookup goes back to reading the
;		file each time.
;
; ************************************************************************************************

		.section code

IO_SYM_FILE = 5 							; 3 is the source, 4 the runtime image, 6 the object

SymCacheBank = 13 							; the first; x16_storage.inc lists every compile-time bank
SYM_CACHE_BANKS = 2 						; 16K, about 1,300 names of GPBMODS's length

SYM_UNREAD = 0 								; symCacheState: nothing read yet this compile
SYM_CACHED = 1 								; every variable is in the banks
SYM_NO_FILE = 2 							; there is no symbol file, or it is not one
SYM_TOO_BIG = 3 							; the names outgrew the banks

; ************************************************************************************************
;
;		Look AsmSymName up. CC and AsmSymCrunched set if found; CS with A=0 if there is no
;		symbol file at all and A=1 if the name is not in it.
;
; ************************************************************************************************

SymbolLookup:
		lda 	symCacheState
		bne 	_SLKnown
		jsr 	SymCacheBuild 				; the first {VAR} of the compile
		lda 	symCacheState
_SLKnown:
		cmp 	#SYM_CACHED
		bne 	_SLNotCached
		jmp 	SymCacheLookup
_SLNotCached:
		cmp 	#SYM_TOO_BIG
		bne 	_SLNoFile
		jmp 	SymFileLookup
_SLNoFile:
		lda 	#0 							; no symbol file at all -- the caller says which
		sec 								; of the two errors that is
		rts

; ************************************************************************************************
;
;		Copy every VARIABLES entry into the banks, and set symCacheState to say how that went.
;
; ************************************************************************************************

SymCacheBuild:
		lda 	#SYM_NO_FILE
		sta 	symCacheState
		jsr 	SymOpen
		bcs 	_SCBExit
		stz 	symCacheBanks
		stz 	symCachePtr 				; $C000 reads as a full bank, so the first entry
		lda 	#$C0 						; starts bank 13
		sta 	symCachePtr+1
_SCBNext:
		jsr 	SymNextVariable
		bcs 	_SCBDone
		lda 	symNameLen 					; the entry is the name and three bytes, and the
		clc 								; zero that ends the bank must fit after it
		adc 	#3
		adc 	symCachePtr
		lda 	symCachePtr+1
		adc 	#0
		cmp 	#$C0
		bcc 	_SCBStore
		lda 	symCacheBanks
		cmp 	#SYM_CACHE_BANKS
		bcs 	_SCBTooBig
		inc 	symCacheBanks
		stz 	symCachePtr
		lda 	#$A0
		sta 	symCachePtr+1
_SCBStore:
		jsr 	SymCacheStore
		bra 	_SCBNext
_SCBDone:
		lda 	#SYM_CACHED
		bra 	_SCBClose
_SCBTooBig:
		lda 	#SYM_TOO_BIG
_SCBClose:
		sta 	symCacheState
		jmp 	SymClose
_SCBExit:
		rts

; ************************************************************************************************
;
;		Write the entry SymNextVariable just read at symCachePtr, with a zero after it, and move
;		symCachePtr on to that zero. No KERNAL call while the bank is selected.
;
; ************************************************************************************************

SymCacheStore:
		lda 	symCachePtr
		sta 	zTemp0
		lda 	symCachePtr+1
		sta 	zTemp0+1
		lda 	CompilerRAMBankReg
		sta 	symSavedBank
		lda 	#SymCacheBank-1 			; symCacheBanks counts from one
		clc
		adc 	symCacheBanks
		sta 	CompilerRAMBankReg
		ldx 	symNameAt
		ldy 	#0
_SCSName:
		lda 	symLine,x
		sta 	(zTemp0),y
		inx
		iny
		cpy 	symNameLen
		bne 	_SCSName
		lda 	#0
		sta 	(zTemp0),y
		iny
		lda 	symValue
		sta 	(zTemp0),y
		iny
		lda 	symValue+1
		sta 	(zTemp0),y
		iny
		lda 	#0 							; the end of the bank, until the next entry
		sta 	(zTemp0),y
		lda 	symSavedBank
		sta 	CompilerRAMBankReg
		tya
		clc
		adc 	symCachePtr
		sta 	symCachePtr
		bcc 	_SCSExit
		inc 	symCachePtr+1
_SCSExit:
		rts

; ************************************************************************************************
;
;		Look AsmSymName up in the banks. Same result as SymbolLookup.
;
; ************************************************************************************************

SymCacheLookup:
		lda 	CompilerRAMBankReg
		sta 	symSavedBank
		ldx 	#0 							; X = bank, counting from SymCacheBank
_SCLBank:
		cpx 	symCacheBanks
		beq 	_SCLNotFound
		txa
		clc
		adc 	#SymCacheBank
		sta 	CompilerRAMBankReg
		stz 	zTemp0
		lda 	#$A0
		sta 	zTemp0+1
_SCLEntry:
		ldy 	#0
		lda 	(zTemp0),y
		beq 	_SCLNextBank 				; the zero that ends the bank
_SCLCompare:
		lda 	(zTemp0),y
		cmp 	AsmSymName,y
		bne 	_SCLSkip
		cmp 	#0 							; both names ended here
		beq 	_SCLFound
		iny
		bra 	_SCLCompare
_SCLSkip:
		lda 	(zTemp0),y 					; on to the zero after the name
		beq 	_SCLSkipped
		iny
		bra 	_SCLSkip
_SCLSkipped:
		tya 								; ...and past it and the crunched name
		clc
		adc 	#3
		adc 	zTemp0
		sta 	zTemp0
		bcc 	_SCLEntry
		inc 	zTemp0+1
		bra 	_SCLEntry
_SCLNextBank:
		inx
		bra 	_SCLBank
_SCLFound:
		iny
		lda 	(zTemp0),y
		sta 	AsmSymCrunched
		iny
		lda 	(zTemp0),y
		sta 	AsmSymCrunched+1 			; zero for a one character name
		stz 	AsmSymCrunched+2
		lda 	symSavedBank
		sta 	CompilerRAMBankReg
		clc
		rts
_SCLNotFound:
		lda 	symSavedBank
		sta 	CompilerRAMBankReg
		lda 	#1 							; there is a symbol file, the name is not in it
		sec
		rts

; ************************************************************************************************
;
;		Look AsmSymName up by reading the file from the top. Same result as SymbolLookup. Only
;		when the names did not fit the banks.
;
; ************************************************************************************************

SymFileLookup:
		jsr 	SymOpen
		bcc 	_SFLNext
		lda 	#0
		rts
_SFLNext:
		jsr 	SymNextVariable
		bcs 	_SFLNotFound
		ldx 	symNameAt
		ldy 	#0
_SFLCompare:
		lda 	symLine,x
		cmp 	AsmSymName,y
		bne 	_SFLNext
		inx
		iny
		cpy 	symNameLen
		bne 	_SFLCompare
		lda 	AsmSymName,y 				; ...and ours must end in the same place, or PR
		bne 	_SFLNext 					; would answer for PRINTER
		lda 	symValue
		sta 	AsmSymCrunched
		lda 	symValue+1
		sta 	AsmSymCrunched+1
		stz 	AsmSymCrunched+2
		jsr 	SymClose
		clc
		rts
_SFLNotFound:
		jsr 	SymClose
		lda 	#1
		sec
		rts

; ************************************************************************************************
;
;		Open the symbol file and read its banner. CC with the input channel on it; CS if there
;		is no symbol file, with nothing left open.
;
; ************************************************************************************************

SymOpen:
		jsr 	SymBuildName 				; <source>.SYM -> SymFileName
		lda 	#IO_SYM_FILE
		sta 	ioFileNo
		lda 	#'R'
		ldx 	#SymFileName & $FF
		ldy 	#SymFileName >> 8
		jsr 	IOSetFileName 				; carry comes back from OPEN
		ldy 	#3
		sty 	ioFileNo 					; put the default back for every other caller
		bcc 	_SOOpened
		rts
_SOOpened:
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
		bcs 	_SONotSymFile
		ldx 	#0
_SOBanner:
		lda 	_SOBaslText,x
		beq 	_SOIsSymFile 				; matched the whole word
		cpx 	symLineLen
		bcs 	_SONotSymFile
		cmp 	symLine,x
		bne 	_SONotSymFile
		inx
		bra 	_SOBanner
_SOIsSymFile:
		clc
		rts
_SONotSymFile:
		jsr 	SymClose
		sec
		rts
_SOBaslText:
		.text 	"BASLOAD", 0

; ************************************************************************************************
;
;		Read on to the next VARIABLES entry. CC with its name at symLine+symNameAt, symNameLen
;		long, and its crunched name in symValue; CS at the end of the file.
;
; ************************************************************************************************

SymNextVariable:
		jsr 	SymReadLine
		bcc 	_SNVHaveLine
		rts 								; end of file, carry set
_SNVHaveLine:
		lda 	symLineLen
		beq 	SymNextVariable 			; blank
		lda 	symLine 					; a data line starts with a space, a section
		cmp 	#' ' 						; heading does not
		beq 	_SNVData
		ldx 	#0 							; is it the VARIABLES heading ?
_SNVHeading:
		lda 	_SNVVariablesText,x
		beq 	_SNVIsVariables 			; matched the whole word
		cmp 	symLine,x
		bne 	SymNextVariable 			; some other heading -- LABELS, FILE:, the banner
		inx
		bra 	_SNVHeading
_SNVIsVariables:
		lda 	#1
		sta 	symInVariables
		bra 	SymNextVariable
		;
		;		" 000030 PR                       =A;"  -- skip the space and the line number,
		;		take the name, then what lies between = and ;.
		;
_SNVData:
		lda 	symInVariables
		beq 	_SNVNextLine 				; still in LABELS, where the values are line numbers
		ldx 	#1 							; past the leading space
_SNVSkipNum:
		lda 	symLine,x
		cmp 	#' '
		beq 	_SNVAtName
		inx
		cpx 	symLineLen
		bcc 	_SNVSkipNum
		bra 	_SNVNextLine 				; malformed -- no second space
_SNVAtName:
		inx 								; first character of the name
		stx 	symNameAt
_SNVName:
		cpx 	symLineLen
		bcs 	_SNVNextLine 				; malformed -- the line ends in the name
		lda 	symLine,x
		cmp 	#' '
		beq 	_SNVNameEnd
		inx
		bra 	_SNVName
_SNVNameEnd:
		txa
		sec
		sbc 	symNameAt
		beq 	_SNVNextLine 				; malformed -- no name
		sta 	symNameLen
_SNVFindEquals:
		lda 	symLine,x
		cmp 	#'='
		beq 	_SNVAtValue
		inx
		cpx 	symLineLen
		bcc 	_SNVFindEquals
		bra 	_SNVNextLine 				; malformed -- no value
_SNVAtValue:
		inx
		stz 	symValue+1 					; a one character name leaves the second zero
		ldy 	#0
_SNVValue:
		cpx 	symLineLen
		bcs 	_SNVNextLine 				; malformed -- no ";"
		lda 	symLine,x
		cmp 	#';'
		beq 	_SNVGotValue
		cpy 	#2 							; BASLOAD crunches to one or two characters; more
		bcs 	_SNVNextLine 				; than that is not a name this BASIC could hold
		sta 	symValue,y
		iny
		inx
		bra 	_SNVValue
_SNVGotValue:
		cpy 	#0
		beq 	_SNVNextLine 				; "=;" -- nothing there
		clc
		rts
_SNVNextLine:
		jmp 	SymNextVariable 			; the head of the loop is out of branch range

_SNVVariablesText:
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
symNameAt: 									; the entry SymNextVariable read: where its name
		.fill 	1 						; starts in symLine, how long it is, and the
symNameLen: 								; crunched name
		.fill 	1
symValue:
		.fill 	2
symCacheState: 								; SYM_UNREAD until the first {VAR}; CompileCode
		.fill 	1 						; resets it
symCacheBanks: 								; banks holding entries, from SymCacheBank up
		.fill 	1
symCachePtr: 								; where the next entry goes
		.fill 	2
symSavedBank: 								; the caller's RAM bank, while one of ours is selected
		.fill 	1

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
