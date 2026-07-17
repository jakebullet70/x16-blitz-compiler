; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		control.asm
;		Purpose:	The compiler's control file, GPC.INPUT
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		The compiler had SOURCE.PRG and OBJECT.PRG built into it, so the only way to point it at
;		a program was to rename files around it. It now reads GPC.INPUT, a plain text file of
;		three lines, which is what lets another program drive it:
;
;			DIR.PRG				line 1	the tokenised BASIC to compile
;			C.DIR.PRG			line 2	the object file to write
;								line 3	options. Read, but ignored for now.
;
;		A line ends at CR, at LF, or at anything else below a space, and an empty line is
;		skipped -- so a control file written on a CRLF host is as good as one written on the X16.
;
;		Lowercase is folded to upper. A name typed in ASCII lowercase is not the PETSCII the
;		KERNAL wants, and it is the mistake a caller will actually make; the host filesystems
;		this runs on are all case insensitive, so folding can only ever help.
;
;		There is no fallback. Without a readable GPC.INPUT the compiler says NO GPC.INPUT FILE
;		and stops, because a compiler that guesses at what it was asked to build is worse than
;		one that refuses.
;
; ************************************************************************************************

CFLineSize = 64 							; each line is a fixed 64-byte slot; the four lines are one
CFLineCount = 4 							; contiguous 256-byte block (source, object, map, mode).
											; ReadControlFile counts lines (cfLine) and tracks CR/LF,
											; so an EMPTY line still advances -- an empty line 3 (no
											; map) must not mis-slot line 4 (the mode). Fixed slots
											; mean a single index walks the block with no pointer,
											; which matters because the KERNAL calls here are free
											; to trash zero page.

		.section code

; ************************************************************************************************
;
;		Read GPC.INPUT into SourceFile, ObjectFile and OptionsText.
;
;		Returns carry SET if there was no usable control file.
;
; ************************************************************************************************

ReadControlFile:
		lda 	#0 							; blank all FOUR lines (256 bytes). This zero-terminates
		tax 								; each of them and leaves a short control file holding
_RCFBlank: 									; empty strings rather than whatever was in memory.
		sta 	SourceFile,x
		inx
		bne 	_RCFBlank

		ldy 	#ControlFile >> 8
		ldx 	#ControlFile & $FF
		jsr 	IOOpenRead
		bcs 	_RCFClose 					; no input channel -- reading is NOT harmless: CHRIN would
											; fall back to the keyboard and wait to be typed at.
		ldx 	#0 							; X = write offset (cfLine*CFLineSize + column)
		stz 	cfLine 						; current line, 0..3
		stz 	cfJustCR 					; nonzero => the previous byte was CR (to swallow a CRLF's LF)
_RCFRead:
		jsr 	IOReadByte 					; carry set at end of file
		bcs 	_RCFClose

		cmp 	#' ' 						; CR, LF, and anything else below a space, ends the line
		bcc 	_RCFEndOfLine

		stz 	cfJustCR 					; a real character clears any pending CR
		cmp 	#$C1 						; PETSCII shifted letters ($C1-$DA), what SHIFT-typing gives;
		bcc 	_RCFNotShifted 				; CBM DOS wants the UNshifted bytes in a filename, and they
		cmp 	#$DB 						; are a different character entirely, not a case.
		bcs 	_RCFNotShifted
		and 	#$7F 						; $C1-$DA -> $41-$5A
		bra 	_RCFStore
_RCFNotShifted:
		cmp 	#'a' 						; and ASCII lowercase, which is what a host text editor
		bcc 	_RCFStore 					; gives you
		cmp 	#'z'+1
		bcs 	_RCFStore
		and 	#$DF 						; $61-$7A -> $41-$5A
_RCFStore:
		pha
		txa 								; the last byte of a line is its zero terminator and is
		and 	#CFLineSize-1 				; never written to, so an over-long name is truncated
		cmp 	#CFLineSize-1 				; rather than running on into the next line.
		pla
		bcs 	_RCFRead
		sta 	SourceFile,x
		inx
		bra 	_RCFRead

_RCFEndOfLine: 								; A < ' '
		cmp 	#$0A 						; LF ?
		bne 	_RCFAdvance
		lda 	cfJustCR 					; an LF right after a CR (a CRLF) -> swallow it, do not
		bne 	_RCFSwallow 				; advance again; the CR already ended the line.
_RCFAdvance: 								; CR, a lone LF, or any other control ends the line
		ldy 	#0 							; remember whether this was a CR (so a following LF is eaten)
		cmp 	#$0D
		bne 	_RCFSetCR
		iny
_RCFSetCR:
		sty 	cfJustCR
		inc 	cfLine 						; advance even on an empty line -- so an empty line 3 (no
		lda 	cfLine 						; map) does not mis-slot line 4 (the mode), which the old
		cmp 	#CFLineCount 				; positional walker got wrong.
		bcs 	_RCFClose 					; captured all four lines -> stop, ignore any more
		asl 	a 							; X = cfLine * CFLineSize (64) = start of the next line
		asl 	a
		asl 	a
		asl 	a
		asl 	a
		asl 	a
		tax
		bra 	_RCFRead
_RCFSwallow:
		stz 	cfJustCR
		bra 	_RCFRead

_RCFClose:
		jsr 	IOReadClose 				; close it either way. Logical file 3 is the one the source
											; is read on, so it has to be free.
		sec
		lda 	SourceFile 					; no source name means there was no usable control file:
		beq 	_RCFFail 					; missing, empty, or a first line we could not use. No object
		lda 	ObjectFile 					; name is just as useless -- nowhere to put the answer.
		beq 	_RCFFail 					; Line 4 (the mode) is optional, so it is not checked here.
		clc
_RCFFail:
		rts

; ************************************************************************************************
;
;		"GPC SQUEALING..." then the two names, each on its own labelled line -- the whole of the
;		compiler's startup output. Three short lines so nothing wraps in 40 columns.
;
;			GPC SQUEALING...
;			in:  <source>
;			out: <object>
;
; ************************************************************************************************

PrintWorking:
		ldx 	#WorkingText & $FF 			; "GPC SQUEALING...",CR
		ldy 	#WorkingText >> 8
		jsr 	PrintMessage
		ldx 	#InText & $FF 				; "in:  "
		ldy 	#InText >> 8
		jsr 	PrintMessage
		ldx 	#0 							; line 1, the source
		jsr 	PrintControlLine
		ldx 	#OutText & $FF 				; CR then "out: "
		ldy 	#OutText >> 8
		jsr 	PrintMessage
		ldx 	#CFLineSize 				; line 2, the object
		jsr 	PrintControlLine
		lda 	#13
		jmp 	$FFD2

; ************************************************************************************************
;
;								There was nothing to work from
;
; ************************************************************************************************

PrintNoControlFile:
		ldx 	#NoControlText & $FF
		ldy 	#NoControlText >> 8
		jmp 	PrintMessage

; ************************************************************************************************
;
;								Print the ASCIIZ string at YX
;
; ************************************************************************************************

PrintMessage:
		stx 	zTemp0
		sty 	zTemp0+1
		ldy 	#0
_PMLoop:
		lda 	(zTemp0),y
		beq 	_PMExit
		phy 								; CHROUT makes no promise about Y
		jsr 	$FFD2
		ply
		iny
		bne 	_PMLoop
_PMExit:
		rts

; ************************************************************************************************
;
;							Print the ASCIIZ control line at offset X
;
; ************************************************************************************************

PrintControlLine:
_PCLLoop:
		lda 	SourceFile,x
		beq 	_PCLExit
		phx
		jsr 	$FFD2
		plx
		inx
		bra 	_PCLLoop
_PCLExit:
		rts

; ************************************************************************************************
;
;										Fixed text
;
; ************************************************************************************************

ControlFile:
		.text 	'GPC.INPUT',0
WorkingText:
		.text 	'GPC SQUEALING...',13,0
InText: 									; uppercase: the screen boots in PETSCII upper/graphics, where
		.text 	'IN:  ',0 				; lowercase bytes are graphics glyphs, not letters
OutText: 									; the CR ends the source line and starts the object's
		.text 	13,'OUT: ',0
NoControlText:
		.text 	'NO GPC.INPUT FILE',13,0

; ************************************************************************************************
;
;		The three lines of GPC.INPUT, laid out as one contiguous block -- see CFLineSize above.
;
;		These are buffers, but they are deliberately NOT in the storage section. That section is
;		a .dsection at $0400 (common.inc) and the code starts at $0801, so it is a 1K hole -- and
;		it was already full. Everything here belongs to the compiler, which lives above
;		ObjectBase and is thrown away when the object code is written, so a buffer here costs a
;		compiled program nothing at all. See the note in file-io/read.asm.
;
; ************************************************************************************************

SourceFile: 								; line 1 : what to compile
		.fill 	CFLineSize
ObjectFile: 								; line 2 : where to write it
		.fill 	CFLineSize
OptionsText: 								; line 3 : the debug map file name, or empty for none
		.fill 	CFLineSize 					; (WriteMapFile keys off its first byte)
ModeText: 									; line 4 : compile mode -- first byte 'S' (SHARED) selects
		.fill 	CFLineSize 					; the resident runtime (GPC.RT.BIN); empty/anything else
											; = the default self-contained (embedded) runtime.
cfLine: 									; ReadControlFile scratch: current line, 0..3
		.fill 	1
cfJustCR: 									; ReadControlFile scratch: nonzero if the last byte was a CR
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
