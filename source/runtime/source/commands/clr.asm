; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		clr.asm
;		Purpose:	Clear memory down
;		Created:	13th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;										CLR command
;
; ************************************************************************************************

CommandClr: ;; [!CLR]
		.entercmd
		jsr 	ClearMemory
		.exitcmd

; ************************************************************************************************
;
;					Clear workspace, reset string system, reset BASIC stack
;
; ************************************************************************************************

ClearMemory:		
		;
		;		Zero workspace
		;
		lda 	storeStartHigh 							; erase the work area
		sta 	zTemp0+1
		stz 	zTemp0
		phy
		ldy 	#0
_ClearLoop1:	
		lda 	#0
		sta 	(zTemp0),y
		iny
		bne 	_ClearLoop1	
		inc 	zTemp0+1
		lda 	zTemp0+1
		cmp 	storeEndHigh
		bne 	_ClearLoop1
		;
		;		Initialise string storage space.
		;
		;		This used to put the ceiling a QUARTER of the workspace below the top, under the
		;		comment "stack space = number of pages in total / 4". There is no stack up there.
		;		The runtime (FOR/GOSUB) stack is set up ten lines below this one, growing DOWN
		;		from storeStartHigh-1:$FF, and the compiler reserves FrameStackPages for it BELOW
		;		the workspace (see application/source/compiler/object.asm). So the top quarter
		;		was reserved for nothing -- and unreachable, because strings only ever grow down
		;		from this ceiling and arrays only ever grow up towards it. Measured on
		;		samples/FSIM16_V1: workspace $7900-$9F00, ceiling $9600, and the highest byte the
		;		program ever touched was $95FA. 2,304 of its 9,728 bytes, for nothing.
		;
		;		The ceiling is exclusive, so taking it right to the top is safe: StringConcrete
		;		subtracts the whole block size from it BEFORE writing a byte, and StringAllocTemp
		;		starts 512 below it, so the highest address either can touch is one less than
		;		this. storeEndHigh is already "the page after the last usable one" (00runtime.asm
		;		is handed $9F, and $9F00 is I/O), which is exactly what that needs.
		;
		lda 	storeEndHigh
		sta 	stringHighMemory+1
		stz 	stringHighMemory

		stz 	stringInitialised 						; string system not initialised
		;
		;		Initialise stack space.
		;
		lda 	storeStartHigh 							; stack at end of start memory.
		dec 	a
		sta 	runtimeStackPtr+1
		lda 	#$FF
		sta 	runtimeStackPtr

		lda 	#$FF 									; duff marker in case we try to remove it.
		sta 	(runtimeStackPtr)
		ply
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
;		02/08/26		String ceiling moved to the top of the workspace; it was a quarter down,
;						reserving space for a stack that lives below the workspace instead.
;
; ************************************************************************************************
