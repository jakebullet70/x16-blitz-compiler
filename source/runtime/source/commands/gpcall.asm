; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		gpcall.asm
;		Purpose:	GP.CALL and the register readers GP.A / GP.X / GP.Y / GP.C
;		Created:	16th August 2026
;		Reviewed: 	No
;		Author : 	Steven De George SR
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;						<Addr> <A> <X> <Y> <C> GP.CALL
;
;		Call machine code with the registers set from arguments, and read the results back with
;		GP.A / GP.X / GP.Y / GP.C. What it removes is the POKE/SYS/PEEK dance:
;
;			POKE $30C,65 : POKE $30D,0 : SYS 49152 : A=PEEK($30C)      becomes
;			GP.CALL 49152,65,0 : A=GP.A
;
;		It shares SYS's storage at $030C-$030F deliberately, so the two interoperate and PEEK
;		still reads what either of them left behind.
;
;		A, X, Y and C are all optional and DEFAULT TO ZERO. Zero needs no sentinel -- there is
;		nothing here that has to test for "omitted", because an unspecified register genuinely is
;		0 -- and 0 compiles to a one byte short constant, so omitting costs less than supplying.
;		Contrast GP.STASH's geometry, where 255 had to be a real sentinel.
;
;		CARRY IN is set with LSR rather than PLP. SYS pushes a whole status byte and PLPs it,
;		which also writes I and D -- clearing the interrupt disable inside a routine that had set
;		it. LSR moves bit 0 of the argument into carry and touches nothing else, and LDA/LDX/LDY
;		do not affect carry, so the registers can be loaded afterwards without disturbing it.
;
; ************************************************************************************************

CommandGPCall: ;; [!gp.call]
		.entercmd
		phy 								; Y is the code pointer offset -- needed after the call
		;
		;		Arguments were pushed left to right, so TOS is the LAST of them.
		;
		lda 	NSMantissa0,x 				; C -- parked in SYS_Reg_S, which the result overwrites
		sta 	SYS_Reg_S
		dex
		lda 	NSMantissa0,x 				; Y
		sta 	SYS_Reg_Y
		dex
		lda 	NSMantissa0,x 				; X
		sta 	SYS_Reg_X
		dex
		lda 	NSMantissa0,x 				; A
		sta 	SYS_Reg_A
		dex
		;
		jsr 	FloatIntegerPart 			; the address itself
		lda 	NSMantissa0,x
		sta 	zTemp0
		lda 	NSMantissa1,x
		sta 	zTemp0+1
		dex 								; drop the address
		phx 								; the float stack pointer is X, and X is an argument
		;
		lda 	SYS_Reg_S 					; carry from bit 0, leaving I and D alone
		lsr 	a
		ldx 	SYS_Reg_X 					; LD* do not affect carry
		ldy 	SYS_Reg_Y
		lda 	SYS_Reg_A
		jsr 	_CGCCall
		;
		php 								; results, status included, for GP.C
		sta 	SYS_Reg_A
		stx 	SYS_Reg_X
		sty 	SYS_Reg_Y
		pla
		sta 	SYS_Reg_S
		;
		plx
		ply
		.exitcmd

_CGCCall:
		jmp 	(zTemp0)

; ************************************************************************************************
;
;					GP.A / GP.X / GP.Y / GP.C -- read back what GP.CALL returned
;
;		Value words taking no argument, exactly as ST/MX/MY are, so they push a value rather than
;		consuming one -- hence the INX. Left UNSHIFTED on purpose: these are read inside loops
;		where 41 cycles against 58 and one byte against two is the whole point of having them
;		instead of PEEK. GP.CALL itself is shifted, like SYS, because a machine code call dwarfs
;		its own dispatch.
;
; ************************************************************************************************

UnaryGPA: ;; [gp.a]
		.entercmd
		lda 	SYS_Reg_A
GPRegPush:
		inx 								; reads as a value, so it pushes one
		jsr 	FloatSetByte
		.exitcmd

UnaryGPX: ;; [gp.x]
		.entercmd
		lda 	SYS_Reg_X
		bra 	GPRegPush

UnaryGPY: ;; [gp.y]
		.entercmd
		lda 	SYS_Reg_Y
		bra 	GPRegPush

UnaryGPC: ;; [gp.c]
		.entercmd
		lda 	SYS_Reg_S 					; carry is bit 0 of the status byte
		and 	#1
		bra 	GPRegPush

		.send 	code

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;		16/08/26		Written.
;
; ************************************************************************************************
