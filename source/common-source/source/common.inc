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
;		Weak so the standalone resident-runtime build (GPC.RT.nnn.BIN) can override it to RTBASE
;		with -D CodeStart on the command line; every other build keeps $801.
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
;		Resident-runtime (GPC.RT.nnn.BIN) ABI -- see application/source/compiler/bootstrap.asm and
;		runtime/source/main/00rt.header. RTBASE is the fixed home the standalone runtime is linked
;		at and loaded to; a shared-mode program's bootstrap checks the magic there, loads it if
;		absent, and enters at RT_ENTRY. RTBASE is PINNED (baked into every shared program's
;		bootstrap), so it is an ABI constant, not auto-computed; zzrt.footer guards it against the
;		runtime outgrowing $9F00.
;
;
;		RTBASE moved $7300 -> $7000 on 31st July 2026 (RT_ABI 1 -> 2). The runtime had outgrown the
;		$9F00 I/O page by 447 bytes and zzrt.footer's guard had been failing the gpc-rt link for
;		some time -- shared mode could not be built at all. Three pages down frees 768 bytes and
;		leaves ~320 spare, at the cost of the same 768 bytes of per-program workspace (~3% of the
;		~26K a shared program gets). If it happens again, lower this and bump RT_ABI together.
;
RTBASE = $7000 								; resident runtime home ($7000..$9EFF, ~11.7K)
RT_ENTRY = RTBASE+4 						; 4-byte magic at RTBASE, then jmp StartRuntime
PCODE_PAGE = $09 							; shared-mode p-code base page ($0900, page-aligned)
MIN_WS_PAGES = 16 							; smallest workspace a shared program keeps (4K)
;
;		RT_ABI is the runtime's ABI ordinal, and it is the ONE place it is written down. It ends up
;		in three places that must agree, so none of them may hard-code it:
;
;			- the 4-byte magic at RTBASE ("GPC" + the digit), which the bootstrap compares to
;			  decide "is the runtime already resident?";
;			- the file name the runtime is BUILT as, GPC.RT.nnn.BIN (runtime/Makefile, via
;			  scripts/rtname.py, which parses the number back out of this line);
;			- the file name a compiled shared-mode program LOOKS FOR (bootstrap.asm).
;
;		Bump it whenever the runtime layout or entry ABI changes. Versioning the file name is what
;		makes the bump mean something: a program compiled against ABI n asks for GPC.RT.00n.BIN by
;		name, so an older or newer runtime sitting on the disk is simply not found, instead of
;		being loaded and jumped into. Programs and runtimes of different vintages can coexist.
;
RT_ABI = 2 									; runtime ABI ordinal -> "GPC2" magic, GPC.RT.002.BIN

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
