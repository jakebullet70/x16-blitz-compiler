; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		machine.asm
;		Purpose:	POWEROFF, RESET and REBOOT
;		Created:	14th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		The three keywords that stop or restart the machine. They are not interchangeable, and it
;		is worth being exact about which is which, because two of them were the wrong way round
;		here. Read out of BASIC ROM bank 4 -- the extended keyword vector table is at $C0A0 and is
;		C64 style, so each entry holds its handler's address minus one:
;
;			POWEROFF	$E7BC	one I2C write, SMC $42 offset 1. Cuts the power.
;			RESET		$E7B8	one I2C write, SMC $42 offset 2. The SMC asserts the reset LINE,
;								so this is a HARD reset -- the same as the physical reset switch.
;			REBOOT		$E6EF	jmp ($FFFC). A SOFT reset: no hardware is reset at all, the KERNAL
;								simply starts again through its own reset vector.
;
;		REBOOT used to do RESET's I2C write, which made a compiled REBOOT hard reset the machine.
;		The manual agrees with the ROM on both, and it was this file that was wrong.
;
; ************************************************************************************************

		.section 	code

X16_SMC_Device = $42 						; the SMC's I2C address
X16_SMC_PowerOff = 1 						; offset 1 : cut the power
X16_SMC_Reset = 2 							; offset 2 : assert the reset line

; ************************************************************************************************
;
;									POWEROFF and RESET
;
;		One I2C write to the System Management Controller each, which is what BASIC does for them.
;		Neither takes a parameter, so X arrives as $FF (an empty stack) and only has to be put
;		back that way after we borrow it for the device number.
;
; ************************************************************************************************

X16CommandPowerOff: ;; [!poweroff]
		.entercmd
		phy
		ldy 	#X16_SMC_PowerOff
		bra 	X16SMCWrite

X16CommandReset: ;; [!reset]
		.entercmd
		phy
		ldy 	#X16_SMC_Reset

X16SMCWrite: 								; global, not a cheap local: POWEROFF branches here
		ldx 	#X16_SMC_Device 			; from its own scope, and _locals do not cross one.
		lda 	#0
		jsr 	X16_i2c_write_byte
		bcs 	X16SMCError
		ply 								; the write returns, and the SMC only acts a moment
		ldx 	#$FF 						; later, so we do carry on running until it does.
		.exitcmd 							; Tidy up properly rather than assume we die here.

X16SMCError:
		.error_channel

; ************************************************************************************************
;
;										REBOOT
;
;		A software reset, straight through the ROM's own reset vector.
;
;		The bank switch is not tidying up, it is the whole trick. $C000-$FFFF is banked, and only
;		bank 0 holds a real reset vector: bank 4, which is the one we are running under, has $AA
;		filler at $FFFA-$FFFF, so jmp ($FFFC) without the stz would jump to $AAAA. (Bank 4 gets
;		away with that because its $FF00 page is a table of trampolines into bank 0, which is also
;		why every KERNAL call in this runtime works without ever touching $01.)
;
;		BASIC cannot do these two instructions inline -- it IS the ROM it is banking away, so it
;		copies a six byte stub to $0100 and jumps to that. We run from RAM, so there is nothing to
;		pull out from under us and the stub is unnecessary.
;
;		No sei, for the same reason BASIC does not bother with one: the KERNAL's reset entry masks
;		interrupts itself, and until it does the IRQ vector still points somewhere valid.
;
; ************************************************************************************************

X16CommandReboot: ;; [!reboot]
		.entercmd
		stz 	SelectROMBank 				; bank 0 = KERNAL, the only bank with a reset vector
		jmp 	($FFFC) 					; and we do not come back

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
