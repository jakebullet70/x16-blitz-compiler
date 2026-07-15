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

CFLineSize = 64 							; the three lines are ONE 192 byte block, so a single
											; 8 bit index walks all of them. Nothing else works:
											; three separate buffers would need a pointer, and
											; the KERNAL calls in here are free to trash one.

		.section code

; ************************************************************************************************
;
;		Read GPC.INPUT into SourceFile, ObjectFile and OptionsText.
;
;		Returns carry SET if there was no usable control file.
;
; ************************************************************************************************

ReadControlFile:
		lda 	#0 							; blank all three lines. This is what puts the zero
		ldx 	#CFLineSize*3-1 			; terminator on the end of each of them, and what
_RCFBlank: 									; leaves a short control file holding empty strings
		sta 	SourceFile,x 				; rather than whatever happened to be in memory.
		dex
		bpl 	_RCFBlank

		ldy 	#ControlFile >> 8
		ldx 	#ControlFile & $FF
		jsr 	IOOpenRead
		ldx 	#0 							; X walks the three lines as one block (preserves C)
		bcs 	_RCFClose 					; carry set means we have no input channel, and then
											; reading is NOT harmless: CHRIN would fall back to
											; the keyboard and sit there waiting to be typed at.
_RCFRead:
		jsr 	IOReadByte 					; carry set at end of file
		bcs 	_RCFClose

		cmp 	#' ' 						; CR, LF, and anything else below a space, ends the
		bcc 	_RCFEndOfLine 				; line

		cmp 	#$C1 						; PETSCII shifted letters, which is what the X16 hands
		bcc 	_RCFNotShifted 				; you if you type the name with SHIFT held down. CBM
		cmp 	#$DB 						; DOS wants the UNshifted ones in a filename, and they
		bcs 	_RCFNotShifted 				; are a different character entirely, not a case.
		and 	#$7F 						; $C1-$DA -> $41-$5A
		bra 	_RCFStore
_RCFNotShifted:
		cmp 	#'a' 						; and ASCII lowercase, which is what a text editor on
		bcc 	_RCFStore 					; the host gives you
		cmp 	#'z'+1
		bcs 	_RCFStore
		and 	#$DF 						; $61-$7A -> $41-$5A
_RCFStore:
		pha
		txa 								; the last byte of a line is its zero terminator and
		and 	#CFLineSize-1 				; is never written to, so an over-long name is
		cmp 	#CFLineSize-1 				; truncated rather than left to run on into the next
		pla 								; line.
		bcs 	_RCFRead
		sta 	SourceFile,x
		inx
		bra 	_RCFRead

_RCFEndOfLine:
		txa
		and 	#CFLineSize-1 				; nothing on this line yet ? then this is the LF of a
		beq 	_RCFRead 					; CRLF, or a blank line -- there is nothing to end.
		txa 								; otherwise step X on to the start of the next line.
		clc
		adc 	#CFLineSize
		and 	#$100-CFLineSize
		tax
		cpx 	#CFLineSize*3 				; stop at three lines, whatever else the file holds
		bcc 	_RCFRead

_RCFClose:
		jsr 	IOReadClose 				; close it either way. Logical file 3 is the one the
											; source is read on, so it has to be free.
		sec
		lda 	SourceFile 					; no source name means there was no usable control
		beq 	_RCFFail 					; file: missing, empty, or a first line we could not
		lda 	ObjectFile 					; use. No object name is just as useless -- we would
		beq 	_RCFFail 					; have nowhere to put the answer.
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
OptionsText: 								; line 3 : read and thrown away for now, so that a
		.fill 	CFLineSize 					; caller can already write options that will one day
											; be honoured.

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
