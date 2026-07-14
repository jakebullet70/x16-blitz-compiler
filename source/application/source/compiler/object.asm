; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		object.asm
;		Purpose:	Write object code out.
;		Created:	9th October 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;									Write object code out.
;
; ************************************************************************************************

;
;		Pages left free below the workspace for the runtime (GOSUB/FOR) stack. clr.asm puts
;		runtimeStackPtr at storeStartHigh-1:$FF and grows it DOWNWARD, so without a gap here
;		a deep call chain would walk straight back into the object code.
;
FrameStackPages = 16 						; 4K, ~250 frames

; ************************************************************************************************
;
;		Write object code out.
;
;		In memory the layout is
;
;			$0801 [ runtime ] ObjectBase [ compiler ] FreeMemory [ object code ] objPtr
;
;		but a saved program never compiles anything, so the compiler is dead weight. The
;		file is therefore written in two pieces -- the runtime, then the object code -- so
;		that on reload the object code lands at ObjectBase, on top of where the compiler was.
;
;		That reclaims (FreeMemory-ObjectBase) bytes from every compiled program, and, more
;		importantly, lets the workspace start just above the object code instead of at a
;		hardcoded $8000 -- which is most of the useable memory a compiled program gets.
;
;		The two immediates in StartCode are patched as they stream past, rather than in RAM,
;		so the copy still in memory (RUN a second time) keeps running from FreeMemory.
;
; ************************************************************************************************

WriteObjectCode:
		jsr 	PatchOutCompile 			; makes it run the runtime on reload
		;
		;		zTemp1 = length of the object code.
		;
		sec
		lda 	objPtr
		sbc 	#FreeMemory & $FF
		sta 	zTemp1
		lda 	objPtr+1
		sbc 	#FreeMemory >> 8
		sta 	zTemp1+1
		;
		;		Round that up to whole pages.
		;
		lda 	zTemp1 						; any part page ?
		beq 	_WOCWholePages
		inc 	zTemp1+1 					; then it needs one more
_WOCWholePages:
		;
		;		newWorkspacePage = ObjectBase + pages(object code) + the frame stack gap.
		;
		clc
		lda 	#ObjectBase >> 8
		adc 	zTemp1+1
		adc 	#FrameStackPages
		sta 	newWorkspacePage

		ldy 	#ObjectFile >> 8
		ldx 	#ObjectFile & $FF
		jsr 	IOOpenWrite 				; open write

		lda 	#1 							; write out the load address $0801
		jsr 	IOWriteByte
		lda 	#8
		jsr 	IOWriteByte
		;
		;		Part one : the runtime, $0801 up to ObjectBase, patching the two immediates
		;		in StartCode on the way past.
		;
		.set16 	zTemp0,StartBasicProgram
_WOCRuntime:
		lda 	zTemp0+1 					; the code page operand ?
		cmp 	#(RunCodePage+1) >> 8
		bne 	_WOCNotCodePage
		lda 	zTemp0
		cmp 	#(RunCodePage+1) & $FF
		bne 	_WOCNotCodePage
		lda 	#ObjectBase >> 8 			; object code moves down to here
		bra 	_WOCEmit
_WOCNotCodePage:
		lda 	zTemp0+1 					; the workspace page operand ?
		cmp 	#(RunWorkspacePage+1) >> 8
		bne 	_WOCPlain
		lda 	zTemp0
		cmp 	#(RunWorkspacePage+1) & $FF
		bne 	_WOCPlain
		lda 	newWorkspacePage 			; so the workspace can start much lower
		bra 	_WOCEmit
_WOCPlain:
		lda 	(zTemp0)
_WOCEmit:
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCSkip1
		inc 	zTemp0+1
_WOCSkip1:
		lda 	zTemp0+1 					; until we reach ObjectBase (page aligned)
		cmp 	#ObjectBase >> 8
		bne 	_WOCRuntime
		lda 	zTemp0
		cmp 	#ObjectBase & $FF
		bne 	_WOCRuntime
		;
		;		Part two : the object code itself, which lands at ObjectBase on reload.
		;
		.set16 	zTemp0,FreeMemory
_WOCCode:
		lda 	zTemp0 						; done ?
		cmp 	objPtr
		bne 	_WOCCodeByte
		lda 	zTemp0+1
		cmp 	objPtr+1
		beq 	_WOCDone
_WOCCodeByte:
		lda 	(zTemp0)
		jsr 	IOWriteByte
		inc 	zTemp0
		bne 	_WOCCode
		inc 	zTemp0+1
		bra 	_WOCCode
_WOCDone:
		jsr 	IOWriteClose 				; close the file.
		rts

		.send code

		.section storage

newWorkspacePage: 							; first page of workspace in the saved file
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
