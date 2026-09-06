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
; ************************************************************************************************

WriteCodeByte:
		pha 								; save on stack
		phx
		phy
		jsr 	SumCodeByte 				; A is still the byte
		tax
		lda 	#BLC_WRITEOUT
		jsr 	CallAPIHandler
		ply 								; restore from stack
		plx
		pla
		rts

; ************************************************************************************************
;
;		THE SUM THE TWO PASSES ARE COMPARED BY.
;
;		Neither pass has an object to checksum -- pass one stores nothing and pass two's goes
;		straight into a file -- so what is compared is the STREAM OF BYTES THE GENERATORS EMIT.
;		That stream is identical in both passes, byte for byte and in the same order, except
;		where pass two writes an answer pass one could not know. Those are counted out in
;		sumSkip and left out of the sum:
;
;			a branch's two operand bytes 	EmitBranch
;			an .unwind's count 				CommandGOTO
;			a GP.ASM blob's address 		AsmCloseBlock
;			the variable space 				CompilePass
;			the GP.ASM pool 				AsmFlushPool -- pass two resolves it in its bank first
;			the GP.BANKED bookkeeping 		GPBankRelocate in pass one, RegionSwitch in pass two
;
;		What it does cover is every opcode and every other operand, in order, which is what
;		catches a second pass that compiled anything differently -- and it catches it before the
;		object is written. That is what the object checksum used to do, and this is what is left
;		to do it with.
;
; ************************************************************************************************

SumCodeByte:
		pha
		lda 	sumSkip 					; one of the bytes the two passes may differ on ?
		ora 	sumSkip+1
		beq 	_SCBSum
		lda 	sumSkip 					; then step over it
		bne 	_SCBNoBorrow
		dec 	sumSkip+1
_SCBNoBorrow:
		dec 	sumSkip
		pla
		rts
_SCBSum:
		pla
		pha
		clc
		adc 	passSum 					; sum1 += byte
		sta 	passSum
		clc
		adc 	passSum+1 					; sum2 += sum1, so a reordering shows up too
		sta 	passSum+1
		pla
		rts

;
;		The next YA bytes are not summed.
;
SumSkipYA:
		sta 	sumSkip
		sty 	sumSkip+1
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

