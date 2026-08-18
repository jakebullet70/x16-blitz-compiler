; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpscan.asm
;		Purpose:	Decide whether the compiled program uses any GP.BASIC handler.
;		Created:	18th August 2026
;
; ************************************************************************************************
; ************************************************************************************************
;
;		The GP handlers are the last thing in the runtime image, from GPBase to ObjectBase. If
;		the program never reaches any of them the whole block can be left out of the object --
;		see WriteObjectCode. This decides which.
;
;		IT ASKS THE QUESTION BY ADDRESS, NOT BY NAME OR BY TOKEN NUMBER. For each opcode in the
;		finished p-code it reads that opcode's VectorTable slot and compares the handler address
;		against GPBase. That is precisely the property being relied on -- "does this instruction
;		jump into the bytes I am about to discard?" -- so it cannot drift: move a handler into
;		or out of gp-runtime/ and this follows it with no list to update. A token-number range
;		check would have needed the GP opcodes renumbered contiguously (an RT_ABI bump and a
;		forced recompile of every shared-mode program), and a "keyword starts with GP." check
;		would have been a naming convention pretending to be an invariant.
;
;		IT SCANS THE P-CODE RATHER THAN HOOKING THE EMITTER, which is what makes it total.
;		Tokens reach the object from two places -- the generator's T action for most keywords,
;		and hand-written X: helpers for the five that carry inline branch offsets (GP.EXITDO and
;		the four GP.SELECT commands, which cannot use T at all). Hooking emission means hooking
;		both, and means the next hand-written GP command silently opts itself out of the check.
;		Reading the finished code has one site and no way to miss anything.
;
;		MoveObjectForward is what makes the walk safe: it steps by real instruction size, so an
;		operand byte that happens to equal a GP opcode is never read as one. Same reason
;		FixBranches uses it.
;
;		WHY IT LIVES IN THE APPLICATION and not beside FixBranches in compiler.library: it
;		references VectorTable and GPBase, which are runtime symbols. compiler.library is linked
;		WITHOUT the runtime by source/unit-tests/compiler-runtime, and putting this there would
;		have broken that build with two undefined symbols.
;
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		Set gpUsed nonzero if the object code at FreeMemory..objPtr reaches any handler at or
;		above GPBase. Preserves objPtr.
;
; ************************************************************************************************

ScanGPUsage:
		stz 	gpUsed
		lda 	objPtr 						; the walk destroys objPtr, and WriteObjectCode still
		sta 	gpScanEnd 					; needs it as the end of the object code
		lda 	objPtr+1
		sta 	gpScanEnd+1
		.set16 	objPtr,FreeMemory
_GPSLoop:
		lda 	(objPtr) 					; the opcode
		cmp 	#$FF 						; the end marker, and it must be tested BEFORE the vector
		beq 	_GPSDone 					; lookup: $FF indexes 127 entries past a 109 entry table
		cmp 	#PCD_ENDSYSTEM+1 			; nothing above the last system token is a real opcode
		bcs 	_GPSNext 					; (defensive -- the walk should never produce one)
		cmp 	#PCD_STARTSYSTEM 			; $DB is .shift -- a two byte token, the one that
		beq 	_GPSShifted 				; matters is the byte after it
		cmp 	#PCD_STARTBINARY 			; below $80 is a variable or literal reference, which
		bcc 	_GPSNext 					; has no vector slot at all
		ldx 	#0 							; VectorTable, indexed from $80
		bra 	_GPSCheck
_GPSShifted:
		ldy 	#1
		lda 	(objPtr),y 					; the shifted token
		ldx 	#1 							; ShiftVectorTable, indexed from $80 likewise
_GPSCheck:
		jsr 	_GPSHandlerHigh 			; A = high byte of this opcode's handler address
		cmp 	#GPBase >> 8
		bcc 	_GPSNext 					; below the cut, so it survives the truncation
		lda 	#1
		sta 	gpUsed
		bra 	_GPSDone 					; one is enough -- nothing later can un-use it
_GPSNext:
		jsr 	MoveObjectForward
		bcc 	_GPSLoop
_GPSDone:
		lda 	gpScanEnd 					; put objPtr back
		sta 	objPtr
		lda 	gpScanEnd+1
		sta 	objPtr+1
		rts

;
;		A = token ($80..$FF), X = 0 for VectorTable / 1 for ShiftVectorTable. Returns the HIGH
;		byte of the handler address in A, which is all the comparison needs -- GPBase is page
;		aligned, so a high-byte compare is exact rather than approximate.
;
_GPSHandlerHigh:
		asl 	a 							; (token-$80)*2, and the -$80 falls out of the shift:
		tay 								; $80..$FF doubled is $100..$1FE, and the carry out is
		cpx 	#0 							; the +$100 we would otherwise subtract back off
		bne 	_GPSHShifted
		lda 	VectorTable+1,y
		rts
_GPSHShifted:
		lda 	ShiftVectorTable+1,y
		rts

gpUsed: 									; nonzero if any GP handler is reachable. Code section,
		.fill 	1 							; not storage -- it belongs to the compiler and is
gpScanEnd: 									; thrown away with it, so it costs a compiled program
		.fill 	2 							; nothing. See the note in file-io/read.asm.

		.send code

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
