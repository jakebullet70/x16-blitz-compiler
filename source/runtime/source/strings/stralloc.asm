; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		stralloc.asm
;		Purpose:	Allocate string memory
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;				Temporary string allocation reset (call if cmd manipulates strings)
;
; ************************************************************************************************

resetStringSystem .macro
		stz 	stringInitialised
		.endm

; ************************************************************************************************
;
;							Initialise string system if required
;
;		TEMPORARIES START stringTempPages BELOW THE HEAP CEILING, and that used to be the
;		constant 2. GP.FN raises it for the length of a call so the callee's own per-line
;		resets hand out memory BELOW the temporaries its caller is still holding -- see
;		gp-runtime/commands/gpfncall.asm, which is the only thing that ever writes it.
;
;		The heap ceiling itself could not be moved instead: StringConcrete's scavenger walks
;		the blocks upward from stringHighMemory and needs them to tile it exactly, so a ceiling
;		lowered into the temporary area starts that walk in garbage.
;
; ************************************************************************************************

StringInitialise:
		pha
		lda 	stringInitialised 			; already done
		bne 	_SIExit

		lda 	stringHighMemory 			; copy high memory - stringTempPages => stringTempPointer
		sta 	stringTempPointer
		lda 	stringHighMemory+1
		sec
		sbc 	stringTempPages
		sta 	stringTempPointer+1

		dec 	stringInitialised 			; set the initialised flag.
_SIExit:
		lda 	availableMemory+1 			; check out of memory
		inc 	a
		inc 	a
		cmp 	stringHighMemory+1
		bcs 	_SIMemory
		pla
		rts
_SIMemory:
		.error_memory

; ************************************************************************************************
;
;								Allocate space for a string of length A.
;
; ************************************************************************************************

StringAllocTemp:
		jsr 	StringInitialise 			; check it is initialised.

		eor 	#$FF 						; subtract A+1 from temp pointer.
		clc
		adc 	stringTempPointer 			; subtract 32 from temp pointer and
		sta 	stringTempPointer 			; save in zsTemp and stackas well.
		sta 	zsTemp
		sta 	NSMantissa0,x

		lda 	stringTempPointer+1
		adc 	#$FF
		sta 	stringTempPointer+1
		sta 	zsTemp+1
		sta 	NSMantissa1,x
		stz 	NSMantissa2,x
		stz 	NSMantissa3,x

		lda 	#0 							; clear string.
		sta 	(zsTemp)
		lda 	#NSSString 			 		; mark as string
		sta 	NSStatus,x
		rts

; ************************************************************************************************
;		
; 										Write A to String
;
; ************************************************************************************************

StringWriteChar:
		phy
		pha
		lda 	(zsTemp)
		inc 	a
		sta 	(zsTemp)
		tay
		pla
		sta 	(zsTemp),y
		ply
		rts

		.send code
		
		.section storage
stringInitialised:							; non zero if string system not set up
		.fill 	1		
stringTempPointer: 							; allocated temporary pointer
		.fill 	2
stringTempPages: 							; pages below the heap ceiling the temporaries start at
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
