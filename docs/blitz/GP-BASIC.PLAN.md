# GP.BASIC — our own BASIC extension for GPC

> **Status: reconstructed 2026-08-16.** The original plan was worked out in a chat session that was
> lost before anything was written down; roughly an afternoon of work went with it. Everything below
> is either (a) recovered from code already in the tree, (b) re-measured today, or (c) re-extracted
> from the dotBASIC manual. Sections marked **LOST** are the parts that were only ever in that chat
> and have *not* been invented back. Do not treat a LOST item as decided.

## 1. What this is

A BASIC extension for **GPC** (this repo's X16 compiler), using **dotBASIC Plus** as the template —
not as a port. dotBASIC is a C64 BASIC 2.0 extension where every added command begins with a dot
(`.COMMAND,PARAMETERS`). We do the same thing with a `GP.` prefix, compiled rather than interpreted.

Template source: *DotBASIC Plus v2.2*, Dave Moorman / LOADSTAR, 2008, based on Mr.Mouse Technology by
Lee Novak. 81-page manual: <https://dotbasic.cbm8bit.com/files/pdf/dotbasic-manual.pdf>
(site <https://dotbasic.cbm8bit.com/>). The manual is not vendored here — it is third-party and
copyrighted; re-download it if you need the prose. The command catalogue extracted from it is in
§7 below.

## 2. What we are taking from dotBASIC, and what does not transfer

**Take: the dotted-namespace idea.** A prefix that the host BASIC can never own means the extension
can grow without ever colliding with the ROM's own keywords. dotBASIC used `.`; we use `GP.` because
BASLOAD accepts dotted identifiers (measured — §4).

**Take: the sectioned shape, but not dotBASIC's sections.** dotBASIC groups its commands as
*Getting Started* (screen colour, loops, mouse, text boxes, regions), *Menus*, *Sound & Graphics*, and
*Strings & Things* (virtual arrays, screen objects, visual design), with an alphabetical reference
("the DotBible") behind it. Sectioning the set that way — for the manual and for the include layout —
is worth copying. The specific four are not: *Sound & Graphics* is struck entirely and the mouse is
struck out of *Getting Started* (§2), so GP.BASIC's sections have to be drawn fresh around what is
left. **What those sections are is not decided** — see §6.

**Take: include-what-you-use.** This is dotBASIC's best structural idea and it is worth stating
plainly, because it cuts against how GPC works today. On the C64 a DB+ project's `.DML` file
*contains only the DotCommands that program actually uses* — the manual is explicit that this is to
avoid spending RAM and disk on commands you never call. GPC currently embeds the **whole** runtime in
every object (measured today: a two-line `PRINT`/`POWEROFF` program compiles to 12,061 bytes; the
six-case GP.DO test to 12,244). If GP.BASIC grows to dotBASIC's size, linking every GP command into
every object repeats exactly the cost dotBASIC engineered around. **This is an open design question,
not a decision** — see §6.

**Does not transfer:** dotBASIC's command set is C64 hardware and LOADSTAR-ecosystem specific — SID,
Mr.Edstar text files, SHP bitmaps, `PEEK(198)` keyboard-buffer idioms, drive device numbers. The
*categories* survive the move to the X16; most of the individual commands do not.

**Sprites, mouse, music and graphics are out of scope entirely.** 22 of the 98 commands are struck
from the catalogue below and are not candidates for a `GP.` spelling:

- **Sprites** — `.SPRITE`, `.SPRFX`, `.F2SPR`. GPC already has native `SPRITE`, `SPRMEM` and `MOVSPR`
  ([x16_command.def](../../source/compiler/source/system-specific/x16/generation/x16_command.def)).
- **Mouse** — `.MA` (mouse ask), `.CAGEM` (cage mouse), `.PUTM` (put mouse), `.LG` (let go —
  wait for buttons released), `.ROLOVR` and `.SETROL` (roll-over highlighting). dotBASIC is a
  mouse-first system built on Mr.Mouse Technology; GP.BASIC is not. Note the knock-on: `.KEYMW`
  (key/mouse wait) and `.EVENT` (wait for click **or** keypress, returning `I%` = -1/-2 for the
  buttons) are hybrids that only half survive — a keyboard-only redesign, not a port. dotBASIC's
  menus are also mouse-driven, though they carry keyboard hotkeys (`HK$`) that a keyboard-only
  version can build on.
- **Music/sound** — `.SID`, `.SIDOFF`. GPC already has a full sound set
  ([x16_sound.def](../../source/compiler/source/system-specific/x16/generation/x16_sound.def)):
  11 FM commands for the YM2151 (`FMINIT`, `FMNOTE`, `FMDRUM`, `FMINST`, `FMVIB`, `FMFREQ`, `FMVOL`,
  `FMPAN`, `FMPLAY`, `FMCHORD`, `FMPOKE`) and 8 PSG commands for VERA (`PSGINIT`, `PSGNOTE`, `PSGVOL`,
  `PSGWAV`, `PSGFREQ`, `PSGPAN`, `PSGPLAY`, `PSGCHORD`).
- **Graphics** — the whole Grafstar family (`.GRAF`, `.GMODE`, `.GPEN`, `.GPLOT`, `.GLINE`, `.GFILL`,
  `.GCLIP`, `.GP`, `.GR00`) plus SHP bitmaps (`.BMP`, `.BMPSCR`). GPC already draws natively:
  `PSET`, `LINE`, `RECT`, `FRAME`, `OVAL`, `RING`, `CHAR`, `SCREEN`, `TILE`, and
  `BLOAD`/`BVLOAD`/`VLOAD`/`BSAVE`/`BVERIFY` for getting images in.

Every one of these would be a second, worse way to do something the compiler already does properly
against real X16 hardware — VERA and the YM2151, not the VIC-II and the SID. **The rule this sets: if
the X16 keyword set already covers a capability, GP.BASIC does not restate it.** GP.BASIC is for what
GPC lacks, not for re-spelling what it has. (By that rule, more of the catalogue is already suspect —
`.BL`/`.BS` duplicate `BLOAD`/`BSAVE`, and `.DISK` overlaps `OPEN`/`CLOSE`/`CMD`. They are left in
below pending the selection pass, not endorsed.)

**Also note dotBASIC's loop is not ours.** dotBASIC's `.DO` is a `DO … .UN <boolean>` /
`.WH <boolean>` pre/post-tested conditional loop. What we shipped (§5) is a *counted* `GP.DO n …
GP.LOOP`, which is prog8's `repeat`. The faithful dotBASIC-style conditional loop — `GP.UNTIL` /
`GP.WHILE` — **is not written**, and the two ideas can coexist.

## 3. Decisions already made — these are in the tree, not proposals

**Token space: `$CE01`–`$CE7F`, allocated DOWNWARD from `$CE7F`.** The direction is the whole point.
`getX16()` in [c64tokens.py](../../source/common-scripts/c64tokens.py) numbers the ROM's statements
*upward* from `$CE80` and re-anchors its functions at a fixed `$CED0`, so the ROM's own scheme can
never structurally reach below `$CE80`, however much it grows. That gives us 127 slots a future ROM
revision cannot collide with — unlike the tempting gaps *above* the keywords (`$CEC2`–`$CECF`,
`$CEDF`–`$CEFF`), which is exactly where the ROM does grow.

**`$CE00` is excluded** — a zero second byte means "unshifted" in the compiler's table format.

**GP tokens are written out explicitly as `id:NAME`, never as a positional list.** `getX16()` computes
ids from list position; if GP names were appended there, adding one would renumber real ROM keywords.
`getGP()` is explicit so adding a keyword can never renumber the others.

**`.` → `CMD_` in symbol generation.** The C64 dump is assembled as
`common-source/source/generated/c64tokens.inc`, where a dot is an illegal symbol character. `CMD_` is
the same substitution `pcode.py` already applies to its own dotted names, so `PCD_` and `C64_` spell a
dotted keyword identically. Idempotent for every pre-GP token — nothing in `get()`/`getX16()` has a dot.

**Accepted cost: GP programs are compile-only.** A PRG containing a `$CE7x` byte cannot be LISTed or
RUN by the ROM, because there is no handler behind it.

**`RT_ABI` must be bumped whenever a runtime command file is added.** Runtime command files are
gathered in directory order, so a new file renumbers every opcode after it — `do.asm` sorts ahead of
`for.asm` and shifted everything from `for` upward by two. `RT_ABI` went 3 → 4 for exactly this.
See [common.inc](../../source/common-source/source/common.inc).

## 4. BASLOAD `#TOKEN` — measured facts (spikes, 2026-08-16)

BASLOAD (in every R49 ROM) is how GP source becomes a tokenised PRG, so it decides what a GP keyword
may look like. All of these were run, not reasoned about; the spikes are in the `dbspike` scratchpad.

| Question | Answer | Evidence |
|---|---|---|
| Does `#TOKEN` emit arbitrary 2-byte tokens? | **Yes** | `TT.PRG` |
| Does a `#TOKEN` definition survive `#INCLUDE`? | **Yes** | `TT2.BASL` defines nothing itself |
| Dotted name (`GP.BOX`)? | **Yes** | `TT3.PRG`: `CE 7F` |
| Dotted name whose tail is a reserved keyword (`GP.MENU`)? | **Yes** — BASLOAD does not re-tokenise the tail | `TT3.PRG`: `CE 7E` |
| `$`-suffixed name (`GP.TRIM$`)? | **NO — rejected** | `TT4.PRG` is 6 bytes: `01 08 00 00`, an empty program |
| `#IFNDEF`/`#DEFINE` guards across `#INCLUDE` boundaries? | **Yes** | `TT5.PRG`: `BOXBODY` appears exactly once with both `GOSUB` targets resolved |

**The `$` rejection is a live constraint on the design.** dotBASIC has string commands
(`.INSTR`, `.PINSTR`, `.SAVSTR`, `.SETSTR`); the obvious GP spelling for a string *function* —
`GP.TRIM$` — does not tokenise. Unresolved. Options not yet evaluated: a non-`$` name returning into a
known variable, a `GP.` statement form that assigns, or finding whether BASLOAD's rejection is the
`$` specifically or the dotted-plus-`$` combination.

## 5. Shipped so far: `GP.DO` / `GP.LOOP`

A counted loop with **no loop variable** — `GP.DO <count> … GP.LOOP`. The missing variable is the
point: per commit `ae6cbd7`, FOR/NEXT spends most of its ~487 cycles/iteration on the iFloat32 index
(decode operand address, read 6 bytes, compare against the terminal value, write 6 back). None of that
exists here; the counter lives in the frame as a plain 16-bit decrement.

- Runtime: [do.asm](../../source/runtime/source/commands/do.asm). New `FRAME_LOOP` (`$A0+6`, 6 bytes),
  laid out so +2/+3 line up with `FRAME_FOR`, which is what `StackSave/LoadCurrentPosition` hard-code.
  Everything else is reused: `GetInteger16Bit`, `StackOpenFrame/FindFrame/CloseFrame`, and the same
  "frame already on top" fast path as NEXT.
- Compiler: pure table entries in [commands.def](../../source/compiler/source/generation/commands.def).
  `GP.DO` reuses `OptionalNumberCompile` (the bare-`SLEEP` helper) verbatim, which pushes 0 for an
  omitted argument — and **0 means forever**, so bare `GP.DO` is an infinite loop for free.
- Post-tested: a count of *n* gives exactly *n* passes. A counter of 0 on entry is unambiguous, because
  the frame is closed the moment a decrement produces zero — zero is never left behind on a live loop.

**Test results (2026-08-16, all pass):**

| Case | Program | Expected | Got |
|---|---|---|---|
| T1 | `GP.DO 5` | 5 | 5 |
| T2 | `GP.DO 1` | 1 | 1 |
| T3 | `GP.DO 3` nesting `GP.DO 4` | 12 | 12 |
| T4 | `GP.DO 1000` (16-bit counter) | 1000 | 1000 |
| T5 | bare `GP.DO`, exited by `IF…THEN` | 7 | 7 |
| T6 | `GP.DO 2` inside `FOR I=1 TO 3` | 6 | 6 |

**Known wart:** T5 leaks a frame. Escaping a `GP.DO` with a `GOTO`/`IF…THEN` leaves the LOOP frame
open, exactly as escaping a `FOR` does. Standard BASIC behaviour, but `GP.DO` is cheap enough to be
used freely, so it will be hit more often than `FOR` is. Undecided whether to document or handle.

## 6. Open questions

1. **LOST: which commands, and the section grouping.** The original plan selected a working set
   (recalled as ~40) from the dotBASIC catalogue and grouped it into sections. That selection and
   grouping existed only in the lost chat. §7 is the raw template to re-select from; it is *not* the plan.
2. **String functions** — `#TOKEN` rejects `$` suffixes (§4).
3. **Include-what-you-use** — do GP commands link only when used, as dotBASIC does, or does every
   object carry all of them as the runtime does today (§2)?
4. **Conditional loops** — `GP.UNTIL`/`GP.WHILE` as dotBASIC's `.UN`/`.WH`, alongside counted `GP.DO`.
5. **The keyboard-only redesign of `.KEYMW` and `.EVENT`** — both wait on mouse *or* keyboard, so
   with the mouse struck they need rethinking rather than porting (§2).

**Token budget:** 127 slots (`$CE01`–`$CE7F`), 2 used (`GP.DO` = `$CE7F`, `GP.LOOP` = `$CE7E`),
**125 free**. The catalogue in §7 is 76 commands after the four struck categories (from 98), so even
adopting all of it fits comfortably — but the space cannot be extended upward, so it is not unlimited.

## 7. Appendix — the dotBASIC Plus catalogue (template, not a plan)

**Structure.** dotBASIC has 11 built-in DotCommands, always present: `.TX` `.BG` `.BR` `.DO` `.UN`
`.MA` `.OF` `.WH` `.KP` `.QS` `.QR` (`.MA` is mouse — struck). Everything else is *included* per
project. Manual sections: *Getting Started* (text boxes, regions), *Menu Madness*, *Sound & Graphics*
(struck in full — bitmaps, SidPlayer, Grafstar), *Strings & Things* (virtual arrays/racks, screen
objects, visual design). Note that striking Sound & Graphics removes one of the four sections
outright, so the manual's shape is no longer the shape of GP.BASIC.

**76 commands** below, with syntax, extracted from the DotBible (manual pp. 45–67). The original 98
minus the 22 struck in §2 — sprites (3), mouse (6), music (2), graphics (11):

| DotCommand | Syntax | Meaning |
|---|---|---|
| `.ALPH` | `.ALPH,START#` | Alphabetize |
| `.AREG` | `.AREG,REG#,SC,CO` | Affect Region |
| `.BG` | `.BG,CO` | Background Colour (built-in) |
| `.BL` | `.BL,FILE$,D,LOC` | Bload |
| `.BL0` | `.BL0,FILE$,D,LOC` | Bload With Zero |
| `.BOX` | `.BOX,X,Y,W,H,SC,CO` | Box |
| `.BR` | `.BR,CO` | Border Colour (built-in) |
| `.BS` | `.BS,FILE$,D,START,END+1` | Bsave |
| `.CHRSWP` | `.CHRSWP,SEEK,REPLACE,CO` | Character Swap |
| `.COLSWP` | `.COLSWP,SEEK,REPLACE` | Colour Swap |
| `.CPYCHR` | `.CPYCHR,START,END+1,DESTINATION` | Copy Character |
| `.CPYIO` | `.CPYIO,START,END+1,DEST` | Copy I/O Intact |
| `.CPYMEM` | `.CPYMEM,START,END+1,DEST` | Copy Memory |
| `.CUT` | `.CUT,X,Y,W,H,LOC` | Cut |
| `.CUTSOB` | `.CUTSOB,X,Y,W,H` | Cut Screen Object |
| `.DELSOB` | `.DELSOB` | Delete Screen Object |
| `.DISK` | `.DISK,COMMAND$,D` | Disk Command |
| `.DIR` | `.DIR,"$:*",D,LOC,#FILENAMES` | Get Directory |
| `.DIRSRT` | `.DIRSRT` | Sort Directory |
| `.DO` | `.DO` | Do (built-in) |
| `.DREG` | `.DREG,REG#,X,Y,W,H` | Define Region |
| `.DRTEXT` | `.DRTEXT,NUMBER,"STATIC STRING"` | Define Region Text |
| `.EDRTEXT` | `.EDRTEXT,LOC` | Edstar To Region Text |
| `.EVENT` | `.EVENT,"keystroke"` | Event |
| `.FANCY` | `.FANCY,X,Y,W,H,S1,S2,C1,C2` | Fancy Lattice |
| `.FTS` | `.FTS,PAGE` | Font/Toolbox/Stash |
| `.I2FP` | `.I2FP,INTEGER` | Integer-To-Floating Point |
| `.INP` | `.INP,X,Y,TXT,CSR,LEN,DEFAULT$` | Text Input |
| `.INPLUS` | `.INPLUS,X,Y,TXT,CSR,LEN,S,OUT$,DEFAULT$` | Input Plus |
| `.INSTR` | `.INSTR,SEARCH$,TARGET$,N` | In-String |
| `.KEYMW` | `.KEYMW` | Key/Mouse Wait |
| `.KP` | `.KP,STRING$` | Key Press (built-in) |
| `.LNKSOB` | `.LNKSOB,LOC` | Link Screen Objects |
| `.MCMENU` | `.MCMENU,NC,X,W,Y,I,U,H,HOT$` | Multi-Column Menu |
| `.MENU` | `.MENU,X,Y,W,I,U,HI,HK$` | Menu |
| `.MENUA` | `.MENUA,X,Y,U,H,HK$,ITEMS$` | Auto-Menu A (shadow) |
| `.MENUB` | `.MENUB,X,Y,U,H,HK$,ITEMS$` | Auto-Menu B |
| `.MSG` | `.MSG,CO,STRING$` | Print Message |
| `.MSMENU` | `.MSMENU,X,Y,W,H,B,I,UN,HI,S,WB,LOC,T$,B$` | Multi-Select Scrolling Menu |
| `.P@` | `.P@,X,Y,STRING$` | Print At |
| `.PASTE` | `.PASTE,X,Y,W,H,LOC` | Paste |
| `.PAUSE` | `.PAUSE,JIFFIES` | Pause |
| `.PC` | `.PC,Y,STRING$` | Print Center |
| `.PINSTR` | `.PINSTR,CHR$,TARGET$,POSITION` | Put In-String |
| `.PPRNT` | `.PPRNT` | Print Racked Data |
| `.PRFILE` | `.PRFILE,X,Y,INDEX#` | Print Filenames |
| `.PRI` | `.PRI,X,Y,INDEX#` | Print Selected Item |
| `.PRTEXT` | `.PRTEXT,INDEX` | Print Text |
| `.PSEL` | `.PSEL,X,Y,INDEX#` | Print Multi-Select Menu Item |
| `.PSTSOB` | `.PSTSOB,INDEX#,X,Y` | Paste Screen Object |
| `.QR` | `.QR` | IRQ Restore (built-in) |
| `.QS` | `.QS` | IRQ Suspend (built-in) |
| `.RDMI` | `.RDMI,ITEMS,BEGIN` | Random Index |
| `.RESTR` | `.RESTR,PAGE` | Screen Restore |
| `.RI` | `.RI,INDEX#` | Rack Index |
| `.RK` | `.RK,LOC` | Rack (virtual array) |
| `.RRK` | `.RRK,LEN` | Re-Rack |
| `.RU` | `.RU,BOX,REV,U,HI,UREV,STRING$` | Are You Sure? |
| `.SAVSTR` | `.SAVSTR,STRING$` | Save String |
| `.SCMENU` | `.SCMENU,X,Y,W,H,B,I,UN,HI,LOC,T$,B$` | Scrolling Menu |
| `.SCNUME` | `.SCNUME,CURX,CURY,TOTX,TOTY,SELX,SELY,REV` | Scroll Number Enabled |
| `.SCPRNT` | `.SCPRNT,X,Y,STRING$` | Scriptor Print (with `.SCRIPT`) |
| `.SCRIPT` | `.SCRIPT,160,128,PAGE` | Scriptor |
| `.SEL` | `.SEL,NUMBER` | Index Selected Items |
| `.SETSOB` | `.SETSOB,LOC` | Set Screen Object |
| `.SETSTR` | `.SETSTR,LOC` | Set String Location |
| `.STASH` | `.STASH,PAGE` | Stash Screen |
| `.SWPMEM` | `.SWPMEM,START,END+1,DESTINATION` | Swap Memory |
| `.TEXRD` | `.TEXRD,LOC,BKGDCOL,TXTCOL,ICONCOL,NAME$` | Text Reader |
| `.TEXT` | `.TEXT,X,Y,W,STRING$` | Text Box |
| `.TEXTC` | `.TEXTC,Y,W,STRING` | Text Box, Centered |
| `.TX` | `.TX,CO` | Text Colour (built-in) |
| `.UN` | `.UN,<boolean>` | Until (built-in) |
| `.WH` | `.WH,<boolean>` | While (built-in) |
| `.WKEY` | `.WKEY` | Wait Key |
| `.YN` | `.YN,X,Y,CO,HI,REV` | Yes/No |

## 8. Testing note — do not lose another afternoon to this

The 16/08 session spent hours believing `GP.DO` was broken in the emulator. It was not. A probe
harness passed `-echo raw` to the **compile** step and never drained the pipe, so the emulator blocked
on a full stdout buffer partway through the compile; the object stopped growing, a
"size stable ⇒ finished" poll read that as success, and every object came out a **byte-exact truncated
prefix** (3782 bytes of the real 12,121) that BRKs into the ML monitor with no error. The tell that it
was never our change: the *pre-change* binary failed identically. Omit `-echo` on the compile step, and
floor-check the object — a real one carries the whole runtime, so anything near 4K is truncation.
