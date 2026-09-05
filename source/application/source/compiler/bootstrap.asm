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
;			2. if not, LOADs GPB/GPC.RT.nnn.BIN to its own home with secondary address 1,
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
		;
		;		The core is up. If this program uses no GPB keyword that is the whole question, but if
		;		it does it must ALSO find the handlers, and a core-only load leaves the core magic
		;		looking exactly the same. So check the second magic below RTBASE as well. Getting this
		;		wrong is not a crash here -- it is a jump into a workspace at the first GPB keyword.
		;
		;		The three per-program bytes are DATA at the end of this template, not immediates in the
		;		code. They have to be: a global label between a "_" branch and its target splits the
		;		local scope in two and the branch stops resolving -- the same trap BBTryLoad's own note
		;		describes, and it cost a build here.
		;
		lda 	BBNeedGP 					; 0 = no GPB keyword, 1 = uses them
		beq 	_BBEnter 					; WARM -- core is all this program needs
		ldx 	#3
_BBCheckGP:
		lda 	RTGPMAGIC,x
		cmp 	BBGPMagic,x
		bne 	_BBCold
		dex
		bpl 	_BBCheckGP
		bra 	_BBEnter 					; WARM -- handlers are up too
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
		;
		;		Which file: the FULL one (handlers + core, loads at RTGPBASE) if this program uses a
		;		GPB keyword, the CORE-ONLY one (loads at RTBASE) if it does not. Loading the full one
		;		always restores both magics, so a program that wanted handlers and found none simply
		;		loads over whatever core was there.
		;
		ldy 	#0 							; which triple: 0 = core only, 3 = full
		lda 	BBNeedGP 					; the same flag the warm check reads
		beq 	_BBPickName
		ldy 	#3
_BBPickName:
		sty 	BBNameIdx
		jsr 	BBLoadLocal
		bcc 	_BBEnter 					; carry clear = loaded OK
		jsr 	BBLoadRoot 					; else the copy at the root of the card
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
		;
		;		A core-only program is about to use the memory the GPB handlers occupy -- its workspace
		;		runs all the way up to RTBASE -- so it must first say so, by wiping RTGPMAGIC.
		;
		;		UNCONDITIONALLY, warm path included, and that is the whole point. It is not enough to
		;		wipe it when the core file is LOADED: the common sequence is a GPB program bringing the
		;		full runtime up, then a core-only program entering it warm and quietly overwriting the
		;		handlers, then a third program wanting them. Nothing was loaded in the middle of that,
		;		so a load-time wipe would never fire and the third program would enter handlers that
		;		had been eaten.
		;
		;		Nor is it safe to let the workspace overwrite the magic by chance: it sits in the top
		;		four bytes of that space, so whether it actually gets written depends on how much RAM
		;		the program uses. Handlers destroyed with the magic left standing is exactly the lie
		;		this check exists to prevent, so it is done on purpose rather than hoped for.
		;
		;		Cost is that the next GPB program always reloads. That is correct, not wasteful -- the
		;		handlers really were thrown away.
		;
		lda 	BBNeedGP
		bne 	_BBGo 						; a GPB program keeps them, and its workspace stops below them
		ldx 	#3
_BBZap:
		stz 	RTGPMAGIC,x 				; stz abs,x rather than lda #0 / sta abs,x -- two bytes, and
		dex 								; the padding below is where GP.BANKED's copy loop went
		bpl 	_BBZap
_BBGo:
		;
		;		A GP.BANKED region ships at the TOP of the p-code, page aligned, and belongs at
		;		$A000 in the bank the program named. Move it there and LEAVE THE BANK SELECTED:
		;		that window is where the code runs for the life of the program.
		;
		;		ONCE PER LOAD, NOT PER RUN. The workspace starts where the region was -- that is
		;		the whole point of putting it at the top -- so by the time a second RUN reaches
		;		here those bytes are variables and strings. Zeroing the page count makes the
		;		second RUN skip the copy and use what is already in the bank, which is still
		;		exactly what the first one put there.
		;
		;		THREE GLOBAL LABELS, not "_" ones. object.asm patches the source page straight
		;		into BBCodeSrc's operand as the template streams past, and it needs the address
		;		to do it. Everything that branches across them branches to a global too, for the
		;		scope reason BBTryLoad's own note gives.
		;
		ldx 	BBCodePages 				; 0 = this program has no banked region
		beq 	BBCodeSkip
		stz 	BBCodePages
		lda 	BBCodeBank
		sta 	$00
		ldy 	#0 							; and it stays 0 between pages -- the byte loop wraps
BBCodeSrc:
		lda 	$FF00,y 					; source page PATCHED
BBCodeDst:
		sta 	$A000,y
		iny
		bne 	BBCodeSrc
		inc 	BBCodeSrc+2
		inc 	BBCodeDst+2
		dex
		bne 	BBCodeSrc
BBCodeSkip:
		lda 	#PCODE_PAGE 				; A = p-code base page ($09), page-aligned for codePtr
		ldx 	BBWSStart 					; X = workspace start page
		ldy 	BBWSEnd 					; Y = workspace end page -- RTBASE>>8 for a program with no GPB
											; keyword, RTGPBASE>>8 for one with the handlers below it. That
											; difference is the whole point of the split: 2,560 bytes.
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
;
;		The four names live in ONE table of (length, lo, hi) triples -- local core, local full,
;		root core, root full -- so picking the file costs one patched byte instead of four copies
;		of the load sequence. X selects local (0) or root (6); BBNameSel adds 0 for core-only or
;		3 for full.
;
BBLoadLocal:
		ldx 	#0
		bra 	BBLoadX
BBLoadRoot:
		ldx 	#6
BBLoadX:
		txa
		clc
		adc 	BBNameIdx 					; 0 = core only, 3 = full -- set by the cold path above
		tax
		ldy 	BBNameTab+2,x 				; Y = name address high
		lda 	BBNameTab+1,x 				; stash the low byte while A is needed for the length
		pha
		lda 	BBNameTab,x 				; A = name length
		plx 								; X = name address low
											; ...and fall straight through: A/X/Y are now exactly what
											; SETNAM wants. The table used to sit between the two, and
											; the "bra BBTryLoad" that jumped it was two of the bytes
											; GP.BANKED's copy loop needed.
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

BBNameTab:
			.byte 	BBCoreEnd-BBCore, <BBCore, >BBCore 					; 0  local, core only
			.byte 	BBFullEnd-BBFull, <BBFull, >BBFull 					; 3  local, full
			.byte 	BBCoreEnd-BBCoreRoot, <BBCoreRoot, >BBCoreRoot 	; 6  root, core only
			.byte 	BBFullEnd-BBFullRoot, <BBFullRoot, >BBFullRoot 	; 9  root, full

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
		;		NOTE the runtime build number is PINNED (rtbuild.txt), not bumped per build -- it
		;		used to bump every time, which renamed the file out from under every already
		;		compiled shared program. Move it only to force a re-pairing, and recompile them
		;		all when you do.
		;
		.cerror RT_ABI > 99, "RT_ABI > 99: the magic's last two bytes are ASCII digits - widen it here and in 00rt.header"
BBMagic:
		.text 	"GP"						; core magic, matched against RTBASE..RTBASE+1
		.byte 	(RT_ABI / 10) + '0' 		; ABI ordinal, two digits, matched against RTBASE+2..3
		.byte 	(RT_ABI - (RT_ABI / 10) * 10) + '0'
BBGPMagic:
		.text 	"GB"						; "handlers loaded too", matched against RTGPMAGIC..+1
		.byte 	(RT_ABI / 10) + '0' 		; same ordinal -- the two halves are one image and one ABI
		.byte 	(RT_ABI - (RT_ABI / 10) * 10) + '0'
		;
		;		One string, two names: the root form is the local form with a "/" in front, so the
		;		fallback costs a single byte rather than a second copy of the name. The name is
		;		formatted, not spelled out, so a build number of any width still comes out right.
		;
BBFullRoot:
		.text 	"/"
BBFull:
		.text 	format("GPB.RT.%03d.BIN", BuildNumber) 	; handlers AND core, loads at RTGPBASE
BBFullEnd:
BBCoreRoot:
		.text 	"/"
BBCore:
		.text 	format("GPC.RT.%03d.BIN", BuildNumber) 	; core only, loads at RTBASE
BBCoreEnd:
BBErrText:
		.text 	"?RT", 13, 0 				; brief -- a full line would wrap in 40 columns

;		The per-program bytes. DATA, not immediates -- see the note at the warm check. The first
;		three are written by WriteObjectCode as the template streams past; BBNameIdx is working
;		state the bootstrap sets itself.
BBWSStart:
		.byte 	$FF 						; workspace start page -- PATCHED
BBWSEnd:
		.byte 	$FF 						; workspace end page (RTBASE or RTGPBASE) -- PATCHED
BBNeedGP:
		.byte 	$FF 						; 0 = no GPB keyword, 1 = uses them -- PATCHED
BBNameIdx:
		.byte 	0 							; which name triple (0 or 3), chosen at run time
BBCodePages:
		.byte 	$FF 						; pages of GP.BANKED region to move, 0 = none -- PATCHED
BBCodeBank:
		.byte 	$FF 						; which bank to move it to -- PATCHED

		.fill 	$0900 - *, 0 				; pad through $08FF so the p-code starts exactly at $0900

		.here
ProgramBootstrapEnd: 						; PHYSICAL end -- (End - Start) == 255 bytes ($0801..$08FF)

BootWSPatchOffset = BBWSStart - $0801 		; offsets of the six per-program bytes within the
BootWSEndPatchOffset = BBWSEnd - $0801 		; streamed template -- object.asm builds its patch
BootGPPatchOffset = BBNeedGP - $0801 		; table from these and nothing else.
BootCodeSrcOffset = BBCodeSrc+2 - $0801 	; ...and the three GP.BANKED needs. The first is an
BootCodePagesOffset = BBCodePages - $0801 	; instruction OPERAND rather than a data byte, which is
BootCodeBankOffset = BBCodeBank - $0801 	; what keeps the copy loop inside the padding.

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
