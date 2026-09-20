; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		create.asm
;		Purpose:	Create variable.
;		Created:	25th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;		  		   XYmake  contains a variable name. Allocate space for it and create it. 
;										Return variable address in YX
;
; ************************************************************************************************

		.section code

CreateVariableRecord:
		pha

		;
		;		Room for another 6-byte record plus the end marker before the list runs off the
		;		top of its window? STRMarkLine makes the mirror-image test on the line table.
		;		Neither existed, so the two tables quietly overwrote each other on a big program.
		;
		;		THIS USED TO TEST AGAINST lineNumberTable, because the two tables shared one 8K
		;		bank and grew towards each other -- so a program with many lines ran the variable
		;		list out of room and vice versa. They have a bank each now (x16_storage.inc), so
		;		the limit is this table's own window end and nothing the line table does can move
		;		it. That is 1,365 records.
		;
		;		X and Y hold the variable NAME here and are read further down, so this may only
		;		use A -- hence the scratch byte rather than the obvious tay.
		;
		clc
		lda 	variableListEnd
		adc 	#7
		sta 	storageScratch
		lda 	variableListEnd+1
		adc 	#0
		cmp 	compilerEndHigh 			; end + 7 must be <= CompilerWorkspaceEnd, so on the
		bcc 	_CVRoom 					; high byte matching, the low byte has to be exactly 0
		bne 	_CVTooBig 					; -- the record ends flush with the top of the bank.
		lda 	storageScratch
		beq 	_CVRoom
_CVTooBig:
		.error_toobig
_CVRoom:

		.varstore_access

		lda 	freeVariableMemory 		; push current free address on stack.
		pha
		lda 	freeVariableMemory+1
		pha

		lda 	variableListEnd  		; copy end of list to zTemp0
		sta 	zTemp0	
		lda 	variableListEnd+1
		sta 	zTemp0+1

		lda 	#6 						; default size if 6 (offset link 3 bytes)
		sta 	(zTemp0)

		tya
		ldy 	#2 						; write out the name.
		sta 	(zTemp0),y
		dey
		txa
		sta 	(zTemp0),y

		ldy 	#3 						; write out the address.
		lda 	freeVariableMemory
		sta 	(zTemp0),y
		iny
		lda 	freeVariableMemory+1
		sta 	(zTemp0),y

		ldy 	#6 						; write EOL marker next record.
		lda 	#0
		sta 	(zTemp0),y

		clc
		lda 	(zTemp0) 				; add offset to variableListEnd
		adc  	variableListEnd
		sta 	variableListEnd
		bcc 	_CVNoCarry2
		inc 	variableListEnd+1
_CVNoCarry2:		
		.varstore_release
		ply 							
		plx
		pla
		rts

; ************************************************************************************************
;
;			Set the last defined variable record to the current code position.
;
; ************************************************************************************************

SetVariableRecordToCodePosition:
		.varstore_access
		pha
		phy
		ldy 	#3 							; store the position LOW-then-HIGH, the same address
		lda 	objPtr 						; order CreateVariableRecord uses (offset 3 = low,
		sta 	(zTemp0),y 					; offset 4 = high). It used to be stored byte-swapped,
		iny 								; which FindVariable (X=[3], Y=[4]) then handed to the FN
		lda 	objPtr+1 					; call code with the bytes reversed -- so a called FN
		sta 	(zTemp0),y 					; jumped to a garbage address. FNCompile is the only reader.
		ply
		pla
		.varstore_release
		rts

; ************************************************************************************************
;
;									Allocate bytes for type A
;
; ************************************************************************************************

;
;		THE SCALAR WALL. A scalar access compiles to two bytes: GetSetVariable halves the
;		variable's offset from the workspace start and splits it over the operand byte and
;		the low three bits of the opcode, which the runtime's .vaddress macro reads back
;		with an and #7. Eleven bits of a halved offset reach 4,096 bytes and no further.
;
;		NOTHING USED TO CHECK IT. Past 4,096 the high byte of the halved offset ran on into
;		bit 3 of the opcode, which is the WRITE flag -- so a READ of a variable up there
;		compiled as a WRITE to the same variable minus 4,096, silently scribbling over an
;		early one, and the compile reported success. GPBMODS crossed the line at 4,400 bytes
;		and the damage landed on whichever early variable the source order happened to pair
;		it with, so the symptom moved every time the program was edited.
;
MaxVariableSpace = 4096 				; bytes of scalars a p-code operand can address

AllocateBytesForType:
		pha
		phx
		ldx 	#2 						; bytes to allocate
		and 	#NSSTypeMask+NSSIInt16
		cmp 	#NSSIFloat
		bne 	_CVNotFloat
		ldx 	#6
_CVNotFloat:
		txa 							; add 6 or 2 to the free memory pointer.
		clc
		adc 	freeVariableMemory
		sta 	freeVariableMemory
		bcc 	_CVNoCarry1
		inc 	freeVariableMemory+1
_CVNoCarry1:				
		;
		;		The variable just allocated ENDS at freeVariableMemory, so the test is
		;		<= MaxVariableSpace: a two byte slot may start at 4,094 and finish flush
		;		with the wall. Checked here, at the crossing, so the error names the line
		;		where the variable that went over is first used.
		;
		lda 	freeVariableMemory+1
		cmp 	#>MaxVariableSpace
		bcc 	_CVSpaceLeft
		bne 	_CVNoSpace
		lda 	freeVariableMemory
		bne 	_CVNoSpace
_CVSpaceLeft:
		plx
		pla
		rts
_CVNoSpace:
		;
		;		THE MESSAGE LIVES HERE, in compiler space, not in errors.asm: that table
		;		links below GPBase and is copied into every compiled program, so a string
		;		there would cost bytes to every program that never comes near the limit.
		;		Same trick as gpbank.asm's _GBRTooBig.
		;
		jsr 	CallErrorHandler
		.text 	"TOO MANY VARIABLES", 0


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
