; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		00gpbase.asm
;		Purpose:	Marks the start of the GP.BASIC handler block.
;		Created:	18th August 2026
;
; ************************************************************************************************
; ************************************************************************************************
;
;		GPBase is the cut line. Everything from here to ObjectBase is GP.BASIC handler code and
;		nothing else, so a program that uses no GP keyword has its runtime written out as
;		$0801..GPBase instead of $0801..ObjectBase -- 2,560 bytes it never loads, and the same
;		again off the bottom of its workspace. See WriteObjectCode and compiler/gpscan.asm.
;
;		IT LIVES INSIDE gp.library, NOT IN A DIVIDER FILE, and that is the point: every link
;		line that pulls in gp.library gets the symbol automatically. A divider would have had to
;		be added to four separate link lines -- the runtime test build, gpc-rt, checkall and the
;		application -- and the one that got forgotten would have failed as an undefined symbol
;		somewhere unrelated.
;
;		THE LEADING ZEROS IN THE NAME ARE LOAD BEARING. build.py sorts by leafname and the sort
;		order IS the link order, so this file must sort ahead of every other file in this tree
;		or the label lands in the middle of the block it is supposed to open.
;
;		It declares no command marker, so it defines no opcode and takes no vector slot --
;		pcode.py walks straight past it and every existing token keeps its number. (Spelling the
;		marker out here would BREAK THE BUILD: pcode.py scans comments too, and a description of
;		one fails its assert as a malformed declaration.)
;
; ************************************************************************************************

		.section code

		;
		;		Page aligned, because WriteObjectCode's copy loop stops on a page boundary and
		;		the object code that lands here on reload must start on one. Costs up to 255
		;		bytes of padding in the compiler's own image, which sits above the cut and is
		;		thrown away anyway.
		;
		.align 	256
GPBase:

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
