; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		input.asm
;		Purpose:	Input commands
;		Created:	1stMay 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;										Input Commands
;
; ************************************************************************************************

CommandXInput: ;; [input]
		.entercmd
		phy 								; save Y
		inx									; space on stack
_INError:		
		jsr 	InputStringToBuffer 		; input from keyboard
		.set16 	zTemp0,ReadBufferSize		; convert from here
		jsr 	ValEvaluateZTemp0
		bcs 	_INError 					; failed, try again.
		ply 								; restore Y
		.exitcmd

CommandInputString: ;; [input$]
		.entercmd
		phy 								; save Y
		jsr 	InputStringToBuffer 		; input from keyboard
		inx 								; make space on stack
		jsr 	FloatSetZero 				; store as string on stack
		lda 	#ReadBufferSize & $FF
		sta 	NSMantissa0,x
		lda 	#ReadBufferSize >> 8
		sta 	NSMantissa1,x
		lda 	#NSSString
		sta 	NSStatus,x
		ply 								; restore Y
		.exitcmd

; ************************************************************************************************
;
;		InputBufferPos holds InputNoLine when no typed line is in hand, and the next read then
;		prompts for one. An empty line and a used-up line both have a zero at InputBufferPos, so
;		the buffer itself cannot say which it is.
;
; ************************************************************************************************

InputNoLine = $FF

CommandInputReset: ;; [input.start]
		.entercmd
		lda 	#InputNoLine
		sta 	InputBufferPos
		.exitcmd

; ************************************************************************************************
;
;		Read the next INPUT item into ReadBuffer. A line typed empty gives an empty item. The
;		ROM keeps the variable's old value instead.
;
;		The empty line is caught here because GetStringToBuffer cannot see it: a line end at
;		the start of an item means "go on to the next line" there, which is right for DATA and
;		would prompt again for INPUT.
;
; ************************************************************************************************

InputStringToBuffer:
		.set16 	ReadBumpNextVec,InputBumpNext
		.set16 	ReadLookNextVec,InputLookNext
		lda 	InputBufferPos 				; a line already in hand ?
		cmp 	#InputNoLine
		bne 	_ISTBItem
		jsr 	InputGetNewLine
		lda 	InputBuffer 				; typed empty ?
		bne 	_ISTBItem
		lda 	#InputNoLine 				; the item is empty, and the next one prompts
		sta 	InputBufferPos
		stz 	ReadBufferSize
		stz 	ReadBuffer
		rts
_ISTBItem:
		jmp 	GetStringToBuffer


; ************************************************************************************************
;
;		Look at the next input character - return CS if we have new line input, forces an end.
;		$00 if end of data.
;
; ************************************************************************************************

InputLookNext:
		phx
		ldx 	InputBufferPos 				; no line in hand: read one
		cpx 	#InputNoLine
		bne 	_ILNHaveLine
		jsr 	InputGetNewLine 			; this sets InputBufferPos to 0
		ldx 	#0
_ILNHaveLine:
		lda 	InputBuffer,x
		bne 	_ILNExit 					; if not EOS return it with CC.
		lda 	#InputNoLine 				; the line is used up, so the next read prompts
		sta 	InputBufferPos
		sec 								; return CS, NZ
		plx
		lda 	#13
		rts
_ILNExit:	
		plx
		cmp 	#0 							; return CC, Z Flag set.
		clc
		rts

; ************************************************************************************************
;
;								Consume 1 input character
;
; ************************************************************************************************

InputBumpNext:
		inc 	InputBufferPos
		rts

; ************************************************************************************************
;
;							Get a new line into the ReadBuffer
;
; ************************************************************************************************

InputGetNewLine:
		pha
		phx
		phy
		lda 	#"?"
		jsr 	IGNLEchoIfScreen
		ldy 	#0 							; line position.
_IGNLLoop:
		jsr 	VectorGetCharacter 			; get a character
		cmp 	#0
		beq 	_IGNLLoop
		cmp 	#$14 						; Backspace ?
		beq 	_IGNBackspace
		cmp 	#$0D 						; Return ?
		beq 	_IGNExit
		cpy 	#80 						; buffer full ?
		beq 	_IGNLLoop
		sta 	InputBuffer,y
		iny
		jsr 	IGNLEchoIfScreen
		bra 	_IGNLLoop

_IGNBackspace:
		cpy 	#0
		beq 	_IGNLLoop
		jsr 	IGNLEchoIfScreen
		dey
		bra 	_IGNLLoop
_IGNExit:
		jsr 	IGNLEchoIfScreen
		lda 	#0 							; make ASCIIZ
		sta 	InputBuffer,y
		stz 	InputBufferPos 				; reset position to start of input buffer.
		ply
		plx
		pla
		rts		

; ************************************************************************************************
;
;								Print A if output channel is screen.
;
; ************************************************************************************************

IGNLEchoIfScreen:
		ldx 	currentChannel
		bne 	_IGNLEExit
		jsr 	VectorPrintCharacter
_IGNLEExit:				
		rts

		.send 	code
		
		.section storage
InputBuffer:
		.fill 	81		
InputBufferPos:
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
