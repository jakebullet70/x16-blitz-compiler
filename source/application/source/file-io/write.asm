; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		write.asm
;		Purpose:	Write file code
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Open sequential file for Write.
; 									   YX = ASCIIZ name
;
; ************************************************************************************************

IOOpenWrite:
		lda 	#'W'			 			; write
		jsr 	IOSetFileName 				; set up name/LFS
		ldx	 	#3 							; use file 3 for writing
		jsr 	$FFC9 						; CHKOUT
		rts

; ************************************************************************************************
;
;									Write A to output file
;
; ************************************************************************************************

IOWriteByte:		
		pha
		phx
		phy
		jsr 	$FFD2
		ply
		plx
		pla
		rts

; ************************************************************************************************
;
;						Delete the object file, before the compile starts
;
;		WriteObjectCode only ever creates the file on SUCCESS, so a compile that stops on an
;		error leaves whatever was there before -- and a stale object from an earlier run is
;		indistinguishable from a fresh one at the filesystem level, and it RUNS. "OK" is the
;		only signal a caller gets that the compile worked; nothing about the file itself says
;		so. Clearing it up front makes a failed compile leave NO object at all, which is the
;		only state that cannot be mistaken for a good one.
;
;		Done through the DOS command channel -- "S0:<name>" on 15,8,15. The status is
;		deliberately NOT read: FILE NOT FOUND is the normal case on a first compile, and there
;		is nothing useful to do about any other outcome either, since the compile has not
;		happened yet and WriteObjectCode reports its own failures.
;
; ************************************************************************************************

IODeleteObject:
		ldy 	#0 							; REFUSE if the object name IS the source name. A
_IODSame: 									; misconfigured GPC.INPUT would otherwise destroy the
		lda 	SourceFile,y 				; source before the compile had read a byte of it, and
		cmp 	ObjectFile,y 				; the compiler would then report a missing file rather
		bne 	_IODDiffer 					; than the mistake that caused it
		tax 								; matched all the way to a shared terminator -> same name
		beq 	_IODDone
		iny
		bra 	_IODSame
_IODDiffer:
		lda 	#'S' 						; build "S0:<name>" -- the DOS scratch command
		sta 	IONameBuffer+0
		lda 	#'0'
		sta 	IONameBuffer+1
		lda 	#':'
		sta 	IONameBuffer+2
		ldy 	#$FF
_IODCopy:
		iny 								; pre-increment copy, as IOSetFileName does
		lda 	ObjectFile,y
		sta 	IONameBuffer+3,y
		bne 	_IODCopy
		;
		tya 								; length is the name plus the three we prefixed
		clc
		adc 	#3
		ldx 	#IONameBuffer & $FF
		ldy 	#IONameBuffer >> 8
		jsr 	$FFBD 						; SETNAM
		lda 	#15 						; SETLFS 15,8,15 -- the command channel, so OPEN is
		ldx 	#8 							; what actually sends the command
		ldy 	#15
		jsr 	$FFBA
		jsr 	$FFC0 						; OPEN
		lda 	#15
		jsr 	$FFC3 						; CLOSE
		jsr 	$FFCC 						; CLRCHN -- leave I/O where the compile expects it
_IODDone:
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
;
; ************************************************************************************************
