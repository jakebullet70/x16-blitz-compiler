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

;
;		THE POOL AND THE FIXUP LIST LIVE IN BANKED RAM, at $A000-$BFFF in bank 3, bracketed by
;		the .asm_access / .asm_release macros in system-specific/x16/x16_storage.inc -- which is
;		also where the bank allocation is written down, and where the rules a window has to obey
;		are set out. The compiler's own name and line tables took the same route to bank 2.
;
;		They are here because low RAM is not free: FreeMemory is page aligned immediately after
;		the compiler's last byte, so every byte of compiler comes one for one off the object
;		buffer -- which is to say off the largest program the thing can compile. A pool in low
;		RAM cost 1,024 bytes of that AND capped total assembly at 1,024 bytes. In the bank it
;		costs nothing and the cap is nearly eight times larger.
;
;		See TODO.md, "Growing the object buffer", for the rest of that story: the buffer binds
;		before the run side does, and has since well before GP.ASM existed.
;
ASM_MAX_BLOCKS = 32 						; GP.ASM blocks in one program
ASM_MAX_FIXUPS = 96 						; blob calls + label references + {VAR} references
ASM_MAX_LABELS = 16 						; labels in ONE block -- they do not cross GP.ENDASM
ASM_MAX_LOCALS = 32 						; label references in one block, awaiting resolution
ASM_SYM_MAX    = 64 						; longest name {VAR} can carry -- BASLOAD's own limit
											; on significant characters, so a name it accepted
											; always fits here

;
;		A fixup is five bytes: kind, target, value. All three kinds write a 16 bit address
;		that cannot be known until WriteObjectCode, and they differ only in where it goes and
;		what it is made of:
;
;			0	a blob call.       target = the .word operand, ADDRESSED ABSOLUTELY because it
;			                       is in the p-code, which is already in the buffer.
;			                       value = the blob's pool offset.
;			1	JMP/JSR a label.   target = a POOL OFFSET (the pool is not placed yet).
;			                       value = the label's pool offset.
;			2	{VAR}.             target = a pool offset. value = the variable slot's offset
;			                       within the workspace.
;
;		0 and 1 resolve against where the object will RUN, 2 against where the workspace will
;		be -- which is why WriteObjectCode has to hand over both.
;
AFIX_CALL  = 0
AFIX_LABEL = 1
AFIX_VAR   = 2

;
;		Three parallel arrays rather than one array of records, and deliberately: a record
;		index would be count*5, which passes 255 well before the table is full and would need
;		a sixteen bit pointer at every touch. Indexed this way every subscript is count or
;		count*2 and stays in X.
;
AsmFixKind    = $A000 						; 1 each
AsmFixTarget  = AsmFixKind   + ASM_MAX_FIXUPS 	; 2 each
AsmFixValue   = AsmFixTarget + 2*ASM_MAX_FIXUPS ; 2 each
AsmLabels     = AsmFixValue  + 2*ASM_MAX_FIXUPS ; 8 each: 6 of name, then the pool offset
AsmLocals     = AsmLabels    + 8*ASM_MAX_LABELS ; 4 each: pool offset, label index, kind
AsmPool       = AsmLocals    + 4*ASM_MAX_LOCALS ; every blob in the program, back to back
ASM_POOL_SIZE = $C000 - AsmPool 			; ...to the top of the window

ASM_NAME_LEN = 6 							; significant characters in a label
ASM_UNDEF = $FFFF 							; a label that has been named but not yet placed

ALOC_REL = 0 								; a branch: one byte, resolved inside the block
ALOC_ABS = 1 								; JMP/JSR: two bytes, handed on as an AFIX_LABEL

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
		stz 	AsmLabelCount 				; labels are per block: a name used in two blocks
		stz 	AsmLocalCount 				; is two different labels, and neither can be
		rts 								; branched to from the other

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
		jsr 	AsmResolveLocals 			; every branch and label reference in this block

		lda 	#PCD_CMD_WORD 				; .word <blob address>
		jsr 	WriteCodeByte
		;
		;		Capture where the operand lands BEFORE writing it -- objPtr is the write cursor,
		;		so this IS the address of the low byte, in the buffer, right now. Absolute and
		;		not an offset, because FreeMemory is an application symbol and this library is
		;		also built on its own.
		;
		;		Built in low RAM first and banked in one go at the end: the record cannot be
		;		assembled straight into the window, because WriteCodeByte sits in the middle of
		;		it and can leave through the error handler, which prints in bank 0.
		;
		lda 	#AFIX_CALL
		sta 	AsmNewKind
		lda 	objPtr
		sta 	AsmNewTarget
		lda 	objPtr+1
		sta 	AsmNewTarget+1
		lda 	AsmBlobStart 				; where this blob starts in the pool
		sta 	AsmNewValue
		lda 	AsmBlobStart+1
		sta 	AsmNewValue+1
		lda 	#0 							; two placeholders, overwritten by AsmPatchAll
		jsr 	WriteCodeByte
		lda 	#0
		jsr 	WriteCodeByte

		.keyword PCD_SYS 					; $DD $B0 -- call it
		jmp 	AsmAddFixup

; ************************************************************************************************
;
;		Add the fixup described by AsmNewKind / AsmNewTarget / AsmNewValue.
;
; ************************************************************************************************

AsmAddFixup:
		lda 	AsmFixupCount
		cmp 	#ASM_MAX_FIXUPS
		bcs 	_AAFTooMany
		asl 	a 							; the two-byte arrays index by count*2
		tax
		lda 	AsmFixupCount
		tay 								; ...and the kind array by count
		.asm_access
		lda 	AsmNewKind
		sta 	AsmFixKind,y
		lda 	AsmNewTarget
		sta 	AsmFixTarget,x
		lda 	AsmNewTarget+1
		sta 	AsmFixTarget+1,x
		lda 	AsmNewValue
		sta 	AsmFixValue,x
		lda 	AsmNewValue+1
		sta 	AsmFixValue+1,x
		.asm_release
		inc 	AsmFixupCount
		rts

_AAFTooMany:
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
		.asm_access
		sta 	(zTemp2)
		.asm_release
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
		.asm_access 						; one byte at a time, and the window CLOSES before
		lda 	(zTemp2) 					; WriteCodeByte -- its ObjectCeiling test can raise
		sta 	AsmByte 					; PROGRAM TOO BIG and leave through the error
		.asm_release 						; handler, which prints, in bank 0
		lda 	AsmByte
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
;		Resolve every fixup, now that both bases are finally known. The caller sets:
;
;		AsmWorkspacePage  where the variables will be -- newWorkspacePage.
;		AsmPageDelta      the difference between where the object sits in the buffer NOW and
;		                  where it will sit when the program runs: runtimeEndPage minus
;		                  FreeMemory >> 8 embedded, PCODE_PAGE minus FreeMemory >> 8 shared.
;		                  The caller works it out because FreeMemory is an application symbol,
;		                  and both ends are page aligned so one byte says all of it.
;
;		This runs LATE -- after WriteObjectCode has settled newWorkspacePage -- and it has to,
;		because {VAR} needs it. Nothing here changes the object's length, so running late is
;		free: the buffer is untouched until it is streamed out.
;
; ************************************************************************************************

AsmPatchAll:
		lda 	AsmFixupCount
		bne 	_APAGo
		rts
_APAGo:
		stz 	AsmFixIdx
_APALoop:
		lda 	AsmFixIdx
		asl 	a
		tax 								; the two-byte arrays
		ldy 	AsmFixIdx 					; ...and the kind array
		.asm_access
		lda 	AsmFixKind,y
		sta 	AsmKind
		lda 	AsmFixTarget,x
		sta 	zTemp1
		lda 	AsmFixTarget+1,x
		sta 	zTemp1+1
		lda 	AsmFixValue,x
		sta 	zTemp0
		lda 	AsmFixValue+1,x
		sta 	zTemp0+1
		.asm_release
		;
		;		THE VALUE. A blob address and a label are both somewhere in the pool, so both
		;		are (where the pool sits in the buffer) + offset + the page delta. A {VAR} is
		;		an offset into the workspace instead, and the workspace has its own base.
		;
		lda 	AsmKind
		cmp 	#AFIX_VAR
		beq 	_APAVariable
		clc
		lda 	AsmPoolBase
		adc 	zTemp0
		sta 	zTemp0
		lda 	AsmPoolBase+1
		adc 	zTemp0+1
		clc
		adc 	AsmPageDelta
		sta 	zTemp0+1
		bra 	_APATarget
_APAVariable:
		clc
		lda 	zTemp0+1
		adc 	AsmWorkspacePage
		sta 	zTemp0+1
		;
		;		THE TARGET. A blob call patches the p-code, which is already in the buffer, so
		;		its address was recorded absolutely as it was emitted. The other two patch the
		;		pool, which had not been placed when they were recorded, so they hold offsets.
		;
_APATarget:
		lda 	AsmKind
		beq 	_APAStore
		clc
		lda 	zTemp1
		adc 	AsmPoolBase
		sta 	zTemp1
		lda 	zTemp1+1
		adc 	AsmPoolBase+1
		sta 	zTemp1+1
_APAStore:
		lda 	zTemp0
		sta 	(zTemp1)
		ldy 	#1
		lda 	zTemp0+1
		sta 	(zTemp1),y

		inc 	AsmFixIdx
		lda 	AsmFixIdx
		cmp 	AsmFixupCount
		bcs 	_APADone 					; the loop body is past branch range, so it is
		jmp 	_APALoop 					; inverted around a jmp
_APADone:
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
		;
		;		A label definition and a mnemonic both start with letters, and they are only
		;		told apart by the colon after one of them. So read the identifier, look, and
		;		WIND srcPtr BACK if it turns out to have been a mnemonic -- which is cheaper
		;		and clearer than trying to assemble from the copy we just took.
		;
		jsr 	CharIsAlpha
		bcc 	_AALInstruction
		lda 	srcPtr
		sta 	AsmLineStart
		lda 	srcPtr+1
		sta 	AsmLineStart+1
		jsr 	AsmReadIdentifier
		jsr 	LookNextNonSpace
		cmp 	#':'
		beq 	_AALLabel
		lda 	AsmLineStart 				; not a label after all
		sta 	srcPtr
		lda 	AsmLineStart+1
		sta 	srcPtr+1
		bra 	_AALInstruction
_AALLabel:
		jsr 	GetNext 					; consume the colon
		jsr 	AsmDefineLabel
		jsr 	LookNextNonSpace 			; an instruction may follow it on the same line
		beq 	_AALNothing
		cmp 	#';'
		beq 	_AALNothing
_AALInstruction:
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
		stz 	AsmIsLabel 					; AsmParseValue clears these too, but an operand
		stz 	AsmIsVar 					; that never reaches it must not inherit the last
		lda 	#ASYN_NONE 					; instruction's
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
		stz 	AsmIsLabel
		stz 	AsmIsVar
		jsr 	LookNextNonSpace
		cmp 	#'$'
		beq 	_APVHex
		cmp 	#'{' 						; {VAR} -- a BASIC variable's slot
		beq 	_APVVariable
		jsr 	CharIsAlpha 				; a name is a label reference
		bcs 	_APVLabel
		jmp 	_APVDecimal

;
;		A label. It may not exist yet -- a forward branch is the whole reason labels are worth
;		having -- so this only reserves an index, and AsmResolveLocals settles it at GP.ENDASM.
;
_APVLabel:
		jsr 	AsmReadIdentifier
		jsr 	AsmFindOrAddLabel 			; -> A = index
		sta 	AsmLabelRef
		inc 	AsmIsLabel
		stz 	AsmIsByte 					; a label is always a 16 bit target
		rts

_APVVariable:
		jsr 	AsmParseBrace
		inc 	AsmIsVar
		stz 	AsmIsByte 					; a slot address is always 16 bit
		rts
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
		cmp 	#$80 						; top bit = "only if the operand fits in a byte"
		bcc 	_ASMTry
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
		lda 	AsmOpcode
		jsr 	AsmPoolWrite
		ldx 	AsmMode
		lda 	AsmModeLen,x
		beq 	_AEIDone 					; implied, no operand at all
		sta 	AsmOperandLen
		;
		;		Where the operand is about to land. Everything deferred -- a branch, a label,
		;		a {VAR} -- is recorded against this.
		;
		lda 	AsmPoolLen
		sta 	AsmOperandAt
		lda 	AsmPoolLen+1
		sta 	AsmOperandAt+1

		lda 	AsmMode
		cmp 	#AMODE_REL
		beq 	_AEIBranch
		;
		;		A label or a {VAR} is a 16 bit address and will not go in a one byte operand.
		;		LDA #LOOP would have to mean one half of an address we do not know yet.
		;
		lda 	AsmIsLabel
		ora 	AsmIsVar
		beq 	_AEIPlain
		lda 	AsmOperandLen
		cmp 	#2
		bcc 	_AEINotAddress

_AEIPlain:
		lda 	AsmValue 					; the operand itself, zero where it is deferred
		jsr 	AsmPoolWrite
		lda 	AsmOperandLen
		cmp 	#2
		bcc 	_AEIDeferred
		lda 	AsmValue+1
		jsr 	AsmPoolWrite

_AEIDeferred:
		lda 	AsmIsVar 					; {VAR}: the slot offset is known NOW, only the
		beq 	_AEIMaybeLabel 				; workspace base is not, so this is a fixup already
		lda 	#AFIX_VAR
		sta 	AsmNewKind
		lda 	AsmOperandAt
		sta 	AsmNewTarget
		lda 	AsmOperandAt+1
		sta 	AsmNewTarget+1
		lda 	AsmValue
		sta 	AsmNewValue
		lda 	AsmValue+1
		sta 	AsmNewValue+1
		jmp 	AsmAddFixup

_AEIMaybeLabel:
		lda 	AsmIsLabel 					; a label may not be placed yet -- hold it locally
		beq 	_AEIDone 					; and let AsmResolveLocals deal with it
		lda 	#ALOC_ABS
		jmp 	AsmAddLocal
_AEIDone:
		rts

;
;		A branch. The displacement is inside the blob, so it does NOT depend on where the blob
;		ends up -- but the label may be further down the block, so it still waits for GP.ENDASM.
;		A branch to a bare number is refused: it would have to be an absolute address, and the
;		displacement to one cannot be worked out until the blob has a run address, which is far
;		too late to report a branch being out of range.
;
_AEIBranch:
		lda 	AsmIsLabel
		beq 	_AEINotAddress
		lda 	#0 							; the placeholder displacement
		jsr 	AsmPoolWrite
		lda 	#ALOC_REL
		jmp 	AsmAddLocal

_AEINotAddress:
		jmp 	AsmBadSyntax

; ************************************************************************************************
;
;		Read an identifier into AsmName, folded to upper case, space padded to ASM_NAME_LEN.
;		Longer names are still CONSUMED, just not stored -- so LONGNAME1 and LONGNAME2 are the
;		same label, which is the same rule BASIC itself applies to variables, and better than
;		leaving the tail of the name to be parsed as an operand.
;
; ************************************************************************************************

AsmReadIdentifier:
		ldx 	#0
_ARILoop:
		jsr 	LookNext
		cmp 	#'a'
		bcc 	_ARINoFold
		cmp 	#'z'+1
		bcs 	_ARINoFold
		sec
		sbc 	#'a'-'A'
_ARINoFold:
		pha
		jsr 	CharIsAlpha
		bcs 	_ARIKeep
		pla
		pha
		jsr 	CharIsDigit
		bcc 	_ARIEnd
_ARIKeep:
		pla
		cpx 	#ASM_NAME_LEN
		bcs 	_ARISkip
		sta 	AsmName,x
		inx
_ARISkip:
		jsr 	GetNext 					; consume it either way
		bra 	_ARILoop
_ARIEnd:
		pla
_ARIPad:
		cpx 	#ASM_NAME_LEN
		bcs 	_ARIDone
		lda 	#' '
		sta 	AsmName,x
		inx
		bra 	_ARIPad
_ARIDone:
		rts

; ************************************************************************************************
;
;		Find AsmName in this block's label table, adding it undefined if it is not there yet.
;		Returns its index in A. A forward branch names a label before it exists, which is the
;		whole point of having them.
;
; ************************************************************************************************

AsmFindOrAddLabel:
		stz 	AsmLabelIdx
_AFALSearch:
		lda 	AsmLabelIdx
		cmp 	AsmLabelCount
		bcs 	_AFALAdd
		asl 	a 							; 8 bytes per label
		asl 	a
		asl 	a
		tax
		ldy 	#0
		.asm_access
_AFALCompare:
		lda 	AsmLabels,x
		cmp 	AsmName,y
		bne 	_AFALNoMatch
		inx
		iny
		cpy 	#ASM_NAME_LEN
		bne 	_AFALCompare
		.asm_release
		lda 	AsmLabelIdx
		rts
_AFALNoMatch:
		.asm_release
		inc 	AsmLabelIdx
		bra 	_AFALSearch

_AFALAdd:
		lda 	AsmLabelCount
		cmp 	#ASM_MAX_LABELS
		bcs 	_AFALTooMany
		asl 	a
		asl 	a
		asl 	a
		tax
		ldy 	#0
		.asm_access
_AFALStore:
		lda 	AsmName,y
		sta 	AsmLabels,x
		inx
		iny
		cpy 	#ASM_NAME_LEN
		bne 	_AFALStore
		lda 	#ASM_UNDEF & $FF 			; named, not yet placed
		sta 	AsmLabels,x
		lda 	#ASM_UNDEF >> 8
		sta 	AsmLabels+1,x
		.asm_release
		lda 	AsmLabelCount
		inc 	AsmLabelCount
		rts

_AFALTooMany:
		.error_memory

; ************************************************************************************************
;
;		Place AsmName here. Defining one twice is refused: the second definition would silently
;		win for references above it and lose for references below.
;
; ************************************************************************************************

AsmDefineLabel:
		jsr 	AsmFindOrAddLabel
		asl 	a
		asl 	a
		asl 	a
		clc
		adc 	#ASM_NAME_LEN 				; past the name, to the offset
		tax
		.asm_access
		lda 	AsmLabels+1,x 				; a real pool offset never reaches $FF00
		cmp 	#ASM_UNDEF >> 8
		bne 	_ADLDuplicate
		lda 	AsmPoolLen
		sta 	AsmLabels,x
		lda 	AsmPoolLen+1
		sta 	AsmLabels+1,x
		.asm_release
		rts
_ADLDuplicate:
		.asm_release
		jmp 	AsmBadSyntax

; ************************************************************************************************
;
;		Remember that the operand just emitted refers to label AsmLabelRef, in the manner A
;		(ALOC_REL or ALOC_ABS). AsmResolveLocals settles it at GP.ENDASM.
;
; ************************************************************************************************

AsmAddLocal:
		sta 	AsmScratch
		lda 	AsmLocalCount
		cmp 	#ASM_MAX_LOCALS
		bcs 	_ADLCTooMany
		asl 	a 							; 4 bytes per local
		asl 	a
		tax
		.asm_access
		lda 	AsmOperandAt
		sta 	AsmLocals,x
		lda 	AsmOperandAt+1
		sta 	AsmLocals+1,x
		lda 	AsmLabelRef
		sta 	AsmLocals+2,x
		lda 	AsmScratch
		sta 	AsmLocals+3,x
		.asm_release
		inc 	AsmLocalCount
		rts

_ADLCTooMany:
		.error_memory

; ************************************************************************************************
;
;		Settle every label reference in the block. Branches are finished here and now -- the
;		displacement is between two points in the same blob, so it does not care where the blob
;		ends up. JMP and JSR want a real address, so they become fixups and wait.
;
; ************************************************************************************************

AsmResolveLocals:
		lda 	AsmLocalCount
		bne 	_ARLGo
		rts
_ARLGo:
		stz 	AsmLocalIdx
_ARLLoop:
		lda 	AsmLocalIdx
		asl 	a
		asl 	a
		tax
		.asm_access
		lda 	AsmLocals,x
		sta 	AsmOperandAt
		lda 	AsmLocals+1,x
		sta 	AsmOperandAt+1
		lda 	AsmLocals+2,x
		sta 	AsmScratch 					; the label
		lda 	AsmLocals+3,x
		sta 	AsmScratch+1 				; how it was referred to
		.asm_release

		lda 	AsmScratch 					; where that label ended up
		asl 	a
		asl 	a
		asl 	a
		clc
		adc 	#ASM_NAME_LEN
		tax
		.asm_access
		lda 	AsmLabels,x
		sta 	AsmValue
		lda 	AsmLabels+1,x
		sta 	AsmValue+1
		.asm_release
		lda 	AsmValue+1
		cmp 	#ASM_UNDEF >> 8
		beq 	_ARLUndefined 				; referred to, never placed

		lda 	AsmScratch+1
		cmp 	#ALOC_REL
		beq 	_ARLBranch
		;
		;		JMP / JSR a label: an address in the pool, so it waits for the pool to be placed
		;
		lda 	#AFIX_LABEL
		sta 	AsmNewKind
		lda 	AsmOperandAt
		sta 	AsmNewTarget
		lda 	AsmOperandAt+1
		sta 	AsmNewTarget+1
		lda 	AsmValue
		sta 	AsmNewValue
		lda 	AsmValue+1
		sta 	AsmNewValue+1
		jsr 	AsmAddFixup
		bra 	_ARLNext
		;
		;		A branch: displacement = label - (the byte after the operand)
		;
_ARLBranch:
		sec
		lda 	AsmValue
		sbc 	AsmOperandAt
		sta 	AsmValue
		lda 	AsmValue+1
		sbc 	AsmOperandAt+1
		sta 	AsmValue+1
		sec
		lda 	AsmValue
		sbc 	#1
		sta 	AsmValue
		lda 	AsmValue+1
		sbc 	#0
		sta 	AsmValue+1
		;
		;		...and it has to fit in a signed byte, which is the one thing about branches
		;		that catches people out. Caught HERE, with the line still known, rather than at
		;		WriteObjectCode where nothing could say which branch was wrong.
		;
		lda 	AsmValue+1
		beq 	_ARLForward 				; 0 high -> low must be 0..127
		cmp 	#$FF
		bne 	_ARLTooFar
		lda 	AsmValue 					; $FF high -> low must be 128..255
		bpl 	_ARLTooFar
		bra 	_ARLPoke
_ARLForward:
		lda 	AsmValue
		bmi 	_ARLTooFar
_ARLPoke:
		lda 	AsmValue
		ldx 	AsmOperandAt
		ldy 	AsmOperandAt+1
		jsr 	AsmPoolPoke
_ARLNext:
		inc 	AsmLocalIdx
		lda 	AsmLocalIdx
		cmp 	AsmLocalCount
		bcs 	_ARLDone 					; as above, out of branch range
		jmp 	_ARLLoop
_ARLDone:
		rts

_ARLUndefined:
		jmp 	AsmBadSyntax
_ARLTooFar:
		.error_range

; ************************************************************************************************
;
;		Write A into the pool at offset YX.
;
; ************************************************************************************************

AsmPoolPoke:
		pha
		clc
		txa
		adc 	#AsmPool & $FF
		sta 	zTemp2
		tya
		adc 	#AsmPool >> 8
		sta 	zTemp2+1
		pla
		.asm_access
		sta 	(zTemp2)
		.asm_release
		rts

; ************************************************************************************************
;
;		{VAR} -- the ADDRESS OF THE VARIABLE'S SLOT in the workspace, for every kind of variable.
;		Not its value, and not, for a string or an array, the bytes it points at: the slot. That
;		is the one rule that holds for all of them, and it is what makes read and write the same
;		thing -- LDA {A} reads the first byte of A, STA {A} writes it.
;
;			{A}   {A%}  {A$}   the scalar's slot, created if the program has not used it yet,
;			                   exactly as an ordinary reference to it would
;			{A()}              the ARRAY's slot, which holds the base address of its data --
;			                   so reaching an element is two steps, as it is for GP.ARRPTR
;
;		An array is never created here. An undimensioned one has no slot to point at yet, and
;		guessing a shape for it from inside an assembly block would be worse than refusing.
;
; ************************************************************************************************

AsmParseBrace:
		;
		;		{VAR} is the ADDRESS OF A BASIC VARIABLE'S SLOT, so LDA {N%} reads it and
		;		STA {N%} writes it, in BASIC's own storage.
		;
		;		THE NAME IN THE REM IS NOT THE NAME IN THE CODE. BASLOAD crunches every
		;		identifier -- N% becomes A%, which is how it offers 64 character names on a two
		;		character BASIC -- and it stores REM text byte for byte, which is the very
		;		property that lets an assembly body survive tokenisation at all. The two halves
		;		of this feature want opposite things from the same tool, so {N%} in a REM names
		;		a variable the compiled code no longer calls N%.
		;
		;		BASLOAD's own #SYMFILE is the bridge: it records source name -> crunched name
		;		for every variable, and this translates through it. So the name is collected as
		;		WRITTEN rather than handed to ExtractVariableName, which would pack the wrong
		;		one.
		;
		jsr 	GetNext 					; consume the {
		stz 	AsmSymType
		ldy 	#0
		;
		;		The name as written. Alphanumeric, first character alphabetic, and it may be
		;		the full 64 BASLOAD allows rather than the two this BASIC keeps -- the crunched
		;		name is what has to fit, and one or two characters is what BASLOAD produces.
		;
		jsr 	LookNext
		jsr 	CharIsAlpha
		bcs 	_APBNameChar
		;
		;		The syntax exit is HERE, at the top, because both of its callers are: the far
		;		end of this routine is out of branch range from either.
		;
_APBBadName:
		jmp 	AsmBadSyntax
_APBNameChar:
		jsr 	LookNext
		jsr 	CharIsAlpha
		bcs 	_APBNameTake
		jsr 	CharIsDigit
		bcc 	_APBNameDone
_APBNameTake:
		cpy 	#ASM_SYM_MAX
		bcs 	_APBBadName 				; longer than the symbol file can hold
		cmp 	#'a'						; fold ASCII lowercase -- BASLOAD writes its symbol
		bcc 	_APBNameStore 				; file in upper case whatever the source looked like
		cmp 	#'z'+1
		bcs 	_APBNameStore
		sec
		sbc 	#'a'-'A'
_APBNameStore:
		sta 	AsmSymName,y
		iny
		jsr 	GetNext 					; consume it
		bra 	_APBNameChar
_APBNameDone:
		lda 	#0
		sta 	AsmSymName,y 				; the lookup wants it terminated
		;
		;		$ and % are the type, ( makes it an array -- the same three the compiler packs
		;		into the name itself, and the symbol file records none of them: BASLOAD crunches
		;		the IDENTIFIER and the sigil rides along separately, so PR$ is filed as PR.
		;
		jsr 	LookNext
		cmp 	#'$'
		bne 	_APBNotString
		lda 	#NSSString
		bra 	_APBHaveType
_APBNotString:
		cmp 	#'%'
		bne 	_APBCheckArray
		lda 	#NSSIInt16
_APBHaveType:
		sta 	AsmSymType
		jsr 	GetNext 					; consume the sigil
_APBCheckArray:
		jsr 	LookNext
		cmp 	#'('
		bne 	_APBLookup
		lda 	AsmSymType
		ora 	#NSSArray
		sta 	AsmSymType
		jsr 	GetNext 					; consume the (
		lda 	#')'
		jsr 	AsmExpect 					; and require the ) -- {N()} names the array itself
_APBLookup:
		lda 	#BLC_SYMLOOKUP 				; AsmSymName -> AsmSymCrunched, application side
		jsr 	CallAPIHandler
		bcs 	_APBSymFailed
		;
		;		Pack the crunched name exactly as ExtractVariableName packs a source one: X is
		;		the first character reduced to 5 bits with the type bits ORed in, Y the second
		;		reduced to 6, and a one character name leaves Y zero. BASLOAD produces one or
		;		two characters, which is precisely what this BASIC can hold -- the 64 character
		;		names live only in the symbol file.
		;
		lda 	AsmSymCrunched
		and 	#31
		ora 	AsmSymType
		tax
		ldy 	#0
		lda 	AsmSymCrunched+1
		beq 	_APBPacked
		and 	#63
		tay
_APBPacked:
		jsr 	FindVariable 				; and it MUST already exist -- {VAR} never creates
		bcc 	_APBUnknown 				; one, see the note below
		stx 	AsmValue
		sty 	AsmValue+1
		lda 	#'}'
		jmp 	AsmExpect

;
;		THREE FAILURES, AND THEY ARE DELIBERATELY NOT THE SAME MESSAGE, because they need three
;		different fixes. The text sits here in compiler space rather than in the shared error
;		table: that table is in common.library, which links BELOW GPBase and is therefore
;		copied into every compiled program, so a message there would cost every program bytes
;		for a diagnostic only the compiler can ever print. Up here it costs nothing.
;
;		{VAR} never CREATES a variable, which is the opposite of what an ordinary BASIC
;		reference does. A name that misses would otherwise hand back a fresh slot BASIC never
;		reads or writes: an assembly block that runs, stores, and changes nothing anyone can
;		see. That is the worst kind of failure this project has, and it is worth an error.
;
_APBSymFailed:
		cmp 	#0
		bne 	_APBUnknown
		jsr 	CallErrorHandler
		.text 	"NO SYMBOL FILE FOR {}", 0

_APBUnknown:
		jsr 	CallErrorHandler
		.text 	"UNKNOWN VARIABLE IN {}", 0


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

AsmPoolLen:
		.fill 	2
AsmPoolBase:
		.fill 	2 						; where the pool landed within the object
AsmBlobStart:
		.fill 	2 						; pool offset of the blob being assembled
AsmNewKind: 							; one fixup, built here before it is banked
		.fill 	1
AsmNewTarget:
		.fill 	2
AsmNewValue:
		.fill 	2
AsmByte:
		.fill 	1 						; one pool byte, carried out of the window
AsmKind:
		.fill 	1 						; the fixup being resolved
AsmFixupCount:
		.fill 	1
AsmFixIdx:
		.fill 	1
AsmPageDelta:
		.fill 	1
AsmWorkspacePage: 						; where the variables land -- newWorkspacePage
		.fill 	1
AsmName:
		.fill 	ASM_NAME_LEN 			; the identifier just read
;
;		{VAR}'s two names. AsmSymName is what the REM says, AsmSymCrunched what BASLOAD renamed
;		it to. THE APPLICATION WRITES THE SECOND ONE (BLC_SYMLOOKUP): it can see these because
;		it links the compiler library, which is the direction that works -- compiler code
;		naming an application symbol is what breaks the standalone build.
;
AsmSymName:
		.fill 	ASM_SYM_MAX+1 			; the name as written, folded to upper case, terminated
AsmSymCrunched:
		.fill 	4 						; one or two characters and a terminator
AsmSymType:
		.fill 	1 						; NSSString / NSSIInt16, plus NSSArray for {N()}
AsmLineStart:
		.fill 	2 						; srcPtr before it, to wind back a mnemonic
AsmLabelCount:
		.fill 	1
AsmLabelIdx:
		.fill 	1
AsmLabelRef: 							; the label this operand refers to
		.fill 	1
AsmLocalCount:
		.fill 	1
AsmLocalIdx:
		.fill 	1
AsmIsLabel:
		.fill 	1
AsmIsVar:
		.fill 	1
AsmOperandAt: 							; pool offset of the operand being emitted
		.fill 	2
AsmOperandLen:
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
