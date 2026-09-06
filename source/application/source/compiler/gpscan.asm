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
;		finished p-code it asks whether that opcode's handler lives at or above GPBase. That is
;		precisely the property being relied on -- "does this instruction jump into the bytes I
;		am about to discard?" -- so it cannot drift: move a handler into or out of gp-runtime/
;		and this follows it with no list to update. A token-number range check would have needed
;		the GP opcodes renumbered contiguously (an RT_ABI bump and a forced recompile of every
;		shared-mode program), and a "keyword starts with GP." check would have been a naming
;		convention pretending to be an invariant.
;
;		IT READS A BITMAP RATHER THAN THE VECTOR TABLE, and that is the only thing that changed
;		when the runtime became a separate file. It used to do the comparison itself --
;		"lda VectorTable+1,y : cmp #GPBase >> 8" -- which needed the runtime's table resident,
;		and the runtime is on disk now. But it never wanted the address, only one bit of it, so
;		genrtimage.py does the comparison against the image's own linked table at build time and
;		emits GPUsageBits. Same question, same answer, asked of 32 bytes instead of 386.
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
		cmp 	#$FF 						; the end marker, and it must be tested BEFORE the
		beq 	_GPSDone 					; lookup: $FF is not an opcode at all
		cmp 	#PCD_ENDSYSTEM+1 			; nothing above the last system token is a real opcode
		bcs 	_GPSNext 					; (defensive -- the walk should never produce one)
		cmp 	#PCD_STARTSYSTEM 			; the .shift prefix -- a two byte token, the one that
		beq 	_GPSShifted 				; matters is the byte after it
		cmp 	#PCD_STARTBINARY 			; below $80 is a variable or literal reference, which
		bcc 	_GPSNext 					; has no vector slot at all
		ldx 	#0 							; VectorTable half of the map
		bra 	_GPSCheck
_GPSShifted:
		ldy 	#1
		lda 	(objPtr),y 					; the shifted token
		ldx 	#1 							; ShiftVectorTable half likewise
_GPSCheck:
		jsr 	GPScanUsesGP 					; carry set if this opcode's handler is above the cut
		bcc 	_GPSNext
		lda 	#1
		sta 	gpUsed
		bra 	_GPSDone 					; one is enough -- nothing later can un-use it
_GPSNext:
		jsr 	MoveObjectForward
		bcc 	_GPSLoop
		jsr 	GPBankHop 					; a GP.BANKED region is past the GP.ASM pool, so the
		bcc 	_GPSLoop 					; walk leaves low memory and carries on there. Its
_GPSDone: 									; keywords count exactly like any other.
		lda 	gpScanEnd 					; put objPtr back
		sta 	objPtr
		lda 	gpScanEnd+1
		sta 	objPtr+1
		rts

;
;		A = token ($80..$FF), X = 0 for the plain table / 1 for the shifted one. Returns carry
;		set if that opcode's handler is at or above GPBase.
;
;		GPUsageBits is 32 bytes: 16 for the plain vectors, then 16 for the shifted, one bit per
;		opcode, bit set meaning "above the cut". The index is the token with bit 7 cleared,
;		which is exactly what the tables themselves are indexed by.
;
GPScanUsesGP:
		pha
		and 	#$7F 						; opcode index, 0..127
		lsr 	a
		lsr 	a
		lsr 	a 							; -> which byte of the map, 0..15
		cpx 	#0
		beq 	_GPSUPlain
		clc
		adc 	#16 						; the shifted half is the second 16 bytes
_GPSUPlain:
		tay
		lda 	GPUsageBits,y
		sta 	gpBits
		pla
		and 	#$07 						; -> which bit of that byte
		tax
		lda 	gpBits
_GPSUShift:
		cpx 	#0
		beq 	_GPSUTest
		lsr 	a
		dex
		bra 	_GPSUShift
_GPSUTest:
		lsr 	a 							; the wanted bit falls into the carry
		rts

gpUsed: 									; nonzero if any GP handler is reachable. Code section,
		.fill 	1 							; not storage -- it belongs to the compiler and is
gpScanEnd: 									; thrown away with it, so it costs a compiled program
		.fill 	2 							; nothing. See the note in file-io/read.asm.
gpBits:
		.fill 	1

; ************************************************************************************************
;
;		THE SAME QUESTION, ANSWERED AS THE BYTES GO PAST.
;
;		The walk above needs a finished object to read, and pass one is about to stop storing
;		one. The answer is wanted before pass two starts, too, because it says how much of the
;		runtime goes into the file and therefore where the object code lands -- so it cannot
;		wait for the object to exist.
;
;		SAME BITMAP, SAME INSTRUCTION SIZES, STILL THE FINISHED CODE. What changes is that the
;		p-code is decoded FORWARDS, a byte at a time, instead of being stepped over with
;		MoveObjectForward. It is still reading what was emitted rather than hooking the two
;		places tokens are emitted from, which is what makes it total: the next hand-written GP
;		command cannot opt itself out of it.
;
;		THE STATE SAYS WHAT THE NEXT BYTE IS -- an opcode, the token after a .shift, the length
;		of a .string or .data, or an operand to be stepped over. Only pass one runs it: pass two
;		writes the same bytes and counting them twice would prove nothing.
;
;		THE CURSOR IS CHECKED, NOT ASSUMED. A statement that fails to compile is rolled back to
;		where it began and the next one is written over it (DeferStatementToRuntime). That start
;		is an instruction boundary, so a write cursor that did not move on by one means "begin
;		again here" -- which is exactly right, and needs nothing to tell it.
;
; ************************************************************************************************

GPS_OPCODE = 0 								; the next byte is an opcode
GPS_SHIFT  = 1 								; ...the token after a .shift prefix
GPS_LENGTH = 2 								; ...the length byte of a .string or .data
GPS_SKIP   = 3 								; ...one of gpScanSkip operand bytes

GPScanReset:
		stz 	gpStreamUsed
		stz 	gpScanState
		stz 	gpScanStop
		.set16 	gpScanAt,FreeMemory
		rts

GPScanByte:
		ldx 	passNumber 					; pass one settles it
		bne 	_GPSBOut
		ldx 	gpScanStop 					; ...and stops at the end marker, or as soon as the
		bne 	_GPSBOut 					; answer is yes
		pha
		lda 	objPtr 						; in step with the byte before it ?
		cmp 	gpScanAt
		bne 	_GPSBResync
		lda 	objPtr+1
		cmp 	gpScanAt+1
		beq 	_GPSBInStep
_GPSBResync:
		stz 	gpScanState 				; no -- a rolled back statement, so start again here
_GPSBInStep:
		clc
		lda 	objPtr
		adc 	#1
		sta 	gpScanAt
		lda 	objPtr+1
		adc 	#0
		sta 	gpScanAt+1
		pla
		;
		ldx 	gpScanState
		beq 	_GPSBOpcode
		cpx 	#GPS_SHIFT
		beq 	_GPSBShifted
		cpx 	#GPS_LENGTH
		beq 	_GPSBLength
		dec 	gpScanSkip 					; GPS_SKIP: one operand byte gone
		bne 	_GPSBOut
		stz 	gpScanState
_GPSBOut:
		rts
;
;		The token after a .shift. MOFSizeTable gives .shift a size of one, which is this byte,
;		so the next one is an opcode again.
;
_GPSBShifted:
		stz 	gpScanState
		ldx 	#1 							; the ShiftVectorTable half of the map
		jsr 	GPScanUsesGP
		bcc 	_GPSBOut
		bra 	_GPSBFound
;
;		The length byte of a .string or .data. A zero length leaves the next byte an opcode.
;
_GPSBLength:
		sta 	gpScanSkip
		ldx 	#GPS_SKIP
		cmp 	#0
		bne 	_GPSBState
		ldx 	#GPS_OPCODE
_GPSBState:
		stx 	gpScanState
		rts
;
;		An opcode. The ranges are MoveObjectForward's, so the two step by the same sizes, and
;		which of them has a vector slot is ScanGPUsage's question above.
;
_GPSBOpcode:
		cmp 	#$FF 						; the end marker: the GP.ASM pool and the relocator's
		beq 	_GPSBStop 					; padding follow it and are not p-code at all
		cmp 	#$40
		bcc 	_GPSBOut 					; 00-3F: one byte, no vector slot
		cmp 	#$70
		bcc 	_GPSBOne 					; 40-6F: two bytes, no vector slot
		cmp 	#PCD_STARTBINARY
		bcc 	_GPSBOut 					; 70-7F: one byte, no vector slot
		cmp 	#PCD_STARTSYSTEM
		bcc 	_GPSBKeyword 				; 80-DC: a keyword, one byte, and it has one
		bne 	_GPSBSystem
		lda 	#GPS_SHIFT 					; DD: the token after it is the one that matters
		sta 	gpScanState
		rts

_GPSBOne:
		lda 	#1
		sta 	gpScanSkip
		lda 	#GPS_SKIP
		sta 	gpScanState
		rts

_GPSBKeyword:
		ldx 	#0 							; the VectorTable half of the map
		jsr 	GPScanUsesGP
		bcs 	_GPSBFound
		rts
;
;		DE and up: a system token, whose operand count is the table MoveObjectForward steps by.
;		255 there means a .string or .data, and the byte after the token is its length.
;
_GPSBSystem:
		pha
		cmp 	#PCD_ENDSYSTEM+1 			; defensive, exactly as the walk is: nothing above the
		bcs 	_GPSBSized 					; last system token has a vector slot
		ldx 	#0
		jsr 	GPScanUsesGP
		bcc 	_GPSBSized
		pla
		bra 	_GPSBFound
_GPSBSized:
		pla
		tay
		lda 	MOFSizeTable-PCD_STARTSYSTEM,y
		cmp 	#$FF
		beq 	_GPSBString
		tax 								; .deferror has no operand at all
		beq 	_GPSBOutFar
		sta 	gpScanSkip
		lda 	#GPS_SKIP
		sta 	gpScanState
		rts
_GPSBString:
		lda 	#GPS_LENGTH
		sta 	gpScanState
_GPSBOutFar:
		rts
;
;		Found one, so the answer is yes and nothing later can change it -- the same reasoning
;		the walk makes when it stops at the first hit.
;
_GPSBFound:
		lda 	#1
		sta 	gpStreamUsed
_GPSBStop:
		lda 	#1
		sta 	gpScanStop
		stz 	gpScanState
		rts

gpStreamUsed: 								; the emit-time answer, which gpUsed is checked against
		.fill 	1 							; for as long as there is an object left to walk
gpScanState: 								; what the NEXT byte is
		.fill 	1
gpScanSkip: 								; ...and how many operand bytes are still to go past
		.fill 	1
gpScanAt: 									; where the next byte belongs, so a statement rolled
		.fill 	2 							; back can be noticed for what it is
gpScanStop: 								; nonzero once the answer is in, or the end marker seen
		.fill 	1

		.send code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		30/08/26		Vector table read replaced by the generated GPUsageBits bitmap, so the
;						runtime image no longer has to be resident to answer the question.
;
; ************************************************************************************************
