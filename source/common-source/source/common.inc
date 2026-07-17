; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		common.inc
;		Purpose:	Common includes/defines/setups
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;										Configuration options
;
;			  Addresses should be on page boundaries (except for ZeroPageMandatory)
;
; ************************************************************************************************
;
;		Where to assemble the runnable code. Happy now , Dave ?
;
;		Weak so the standalone resident-runtime build (GPC.RT.BIN) can override it to RTBASE with
;		-D CodeStart=$7300 on the command line; every other build keeps $801.
;
		.weak
CodeStart = $801
		.endweak
;
;		Variables that have to be in zero page because it's used in (xx),y
;
ZeroPageMandatory = $22
;
;		Variables that can go anywhere
;
MemoryStorage = $400
;
;		Resident-runtime (GPC.RT.BIN) ABI -- see application/source/compiler/bootstrap.asm and
;		runtime/source/main/00rt.header. RTBASE is the fixed home the standalone runtime is linked
;		at and loaded to; a shared-mode program's bootstrap checks the magic there, loads it if
;		absent, and enters at RT_ENTRY. RTBASE is PINNED (baked into every shared program's
;		bootstrap), so it is an ABI constant, not auto-computed; zzrt.footer guards it against the
;		runtime outgrowing $9F00.
;
RTBASE = $7300 								; resident runtime home ($7300..$9EFF, ~11K)
RT_ENTRY = RTBASE+4 						; 4-byte magic at RTBASE, then jmp StartRuntime
PCODE_PAGE = $09 							; shared-mode p-code base page ($0900, page-aligned)
MIN_WS_PAGES = 16 							; smallest workspace a shared program keeps (4K)

; ************************************************************************************************
;
;									Set up code and data sections
;
; ************************************************************************************************

		* = ZeroPageMandatory 				; *must* be in zero page
		.dsection zeropage

		* = MemoryStorage 					; doesn't matter if zero page or not
		.dsection storage
StorageEnd:

		* = CodeStart
		.dsection code

;
;		storage is a 1K hole -- $0400 to $0801, and no further, because the code starts there.
;		Nothing warns you when it runs out: the section simply carries on over the top of the
;		BASIC stub, and the program corrupts itself the first time it writes to the buffer that
;		spilled. It HAD run out, silently, and only survived because the one buffer hanging over
;		the edge was never filled past its fifteenth byte. So say so, loudly.
;
		.cerror StorageEnd > CodeStart, "storage has overflowed into the code - put compiler-only buffers in the code section (see application/source/file-io/read.asm)"

; ************************************************************************************************
;
;										Zero Page Common Usage
;
; ************************************************************************************************

		.section zeropage

codePtr:	 								; address of current line.
		.fill 	2

objPtr: 									; address in code. 
		.fill 	2 							

zTemp0: 									; temporary words used in the interpreter.
		.fill 	2
zTemp1:
		.fill 	2
zTemp2:
		.fill 	2

		.endsection

; ************************************************************************************************
;
;							Insert an Emulator Breakpoint
;
; ************************************************************************************************

debug 		.macro
		.byte 	$DB 						; causes a break in the emulator
		.endm

; ************************************************************************************************
;
;								Set a 2 byte value in memory
;
; ************************************************************************************************

set16 		.macro
		lda 	#((\2) & $FF)
		sta 	0+\1
		lda 	#((\2) >> 8) & $FF
		sta 	1+\1
		.endm

; ************************************************************************************************
;
;										Exit emulation
;
; ************************************************************************************************

exitemu .macro
		stx 	zTemp0
		jmp 	$FFFF
		.endm

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
