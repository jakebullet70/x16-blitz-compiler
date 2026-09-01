; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gparrptr.asm
;		Purpose:	GP.ARRPTR -- the address of an array's element zero
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
;		This was gpsort.asm, and GP.SORT was the bulk of it. The sort left the GP block on
;		1st September 2026 and is GPC-BASIC/SORT.INC.BL now -- the same shell sort, the same
;		Ciura gaps, written in GP.ASM -- because the block is all or nothing and 408 of its
;		bytes were a sort that most programs never call. What is left is the 49 bytes that
;		hand an array's address over, which is what the module is built on: a BASL subroutine
;		cannot be passed an array.
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;						GP.ARRPTR(a()) -> the address of element ZERO
;
;		The escape hatch. It is for the jobs too specific to ever be keywords -- sprite
;		batching, array fill, checksum, min/max -- which can be written once as machine code
;		and driven with GP.CALL, or with a GP.ASM block, instead of each having to become its
;		own keyword or not exist. GP.SORT is now the first and largest example of exactly that.
;
;		It is AnyArrayCompile's path with the value RETURNED rather than consumed.
;
;		Returns base + variableStartPage*256 + 3, skipping the 3-byte header, so the answer is
;		element zero and not the count word. THE HEADER IS STILL THERE and is worth knowing
;		about: count low, count high, then the type byte, at -3, -2 and -1. SORT.INC.BL reads
;		its element count and rejects a float array from exactly those three bytes.
;
;		Stride is the caller's business: 2 bytes for a string (a pointer to its block) and 6
;		for a number.
;
;		Multi-dimensional arrays are REJECTED, because the elements are not a flat run -- they
;		are pointers to sub-levels, so an address into one would be used as data and corrupt
;		silently.
;
;		A subscript inside the parentheses is a syntax error by construction: AnyArrayCompile
;		demands the ")" immediately. GP.ARRPTR(A(3)) does not compile -- add 3*stride yourself.
;
;		SAME WARNING AS GP.STRPTR: the address routinely exceeds 32767, and BASIC's AND is 16-bit
;		SIGNED, so splitting it with "P AND 255" raises OUT OF RANGE. Use GP.HIBYTE / GP.LOBYTE,
;		or the long form H = INT(P/256) : L = P - H*256.
;
; ************************************************************************************************

UnaryGPArrPtr: ;; [!gp.arrptr]
		.entercmd
		phy
		lda 	NSMantissa0,x 				; the base arrives as an OFFSET, so the high byte
		sta 	zTemp0 						; needs variableStartPage adding to make it real
		lda 	NSMantissa1,x
		clc
		adc 	variableStartPage
		sta 	zTemp0+1
		;
		ldy 	#2 							; bit 7 of the type byte = sub-arrays below this level
		lda 	(zTemp0),y
		bmi 	_GAPBad
		;
		clc 								; step over the 3-byte header to element zero
		lda 	zTemp0
		adc 	#3
		sta 	NSMantissa0,x
		lda 	zTemp0+1
		adc 	#0
		sta 	NSMantissa1,x
		stz 	NSMantissa2,x 				; and retype it from an int16 reference to a plain
		stz 	NSMantissa3,x 				; number, exactly as GP.STRPTR does
		stz 	NSExponent,x
		stz 	NSStatus,x 					; NSSIFloat is $00, so this also clears the sign
		ply
		.exitcmd

_GAPBad:
		ply 								; code pointer back before raising, or the address in
		.error_index 						; the message is a fixed meaningless one

		.send 	code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		17/08/26		Written, as gpsort.asm.
;		01/09/26		GP.SORT moved out of the block into GPC-BASIC/SORT.INC.BL. The file is
;						renamed for what is left of it, and the 15 bytes of gps* storage that
;						sat below $0801 went with the sort.
;
; ************************************************************************************************
