; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		linput.asm
;		Purpose:	LINPUT, LINPUT# and BINPUT#
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		Two P-codes serve all three keywords, because the CHANNEL is not their business: the "#"
;		forms are compiled with the C: (channel execute) prefix, which sets currentChannel around
;		the command and puts it back afterwards. That is exactly how INPUT and INPUT# already
;		share one runtime. So:
;
;			[linput]	S[X] = a delimiter	->	S[X] = everything up to it
;			[binput]	S[X] = a count		->	S[X] = that many bytes
;
;		LINPUT (no #) is simply [linput] on channel 0 with a delimiter of 13, and channel 0 is the
;		KERNAL's screen editor -- CHRIN hands back the logical line a character at a time as the
;		user types it, with every editor key working. That is what LINPUT is FOR, and it is also
;		why the manual warns that an empty line comes back as a single space and trailing spaces
;		are lost: that is the editor's doing, not ours, and we inherit it for free.
;
;		END OF FILE is checked BEFORE each read, never after. The KERNAL sets ST when it hands
;		over the LAST byte, so that byte is real and must be kept; it is the NEXT read that has
;		nothing to give. Testing first keeps the last byte and still stops. See st.asm -- without
;		ST a program could not tell EOF from a blank line, and a read loop could never end.
;
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;					LINPUT <var$>  /  LINPUT# <n>,<var$>[,<delimiter>]
;
; ************************************************************************************************

CommandXLinput: ;; [!linput]
		.entercmd 							; S[X] is the delimiter
		phy
		jsr 	GetInteger8Bit
		sta 	liDelimiter
		phx 								; the KERNAL calls below are free to trash X, so park
											; the float stack pointer and use X as the index
		jsr 	LinputOpenChannel
		stz 	ReadBufferSize
_CLILoop:
		jsr 	LinputAtEndOfFile
		bne 	_CLIDone
		jsr 	X16_CHRIN
		cmp 	liDelimiter
		beq 	_CLIDone 					; the delimiter is consumed, but never stored
		ldx 	ReadBufferSize
		cpx 	#255 						; ReadBuffer is 255 bytes. A full one takes no more, but
		beq 	_CLILoop 					; still runs on to the delimiter, so that the next read
											; starts at the beginning of a line rather than mid-way
		sta 	ReadBuffer,x
		inc 	ReadBufferSize
		bra 	_CLILoop
_CLIDone:
		jsr 	LinputCloseChannel
		plx
		jsr 	LinputResult
		ply
		.exitcmd

; ************************************************************************************************
;
;							BINPUT# <n>,<var$>,<len>
;
; ************************************************************************************************

CommandXBinput: ;; [!binput]
		.entercmd 							; S[X] is how many bytes are wanted
		phy
		jsr 	GetInteger8Bit
		sta 	liCount
		phx
		jsr 	LinputOpenChannel
		stz 	ReadBufferSize
_CBILoop:
		lda 	ReadBufferSize 				; got them all ?
		cmp 	liCount
		beq 	_CBIDone
		jsr 	LinputAtEndOfFile 			; "if there are fewer than <len> bytes available to
		bne 	_CBIDone 					; be read, fewer bytes will be stored"
		jsr 	X16_CHRIN
		ldx 	ReadBufferSize
		sta 	ReadBuffer,x
		inc 	ReadBufferSize
		bra 	_CBILoop
_CBIDone:
		jsr 	LinputCloseChannel
		plx
		jsr 	LinputResult
		ply
		.exitcmd

; ************************************************************************************************
;
;		Z clear when the channel has run out. Bit 6 of the KERNAL status is end of file.
;
; ************************************************************************************************

LinputAtEndOfFile:
		jsr 	X16_READST
		and 	#$40
		rts

; ************************************************************************************************
;
;		Point the KERNAL's input at the current channel, and afterwards put it back. Channel 0
;		means the keyboard, which is CLRCHN's default, not a file to CHKIN.
;
; ************************************************************************************************

LinputOpenChannel:
		ldx 	currentChannel
		beq 	LinputCloseChannel
		jmp 	X16_CHKIN

LinputCloseChannel:
		jmp 	X16_CLRCHN

; ************************************************************************************************
;
;		Leave the buffer in S[X] as a string. ReadBufferSize is the length byte and ReadBuffer
;		follows it, which IS Blitz's string layout, so the buffer's own address is the string.
;		This overwrites the parameter that was in S[X], so the stack comes out level and the
;		store the compiler emits next pops the result straight into the variable.
;
; ************************************************************************************************

LinputResult:
		jsr 	FloatSetZero
		lda 	#ReadBufferSize & $FF
		sta 	NSMantissa0,x
		lda 	#ReadBufferSize >> 8
		sta 	NSMantissa1,x
		lda 	#NSSString
		sta 	NSStatus,x
		rts

		.send 	code

		.section storage
liDelimiter:
		.fill 	1
liCount:
		.fill 	1
		.send storage

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
