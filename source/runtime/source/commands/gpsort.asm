; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpsort.asm
;		Purpose:	GP.SORT -- shell sort a string array in place
;		Created:	17th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;					GP.SORT a$() [,descending] [,foldcase]  -- sort in place
;
;		The reason this is worth assembly when GP.INSTR's helpers were not: it moves POINTERS.
;		A string variable or array element holds a 2-byte address of its [MaxLen][Ctrl][Len][Data]
;		block, so exchanging two elements is a 2-byte swap whatever the strings are -- no
;		temporary, no copying, no heap traffic, O(1) per swap regardless of length. The same sort
;		in BASIC would allocate a temporary string per comparison AND per swap.
;
;		SHELL SORT with halving gaps. Chosen over the alternatives for what it does NOT need:
;		no recursion and no stack (quicksort needs both, and the frame stack here is a fixed 4K),
;		no worst case blow-up on already-sorted input, and no scratch array (merge sort needs one,
;		and there is nowhere to put it). About n^1.3 on real data against bubble sort's n^2.
;
;		<descending> and <foldcase> are optional and default to 0 = ascending, case-sensitive.
;		Both are compared against zero only, so any non-zero value means "yes".
;
;		LIMIT: 255 elements. Beyond that .error_range, because a 16-bit index would grow every
;		address calculation in the inner loop to serve a case that does not arise on this machine.
;		Note DIM A$(255) is 256 elements and so is one too many -- DIM A$(254) is the largest.
;
; ************************************************************************************************

CommandGPSort: ;; [!gp.sort]
		.entercmd
		phy 								; Y is the code pointer offset
		;
		jsr 	FloatIntegerPart 			; <foldcase>, pushed last
		lda 	NSMantissa0,x
		sta 	gpsFold
		dex
		jsr 	FloatIntegerPart 			; <descending>
		lda 	NSMantissa0,x
		sta 	gpsDesc
		dex
		;
		;		The array base arrives as an OFFSET, exactly as ArrayConvert1 receives it, so the
		;		high byte needs variableStartPage adding to make it a real address.
		;
		;		gpsArray lives in MemoryStorage, NOT zero page, so it can be READ absolutely but
		;		can never be the pointer in a (ptr),y. The header reads below therefore go through
		;		zTemp0, which is the same copy GPSortElementY rebuilds for every element anyway.
		;
		lda 	NSMantissa0,x
		sta 	gpsArray
		sta 	zTemp0
		lda 	NSMantissa1,x
		clc
		adc 	variableStartPage
		sta 	gpsArray+1
		sta 	zTemp0+1
		dex 								; consumed -- this is a statement, not a function
		;
		ldy 	#2 							; the type byte
		lda 	(zTemp0),y
		bmi 	_GSBadArrayNear 			; bit 7 = this level holds sub-arrays, so 2-D or worse
		and 	#NSSTypeMask
		cmp 	#NSSString
		bne 	_GSBadArrayNear 			; a float array's elements are 6 bytes, not 2
		;
		ldy 	#1 							; count high byte
		lda 	(zTemp0),y
		beq 	_GSCountOk
_GSTooBigNear:
		jmp 	_GSTooBig 					; 256 or more elements
_GSBadArrayNear:
		jmp 	_GSBadArray 				; both errors are a long way below, so trampoline
_GSCountOk:
		lda 	(zTemp0)
		sta 	gpsCount
		cmp 	#2
		bcs 	_GSBigEnough
		jmp 	_GSDone 					; 0 or 1 elements is already sorted
_GSBigEnough:
		;
		;		Step the base past the 3-byte header so element i is at gpsArray + i*2.
		;
		clc
		lda 	gpsArray
		adc 	#3
		sta 	gpsArray
		bcc 	_GSHaveBase
		inc 	gpsArray+1
_GSHaveBase:
		;
		;		The gap sequence is a fixed TABLE, not the halving one Shell published in 1959.
		;		Halving is the weakest of the known sequences -- worst case n^2 -- and 132/57/23/
		;		10/4/1 is Ciura's, empirically the best for arrays this size at roughly n^1.25.
		;		Taken from prog8's sorting.p8, which uses exactly these six.
		;
		;		Gaps larger than the array need no special case: the outer loop starts i AT the
		;		gap and exits immediately when that is already past the end.
		;
		stz 	gpsGapIdx
_GSGapLoop:
		ldy 	gpsGapIdx
		cpy 	#GPSortGapEnd-GPSortGaps
		bcc 	_GSGapOk
		jmp 	_GSDone
_GSGapOk:
		inc 	gpsGapIdx
		lda 	GPSortGaps,y
		sta 	gpsGap
		;
		;		for i = gap to count-1
		;
		sta 	gpsI
_GSOuter:
		lda 	gpsI
		cmp 	gpsCount
		bcs 	_GSNextGap
		;
		;		temp = a[i], j = i
		;
		ldy 	gpsI
		jsr 	GPSortElementY 				; -> zTemp0 = &a[i]
		lda 	(zTemp0)
		sta 	gpsTemp
		ldy 	#1
		lda 	(zTemp0),y
		sta 	gpsTemp+1
		lda 	gpsI
		sta 	gpsJ
		;
		;		while j >= gap and a[j-gap] sorts after temp:  a[j] = a[j-gap] ; j -= gap
		;
_GSInner:
		lda 	gpsJ
		cmp 	gpsGap
		bcc 	_GSPlace 					; j < gap, so there is nothing below to compare
		sec
		sbc 	gpsGap
		tay 								; Y = j - gap
		jsr 	GPSortElementY 				; -> zTemp0 = &a[j-gap]
		;
		lda 	(zTemp0) 					; that element -> zTemp1, the left operand
		sta 	zTemp1
		ldy 	#1
		lda 	(zTemp0),y
		sta 	zTemp1+1
		lda 	gpsTemp 					; temp -> zTemp2, the right operand
		sta 	zTemp2
		lda 	gpsTemp+1
		sta 	zTemp2+1
		jsr 	GPSortCompare 				; A = $FF, 0 or 1
		;
		ldy 	gpsDesc 					; descending flips the sense of the answer. Test it in
		beq 	_GSTestOrder 				; Y -- A holds the result and must survive
		eor 	#$FF 						; negate: 1 <-> $FF, 0 unchanged
		inc 	a
_GSTestOrder:
		cmp 	#1 							; "sorts after" is the only case that shifts
		bne 	_GSPlace
		;
		;		Shift a[j-gap] up into a[j], then step j down by gap.
		;
		ldy 	gpsJ
		jsr 	GPSortElementY 				; -> zTemp0 = &a[j]
		lda 	zTemp1
		sta 	(zTemp0)
		ldy 	#1
		lda 	zTemp1+1
		sta 	(zTemp0),y
		;
		lda 	gpsJ
		sec
		sbc 	gpsGap
		sta 	gpsJ
		bra 	_GSInner
_GSPlace:
		ldy 	gpsJ 						; a[j] = temp
		jsr 	GPSortElementY
		lda 	gpsTemp
		sta 	(zTemp0)
		ldy 	#1
		lda 	gpsTemp+1
		sta 	(zTemp0),y
		;
		inc 	gpsI
		jmp 	_GSOuter 					; the inner loop is longer than a bra can reach back

_GSNextGap:
		jmp 	_GSGapLoop 					; on to the next gap in the table

_GSDone:
		ply
		.exitcmd

_GSBadArray:
		ply 								; restore the code pointer BEFORE raising, or the
		.error_index 						; "@ $xxxx" is a fixed meaningless address
_GSTooBig:
		ply
		.error_range

; ************************************************************************************************
;
;		zTemp0 = the address of element Y (Y = index, 0..254). Clobbers A and Y.
;
; ************************************************************************************************

GPSortGaps:
		.byte 	132, 57, 23, 10, 4, 1
GPSortGapEnd:

GPSortElementY:
		tya
		asl 	a 							; index * 2 -- and the carry OUT of this is bit 8 of the
		sta 	zTemp0 						; result, which must be kept. From element 128 upward
		lda 	#0 							; the doubled index no longer fits a byte, and throwing
		rol 	a 							; that bit away puts every such element 256 bytes low.
		clc
		adc 	gpsArray+1
		sta 	zTemp0+1
		clc
		lda 	zTemp0
		adc 	gpsArray
		sta 	zTemp0
		bcc 	_GSEYDone
		inc 	zTemp0+1
_GSEYDone:
		ldy 	#0
		rts

; ************************************************************************************************
;
;		Compare the string blocks at zTemp1 and zTemp2, returning $FF / 0 / 1 in A as
;		CompareStrings does. Folds case when gpsFold is non-zero.
;
;		A NULL POINTER IS AN EMPTY STRING, and that is the trap this whole command turns on. A
;		never-assigned element is $0000 -- ReadStringZTemp0Sub hands out a static empty string for
;		exactly that case -- so without this a DIM A$(20) with five entries filled would compare
;		against whatever happens to live at address 2 and scribble the array into sorted order
;		based on it.
;
;		The blocks are [MaxLen][Ctrl][Len][Data], so the length is at +2 and the text starts at +3.
;
; ************************************************************************************************

GPSortCompare:
		lda 	zTemp1+1 					; left length, or zero if the pointer is null
		beq 	_GSCLeftNull
		ldy 	#2
		lda 	(zTemp1),y
		bra 	_GSCHaveLeft
_GSCLeftNull:
		lda 	#0
_GSCHaveLeft:
		sta 	gpsLenL
		;
		lda 	zTemp2+1 					; right length
		beq 	_GSCRightNull
		ldy 	#2
		lda 	(zTemp2),y
		bra 	_GSCHaveRight
_GSCRightNull:
		lda 	#0
_GSCHaveRight:
		sta 	gpsLenR
		;
		cmp 	gpsLenL 					; compare min(lenL,lenR) characters
		bcs 	_GSCUseLeft
		bra 	_GSCHaveCount
_GSCUseLeft:
		lda 	gpsLenL
_GSCHaveCount:
		sta 	gpsRun
		beq 	_GSCLengths 				; one of them is empty, so length decides
		;
		ldy 	#2 							; +3 is the first character, so pre-increment from 2
_GSCLoop:
		iny
		lda 	(zTemp2),y 					; right character first, so A holds the LEFT one at
		jsr 	GPSortFold 					; the compare and the carry means what it does in
		sta 	gpsChar 					; CompareStrings
		lda 	(zTemp1),y
		jsr 	GPSortFold
		cmp 	gpsChar
		bne 	_GSCDiffer
		dec 	gpsRun
		bne 	_GSCLoop
_GSCLengths:
		sec
		lda 	gpsLenL
		sbc 	gpsLenR
		beq 	_GSCSame
_GSCDiffer:
		lda 	#$FF
		bcc 	_GSCExit
		lda 	#$01
_GSCExit:
		rts
_GSCSame:
		lda 	#0
		rts

;
;		A -> upper case if gpsFold says so and it is a lower case letter.
;
GPSortFold:
		pha 								; Y is the string index and X is the number stack
		lda 	gpsFold 					; pointer, so the flag can only be tested through A
		beq 	_GSFNo
		pla
		cmp 	#'a'
		bcc 	_GSFOut
		cmp 	#'z'+1
		bcs 	_GSFOut
		and 	#$DF
_GSFOut:
		rts
_GSFNo:
		pla
		rts

; ************************************************************************************************
;
;						GP.ARRPTR(a()) -> the address of element ZERO
;
;		The escape hatch. GP.SORT is the built-in for a job common enough to be worth doing
;		properly in assembly; this is for the jobs too specific to ever be keywords -- sprite
;		batching, array fill, checksum, min/max -- which can now be written once as machine code
;		and driven with GP.CALL instead of each having to become its own keyword or not exist.
;
;		It is StringArrayCompile's path with the element-type check dropped (a float array is
;		just as valid a target) and the value RETURNED rather than consumed.
;
;		Returns base + variableStartPage*256 + 3, skipping the 3-byte header, so the answer is
;		element zero and not the count word. Stride is the caller's business: 2 bytes for a
;		string (a pointer to its block) and 6 for a number.
;
;		Multi-dimensional arrays are REJECTED, exactly as GP.SORT rejects them and for the same
;		reason -- the elements are not a flat run, they are pointers to sub-levels, so an address
;		into one would be used as data and corrupt silently.
;
;		A subscript inside the parentheses is a syntax error by construction: AnyArrayCompile
;		demands the ")" immediately. GP.ARRPTR(A(3)) does not compile -- add 3*stride yourself.
;
;		SAME WARNING AS GP.STRPTR: the address routinely exceeds 32767, and BASIC's AND is 16-bit
;		SIGNED, so splitting it with "P AND 255" raises OUT OF RANGE. Use
;		H = INT(P/256) : L = P - H*256.
;
; ************************************************************************************************

UnaryGPArrPtr: ;; [!gp.arrptr]
		.entercmd
		phy
		lda 	NSMantissa0,x 				; the base arrives as an offset, as GP.SORT receives it
		sta 	zTemp0
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

		.section storage
gpsArray:									; base of the element data (header already skipped)
		.fill 	2
gpsTemp: 									; the element being placed this pass
		.fill 	2
gpsCount: 									; how many elements
		.fill 	1
gpsGap: 									; current shell sort gap
		.fill 	1
gpsGapIdx: 									; how far into GPSortGaps we are
		.fill 	1
gpsI: 										; outer index
		.fill 	1
gpsJ: 										; inner index
		.fill 	1
gpsDesc: 									; non-zero = descending
		.fill 	1
gpsFold: 									; non-zero = ignore case
		.fill 	1
gpsLenL:									; the two lengths being compared
		.fill 	1
gpsLenR:
		.fill 	1
gpsRun: 									; characters still to compare
		.fill 	1
gpsChar: 									; folded right-hand character
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
;		17/08/26		Written.
;
; ************************************************************************************************
