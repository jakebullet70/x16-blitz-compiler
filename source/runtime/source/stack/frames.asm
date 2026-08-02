; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		frames.asm
;		Purpose:	Stack frame routines
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;										Open a frame
;
; ************************************************************************************************

StackOpenFrame:
		pha 								; save frame marker
		and 	#$1F 						; bytes required.
		sta 	zTemp0
		;
		sec 								; subtract from runtime stack pointer.
		lda		runtimeStackPtr
		sbc 	zTemp0
		sta 	runtimeStackPtr
		lda		runtimeStackPtr+1
		sbc 	#0
		sta 	runtimeStackPtr+1
		;
		;		...and refuse if that was one frame too many. Nothing tested this before: the
		;		stack simply carried on down out of the gap the compiler left for it and into the
		;		object code, so the program overwrote itself and then ran what it had written.
		;
		;		stackFloorHigh (00runtime.asm) is storeStartHigh - FrameStackPages, so it is page
		;		aligned; a frame is at most 31 bytes, so testing the high byte AFTER the subtraction
		;		is exact -- the new frame either starts inside the gap or it does not, and it cannot
		;		straddle. A is already the new high byte, so this costs six cycles a GOSUB.
		;
		;		OUT OF MEMORY, because that is what stock BASIC reports for too many nested GOSUBs.
		;
		cmp 	stackFloorHigh
		bcc 	_SOFOverflow
		;
		pla 								; put frame marker at +0
		sta 	(runtimeStackPtr)
		rts

_SOFOverflow:
		.error_memory

; ************************************************************************************************
;
;										Close a frame
;
; ************************************************************************************************

StackCloseFrame:
		lda 	(runtimeStackPtr)			; get frame marker
		and 	#$1F 						; size
		clc
		adc 	runtimeStackPtr
		sta 	runtimeStackPtr
		bcc 	_SCFNoCarry
		inc 	runtimeStackPtr+1
_SCFNoCarry:
		rts

; ************************************************************************************************
;
;									Find frame of type A
;
; ************************************************************************************************

StackFindFrame:
		sta 	requiredFrame
_SFFLoop:
		lda 	(runtimeStackPtr) 			; get TOS
		cmp 	#$FF 						; if found $FF then this is a fail.
		beq 	SCFFail 			
		cmp 	requiredFrame 				; found this type ?
		beq 	_SFFFound
		jsr 	StackCloseFrame 			; close the top frame
		bra 	_SFFLoop 					; and try te next.
_SFFFound:
		rts		

; ************************************************************************************************
;
;										Check a frame
;
; ************************************************************************************************

StackCheckFrame:
		cmp 	(runtimeStackPtr) 			; matches current frame
		bne 	SCFFail
		rts
SCFFail:
		.error_structure

		.send code

		.section storage
requiredFrame:
		.fill 	1
		.send 	storage		
		
; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		02/08/26		StackOpenFrame now refuses to grow the frame stack below stackFloorHigh; it
;						used to run on into the object code.
;		22/06/23 		Added StackFindFrame which looks for a frame of this type and throws
;						non matchers.
;
; ************************************************************************************************
