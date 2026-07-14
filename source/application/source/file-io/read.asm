; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		read.asm
;		Purpose:	Read file code.
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								 Open sequential file for Read
; 									   YX = ASCIIZ name
;
; ************************************************************************************************

IOOpenRead:
		lda 	#'R' 						; read.
		jsr 	IOSetFileName 				; set up name/LFS
		ldx	 	#3 							; use file 3 for reading
		jsr 	$FFC6 						; CHKIN
		rts

; ************************************************************************************************
;
;									Read A from input file
;
;			    If read,  A=Byte and Carry Clear, else A = Error and Carry Set
;
; ************************************************************************************************

IOReadByte:
		phx 					
		phy
		jsr 	$FFB7 						; read ST
		sec
		bne 	_IORExit
		jsr 	$FFCF 						; read a byte
		clc 								; status OK.
_IORExit:		
		ply
		plx
		rts

; ************************************************************************************************
;
;							    Close files (use the same code)
;
; ************************************************************************************************

IOReadClose:
IOWriteClose:
		lda 	#3 							; CLOSE# 3
		jsr 	$FFC3
		jsr 	$FFCC 						; CLRCHN
		rts

; ************************************************************************************************
;
;				 Set LFS, Name and Open File. YX = Filename (ASCIIZ) A = R/W
;
; ************************************************************************************************

IOSetFileName:
		pha 								; save R/W
		stx 	zTemp0
		sty 	zTemp0+1
		ldy 	#$FF 						; copy name given
_IOSCopy:
		iny 								; pre-increment copy
		lda 	(zTemp0),y
		sta 	IONameBuffer,y
		bne 	_IOSCopy
		;
		sta 	IONameBuffer+4,y
		lda 	#',' 						; append ,S,[R|W]
		sta 	IONameBuffer+0,y
		sta 	IONameBuffer+2,y
		lda 	#'S'
		sta 	IONameBuffer+1,y
		pla 								; write R/W out
		sta 	IONameBuffer+3,y

		tya 								; length of name to A
		clc
		adc 	#4 							; we added 4 characters.
 								
		ldx 	#IONameBuffer & $FF			; name address to YX
		ldy 	#IONameBuffer >> 8

	    jsr 	$FFBD          				; call SETNAM

    	lda 	#3 							; set LFS to 3,8,3
		ldx 	#8
		ldy 	#3
		jsr 	$FFBA		

		jsr 	$FFC0 						; OPEN
		rts

; ************************************************************************************************
;
;		The name, with ",S,R" or ",S,W" appended.
;
;		This was 64 bytes in the storage section, and that was a loaded gun. storage is a
;		.dsection at $0400 with the code starting at $0801 (common.inc), so it is a 1K hole --
;		and it was already full to the last byte. IONameBuffer sat at $07F1, which left it room
;		for exactly "SOURCE.PRG,S,R" and its terminator: fifteen bytes, ending at $07FF. Any
;		name longer than that would have written straight over the BASIC stub at $0801 and
;		destroyed the program that was running.
;
;		Nobody noticed because the two names were hardcoded and both were ten characters. Now
;		that GPC.INPUT supplies them, they can be any length, so the buffer is here in the code
;		section instead -- which is the compiler, above ObjectBase, thrown away when the object
;		code is written. It costs a compiled program nothing.
;
; ************************************************************************************************

IONameBuffer:
		.fill 	CFLineSize+8 				; the longest line GPC.INPUT can hold, plus ",S,R"
											; and the zero
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
