; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		reset.asm
;		Purpose:	Reset information storage
;		Created:	15th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								Reset the storage (variables,line#)
;
; ************************************************************************************************

STRReset:

		lda	 	compilerStartHigh 			; set up the two table pointers
		sta 	variableListEnd+1
		stz 	variableListEnd

		lda 	compilerEndHigh
		sta 	lineNumberTable+1
		stz 	lineNumberTable

		.storage_access 					; clear the head of the work area list.

		;
		;		This read the LOW byte of variableListEnd (just zeroed two lines above) into the
		;		HIGH byte of zTemp0, so it wrote its terminator to $0000 -- on the X16 that is the
		;		RAM BANK register, not the table -- and left the real head at compilerStartHigh:$00
		;		holding whatever was there. It only ever appeared to work because the head happens
		;		to be zero on a cold boot; a second compile in the same session inherited the first
		;		compile's list. FindVariable walks from the head, so a non-zero byte there sends it
		;		off through garbage records.
		;
		lda 	variableListEnd+1
		sta 	zTemp0+1
		stz 	zTemp0
		lda 	#0
		sta 	(zTemp0)

		.storage_release
		.set16 freeVariableMemory,0 		; clear the free variable memory record.
		rts
		.send code

		.section storage
lineNumberTable:							; line number table, works down.
		.fill 	2		
variableListEnd:							; known variables, works up.
		.fill 	2	
freeVariableMemory: 						; next free memory slot
		.fill 	2
storageScratch: 							; one byte of working space for the table-collision
		.fill 	1 							; test in CreateVariableRecord (X and Y are busy there)
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
