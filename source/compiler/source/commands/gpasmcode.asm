; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpasmcode.asm
;		Purpose:	The GP.ASM assembler, and the lowering it emits.
;		Created:	30th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;		THE LOWERING, AND WHY IT COSTS NO RUNTIME BYTES.
;
;		A block assembles to five bytes of p-code and nothing else:
;
;			$DF lo hi		.word  <- the blob's absolute run address
;			$DD $B0			.shift + sys
;
;		SYS already IS the primitive this feature needs -- it saves X and Y, marshals the
;		registers through $030C-$030F, calls through an indirect and comes back. Its handler,
;		and .word's, are both far below GPBase, so a program whose only GP.BASIC keyword is
;		GP.ASM never drags in the 2K GP runtime block. Measured: such a program compiles
;		GP OUT at RT 12031, exactly what a program with no GP keyword at all costs.
;
;		THE BLOBS THEMSELVES GO IN A POOL APPENDED AFTER THE $FF END MARKER. Nothing walks
;		there: MoveObjectForward returns carry set on $FF, and FixBranches, ScanGPUsage and
;		ReadLookNext all stop on it. So the pool needs no length byte, no carrier opcode and
;		no framing -- and therefore has none of the 127-byte-per-block cap a carried payload
;		would have had.
;
;		The price is the ONE genuinely new thing here: .word's operand is an ABSOLUTE address,
;		the first position-dependent operand in this p-code. Branches are offsets, .string is
;		codePtr relative and .varspace is workspace relative; this is not. It cannot be
;		computed while the statement compiles either, because the object's run base is not
;		known until ScanGPUsage has decided whether the GP block is cut. So each one is
;		recorded as a fixup and patched into the object buffer inside WriteObjectCode, where
;		runtimeEndPage (or PCODE_PAGE, shared) is finally known. All of that is compiler work,
;		which costs a compiled program nothing.
;
; ************************************************************************************************

ASM_POOL_SIZE = 1024 						; total assembled bytes across the whole program
ASM_MAX_BLOCKS = 32 						; GP.ASM blocks in one program

;
;		Operand syntax classes -- what the text LOOKED like, before the mnemonic gets a say in
;		which addressing mode that turns into.
;
ASYN_NONE = 0 								; nothing, or a bare A
ASYN_IMM  = 1 								; #n
ASYN_ABS  = 2 								; n
ASYN_ABSX = 3 								; n,X
ASYN_ABSY = 4 								; n,Y
ASYN_IND  = 5 								; (n)
ASYN_INDX = 6 								; (n,X)
ASYN_INDY = 7 								; (n),Y

; ************************************************************************************************
;
;		Start a block: remember where in the pool its blob begins.
;
; ************************************************************************************************

AsmOpenBlock:
		lda 	AsmPoolLen
		sta 	AsmBlobStart
		lda 	AsmPoolLen+1
		sta 	AsmBlobStart+1
		rts

; ************************************************************************************************
;
;		Close a block: cap the blob with an RTS and emit the five bytes of p-code that call it.
;
;		THE RTS IS ALWAYS APPENDED, even when the last instruction was already one. SYS enters
;		the blob with a JSR, so a blob that falls off its own end returns to wherever the stack
;		happens to point and takes the machine with it. One byte to make that impossible is the
;		right trade; a blob ending in JMP just carries an unreachable RTS after it.
;
; ************************************************************************************************

AsmCloseBlock:
		lda 	#$60 						; RTS
		jsr 	AsmPoolWrite

		lda 	AsmFixupCount 				; room for another block ?
		cmp 	#ASM_MAX_BLOCKS
		bcs 	_ACBTooMany
		asl 	a 							; 4 bytes per fixup
		asl 	a
		tax
		lda 	AsmBlobStart 				; where this blob starts in the pool
		sta 	AsmFixups+2,x
		lda 	AsmBlobStart+1
		sta 	AsmFixups+3,x

		lda 	#PCD_CMD_WORD 				; .word <blob address>
		jsr 	WriteCodeByte
		;
		;		Capture where the operand lands BEFORE writing it -- objPtr is the write cursor,
		;		so this IS the address of the low byte, in the buffer, right now. Absolute and
		;		not an offset, because FreeMemory is an application symbol and this library is
		;		also built on its own. WriteCodeByte preserves X, so the fixup index survives
		;		the calls around it.
		;
		lda 	objPtr
		sta 	AsmFixups+0,x
		lda 	objPtr+1
		sta 	AsmFixups+1,x
		lda 	#0 							; two placeholders, overwritten by AsmPatchBlobs
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte

		.keyword PCD_SYS 					; $DD $B0 -- call it
		inc 	AsmFixupCount
		rts

_ACBTooMany:
		.error_memory

; ************************************************************************************************
;
;		Append A to the blob pool.
;
; ************************************************************************************************

AsmPoolWrite:
		pha
		lda 	AsmPoolLen+1 				; full ?
		cmp 	#ASM_POOL_SIZE >> 8
		bcc 	_APWSpace
		lda 	AsmPoolLen
		cmp 	#ASM_POOL_SIZE & $FF
		bcs 	_APWFull
_APWSpace:
		clc
		lda 	#AsmPool & $FF
		adc 	AsmPoolLen
		sta 	zTemp2
		lda 	#AsmPool >> 8
		adc 	AsmPoolLen+1
		sta 	zTemp2+1
		pla
		sta 	(zTemp2)
		inc 	AsmPoolLen
		bne 	_APWDone
		inc 	AsmPoolLen+1
_APWDone:
		rts
_APWFull:
		pla
		.error_memory

; ************************************************************************************************
;
;		Append the whole pool to the object, AFTER the $FF end marker and after FixBranches has
;		walked the p-code. Records where it landed so the fixups can be resolved later.
;
; ************************************************************************************************

AsmFlushPool:
		lda 	AsmPoolLen 					; no GP.ASM in this program at all
		ora 	AsmPoolLen+1
		bne 	_AFPGo
		rts
_AFPGo:
		lda 	objPtr 						; where the pool starts, in the buffer
		sta 	AsmPoolBase
		lda 	objPtr+1
		sta 	AsmPoolBase+1

		.set16 	zTemp2,AsmPool
		stz 	AsmCopyIdx
		stz 	AsmCopyIdx+1
_AFPLoop:
		lda 	AsmCopyIdx 					; copied everything ?
		cmp 	AsmPoolLen
		lda 	AsmCopyIdx+1
		sbc 	AsmPoolLen+1
		bcs 	_AFPDone
		lda 	(zTemp2)
		jsr 	WriteCodeByte 				; uses objPtr only, leaves zTemp2 alone
		inc 	zTemp2
		bne 	_AFPNoCarry
		inc 	zTemp2+1
_AFPNoCarry:
		inc 	AsmCopyIdx
		bne 	_AFPLoop
		inc 	AsmCopyIdx+1
		bra 	_AFPLoop
_AFPDone:
		rts

; ************************************************************************************************
;
;		Resolve every .word operand now that the object's run base is known.
;
;		A = the PAGE DELTA between where the object sits in the buffer now and where it will
;		sit when the program runs, i.e. runtimeEndPage - (FreeMemory >> 8) embedded, or
;		PCODE_PAGE - (FreeMemory >> 8) shared. The caller works that out because FreeMemory is
;		an application symbol; both ends are page aligned, so one byte says all of it.
;
; ************************************************************************************************

AsmPatchBlobs:
		sta 	AsmPageDelta
		lda 	AsmFixupCount
		beq 	_APBDone
		stz 	AsmFixIdx
_APBLoop:
		lda 	AsmFixIdx
		asl 	a
		asl 	a
		tax
		;
		;		run address = (where the blob sits in the buffer) + the page delta
		;
		clc
		lda 	AsmPoolBase
		adc 	AsmFixups+2,x
		sta 	zTemp0
		lda 	AsmPoolBase+1
		adc 	AsmFixups+3,x
		clc
		adc 	AsmPageDelta
		sta 	zTemp0+1
		;
		;		...written straight into the operand, whose address was recorded as it was
		;		emitted. The buffer has not moved since.
		;
		lda 	AsmFixups+0,x
		sta 	zTemp1
		lda 	AsmFixups+1,x
		sta 	zTemp1+1
		lda 	zTemp0
		sta 	(zTemp1)
		ldy 	#1
		lda 	zTemp0+1
		sta 	(zTemp1),y

		inc 	AsmFixIdx
		lda 	AsmFixIdx
		cmp 	AsmFixupCount
		bcc 	_APBLoop
_APBDone:
		rts

; ************************************************************************************************
;
;		Assemble one REM body line. srcPtr is just past the REM token.
;
; ************************************************************************************************

AsmAssembleLine:
		jsr 	LookNextNonSpace 			; first real character on the line
		beq 	_AALNothing 				; a bare REM assembles to nothing
		cmp 	#';' 						; ...and so does a comment
		beq 	_AALNothing
		jsr 	AsmReadMnemonic
		jsr 	AsmParseOperand
		jsr 	AsmSelectMode
		jsr 	AsmEmitInstruction
		jsr 	LookNextNonSpace 			; nothing may follow but a comment
		beq 	_AALNothing
		cmp 	#';'
		beq 	_AALNothing
		jmp 	AsmBadSyntax
_AALNothing:
		rts

; ************************************************************************************************
;
;		Three letters into fifteen bits, A=1..Z=26, exactly as genasm.py packs the table.
;
; ************************************************************************************************

AsmReadMnemonic:
		stz 	AsmPacked
		stz 	AsmPacked+1
		ldx 	#3
_ARMChar:
		jsr 	GetNext
		cmp 	#'a' 						; fold lower case -- BASLOAD upshifts, the host
		bcc 	_ARMNoFold 					; tokeniser does not
		cmp 	#'z'+1
		bcs 	_ARMNoFold
		sec
		sbc 	#'a'-'A'
_ARMNoFold:
		jsr 	CharIsAlpha
		bcc 	AsmBadSyntax
		sec
		sbc 	#'A'-1 						; A=1..Z=26, so a zero packed word can terminate
		pha
		ldy 	#5 							; packed = packed << 5
_ARMShift:
		asl 	AsmPacked
		rol 	AsmPacked+1
		dey
		bne 	_ARMShift
		pla 								; ...| this letter
		ora 	AsmPacked
		sta 	AsmPacked
		dex
		bne 	_ARMChar
		rts

AsmBadSyntax:
		.error_syntax

; ************************************************************************************************
;
;		Work out what the operand LOOKS like, and its value. Which addressing mode that becomes
;		is AsmSelectMode's job, because it depends on the mnemonic.
;
; ************************************************************************************************

AsmParseOperand:
		stz 	AsmValue
		stz 	AsmValue+1
		stz 	AsmIsByte
		lda 	#ASYN_NONE
		sta 	AsmSyntax

		jsr 	LookNextNonSpace
		beq 	_APODone 					; implied
		cmp 	#';'
		beq 	_APODone 					; implied, with a comment after it
		cmp 	#'#'
		beq 	_APOImmediate
		cmp 	#'('
		beq 	_APOIndirect
		cmp 	#'A' 						; a bare A is the accumulator, i.e. implied
		bne 	_APOAbsolute
		jsr 	GetNext 					; consume it and see what follows
		jsr 	LookNextNonSpace
		beq 	_APODone
		cmp 	#';'
		beq 	_APODone
		jmp 	AsmBadSyntax 				; A followed by anything else is not a form we have
_APODone:
		rts

_APOImmediate:
		jsr 	GetNext 					; consume the #
		jsr 	AsmParseValue
		lda 	#ASYN_IMM
		sta 	AsmSyntax
		rts

;
;		Absolute, or one of the two indexed forms.
;
_APOAbsolute:
		jsr 	AsmParseValue
		lda 	#ASYN_ABS
		sta 	AsmSyntax
		jsr 	LookNextNonSpace
		cmp 	#','
		bne 	_APODone
		jsr 	GetNext 					; consume the comma
		jsr 	AsmReadIndexRegister 		; X -> carry clear, Y -> carry set
		lda 	#ASYN_ABSX
		bcc 	_APOAbsIndexed
		lda 	#ASYN_ABSY
_APOAbsIndexed:
		sta 	AsmSyntax
		rts

;
;		(n) / (n,X) / (n),Y
;
_APOIndirect:
		jsr 	GetNext 					; consume the (
		jsr 	AsmParseValue
		jsr 	LookNextNonSpace
		cmp 	#','
		beq 	_APOIndX
		;
		;		(n), and then possibly ,Y
		;
		lda 	#')'
		jsr 	AsmExpect
		lda 	#ASYN_IND
		sta 	AsmSyntax
		jsr 	LookNextNonSpace
		cmp 	#','
		bne 	_APODone
		jsr 	GetNext
		jsr 	AsmReadIndexRegister
		bcc 	_APOBadIndex 				; (n),X does not exist
		lda 	#ASYN_INDY
		sta 	AsmSyntax
		rts
;
;		(n,X)
;
_APOIndX:
		jsr 	GetNext 					; consume the comma
		jsr 	AsmReadIndexRegister
		bcs 	_APOBadIndex 				; (n,Y) does not exist
		lda 	#')'
		jsr 	AsmExpect
		lda 	#ASYN_INDX
		sta 	AsmSyntax
		rts

_APOBadIndex:
		jmp 	AsmBadSyntax

; ************************************************************************************************
;
;		Read an index register: carry clear for X, carry set for Y, anything else is a syntax
;		error.
;
; ************************************************************************************************

AsmReadIndexRegister:
		jsr 	LookNextNonSpace
		jsr 	GetNext
		cmp 	#'x'
		beq 	_ARIRX
		cmp 	#'X'
		beq 	_ARIRX
		cmp 	#'y'
		beq 	_ARIRY
		cmp 	#'Y'
		bne 	_ARIRBad
_ARIRY:
		sec
		rts
_ARIRX:
		clc
		rts
_ARIRBad:
		jmp 	AsmBadSyntax

; ************************************************************************************************
;
;		Require the next non-space character to be A.
;
; ************************************************************************************************

AsmExpect:
		pha
		jsr 	LookNextNonSpace
		jsr 	GetNext
		sta 	AsmScratch
		pla
		cmp 	AsmScratch
		bne 	_AEBad
		rts
_AEBad:
		jmp 	AsmBadSyntax

; ************************************************************************************************
;
;		A number: $hex or decimal. AsmIsByte says whether it will fit in one byte, which is what
;		picks zero page over absolute -- for hex that is the DIGIT COUNT, so $0080 is absolute
;		and $80 is zero page, and for decimal it is simply the magnitude.
;
; ************************************************************************************************

AsmParseValue:
		stz 	AsmValue
		stz 	AsmValue+1
		stz 	AsmDigits
		jsr 	LookNextNonSpace
		cmp 	#'$'
		beq 	_APVHex
		jmp 	_APVDecimal
_APVHex:
		jsr 	GetNext 					; consume the $
_APVHexLoop:
		jsr 	LookNext
		jsr 	ConvertHexStyle 			; 0-35, carry set if it converted at all
		bcc 	_APVHexEnd
		cmp 	#16 						; G-Z are not hex digits
		bcs 	_APVHexEnd
		pha
		jsr 	GetNext 					; consume the digit
		ldy 	#4 							; value = value << 4
_APVHexShift:
		asl 	AsmValue
		rol 	AsmValue+1
		dey
		bne 	_APVHexShift
		pla 								; ...| this digit
		ora 	AsmValue
		sta 	AsmValue
		inc 	AsmDigits
		bra 	_APVHexLoop
_APVHexEnd:
		lda 	AsmDigits
		beq 	_APVBad 					; a bare $
		cmp 	#3 							; one or two digits -> a byte
		bcs 	_APVNotByte
		bra 	_APVIsByte

_APVBad:
		jmp 	AsmBadSyntax

_APVDecimal:
		jsr 	LookNext
		jsr 	CharIsDigit
		bcc 	_APVBad
_APVDecLoop:
		jsr 	LookNext
		jsr 	CharIsDigit
		bcc 	_APVDecEnd
		jsr 	GetNext
		sec
		sbc 	#'0'
		pha
		jsr 	AsmValueTimesTen
		pla
		clc
		adc 	AsmValue
		sta 	AsmValue
		bcc 	_APVDecLoop
		inc 	AsmValue+1
		bra 	_APVDecLoop
_APVDecEnd:
		lda 	AsmValue+1 					; under 256 -> a byte
		bne 	_APVNotByte
_APVIsByte:
		lda 	#1
		sta 	AsmIsByte
		rts
_APVNotByte:
		stz 	AsmIsByte
		rts

;
;		AsmValue = AsmValue * 10, as *8 + *2.
;
AsmValueTimesTen:
		lda 	AsmValue
		sta 	AsmScratch
		lda 	AsmValue+1
		sta 	AsmScratch+1
		asl 	AsmValue 					; value *2
		rol 	AsmValue+1
		asl 	AsmScratch 					; scratch = original *2
		rol 	AsmScratch+1
		asl 	AsmValue 					; value *4
		rol 	AsmValue+1
		asl 	AsmValue 					; value *8
		rol 	AsmValue+1
		clc
		lda 	AsmValue
		adc 	AsmScratch
		sta 	AsmValue
		lda 	AsmValue+1
		adc 	AsmScratch+1
		sta 	AsmValue+1
		rts

; ************************************************************************************************
;
;		Turn (mnemonic, syntax class) into an opcode. The mnemonic decides which of the candidate
;		modes for that syntax actually exists -- LDA $12 is zero page because LDA has one, JSR $12
;		is absolute because JSR does not.
;
; ************************************************************************************************

AsmSelectMode:
		.set16 	zTemp2,AsmMnemonicTable
_ASMFind:
		lda 	(zTemp2) 					; end of table ?
		ldy 	#1
		ora 	(zTemp2),y
		beq 	_ASMUnknown
		lda 	(zTemp2)
		cmp 	AsmPacked
		bne 	_ASMNext
		lda 	(zTemp2),y
		cmp 	AsmPacked+1
		beq 	_ASMFound
_ASMNext:
		clc
		lda 	zTemp2
		adc 	#4
		sta 	zTemp2
		bcc 	_ASMFind
		inc 	zTemp2+1
		bra 	_ASMFind

_ASMUnknown:
		jmp 	AsmBadSyntax

_ASMFound:
		ldy 	#2
		lda 	(zTemp2),y
		sta 	AsmEntryFirst
		iny
		lda 	(zTemp2),y
		sta 	AsmEntryCount
		;
		;		Try this syntax class's candidate modes in order. The top bit marks a candidate
		;		that is only allowed when the operand fits in a byte.
		;
		lda 	AsmSyntax
		asl 	a 							; three candidates each
		clc
		adc 	AsmSyntax
		sta 	AsmChoiceIdx
		lda 	#3
		sta 	AsmChoiceLeft
_ASMCandidate:
		ldx 	AsmChoiceIdx
		lda 	AsmModeChoice,x
		cmp 	#$FF
		beq 	_ASMNoMode
		bpl 	_ASMTry 					; no byte-only flag
		and 	#$7F
		ldx 	AsmIsByte
		beq 	_ASMNextCandidate 			; byte-only candidate, and this operand is not one
_ASMTry:
		jsr 	AsmFindModeEntry 			; carry set, A = opcode, if the mnemonic has it
		bcs 	_ASMGotIt
_ASMNextCandidate:
		inc 	AsmChoiceIdx
		dec 	AsmChoiceLeft
		bne 	_ASMCandidate
_ASMNoMode:
		jmp 	AsmBadSyntax
_ASMGotIt:
		sta 	AsmOpcode
		rts

; ************************************************************************************************
;
;		Does this mnemonic have addressing mode A ? Carry set and A = its opcode if so, with
;		AsmMode left holding the mode. Carry clear if not. Destroys X and Y.
;
; ************************************************************************************************

AsmFindModeEntry:
		sta 	AsmScratch 					; the mode we want
		lda 	AsmEntryFirst 				; byte offset = index * 2, which can pass 255
		asl 	a
		sta 	zTemp0
		lda 	#0
		rol 	a
		sta 	zTemp0+1
		clc
		lda 	zTemp0
		adc 	#AsmModeTable & $FF
		sta 	zTemp0
		lda 	zTemp0+1
		adc 	#AsmModeTable >> 8
		sta 	zTemp0+1
		ldx 	AsmEntryCount
_AFMELoop:
		lda 	(zTemp0)
		cmp 	AsmScratch
		beq 	_AFMEFound
		clc
		lda 	zTemp0
		adc 	#2
		sta 	zTemp0
		bcc 	_AFMENoCarry
		inc 	zTemp0+1
_AFMENoCarry:
		dex
		bne 	_AFMELoop
		clc
		rts
_AFMEFound:
		lda 	AsmScratch
		sta 	AsmMode
		ldy 	#1
		lda 	(zTemp0),y 					; the opcode
		sec
		rts

; ************************************************************************************************
;
;		Emit the opcode and however many operand bytes its mode takes.
;
; ************************************************************************************************

AsmEmitInstruction:
		lda 	AsmMode
		cmp 	#AMODE_REL
		beq 	AsmNoBranchesYet
		lda 	AsmOpcode
		jsr 	AsmPoolWrite
		ldx 	AsmMode
		lda 	AsmModeLen,x
		beq 	_AEIDone 					; implied, no operand at all
		pha
		lda 	AsmValue
		jsr 	AsmPoolWrite
		pla
		cmp 	#2
		bcc 	_AEIDone
		lda 	AsmValue+1
		jsr 	AsmPoolWrite
_AEIDone:
		rts

;
;		A branch needs a label to aim at, and labels are not in yet. The displacement cannot be
;		computed from an absolute address either, because the blob's own run address is not known
;		until WriteObjectCode. Say so plainly rather than assemble something wrong.
;
AsmNoBranchesYet:
		.error_unimplemented

; ************************************************************************************************
;
;		Candidate addressing modes per syntax class, three each, $FF for none. The top bit marks
;		a candidate that only applies when the operand fits in a byte.
;
; ************************************************************************************************

AsmModeChoice:
		.byte 	AMODE_IMP,$FF,$FF 						; ASYN_NONE
		.byte 	AMODE_IMM,$FF,$FF 						; ASYN_IMM
		.byte 	AMODE_REL,AMODE_ZP|$80,AMODE_ABS 		; ASYN_ABS
		.byte 	AMODE_ZPX|$80,AMODE_ABX,$FF 			; ASYN_ABSX
		.byte 	AMODE_ZPY|$80,AMODE_ABY,$FF 			; ASYN_ABSY
		.byte 	AMODE_IZP|$80,AMODE_IND,$FF 			; ASYN_IND
		.byte 	AMODE_IZX|$80,AMODE_IAX,$FF 			; ASYN_INDX
		.byte 	AMODE_IZY,$FF,$FF 						; ASYN_INDY

;
;		Operand bytes per addressing mode.
;
AsmModeLen:
		.byte 	0 						; IMP
		.byte 	1 						; IMM
		.byte 	1 						; ZP
		.byte 	1 						; ZPX
		.byte 	1 						; ZPY
		.byte 	2 						; ABS
		.byte 	2 						; ABX
		.byte 	2 						; ABY
		.byte 	2 						; IND
		.byte 	1 						; IZX
		.byte 	1 						; IZY
		.byte 	1 						; IZP
		.byte 	2 						; IAX
		.byte 	1 						; REL

; ************************************************************************************************
;
;		All of this is compiler space -- above ObjectBase, thrown away when the object is
;		written. storage is the 1K hole below the code and is already full, so none of it can
;		go there; see the note in application/source/file-io/read.asm.
;
; ************************************************************************************************

AsmPool:
		.fill 	ASM_POOL_SIZE 			; every blob in the program, back to back
AsmPoolLen:
		.fill 	2
AsmPoolBase:
		.fill 	2 						; where the pool landed within the object
AsmBlobStart:
		.fill 	2 						; pool offset of the blob being assembled
AsmFixups:
		.fill 	4*ASM_MAX_BLOCKS 		; per block: p-code operand offset, blob pool offset
AsmFixupCount:
		.fill 	1
AsmFixIdx:
		.fill 	1
AsmPageDelta:
		.fill 	1
AsmCopyIdx:
		.fill 	2
AsmPacked:
		.fill 	2 						; the mnemonic being assembled
AsmSyntax:
		.fill 	1
AsmValue:
		.fill 	2
AsmIsByte:
		.fill 	1
AsmDigits:
		.fill 	1
AsmMode:
		.fill 	1
AsmOpcode:
		.fill 	1
AsmEntryFirst:
		.fill 	1
AsmEntryCount:
		.fill 	1
AsmChoiceIdx:
		.fill 	1
AsmChoiceLeft:
		.fill 	1
AsmScratch:
		.fill 	2

		.send code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		30/08/26		Written. Numeric operands and all thirteen non-branch addressing modes;
;						branches and {VAR} are not in yet.
;
; ************************************************************************************************
