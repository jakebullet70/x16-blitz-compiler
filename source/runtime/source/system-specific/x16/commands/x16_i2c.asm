; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		x16_i2c.asm
;		Purpose:	I2C Peek/Poke
;		Created:	9th May 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

		.section code

; ************************************************************************************************
;
;								I2CPOKE device,register,value
;
; ************************************************************************************************

X16I2CPoke: ;; [!I2CPOKE]
		.entercmd
		phy
		jsr 	GetInteger8Bit 				; value
		pha
		dex
		jsr 	GetInteger8Bit 				; register
		pha
		dex
		jsr 	GetInteger8Bit 				; device
		tax 			
		ply
		pla
		jsr 	X16_i2c_write_byte 			; write the byte out.
		bcs 	X16I2CError
		ply
		ldx 	#$FF
		.exitcmd

X16I2CError:
		.error_channel

; ************************************************************************************************
;
;								POWEROFF and REBOOT
;
;		Both are a single I2C write to the System Management Controller, which is what X16
;		BASIC does for them. Neither takes a parameter, so X arrives as $FF (empty stack) and
;		only has to be put back that way after we borrow it for the device number.
;
; ************************************************************************************************

X16_SMC_Device = $42 						; the SMC's I2C address
X16_SMC_PowerOff = 1 						; offset 1 : power down
X16_SMC_Reset = 2 							; offset 2 : reset

X16CommandPowerOff: ;; [!poweroff]
		.entercmd
		phy
		ldy 	#X16_SMC_PowerOff
		bra 	X16SMCWrite

X16CommandReboot: ;; [!reboot]
		.entercmd
		phy
		ldy 	#X16_SMC_Reset

X16SMCWrite: 								; global, not a cheap local: POWEROFF branches here
		ldx 	#X16_SMC_Device 			; from its own scope, and _locals do not cross one.
		lda 	#0
		jsr 	X16_i2c_write_byte
		bcs 	X16I2CError
		ply 								; the write returns, and the SMC only cuts power a
		ldx 	#$FF 						; moment later, so we do carry on running until it
		.exitcmd 							; does. Tidy up properly rather than assume we die here.

; ************************************************************************************************
;
;									I2CPEEK(device,register)
;
; ************************************************************************************************

X16I2CPeek: ;; [!I2CPEEK]		
		.entercmd
		phx
		phy
		jsr 	GetInteger8Bit 				; register
		pha
		dex
		jsr 	GetInteger8Bit 				; device
		tax 								; X device
		ply 								; Y register
		jsr 	X16_i2c_read_byte 			; read I2C
		bcs 	X16I2CError
		ply 								; restore Y/X
		plx
		dex 								; drop TOS (register)
		jsr 	FloatSetByte 				; write read value to TOS.
		.exitcmd

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
