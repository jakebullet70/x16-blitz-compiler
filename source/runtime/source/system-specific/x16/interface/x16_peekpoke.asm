; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_peekpoke.asm
;		Purpose:	Read/Write memory
;		Created:	20th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;											Write Memory
;
; ************************************************************************************************

XPokeMemory:
		stx 	zTemp0
		sty 	zTemp0+1

		ldy 	SelectRAMBank 				; old RAM bank in Y
		ldx 	ramBank 					; switch to BANKed RAMBank if not $FF
		cpx 	#$FF
		beq 	_XPMNoSwitch
		stx 	SelectRAMBank
_XPMNoSwitch:
		sta 	(zTemp0) 					; do the POKE
		sty 	SelectRAMBank 				; reselect previous RAM Bank.		
_XPMExit:
		rts

; ************************************************************************************************
;
;											Read Memory
;
; ************************************************************************************************

;		$C000-$FFFF reads the ROM bank BANK chose, 0 (KERNAL) by default, as X16 BASIC does.

XPeekMemory:
		stx 	zTemp0
		sty 	zTemp0+1
		cpy 	#$C0
		bcs 	_XPMReadROM

		ldy 	SelectRAMBank 				; old RAM bank in Y
		ldx 	ramBank 					; switch to BANKed RAMBank if not $FF
		cpx 	#$FF
		beq 	_XPMNoSwitch
		stx 	SelectRAMBank
_XPMNoSwitch:
		lda 	(zTemp0) 					; do the PEEK
		sty 	SelectRAMBank 				; reselect previous RAM bank.
		rts

_XPMReadROM:
		php
		sei
		ldy 	SelectROMBank 				; old ROM bank in Y
		lda 	romBank
		sta 	SelectROMBank
		lda 	(zTemp0)
		sty 	SelectROMBank
		plp
		rts


; ************************************************************************************************
;
;											BANK command
;
; ************************************************************************************************

CommandBank: ;; [!bank]
		.entercmd
		lda 	NSMantissa0 				; RAM bank
		sta 	ramBank 					; store & make current
		sta 	SelectRAMBank
		lda 	NSMantissa0+1 		 		; ROM specified 
		cmp 	#$FF
		beq 	_CBNoUpdate
		sta 	romBank 					; PEEK and SYS select it for $C000-$FFFF
_CBNoUpdate:		
		ldx 	#$FF
		.exitcmd

		.send code

		.section storage
ramBank:
		.fill 	1
romBank:
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
