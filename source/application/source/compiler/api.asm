; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		api.asm
;		Purpose:	Compiler API Interface
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;									API Entry point
;
; ************************************************************************************************

		.section code

CompilerAPI:
		cmp 	#BLC_OPENIN
		beq 	_CAOpenIn
		cmp 	#BLC_CLOSEIN
		beq 	_CACloseIn
		cmp 	#BLC_READIN
		beq 	_CARead
		cmp 	#BLC_RESETOUT
		beq 	_CAResetOut
		cmp 	#BLC_CLOSEOUT
		beq 	_CACloseOut
		cmp 	#BLC_WRITEOUT
		beq 	_CAWriteByte
		cmp 	#BLC_PRINTCHAR
		beq 	_CAPrintScreen
		cmp 	#BLC_SYMLOOKUP
		beq 	_CASymLookup
		cmp 	#BLC_ENDPASS1
		beq 	_CAEndPass1
		cmp 	#BLC_ENDPASS2
		beq 	_CAEndPass2
		.debug

; ************************************************************************************************
;
;		End of pass one: settle how big the program is and where everything in it goes, so that
;		pass two can be told. See PrepareObjectCode in compiler/object.asm.
;
; ************************************************************************************************

_CAEndPass1:
		jmp 	PrepareObjectCode

; ************************************************************************************************
;
;		End of pass two: everything still buffered, then the padding and the GP.BANKED regions.
;		Comes back with the object's checksum in YA -- see ObjStreamClose.
;
; ************************************************************************************************

_CAEndPass2:
		jmp 	ObjStreamClose

; ************************************************************************************************
;
;		Translate a GP.ASM {VAR} name through BASLOAD's #SYMFILE. Here rather than in the
;		compiler library because the file name comes from GPC.INPUT's source line, which is an
;		application symbol -- the same reason the GP usage scan is on this side.
;
; ************************************************************************************************

_CASymLookup:
		jmp 	SymbolLookup

; ************************************************************************************************
;
;									Open source file for reading
;
; ************************************************************************************************

_CAOpenIn:	
		ldy 	#SourceFile >> 8 			; name of file
		ldx 	#SourceFile & $FF		
		jsr 	IOOpenRead 					; open file
		jsr 	IOReadByte 					; skip the 2 byte load address header
		jsr 	IOReadByte
		rts

; ************************************************************************************************
;
;									Close read source file
;
; ************************************************************************************************

_CACloseIn:
		jmp 	IOReadClose

; ************************************************************************************************
;
;								Code is stored from free memory onwards
;
; ************************************************************************************************

_CAResetOut:
		.set16 	objPtr,FreeMemory
		rts

_CACloseOut:
		stz 	objStreamLive 				; the compile worked and the object is complete, so
		jmp 	IOObjectClose 				; there is nothing left to tidy away

; ************************************************************************************************
;
;								One object byte, in X, at objPtr
;
;		NEITHER PASS STORES THE OBJECT. Pass two's goes into the file as it is compiled -- see
;		ObjStreamByte -- and pass one's is never written down at all: what pass one is for is
;		working out where everything lands, and for that it only has to COUNT.
;
;		THAT IS WHAT TOOK THE SIZE WALL AWAY. The object used to be built in a buffer running
;		from FreeMemory up to $9F00, so every byte of the compiler came straight off the largest
;		program it could build -- and a program with eight GP.BANKED regions can be 81,152 bytes
;		against 39,679 of low RAM, which no amount of shrinking the compiler could have reached.
;		There is no buffer, so there is no ceiling here to test against: what bounds a program
;		now is whether it can RUN, which PrepareObjectCode asks at the end of pass one.
;
;		Pass one still walks every byte past GPScanByte, because "does this program reach a GP
;		handler?" has to be answered before pass two starts -- see compiler/gpscan.asm.
;
; ************************************************************************************************

_CAWriteByte:
		txa
		ldx 	passNumber
		bne 	_CAWBStream
		jsr 	GPScanByte
		bra 	_CAWBBump
_CAWBStream:
		jsr 	ObjStreamByte
_CAWBBump:
		inc 	objPtr
		bne 	_HWOWBNoCarry
		inc 	objPtr+1
_HWOWBNoCarry:
		rts

; ************************************************************************************************
;
;								Print character to screen
;
; ************************************************************************************************
		
_CAPrintScreen:
		txa 								; CLRCHN DOES NOT PRESERVE X, and the character to
		pha 								; print is in it
		jsr 	IOSelectScreen 				; the object file is open for output and may be
		pla 								; selected -- CHROUT would put the message in it
		jmp 	$FFD2

; ************************************************************************************************
;
;									  Read line
;
; ************************************************************************************************

_CARead:
		jsr 	IOSelectSource 			; the object file may have had the channel last
		jsr 	IOReadByte 				; copy the address of next into the buffer
		sta 	SourceLine+0
		jsr 	IOReadByte
		sta 	SourceLine+1
		;
		ora 	sourceLine				; if both were zero, exit with CC (e.g. fail)
		clc
		beq		_CARExit

		jsr 	IOReadByte 				; read the line # into the buffer.
		sta 	SourceLine+2
		jsr 	IOReadByte
		sta 	SourceLine+3
		;
		ldx 	#4 						; read the body of the line.
_CAReadLine:
		jsr 	IOReadByte 				; now keep copying to EOL
		sta 	SourceLine,x
		inx
		cmp 	#0
		bne 	_CAReadLine
		;		
		sec 							; read a line okay
		ldy 	#SourceLine >> 8
		ldx 	#SourceLine & $FF
_CARExit:		
		rts


;;		ldy 	#ObjectFile >> 8
;		ldx 	#ObjectFile & $FF		
;		jsr 	IOOpenWrite
;		lda 	#12
;		jsr 	IOWriteByte
;		lda 	#13
;		jsr 	IOWriteByte
;		jsr 	IOWriteClose
				
SourceLine: 								; line for source code storage. In the code section, not
		.fill 	256 						; storage: see the note in file-io/read.asm -- this was
											; the single biggest thing in a 1K hole that had run
											; out of room.
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

