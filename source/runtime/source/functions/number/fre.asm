; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		fre.asm
;		Purpose:	Calculate free space
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;											FRE() function
;
; ************************************************************************************************

;
;		Free memory is the gap in the middle of the workspace: arrays grow UP from
;		availableMemory (support/allocate.asm, moved by dim.asm) and the string heap grows DOWN
;		from stringHighMemory (strings/concrete.asm). Whatever is between them is what a program
;		can still spend, and it is what the two out-of-memory tests measure against each other.
;
;		This used to subtract stringLowMemory, which was declared in data.inc, read here, and
;		WRITTEN NOWHERE -- so it was always zero and FRE returned the ADDRESS of the string
;		ceiling rather than a count. On a compiled samples/FSIM16_V1 that is 40704 where the
;		answer is about 5900. stringLowMemory has been deleted rather than maintained: it would
;		only have been a second copy of availableMemory, and two things that must agree is how
;		this codebase keeps hurting itself.
;
;		Measured against the ROM, 2026-08-02 (x16emu r49): stock X16 FRE returns a POSITIVE byte
;		count with no C64-style wrap above 32767 -- a 7-line program reported 38537 -- and the
;		argument is ignored, FRE(1) = FRE(0). A positive count is therefore right; the number
;		itself cannot match stock, because GPC has no BASIC program text in the way and lays its
;		scalars out at a fixed offset instead of allocating them from the same pool.
;
;		The two ends cannot cross, so this cannot underflow: DIMWriteByte refuses to let the
;		arrays reach the string ceiling's page, and StringConcrete refuses to bring the ceiling
;		below availableMemory. Equal is legal and returns 0.
;
UnaryFre:	;; [fre]
		.entercmd

		jsr 	FloatSetZero 				; zero the result (32 bit integer)
		sec
		lda 	stringHighMemory 			; free = string floor - top of the arrays
		sbc 	availableMemory
		sta		NSMantissa0,x
		lda 	stringHighMemory+1
		sbc 	availableMemory+1
		sta		NSMantissa1,x

		.exitcmd

		.send 	code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		02/08/26		Subtract availableMemory, not the never-written stringLowMemory. FRE was
;						returning the string ceiling's address instead of a byte count.
;
; ************************************************************************************************
