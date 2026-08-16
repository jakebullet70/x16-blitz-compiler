; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		for.asm
;		Purpose:	FOR command
;		Created:	20th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;								<RefAddr|Type> <Terminal> <Step> FOR
;
; ************************************************************************************************

CommandXFor: ;; [for]
		.entercmd
		;
		;		Stock BASIC REUSES the frame of an open FOR with the same index variable rather
		;		than opening a second one. Opening unconditionally leaked 19 bytes of frame stack
		;		every time a loop was abandoned and re-entered, so
		;
		;			20 FOR I=1 TO 5 : C=C+1 : IF C<500 THEN 20
		;
		;		runs forever interpreted but died compiled with OUT OF MEMORY after ~215 passes.
		;		Search first, as FNDFOR does. Only worth looking if the top frame is a FOR at all,
		;		because the search stops at the first frame that is not one.
		;
		lda 	(runtimeStackPtr)
		cmp 	#FRAME_FOR
		bne 	_CFNoReuse
		jsr 	ReuseForFrame
_CFNoReuse:
		lda 	#FRAME_FOR 					; open frame
		jsr 	StackOpenFrame
		jsr 	StackSaveCurrentPosition 	; normalise to Y=0 and save position.

		ldy 	#7 							; copy step out
		jsr 	CopyTOSToOffsetY
		dex
		ldy 	#13 						; copy terminal value.
		jsr 	CopyTOSToOffsetY
		dex

		;
		;		Bit 15 of the reference used to mean "int16 index", recorded here at frame
		;		offset 4 bit 7. NEXT never read that bit -- it wrote a raw float back into the
		;		two-byte slot, so a negative index came back as its magnitude. The compiler now
		;		rejects an int16 index outright, as stock X16 BASIC does (?SYNTAX ERROR), so
		;		this bit is always clear. Kept, with the masking below, so a stale object file
		;		that still sets it stores a flag nothing acts on rather than a bogus address.
		;
		lda 	NSMantissa1,x 				; bit 15 of reference indicates type int16
		and 	#$80
		ldy 	#4
		sta 	(runtimeStackPtr),y

		lda 	NSMantissa0,x 				; copy the reference address
		ldy 	#5 							; adjusted to be a real address
		sta 	(runtimeStackPtr),y
		sta 	zTemp0 						; also to zTemp0
		iny
		lda 	NSMantissa1,x
		clc
		and 	#$7F 						; throw the type bit.
		sta 	(runtimeStackPtr),y
		adc 	variableStartPage 			; point to variable page.
		sta 	zTemp0+1
		dex 								; throw reference.
		;
		;		We look for optimisation options. Here we have optimisation
		; 		if the index value, step value, and terminal value are all
		; 		positive integers, step is 1 byte - we can do it much more quickly.
		;
		ldy 	#5 							; check the index, step and terminal values
		lda 	(zTemp0),y 					; are all +ve integers, sign bits first.
		ldy 	#12 
		ora 	(runtimeStackPtr),y
		ldy 	#18
		ora 	(runtimeStackPtr),y
		and 	#$80 						; only interested in sign bit.
		;
		dey 								; now the exponents.
		ora 	(zTemp0),y
		ldy 	#11
		ora 	(runtimeStackPtr),y
		ldy 	#17
		ora 	(runtimeStackPtr),y

		ldy 	#8 							; step must be 1 byte.
		ora 	(runtimeStackPtr),y
		iny
		ora 	(runtimeStackPtr),y
		iny
		ora 	(runtimeStackPtr),y

		bne 	_CFNoOptimise
		;
		;		A ZERO step must never take the optimised path. Two reasons: its increment loop
		;		in next.asm propagates carry with "beq _CNOIncrement", and adding 0 to a 0 byte
		;		leaves 0 -- so with a zero index it walks Y straight off the end of the 4-byte
		;		variable, corrupting whatever follows. And the optimised exit test is a plain
		;		"terminal < value" magnitude check, which cannot express the exact-equality exit
		;		that STEP 0 requires. Send it to the general path, which handles both.
		;
		ldy 	#7 							; step low byte (mantissa1..3 are already known zero)
		lda 	(runtimeStackPtr),y
		beq 	_CFNoOptimise

		ldy 	#4 							; set the runtime stack pointer optimisation flag.
		lda 	(runtimeStackPtr),y
		ora 	#$40
		sta 	(runtimeStackPtr),y

_CFNoOptimise:
		ldy 	#0
		.exitcmd	

; ************************************************************************************************
;
;								Copy TOS to stack frame offset Y
;
; ************************************************************************************************

CopyTOSToOffsetY:
		lda 	NSMantissa0,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa1,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa2,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSMantissa3,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSExponent,x
		sta 	(runtimeStackPtr),y
		iny
		lda 	NSStatus,x
		sta 	(runtimeStackPtr),y
		rts

; ************************************************************************************************
;
;		Throw any open FOR frame using the same index variable as the FOR about to be opened,
;		along with every frame stacked above it, so the new frame reuses its space.
;
;		Walks a COPY of the stack pointer and only commits on a match, so a search that finds
;		nothing leaves the stack untouched. Stops at the first frame that is not a FOR, exactly
;		as the 6502 ROM does -- which is what makes an intervening GOSUB shield a subroutine's
;		FOR I from the caller's. The $FF stack-empty marker is not FRAME_FOR, so it stops there
;		too and needs no test of its own.
;
;		Y holds the code pointer offset on entry to a command, and StackOpenFrame's OUT OF
;		MEMORY reports codePtr+Y, so Y is saved and restored -- see blitz-error-codeptr-y.
;
; ************************************************************************************************

ReuseForFrame:
		phy
		dex 								; <reference> <terminal> <step>, so the index
		dex 								; variable reference is two below TOS.
		lda 	NSMantissa0,x
		sta 	zTemp2
		lda 	NSMantissa1,x
		and 	#$7F 						; frame offset 6 holds it with the type bit thrown.
		sta 	zTemp2+1
		inx
		inx
		;
		lda 	runtimeStackPtr 			; walk a copy
		sta 	zTemp1
		lda 	runtimeStackPtr+1
		sta 	zTemp1+1
_RFFLoop:
		lda 	(zTemp1) 					; still a FOR frame ?
		cmp 	#FRAME_FOR
		bne 	_RFFExit
		ldy 	#5 							; same index variable ?
		lda 	(zTemp1),y
		cmp 	zTemp2
		bne 	_RFFNext
		iny
		lda 	(zTemp1),y
		cmp 	zTemp2+1
		beq 	_RFFFound
_RFFNext:
		clc 								; step over the frame and try the next.
		lda 	zTemp1
		adc 	#FRAME_FOR & $1F
		sta 	zTemp1
		bcc 	_RFFLoop
		inc 	zTemp1+1
		bra 	_RFFLoop

_RFFFound:
		clc 								; discard it and everything above it.
		lda 	zTemp1
		adc 	#FRAME_FOR & $1F
		sta 	runtimeStackPtr
		lda 	zTemp1+1
		adc 	#0
		sta 	runtimeStackPtr+1
_RFFExit:
		ply
		rts

; ************************************************************************************************
;
;		0	FOR Marker 				[1]
;		1 	Page/Position for loop 	[3]
;		4 	Control 				[1] 	Integer/Int16:7 ; optimised:6
;		5 	Index Variable 			[2]  	Offset Address 
;		7 	Step (+1 optimise) 		[6]
;		13	Terminal Value.	 		[6]
;
; ************************************************************************************************

		.send 	code
		
; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		16/08/26		FOR now reuses the frame of an open FOR with the same index variable, as
;						stock BASIC's FNDFOR does. Opening unconditionally leaked 19 bytes of
;						frame stack per abandoned loop, so a program that ran forever interpreted
;						died compiled with OUT OF MEMORY after ~215 passes.
;
; ************************************************************************************************
