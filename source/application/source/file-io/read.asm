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
;			 Open the runtime image for read -- YX = ASCIIZ name, carry set if it failed
;
;		ON ITS OWN LOGICAL FILE, because it is read while OBJECT.PRG is open for write and
;		everything else here uses file 3 for both. The channel is NOT selected here: the
;		streamer alternates CHKIN/CHKOUT a page at a time, so whichever it set would be wrong
;		by the time the first byte moved.
;
; ************************************************************************************************

IO_IMAGE_FILE = 4

IOOpenImage:
		lda 	#IO_IMAGE_FILE
		sta 	ioFileNo
		lda 	#'R'
		jsr 	IOSetFileName 				; carry comes back from OPEN
		ldy 	#3 							; put the default back for every other caller
		sty 	ioFileNo 					; (sty leaves the carry alone)
		rts

; ************************************************************************************************
;
;						Select the image for input / the object file for output
;
; ************************************************************************************************

IOImageIn:
		ldx 	#IO_IMAGE_FILE
		jmp 	$FFC6 						; CHKIN

IOObjectOut:
		ldx 	#3
		jmp 	$FFC9 						; CHKOUT

; ************************************************************************************************
;
;									  Close the runtime image
;
; ************************************************************************************************

IOCloseImage:
		lda 	#IO_IMAGE_FILE
		jsr 	$FFC3 						; CLOSE
		jmp 	$FFCC 						; CLRCHN -- the object file stays OPEN but stops being
											; the selected output, so IOObjectOut before writing.

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
		pla 								; recover R/W
		cmp 	#'W'
		bne 	_IOSRead 					; reading uses the PLAIN name -- see the note below
		lda 	#',' 						; writing appends ",S,W" to create the file
		sta 	IONameBuffer+0,y
		sta 	IONameBuffer+2,y
		lda 	#'S'
		sta 	IONameBuffer+1,y
		lda 	#'W'
		sta 	IONameBuffer+3,y
		lda 	#0 							; terminator after the suffix
		sta 	IONameBuffer+4,y
		tya 								; name length plus the four we appended
		clc
		adc 	#4
		bra 	_IOSSetName
_IOSRead:
		tya 								; READ: the length is just the name -- NO ",S,R". Box16's
											; -hypercall_path opens the raw SETNAM string, so a
											; ",S,R" suffix makes it hunt for a host file literally
											; called "NAME,S,R" and the open fails. A plain name
											; reads on x16emu, Box16 and real CMDR-DOS alike (x16emu
											; only tolerated the suffix by parsing it off first).
											; Writing still needs ",S,W", which Box16 does honour.
_IOSSetName:
 								
		ldx 	#IONameBuffer & $FF			; name address to YX
		ldy 	#IONameBuffer >> 8

	    jsr 	$FFBD          				; call SETNAM

    	lda 	ioFileNo 					; set LFS to n,8,n -- n is 3 for everything except
		ldx 	#8 							; the runtime image, which has to be open for READ at
		ldy 	ioFileNo 					; the same time the object file is open for WRITE.
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

ioFileNo: 									; the logical file IOSetFileName opens on. Code
		.byte 	3 							; section, like everything else here -- it is the
											; compiler's, and the compiler is thrown away.

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
