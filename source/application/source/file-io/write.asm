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
;				Delete the object file and its map, before the compile starts
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

IODeleteOutputs:
		ldx 	#ObjectFile & $FF 			; the object itself, always
		ldy 	#ObjectFile >> 8
		jsr 	IOScratchFile
		;
		;		And the debug map, if GPC.INPUT line 3 asked for one -- WriteMapFile keys off the
		;		same first byte. It is not runnable, so it cannot be mistaken for a program, but a
		;		map left over from an earlier run describes an object that no longer exists: every
		;		line-number-to-offset entry in it is wrong, and it is read by a debugger that has
		;		no way to tell. The two files are written together and they go together.
		;
		lda 	OptionsText
		beq 	_IODODone
		ldx 	#OptionsText & $FF
		ldy 	#OptionsText >> 8
		jsr 	IOScratchFile
_IODODone:
		rts

;
;		AND NOT THE .Bnn OVERLAYS, which is a deliberate gap and not an oversight.
;
;		The obvious sweep is one wildcard -- "S0:<object>.B*" -- because which banks this source
;		asks for is not known until it has been read. IT SCRATCHES THE SOURCE. CBM pattern
;		matching is a prefix and a "*", so "BANKA.B*" matches BANKA.BASL as squarely as it
;		matches BANKA.B05, and building it destroyed seventeen test sources on 08/09/26. Nor is
;		there a safer spelling: every extension this project uses begins with B.
;
;		WHAT THE SWEEP WAS FOR IS DONE ELSEWHERE ANYWAY. ObjEmitOverlay scratches each overlay
;		by its exact name immediately before writing it, which is what "name,S,W" needs -- it
;		refuses to open over a file that exists -- and covers every overlay this compile
;		produces. ObjStreamAbort takes away the one that was in flight if the compile stopped.
;
;		WHAT IS LEFT IS AN ORPHAN: a .Bnn from an earlier run whose GP.BANKED has since changed
;		its bank number or gone. It is not part of the program any more, so nothing loads it,
;		and the programmer owns stale overlays by decision. Deleting it would need a list of
;		the banks the LAST compile used, which nothing keeps.
;

; ************************************************************************************************
;
;								Scratch one file.  YX = ASCIIZ name
;
; ************************************************************************************************

IOScratchFile:
		stx 	zTemp0
		sty 	zTemp0+1
		;
		;		REFUSE if the name IS the source name. A misconfigured GPC.INPUT would otherwise
		;		destroy the source before the compile had read a byte of it, and the compiler
		;		would then report a missing file rather than the mistake that caused it.
		;
		ldy 	#0
_IOSFSame:
		lda 	(zTemp0),y
		cmp 	SourceFile,y
		bne 	_IOSFDiffer
		tax 								; matched to a shared terminator -> the same name
		beq 	_IOSFDone
		iny
		bra 	_IOSFSame
_IOSFDiffer:
		lda 	#'S' 						; build "S0:<name>" -- the DOS scratch command
		sta 	IONameBuffer+0
		lda 	#'0'
		sta 	IONameBuffer+1
		lda 	#':'
		sta 	IONameBuffer+2
		ldy 	#$FF
_IOSFCopy:
		iny 								; pre-increment copy, as IOSetFileName does
		lda 	(zTemp0),y
		sta 	IONameBuffer+3,y
		bne 	_IOSFCopy
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
_IOSFDone:
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
