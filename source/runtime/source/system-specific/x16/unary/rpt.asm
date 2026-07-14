; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		rpt.asm
;		Purpose:	RPT$()
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		RPT$(<byte>,<count>) is CHR$ with a repeat count, and it is built the same way: allocate
;		a temp string of the right length, write the length byte, then fill it.
;
;		StringAllocTemp puts the new string's address into S[X], so the dex below is what makes
;		the result land in the FIRST argument's slot, which is where a function's result belongs.
;
; ************************************************************************************************

		.section 	code

UnaryRPT: ;; [!rpt$]
		.entercmd
		;
		;		The count is the last argument. It cannot go through GetInteger8Bit, which just
		;		takes the low byte of the mantissa -- RPT$(65,300) would quietly hand back 44
		;		characters instead of complaining. Stock raises ?ILLEGAL QUANTITY for a count of
		;		zero as well, rather than returning an empty string, so zero is an error too.
		;
		.floatinteger
		lda 	NSStatus,x 					; negative
		bmi 	_URPTRange
		lda 	NSMantissa1,x 				; or too big to be a byte
		ora 	NSMantissa2,x
		ora 	NSMantissa3,x
		bne 	_URPTRange
		lda 	NSMantissa0,x
		beq 	_URPTRange 					; or zero
		sta 	rptCount

		dex 								; X now addresses the character -- and that is also
		jsr 	GetInteger8Bit 				; the slot the result has to be left in
		sta 	rptChar

		lda 	rptCount
		jsr 	StringAllocTemp 			; address into zsTemp, and into S[X] as the result
		lda 	rptCount
		sta 	(zsTemp) 					; the length byte comes first

		phy 								; Y is the code position
		ldy 	rptCount
_URPTFill:
		lda 	rptChar
		sta 	(zsTemp),y
		dey
		bne 	_URPTFill
		ply
		.exitcmd

_URPTRange:
		.error_range

		.send 	code

		.section storage
rptCount:
		.fill 	1
rptChar:
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
