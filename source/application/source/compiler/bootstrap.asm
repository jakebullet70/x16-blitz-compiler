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
;			1. checks the 4-byte magic at RTBASE, and the same 4 bytes at $A000 in bank 1 -- are
;			   the shared runtime and its bank code already resident?
;			2. if not, LOADs GPB/GPC.RT.nnn.BIN to its own home and GP1.RT.nnn.BIN into bank 1,
;			   both with secondary address 1 and both from one place, the current directory or
;			   else the root of the SD card;
;			3. enters the resident runtime at RT_ENTRY, handing it this program's p-code page,
;			   workspace start (patched per program) and workspace end, with BASIC's RAM bank
;			   selected again.
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
		;		BANK 1 IS SELECTED FOR THE WHOLE BOOTSTRAP: the check reads $A000 and the cold path
		;		loads into it. BASIC's bank goes on the stack here and comes back before either exit,
		;		so a POKE to $A000 with no BANK still writes the bank BASIC left selected. The runtime
		;		saves and restores that bank around every bank 1 handler.
		;
		lda 	$00
		pha
		lda 	#HANDLER_BANK
		sta 	$00
		;
		;		Is the shared runtime already resident? Compare the core's 4 magic bytes at RTBASE and
		;		the same 4 at $A000, where the bank code starts, in one loop. The embedded bank code
		;		has "GE" there, so a shared program never enters it.
		;
		ldx 	#3
_BBCheck:
		lda 	RTBASE,x
		cmp 	BBMagic,x
		bne 	_BBCold
		lda 	$A000,x
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
		;		found, "/GPC.RT.001.BIN" loads).
		;
		;		Which file: the FULL one (handlers + core, loads at RTGPBASE) if this program uses a
		;		GPB keyword, the CORE-ONLY one (loads at RTBASE) if it does not. Loading the full one
		;		always restores both magics, so a program that wanted handlers and found none simply
		;		loads over whatever core was there.
		;
		;		THEN THE BANK CODE, GP1.RT.nnn.BIN, into bank 1 from the SAME place. The three names
		;		differ only in their third character, so there is one name and that character is
		;		patched before each load. A bank code file missing beside a core that loaded is ?RT,
		;		not a search of the root: the two files are one build.
		;
		;		$A000 IS ZEROED FIRST. A core that loads beside a missing bank code file would
		;		otherwise leave an older bank code's magic standing, and the next run would enter
		;		this core with that code.
		;
		stz 	$A000
		lda 	#'C' 						; core only
		ldx 	BBNeedGP 					; the same flag the warm check reads
		beq 	_BBName
		lda 	#'B' 						; handlers and core
_BBName:
		sta 	BBName+2
		lda 	#<BBName 					; the local form of the name
		sta 	BBNameLo
		jsr 	BBLoad
		bcc 	_BBBank 					; carry clear = loaded OK
		dec 	BBNameLo 					; else the root form, one byte earlier with its "/"
		jsr 	BBLoad
		bcs 	_BBFail
_BBBank:
		lda 	#'1' 						; the bank code, from wherever the core came from
		sta 	BBName+2
		jsr 	BBLoad
		bcc 	_BBEnter
_BBFail:
		;
		;		Not on the disk. Print a short notice and drop back to BASIC READY with BASIC's bank
		;		selected again -- no runtime is up, so there is no runtime error path to take.
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
		pla 								; BASIC's bank, saved at BootEntry
		sta 	$00
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
		pla 								; BASIC's bank again, saved at BootEntry
		sta 	$00
		;
		;		HAND OVER. Three values the runtime wants, and a jmp -- and BOTH the base page
		;		and the jmp target are PATCHED, because a GP.BANKED program does not come
		;		straight here from the bootstrap.
		;
		;		A banked program carries a second bootstrap page (bootstrap2.asm) at $0900, which
		;		copies its regions into their banks; its p-code therefore starts at $0A00 rather
		;		than $0900. So WriteObjectCode patches the base page to $0A and this jmp to
		;		$0900, and the extension page does this same handover itself once it is done.
		;		A program with no region gets $09 and RT_ENTRY -- the bytes already in the
		;		template -- and its object is byte for byte what it was before any of this.
		;
		;		THE COPYING USED TO BE HERE, an 8-page loop inside this padding. It moved out to
		;		the extension page when regions became plural: the loop grew a table walk, every
		;		program was paying for it in a 255-byte template with two bytes spare, and only
		;		a banked one ever ran a single instruction of it.
		;
		;		GLOBAL LABELS, not "_" ones -- object.asm patches these operands as the template
		;		streams past and needs the addresses to do it. See BBTryLoad's own note.
		;
BBBasePage:
		lda 	#PCODE_PAGE 				; A = p-code base page -- PATCHED, $09 or $0A
		ldx 	BBWSStart 					; X = workspace start page
		ldy 	BBWSEnd 					; Y = workspace end page -- RTBASE>>8 for a program with no GPB
											; keyword, RTGPBASE>>8 for one with the handlers below it. That
											; difference is the whole point of the split: 2,560 bytes.
BBRunJmp:
		jmp 	RT_ENTRY 					; RTBASE+4 -> jmp StartRuntime -- PATCHED, both operand
											; bytes, to $0900 when there is an extension page

; ------------------------------------------------------------------------------------------------
;		LOAD a file with secondary address 1, which makes the KERNAL honour the file's own load
;		address -- RTGPBASE, RTBASE, or $A000 in the bank selected -- and ignore the one in X/Y.
;		BBTryLoad takes the name as SETNAM does, length in A and address in X/Y, and bootstrap2.asm
;		calls it for the regions; BBLoad sets those three up for the runtime's name first. Logical
;		file 0 (file 1 has been seen to hang a later OPEN). Loading high never touches $0801 or the
;		p-code, so this bootstrap survives its own load. Returns carry clear on success, set if the
;		file is not there -- so the caller can just try the next name.
;
;		Sits BELOW _BBEnter deliberately: labels beginning with "_" are local to the enclosing
;		scope in 64tass, and a global label placed between _BBCold and _BBEnter would split that
;		scope in two, leaving the earlier branches referring to an _BBEnter they can no longer see.
; ------------------------------------------------------------------------------------------------
;
;		BBNameLo is the low byte of the name's address: BBName for the local form, one less for the
;		root form and its "/". Both end at BBNameEnd on the same page, so the length is BBNameEnd's
;		low byte less BBNameLo.
;
BBLoad:
		ldx 	BBNameLo 					; X = name address low
		lda 	#<BBNameEnd 				; A = name length
		sec
		sbc 	BBNameLo
		ldy 	#>BBName 					; Y = name address high
											; ...and fall straight through: A/X/Y are now exactly what
											; SETNAM wants.
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
		;		One string, every name. The root form is the local form with a "/" in front, so the
		;		fallback costs a single byte, and the third character is patched to B, C or 1 before
		;		each load, so the three files cost one name. The name is formatted, not spelled out,
		;		so a build number of any width still comes out right.
		;
BBNameRoot:
		.text 	"/"
BBName:
		.text 	format("GPC.RT.%03d.BIN", BuildNumber) 	; third character PATCHED at run time: B, C or 1
BBNameEnd:
		.cerror (>BBNameRoot) != (>BBNameEnd), "bootstrap runtime name crosses a page -- BBLoad subtracts low bytes"
BBErrText:
		.text 	"?RT", 13, 0 				; brief -- a full line would wrap in 40 columns

;		The per-program bytes. DATA, not immediates -- see the note at the warm check. The first
;		three are written by WriteObjectCode as the template streams past; BBNameLo is working
;		state the bootstrap sets itself.
BBWSStart:
		.byte 	$FF 						; workspace start page -- PATCHED
BBWSEnd:
		.byte 	$FF 						; workspace end page (RTBASE or RTGPBASE) -- PATCHED
BBNeedGP:
		.byte 	$FF 						; 0 = no GPB keyword, 1 = uses them -- PATCHED
BBNameLo:
		.byte 	0 							; the name's low address byte, local or root form -- set on the cold path

		.fill 	$0900 - *, 0 				; pad through $08FF so the p-code starts exactly at $0900

		.here
ProgramBootstrapEnd: 						; PHYSICAL end -- (End - Start) == 255 bytes ($0801..$08FF)

BootWSPatchOffset = BBWSStart - $0801 		; offsets of the six per-program bytes within the
BootWSEndPatchOffset = BBWSEnd - $0801 		; streamed template -- object.asm builds its patch
BootGPPatchOffset = BBNeedGP - $0801 		; table from these and nothing else. The first three
BootBasePageOffset = BBBasePage+1 - $0801 	; are DATA bytes; the last three are instruction
BootRunJmpOffset = BBRunJmp+1 - $0801 		; OPERANDS -- the base page, and the jmp's two, which
											; are patched to the extension page for a banked program.

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
