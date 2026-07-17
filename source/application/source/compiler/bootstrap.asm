; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		bootstrap.asm
;		Purpose:	Per-program bootstrap streamed into a "resident runtime" (SHARED) compile.
;		Created:	17th July 2026
;		Reviewed: 	No
;
; ************************************************************************************************
; ************************************************************************************************
;
;		When GPC.INPUT's 4th line selects SHARED mode, a compiled program carries NO embedded
;		runtime. Instead WriteObjectCode (object.asm) streams this template as the program's first
;		255 bytes ($0801..$08FF), followed by the p-code at $0900. On RUN, BASIC's SYS 2069 enters
;		BootEntry, which:
;
;			1. checks the 4-byte magic at RTBASE -- is the shared runtime already resident?
;			2. if not, LOADs GPC.RT.BIN to its own home ($7300) with secondary address 1;
;			3. enters the resident runtime at RT_ENTRY, handing it this program's p-code page,
;			   workspace start (patched per program) and workspace end.
;
;		So any program brings the runtime up if it is missing, and reuses it if it is already
;		there -- one runtime on disk, loaded once in memory.
;
;		This template runs at $0801 but is STORED up in compiler space (it is globbed into the
;		application _library.asm, linked above ObjectBase). `.logical $0801 ... .here` makes 64tass
;		resolve every label inside to $08xx while placing the physical bytes in compiler space, so
;		the streamed bytes are correct for execution at $0801 after reload. object.asm streams from
;		the PHYSICAL labels ProgramBootstrap..ProgramBootstrapEnd and patches the one WS_START byte
;		at BootWSPatchOffset. The compiler's own $0801 entry (00main.header) is untouched -- this is
;		inert data the compiler only writes to disk, never executes.
;
; ************************************************************************************************

		.section code

ProgramBootstrap: 							; PHYSICAL label (compiler space) -- object.asm streams here
		.logical $0801

; ------------------------------------------------------------------------------------------------
;		BASIC stub -- byte-identical to StartBasicProgram (00main.header): 10 SYS 2069:REM GPC!
; ------------------------------------------------------------------------------------------------
		.word 	$0813 						; link -> the end-of-program marker at $0813
		.word 	10 							; line number
		.byte 	$9E 						; SYS token
		.text 	' 2069' 					; space, $0815 in decimal
		.byte 	$3A 						; ':' statement separator
		.byte 	$8F 						; REM token
		.text 	' GPC!' 					; compiler signature -- shows on LIST
		.byte 	0 							; end of line
		.word 	0 							; end of program

; ------------------------------------------------------------------------------------------------
;		SYS 2069 lands here ($0815).
; ------------------------------------------------------------------------------------------------
BootEntry:
		.cerror BootEntry != $0815, "bootstrap SYS entry is not at $0815 -- BASIC stub size drifted"
		;
		;		Is the shared runtime already resident? Compare the 4 magic bytes at RTBASE.
		;
		ldx 	#3
_BBCheck:
		lda 	RTBASE,x
		cmp 	BBMagic,x
		bne 	_BBCold
		dex
		bpl 	_BBCheck
		bra 	_BBEnter 					; WARM -- runtime already up, just enter it
_BBCold:
		;
		;		Cold: LOAD GPC.RT.BIN to its own home. Secondary address 1 makes the KERNAL honour
		;		the file's own load address ($7300), ignoring the address in X/Y. Logical file 0
		;		(file 1 has been seen to hang a later OPEN). Loading high never touches $0801 or the
		;		p-code, so this bootstrap survives its own load.
		;
		lda 	#BBNameEnd-BBName 		; SETNAM(length, name)
		ldx 	#<BBName
		ldy 	#>BBName
		jsr 	X16_SETNAM
		lda 	#0 							; SETLFS(logical file 0, device 8, secondary 1)
		ldx 	#8
		ldy 	#1
		jsr 	X16_SETLFS
		lda 	#0 							; LOAD into system memory
		ldx 	#<RTBASE 					; load address (ignored under SA=1, but pass the home)
		ldy 	#>RTBASE
		jsr 	X16_LOAD
		bcc 	_BBEnter 					; carry clear = loaded OK
		;
		;		Load failed (GPC.RT.BIN not on the disk). Print a short notice and drop back to
		;		BASIC READY -- no runtime is up, so there is no runtime error path to take.
		;
		ldx 	#0
_BBErr:
		lda 	BBErrText,x
		beq 	_BBErrDone
		phx
		jsr 	X16_CHROUT
		plx
		inx
		bne 	_BBErr
_BBErrDone:
		rts 								; return to the SYS caller -> BASIC READY

; ------------------------------------------------------------------------------------------------
;		Hand off to the resident runtime. Both cold and warm paths funnel through here, so the
;		SYS return address is preserved on the stack -- an END in the program RTSes cleanly back
;		to BASIC, exactly as an embedded program does.
; ------------------------------------------------------------------------------------------------
_BBEnter:
		lda 	#PCODE_PAGE 				; A = p-code base page ($09), page-aligned for codePtr
BootWS:
		ldx 	#$FF 						; X = workspace start page -- PATCHED by WriteObjectCode
		ldy 	#RTBASE >> 8 				; Y = workspace end page ($73 -- just below the runtime)
		jmp 	RT_ENTRY 					; RTBASE+4 -> jmp StartRuntime

BBMagic:
		.text 	"GPC1" 						; MUST match the magic in runtime/source/main/00rt.header
BBName:
		.text 	"GPC.RT.BIN"
BBNameEnd:
BBErrText:
		.text 	"?RT", 13, 0 				; brief -- a full line would wrap in 40 columns

		.fill 	$0900 - *, 0 				; pad through $08FF so the p-code starts exactly at $0900

		.here
ProgramBootstrapEnd: 						; PHYSICAL end -- (End - Start) == 255 bytes ($0801..$08FF)

BootWSPatchOffset = BootWS + 1 - $0801 		; offset of the WS_START operand within the streamed bytes

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
