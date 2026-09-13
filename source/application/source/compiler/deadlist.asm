; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		deadlist.asm
;		Purpose:	Write the removed-line list GPC.INPUT line 5 names
;		Created:	13th September 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************
;
;		One decimal line number a line, LF-terminated like the map, in source order. The list
;		is every line the compile left out: each line nothing reaches, and the lines a GP.ASM
;		or GP.BANKEDSTR block read for itself when its opener was left out with it. Deleting
;		exactly these lines from the source and compiling with the option off gives the same
;		object -- source/unit-tests/dcstrip.py is that test.
;
;		Pass one wrote the numbers into the edge bank as it skipped each line (deadcode.asm,
;		DCListLine). The edges were finished with at the end of pass zero, and nothing else
;		uses that bank.
;
;		An empty file when nothing was removed, including when a table filled: the file says
;		the option ran.
;
; ************************************************************************************************

		.section code

WriteDeadList:
		lda 	DeadListFile 				; no fifth line -> no list asked for
		bne 	_WDLStart
		rts
_WDLStart:
		ldx 	#DeadListFile & $FF
		ldy 	#DeadListFile >> 8
		jsr 	IOOpenWrite
		stz 	deadWalk
		stz 	deadWalk+1
_WDLLoop:
		lda 	deadWalk
		cmp 	dcListCount
		lda 	deadWalk+1
		sbc 	dcListCount+1
		bcs 	_WDLDone
		;
		;		Two bytes a number, so the index doubled. The list holds at most 4,096, so the
		;		doubled high byte is under $20 and the carry into the page add is clear.
		;
		lda 	deadWalk
		asl 	a
		sta 	zTemp0
		lda 	deadWalk+1
		rol 	a
		clc
		adc 	#DCListTable >> 8
		sta 	zTemp0+1
		.dcedge_access
		lda 	(zTemp0)
		sta 	mapValue
		ldy 	#1
		lda 	(zTemp0),y
		sta 	mapValue+1
		.dcedge_release
		jsr 	IOWriteDecimal 				; the map writer's decimal, which writes mapValue
		lda 	#10
		jsr 	IOWriteByte
		inc 	deadWalk
		bne 	_WDLLoop
		inc 	deadWalk+1
		bra 	_WDLLoop
_WDLDone:
		jmp 	IOWriteClose

deadWalk: 									; the number being written
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
;		13/09/26		Written.
;
; ************************************************************************************************
