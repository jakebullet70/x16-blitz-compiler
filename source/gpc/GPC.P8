; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		GPC.P8
;		Purpose:	Front end for GPC, the Blitz inspired X16 compiler
;		Code name:  Greased Piglet Compiler!
;		Created:	14th July 2026
;
; ************************************************************************************************
; ************************************************************************************************
;
;		GPC.BLITZ.BIN is driven by GPC.INPUT, a three line control file -- source, object, and a
;		third line that names a debug map file (line#->offset, for reading runtime errors) or is
;		empty for none. That is what lets a program drive it, but it is a poor thing to ask a
;		person to write by hand. So this asks the three questions, writes the file, and hands the
;		machine over to the GPC.BLITZ.BIN file.
;
;		%option no_sysinit is not decoration. Prog8's normal startup calls sys.init_system(),
;		which resets the screen mode, the charset and the colours. This program is a prompt and
;		nothing more: it leaves the machine looking exactly as it found it.
;
;		The one place it does touch the screen is chain_run, at the very end, and there it is not
;		decoration either -- see the note there.
;
; ************************************************************************************************

%import textio
%import diskio
%zeropage basicsafe
%option no_sysinit

main {
	const ubyte NAMEMAX = 40 					; the longest name we will take. Blitz allows 63.

	word build_num = 105	
	str source_name = " " * NAMEMAX
	str object_name = " " * NAMEMAX
	str map_name = " " * NAMEMAX
	str control = " " * (NAMEMAX * 3 + 8) 		; the three lines of GPC.INPUT, built up in memory

	sub start() {
		txt.print("\ngpc... a blitz inspired x16 compiler\n")
		txt.print("summer 2026, v0.9.")
		txt.print_uw(build_num)
		txt.nl()
		txt.nl()

		cx16.kbdbuf_clear() 					; drop the RETURN that ran us, and any type-ahead

		if read_line("input  file: ", source_name) == 0 {
			txt.print("\nbye, exiting\n") 	; a bare RETURN here means "never mind"
			return
		}

		; the source has to exist -- check before asking for an output name or deleting anything,
		; so a mistyped name stops here instead of scratching last time's good build for a compile
		; that cannot even start.
		if not diskio.exists(source_name) {
			txt.print("\ninput file not found\n")
			return
		}

		if read_line("output file: ", object_name) == 0
			default_object() 					; a bare RETURN : name the object after the source

		map_name[0] = 0 						; no map unless the user asks for one
		if ask_yesno("make a debug map? ") 		; a line#->offset file, for reading runtime errors
			default_map() 						; yes : name it after the source, m. for c.

		clear_old_output()

		if not write_control() {
			txt.print("\ncannot write gpc.input\n")
			return
		}

		chain_run("gpc.blitz.bin")
	}

	; ********************************************************************************************
	;
	;		Scratch last time's object and map before compiling. CBM DOS will not overwrite an
	;		existing file, so a second compile would otherwise fail with FILE EXISTS; and a stale
	;		map left beside a compile that failed would decode a later error to the wrong line.
	;		delete() is harmless when the file is not there. Only reached once the source has been
	;		found, so a good previous build is never thrown away for a compile that cannot run.
	;
	; ********************************************************************************************

	sub clear_old_output() {
		diskio.delete(object_name)
		if map_name[0] != 0 					; only when this run asked for a map
			diskio.delete(map_name)
	}

	; ********************************************************************************************
	;
	;		Print a prompt and read a filename, doing our own line editing rather than leaning on
	;		the KERNAL screen editor. The editor lets the cursor roam the whole screen, so a stray
	;		cursor-up before RETURN drags an earlier line -- the prompt, or leftover text -- straight
	;		into the name. Here every key is inspected: RETURN ends the line, DELETE rubs out the
	;		last character, a printable byte is taken, and everything else -- cursor keys, HOME, CLR,
	;		INSERT, colour codes, function keys, STOP -- is swallowed. The cursor cannot leave the
	;		line, so nothing off it can get in.
	;
	;		Returns the count entered; 0 means the user just pressed RETURN.
	;
	; ********************************************************************************************

	sub read_line(str prompt, str buffer) -> ubyte {
		txt.print(prompt)
		ubyte count = 0
		repeat {
			ubyte key = cbm.GETIN2() 			; keyboard only, 0 when nothing is waiting
			if key != 0 {
				when key {
					$0d -> { 					; RETURN : the line is finished
						buffer[count] = 0
						txt.nl()
						return count
					}
					$14 -> { 					; DELETE : rub the last character out
						if count != 0 {
							count--
							txt.chrout($14)
						}
					}
					else -> {
						; Printable PETSCII only ($20-$7f, $a0-$ff). Everything else is a
						; control code -- ignored, so the cursor never moves off the line.
						if (key >= $20 and key <= $7f) or key >= $a0 {
							if count < NAMEMAX-1 {
								buffer[count] = key
								count++
								txt.chrout(key)
							}
						}
					}
				}
			}
		}
	}

	; ********************************************************************************************
	;
	;		Print a prompt and wait for a yes/no answer: Y (or y) is yes, N (or n) or a bare
	;		RETURN is no, everything else is ignored -- the same one-line discipline as read_line.
	;		The answer is echoed so the screen reads back cleanly.
	;
	; ********************************************************************************************

	sub ask_yesno(str prompt) -> bool {
		txt.print(prompt)
		repeat {
			ubyte key = cbm.GETIN2() 			; keyboard only, 0 when nothing is waiting
			when key {
				'y', 'Y' -> {
					txt.print("yes\n")
					return true
				}
				'n', 'N', $0d -> {
					txt.print("no\n")
					return false
				}
			}
		}
	}

	; ********************************************************************************************
	;
	;		A bare RETURN on the output prompt means "name the object after the source". The
	;		convention the compiler shipped with is a "c." in front -- DIR.PRG compiles to
	;		C.DIR.PRG -- so the two sit on the disk side by side. Lowercase c and . in the source
	;		are PETSCII $43/$2e, exactly what CBM DOS reads as "C.".
	;
	; ********************************************************************************************

	sub default_object() {
		object_name[0] = 'c'
		object_name[1] = '.'
		ubyte i = 0
		while i < NAMEMAX-3 and source_name[i] != 0 {
			object_name[i+2] = source_name[i]
			i++
		}
		object_name[i+2] = 0
	}

	; ********************************************************************************************
	;
	;		"Yes" to the map question names it after the source with an "m." in front, the same
	;		convention as the "c." object -- so DIR.PRG gives C.DIR.PRG and M.DIR.PRG, the trio
	;		sitting together on the disk.
	;
	; ********************************************************************************************

	sub default_map() {
		map_name[0] = 'm'
		map_name[1] = '.'
		ubyte i = 0
		while i < NAMEMAX-3 and source_name[i] != 0 {
			map_name[i+2] = source_name[i]
			i++
		}
		map_name[i+2] = 0
	}

	; ********************************************************************************************
	;
	;		Write the three lines out.
	;
	;		Type the names in lowercase. That is not a style preference: an unshifted letter on
	;		the X16 is PETSCII $41-$5A, which is the same byte as an ASCII capital and is what
	;		CBM DOS wants in a filename. Typing them SHIFTED gives $C1-$DA instead, which is a
	;		different character altogether -- Blitz folds those back, but only because it has to.
	;
	; ********************************************************************************************

	sub write_control() -> bool {
		ubyte n = add_line(0, source_name) 		; line 1 : what to compile
		n = add_line(n, object_name) 			; line 2 : where to put it
		n = add_line(n, map_name) 				; line 3 : the map file, or empty (just a CR) if the
												; user did not want one -- add_line handles both.

		diskio.delete("gpc.input") 				; scratch any old one first: CBM DOS will not
												; overwrite an existing file, so a second run
												; would otherwise fail with FILE EXISTS.
		if not diskio.f_open_w("gpc.input")
			return false
		void diskio.f_write(control, n)
		diskio.f_close_w()
		return true
	}

	sub add_line(ubyte at, str text) -> ubyte {
		ubyte i = 0
		while text[i] != 0 {
			control[at] = text[i]
			at++
			i++
		}
		control[at] = 13 						; every line ends with a carriage return
		return at + 1
	}

	; ********************************************************************************************
	;
	;		Hand the machine over to the compiler.
	;
	;		GPC.BLITZ.BIN loads at $0801, which is exactly where THIS program is sitting, so we cannot
	;		load it ourselves: the KERNAL's LOAD would overwrite the code that called it and
	;		return into the wreckage. So we do not load it at all. We leave the LOAD command on
	;		the screen, put the cursor back on it, drop CR + RUN into the keyboard buffer, and
	;		exit. BASIC comes back to READY, reads the keyboard, and types the line in for itself
	;		-- by which time we are long gone and $0801 is free.
	;
	;		The keyboard buffer is only ten bytes, which is why the LOAD line goes on the screen
	;		rather than into the buffer: LOAD"GPC.BLITZ.BIN" alone would not fit.
	;
	;		The rows are counted, and the count matters. After we exit, BASIC prints CR, "READY.",
	;		CR -- which walks the cursor down two rows from wherever we left it. So we leave the
	;		cursor at row 0 and put the LOAD line on row 2, and BASIC's own output lands the
	;		cursor exactly on it. Row 1 is sacrificial: "READY." is printed over it.
	;
	;		(This is the "dynamic keyboard", and it is the same trick XFMGR2 uses to launch its
	;		setup program, and AUTOBOOT.BASL to reach BASLOAD.)
	;
	; ********************************************************************************************

	sub chain_run(str name) {
		txt.chrout($93) 						; clear screen, cursor home  -> row 0
		txt.nl() 								; -> row 1, which "READY." will be printed over
		txt.nl() 								; -> row 2
		txt.print("load") 						; row 2 : load"gpc.blitz.bin"
		txt.chrout($22)
		txt.print(name)
		txt.chrout($22)
		txt.chrout($91) 						; cursor up -> row 1
		txt.chrout($91) 						; cursor up -> row 0

		cx16.kbdbuf_clear()
		cx16.kbdbuf_put($0d) 					; CR : submits the LOAD line the cursor is sitting on
		cx16.kbdbuf_put('r')
		cx16.kbdbuf_put('u')
		cx16.kbdbuf_put('n')
		cx16.kbdbuf_put($0d) 					; RUN + CR : and away it goes
	}
}
