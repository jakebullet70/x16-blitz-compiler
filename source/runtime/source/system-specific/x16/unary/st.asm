; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		st.asm
;		Purpose:	ST, the KERNAL status byte
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		ST is not a keyword and never gets tokenised -- like TI and TI$ it is a RESERVED VARIABLE
;		NAME, so it reaches the compiler as a plain identifier and is intercepted in FindVariable.
;
;		It exists because LINPUT#, BINPUT# and INPUT# have no other way to say "that was the end
;		of the file". Without it a read loop cannot terminate: at EOF LINPUT# hands back an empty
;		string, which is indistinguishable from a blank line in the file, and the program spins.
;
;			ST and  16 = verify mismatch (BVERIFY)
;			ST and  64 = end of file
;			ST and 128 = device not present
;
; ************************************************************************************************

		.section 	code

UnaryST: ;; [!st]
		.entercmd
		phx 								; READST is documented as only touching A, but the
		phy 								; float stack pointer is not worth gambling on
		jsr 	X16_READST
		ply
		plx
		inx 								; ST reads as a value, so it pushes one
		jsr 	FloatSetByte
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
;
; ************************************************************************************************
