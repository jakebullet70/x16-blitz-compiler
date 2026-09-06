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
;		application symbol -- the same reason ScanGPUsage is on this side.
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
;									Write byte A to free memory
;
; ************************************************************************************************

_CAWriteByte:
		;
		;		The object buffer has a CEILING and this is the only place that can enforce it.
		;		Without this test the p-code just kept going past the end of usable low RAM,
		;		over whatever was there, and the compile still said OK -- see the note on
		;		ObjectCeiling in start.asm for what that cost. Refusing to emit a byte we have
		;		nowhere to put is the whole fix; PROGRAM TOO BIG is reported against the source
		;		line being compiled, so the message says where the budget ran out.
		;
		;		The ceiling is page aligned, so comparing the high byte is exact.
		;
		;
		;		PASS TWO DOES NOT STORE IT. Its object goes into the file as it is compiled --
		;		see ObjStreamByte -- and objPtr is a write cursor over an object that is not in
		;		memory at all. Pass one still lays one out, for as long as anything reads it.
		;
		lda 	passNumber
		bne 	_CAWBStream
		lda 	objPtr+1
		cmp 	#ObjectCeiling >> 8
		bcs 	_CAWBTooBig
		txa
		sta 	(objPtr)
		jsr 	GPScanByte 					; ...and the one place every object byte goes past, so
											; it is where "does this program reach a GP handler?"
											; is answered -- see compiler/gpscan.asm
		bra 	_CAWBBump
_CAWBStream:
		txa
		jsr 	ObjStreamByte
_CAWBBump:
		inc 	objPtr
		bne 	_HWOWBNoCarry
		inc 	objPtr+1
_HWOWBNoCarry:
		rts

_CAWBTooBig:
		.error_toobig

; ************************************************************************************************
;
;								Print character to screen
;
; ************************************************************************************************
		
_CAPrintScreen:
		jsr 	IOSelectScreen 				; the object file is open for output and may be
		txa 								; selected -- CHROUT would put the message in it
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

