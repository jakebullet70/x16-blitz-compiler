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
;			2. if not, LOADs GPC.RT.nnn.BIN to its own home (RTBASE) with secondary address 1,
;			   trying the current directory first and then the root of the SD card;
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
		;		Cold: LOAD the runtime to its own home. Try the CURRENT DIRECTORY first, then the
		;		ROOT of the SD card -- a program run from its own folder finds a runtime sitting
		;		beside it, and otherwise falls back to one copy kept at the root, so every folder
		;		on the card does not need its own 11K duplicate. A leading "/" is what addresses
		;		the root (measured on R49 from inside a subdirectory: "GPC.RT.001.BIN" is not
		;		found, "/GPC.RT.001.BIN" loads). The two names overlap in one string -- BBNameRoot
		;		is just BBName with the "/" in front of it.
		;
		lda 	#BBNameEnd-BBName 			; local: "GPC.RT.001.BIN"
		ldx 	#<BBName
		ldy 	#>BBName
		jsr 	BBTryLoad
		bcc 	_BBEnter 					; carry clear = loaded OK
		lda 	#BBNameEnd-BBNameRoot 		; root: "/GPC.RT.001.BIN"
		ldx 	#<BBNameRoot
		ldy 	#>BBNameRoot
		jsr 	BBTryLoad
		bcc 	_BBEnter
		;
		;		Neither copy is on the disk. Print a short notice and drop back to BASIC READY --
		;		no runtime is up, so there is no runtime error path to take.
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

; ------------------------------------------------------------------------------------------------
;		Try to LOAD the runtime under the name in A (length) / X,Y (address). Secondary address 1
;		makes the KERNAL honour the file's own load address (RTBASE), ignoring the address in X/Y.
;		Logical file 0 (file 1 has been seen to hang a later OPEN). Loading high never touches
;		$0801 or the p-code, so this bootstrap survives its own load. Returns carry clear on
;		success, set if the file is not there -- so the caller can just try the next name.
;
;		Sits BELOW _BBEnter deliberately: labels beginning with "_" are local to the enclosing
;		scope in 64tass, and a global label placed between _BBCold and _BBEnter would split that
;		scope in two, leaving the earlier branches referring to an _BBEnter they can no longer see.
; ------------------------------------------------------------------------------------------------
BBTryLoad:
		jsr 	X16_SETNAM 					; SETNAM(length in A, name in X/Y)
		lda 	#0 							; SETLFS(logical file 0, device 8, secondary 1)
		ldx 	#8
		ldy 	#1
		jsr 	X16_SETLFS
		lda 	#0 							; LOAD into system memory
		ldx 	#<RTBASE 					; load address (ignored under SA=1, but pass the home)
		ldy 	#>RTBASE
		jmp 	X16_LOAD 					; its carry is our carry

		;
		;		TWO different numbers here, deliberately, because they answer two questions:
		;
		;		  the MAGIC carries RT_ABI -- "is a runtime already resident, and is it one I can
		;		  enter?" That is an ABI-compatibility question, so it moves only when the layout
		;		  or entry contract changes, and a resident runtime from any build of the same ABI
		;		  is safely reused.
		;
		;		  the FILE NAME carries the engine's BUILD number -- "which runtime file is mine?"
		;		  That pins a compiled program to the exact runtime it was built against.
		;
		;		Both come from a single definition (RT_ABI in common.inc, BuildNumber generated
		;		into version.asm by bumpbuild.py) rather than being spelled out here, so this copy
		;		cannot drift from the runtime's own or from what rtname.py builds.
		;
		;		NOTE the build number bumps on EVERY engine build, so the name changes every
		;		build: a program compiled against build N wants GPC.RT.<N>.BIN specifically and
		;		will ?RT against a later one. That is the point -- exact pairing -- but it does
		;		mean shared programs must be recompiled whenever the engine is rebuilt.
		;
		.cerror RT_ABI > 99, "RT_ABI > 99: the magic's last two bytes are ASCII digits - widen it here and in 00rt.header"
BBMagic:
		.text 	"GP"						; magic, matched against RTBASE..RTBASE+1
		.byte 	(RT_ABI / 10) + '0' 		; ABI ordinal, two digits, matched against RTBASE+2..3
		.byte 	(RT_ABI - (RT_ABI / 10) * 10) + '0'
		;
		;		One string, two names: the root form is the local form with a "/" in front, so the
		;		fallback costs a single byte rather than a second copy of the name. The name is
		;		formatted, not spelled out, so a build number of any width still comes out right.
		;
BBNameRoot:
		.text 	"/"
BBName:
		.text 	format("GPC.RT.%03d.BIN", BuildNumber)
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
