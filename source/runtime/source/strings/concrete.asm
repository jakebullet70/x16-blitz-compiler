; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		concrete.asm
;		Purpose:	Concrete string memory
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;									Concrete String YA -> YA
;
; ************************************************************************************************

StringConcrete:	
		stz 	stringInitialised	 		; initialise next usage

		sty 	zTemp2+1 					; save pointer to new string
		sta 	zTemp2
		;
		lda 	(zTemp2) 					; length required
		lsr 	a 							; allow half as much for expansion.
		clc
		adc 	(zTemp2)
		bcc 	_SCNoOverflow
		lda 	#255
_SCNoOverflow:
		cmp 	#10 						; and a minimum of 10
		bcs 	_SCNoMinimum		
		lda 	#10
_SCNoMinimum:
		sta 	zTemp1 						; save max length.
		;
		;		BEFORE TAKING THE CEILING DOWN, LOOK FOR A DEAD BLOCK. write_string flags a
		;		block it outgrows (control bit 7), and until 02/09/26 nothing ever read that
		;		flag, so every string that grew past its block leaked it for good. Measured on
		;		samples/editor: startup alone left ~3.5K of corpses in a 5K workspace, and its
		;		self-check's "intermittent" OUT OF MEMORY was that leak wobbling a page either
		;		side of the line. First fit, and the max length is KEPT -- a corpse is its size
		;		however it is reborn. The blocks tile the heap exactly from stringHighMemory up
		;		to the ceiling, so the walk lands on storeEndHigh:00 or stops sooner, never past.
		;
		lda 	stringHighMemory 			; walk from the bottom of the heap.
		sta 	zsTemp
		lda 	stringHighMemory+1
		sta 	zsTemp+1
_SCRScan:
		lda 	zsTemp+1 					; ceiling page reached = no corpse fitted.
		cmp 	storeEndHigh
		bcs 	_SCRFresh
		ldy 	#1
		lda 	(zsTemp),y 					; control byte, bit 7 = dead.
		bpl 	_SCRNext
		lda 	(zsTemp) 					; dead: does its max length fit the ask?
		cmp 	zTemp1
		bcc 	_SCRNext
		lda 	#0 							; back to life: clear the control byte;
		sta 	(zsTemp),y 					; the ceiling is untouched.
		lda 	zsTemp 						; reborn string in YA.
		ldy 	zsTemp+1
		rts
_SCRNext:
		lda 	(zsTemp) 					; step over max + 3 (the header).
		clc
		adc 	zsTemp
		sta 	zsTemp
		bcc 	_SCRNext2
		inc 	zsTemp+1
_SCRNext2:
		lda 	zsTemp
		clc
		adc 	#3
		sta 	zsTemp
		bcc 	_SCRScan
		inc 	zsTemp+1
		bra 	_SCRScan
_SCRFresh:
		;
		sec
		lda		stringHighMemory 			; subtract max length from high memory.
		sbc 	zTemp1
		tay
		lda 	stringHighMemory+1 	
		sbc 	#0
		pha
		;
		sec 								; subtract 3 more
		tya 							
		sbc 	#3
		sta 	stringHighMemory 			; to string high memory/zsTemp
		sta 	zsTemp
		;
		pla
		sbc 	#0
		sta 	stringHighMemory+1
		sta 	zsTemp+1
		;
		;		zsTemp is the base of the new block. Nothing checked it had anywhere to go.
		;
		;		This pointer only ever travels DOWN, and on the ASSIGNMENT path -- which is every
		;		A$=... in the language -- StringInitialise's out-of-memory test is never reached,
		;		because that only runs when something allocates a TEMPORARY (STR$, CHR$, concat).
		;		So the heap walked out of the bottom of the workspace, through the arrays, the
		;		scalars and the FOR/GOSUB stack, and into the p-code, and the program then executed
		;		its own string data. Measured 2026-08-02: a loop assigning a 36-character literal
		;		into a string array BRKed into the machine-language monitor on the 405th pass, with
		;		no error of any kind. It did the same on the pristine engine, 101 passes earlier.
		;
		;		availableMemory is the top of the array area (allocate.asm, dim.asm) -- the other
		;		end of the same free gap, and the mirror image of the test DIMWriteByte already
		;		makes when the arrays grow up towards us. Landing exactly on it is legal; the next
		;		temporary is what then reports the gap is gone, via StringInitialise's 512-byte
		;		margin.
		;
		;		Only A is used, so X (the numeric stack) and the returned YA are untouched, and the
		;		cost is a compare on each assignment that allocates.
		;
		cmp 	availableMemory+1
		bcc 	_SCNoMemory
		bne 	_SCRoom
		lda 	zsTemp
		cmp 	availableMemory
		bcc 	_SCNoMemory
_SCRoom:
		;
		lda 	zTemp1 						; set max length.
		sta 	(zsTemp)
		ldy 	#1 							; clear control byte.
		lda 	#0
		sta 	(zsTemp),y
		;
		lda 	zsTemp 						; new empty string in YA.
		ldy 	zsTemp+1
		rts

_SCNoMemory:
		.error_memory

		.send code

; ************************************************************************************************
;
;		Concreted string (total size = MaxLength + 3)
;
;		[Max length] [Control] [Act Length] [Data]
;		
; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		02/08/26		String heap now bounds-checked against availableMemory; the assignment path
;						had no out-of-memory test at all.
;
; ************************************************************************************************
