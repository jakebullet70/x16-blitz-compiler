; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		api.asm
;		Purpose:	Short version of common API functions
;		Created:	7th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Get line number of current line -> YA
;
; ************************************************************************************************		

GetLineNumber:
		ldy 	currentLineNumber+1
		lda 	currentLineNumber
		rts
		
; ************************************************************************************************
;
;									Write byte A to output
;
;		Every byte of p-code the compiler produces goes through here, which is what makes it the
;		place to checksum the stream. The two passes MUST emit the same bytes -- see the pass
;		loop in main/compiler.asm -- and nothing else in the compiler enforces that, so a
;		Fletcher-16 is accumulated here and compared at the end of pass two. Above the API
;		boundary deliberately: it does not care where the byte lands, so the compiler's own test
;		harness is covered by the same check as the application.
;
;		A DEFERRED STATEMENT'S BYTES ARE COUNTED AND THEN DISCARDED. CompilerErrorHandler rolls
;		objPtr back over them, but they are already in the sum -- in both passes alike, so the
;		comparison still holds, and it now also proves the discarded bytes matched. That is the
;		right side to err on.
;
; ************************************************************************************************

WriteCodeByte:
		pha 								; save on stack
		phx
		phy
		tax 								; X = the byte, which is what BLC_WRITEOUT wants, and
											; it frees A for the sum
		txa
		clc
		adc 	passSum 					; sum1 += byte
		sta 	passSum
		clc
		adc 	passSum+1 					; sum2 += sum1, so a reordering shows up too
		sta 	passSum+1

		lda 	#BLC_WRITEOUT
		jsr 	CallAPIHandler
		ply 								; restore from stack
		plx
		pla
		rts

; ************************************************************************************************
;
;								Write byte A to output, WITHOUT checksumming it
;
;		For the operand bytes whose value is legitimately different in the two passes -- pass one
;		does not yet know what pass two will emit, which is the entire reason there are two of
;		them. The byte still occupies its slot, so the LENGTH check still covers it, and the two
;		passes stay in step in the sum because both of them skip the same slots.
;
;		Use it ONLY where the difference is by design. Every other byte goes through
;		WriteCodeByte, where a difference means a compiler bug and is meant to be caught.
;
; ************************************************************************************************

WriteCodeResolved:
		pha 								; save on stack
		phx
		phy
		tax
		lda 	#BLC_WRITEOUT
		jsr 	CallAPIHandler
		ply 								; restore from stack
		plx
		pla
		rts

; ************************************************************************************************
;
;								Print character A to Screen/Error Stream
;
; ************************************************************************************************

PrintCharacter
		pha
		phx
		phy
		tax
		lda 	#BLC_PRINTCHAR
		jsr 	CallAPIHandler
		ply
		plx
		pla
		rts

; ************************************************************************************************
;
;					Process new line - set source pointer, extract line number
;
; ************************************************************************************************
 
ProcessNewLine:
		stx 	zTemp0 						; save address in zTemp0
		sty 	zTemp0+1

		clc 								; set the srcPtr to the start of the actual code (e.g. offset 4)
		txa
		adc 	#4
		sta 	srcPtr
		tya
		adc 	#0
		sta 	srcPtr+1

		ldy 	#2							; read and save line number
		lda 	(zTemp0),y
		sta 	currentLineNumber
		iny
		lda 	(zTemp0),y
		sta 	currentLineNumber+1
		rts

		.send 	code

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

