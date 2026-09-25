# INT16 conversion -- handoff

## 0. Read this first

Written 2026-09-13. Nothing is converted yet.

The job: update the GPC-BASIC library code to use INTs where it can, then update the projects built
with that code. In practice a numeric scalar that only ever holds a whole number from -32,768 to
32,767 gets a `%` suffix. The library is converted in the working copy
`samples/GPB-MODS-TESTING/GPC-BASIC/` first, then carried to root `GPC-BASIC/`, XBASE and GPB.HELP.

`source/gpc/int16scan.py` is the inventory and the check. Every number below is its output (§8).

Rules for this job:

- Re-read a file before writing it. Other sessions edit this tree. On 2026-09-12 `FILEIO.INC.BL`
  and `FILEIO.BANK.INC.BL` in the working copy carried uncommitted edits that are not this job's.
- Ask before every build, and run it in the background. Never build PICKDEMO.
- Do not run `MKHELP.PY` unless asked, although the manual's variable names change.
- `GPB.INC.BL` is not part of this.

## 1. What a `%` buys

| type | scalar | array element |
|---|---|---|
| float, no suffix | 6 B | 6 B |
| int16 `%` | 2 B | 2 B |
| string `$` | 2 B | 2 B |

Scalar sizes are `AllocateBytesForType` in `source/compiler/source/storage/create.asm`. Element
sizes were measured (memory: array-element-sizes-measured).

The p-code does not change. A scalar access is two bytes and an array access one, whatever the type
(`variables/readwrite.asm`).

The saving is workspace: the low-RAM block the bootstrap sets up. Scalars take a fixed block at its
foot, sized by the `.varspace` operand. Arrays grow up above that block and the string heap grows
down from the top. A byte taken off the scalars is a byte more for strings and arrays at run time.
The PRG does not get smaller.

## 2. The numbers

From the last builds: GPBMODS and GPB.HELP 2026-09-12, GUIFRMT and XBASE 2026-09-11.

| program | workspace B | variable space B | untyped scalars | free | review | blocked | free B | free + review B | of which library |
|---|---|---|---|---|---|---|---|---|---|
| GPBMODS | 8,448 | 3,436 | 377 | 326 | 20 | 31 | 1,304 | 1,384 | 1,352 |
| XBASE | 12,288 | 3,122 | 405 | 360 | 15 | 30 | 1,440 | 1,500 | 1,324 |
| GPB.HELP | 7,168 | 2,204 | 291 | 261 | 7 | 23 | 1,044 | 1,072 | 780 |
| GUIFRMT | 17,664 | 1,802 | 245 | 227 | 2 | 16 | 908 | 916 | 896 |

- free: the scan found no reason not to convert. That is not proof.
- review: an assignment needs reading. §4 decides each one.
- blocked: stays float. A FOR index, a read of TI, FRE, GP.STRPTR or GP.ARRPTR, an address, or a
  value past 32,767.

Untyped arrays are not in the byte columns. THEME.CLR is in every program. XBASE also has DB.ISOPEN,
DB.CH, DB.STRIDE, DB.NFLD, DB.DATA0, DB.COUNT, DB.RECNO, XB.MITEMS, XB.MWIDTH and XB.RULE. A `%`
array saves 4 B an element.

Library bytes, free + review, in GPBMODS:

| module | B | module | B |
|---|---|---|---|
| GUI | 412 | STRINGS | 44 |
| MENUVERT | 152 | BANKMGR | 36 |
| STASHVRAM | 128 | FILEDIR | 36 |
| MENUBAR | 76 | STASHVRAMGC | 32 |
| LINEINPUT | 72 | GUI2 | 28 |
| STASH | 60 | APPSYS | 24 |
| STRUSING | 52 | SORT | 20 |
| COMBO | 52 | THEME | 20 |
| FILEIO | 52 | five SHIMs, STASHFILE, STRCASE | 4 to 12 each |

Project names, free + review: GPB.HELP.BASL 292 B, XBASE.BASL 96, DB 76, XBMENUS 72, DBFILE 44,
DBFORM 28, GPBMODS.BASL 32, GUIFRMT.BASL 20.

Measured variable space is larger than the named variables add up to, by 216 B in GUIFRMT and up to
772 B in GPBMODS. The gap is not traced. It does not change the saving, which is 4 B a name.

GP.BANKEDSTR group names (72 in GPBMODS, 9 in XBASE) and GP.DEFPROC verbs appear in the SYM as
variables. They are not. Nothing allocates them, because only `refterm.asm`, `dim.asm` and
`select.asm` call `AllocateBytesForType`. A `%` on either is a syntax error (`commands/gpbstr.asm`,
`commands/gpdefproc.asm`). The scan leaves them out.

## 3. Hazards

WARNING: A MISSED SITE COMPILES CLEAN AND SPLITS THE VARIABLE IN TWO. BASLOAD looks a name up
without its suffix and copies the `%` through (`BASLOAD-GPC/src/line.inc:1103-1112`), so
`GUI.WIDTH` and `GUI.WIDTH%` are two variables. A caller still writing the plain name sets one the
module never reads. Run `int16scan.py --check` after every module.

WARNING: AN INT16 STORE HAS NO RANGE CHECK. `WriteIntegerZTemp0Sub`
(`source/runtime/source/memory/write_int.asm`) takes the integer part and keeps the low two bytes.
40,960 stores as -24,576 and 2.7 as 2, with no error.

WARNING: `FOR X% =` IS A COMPILE ERROR (`commands/for.asm:49`). Every FOR index stays float. FOR
indices are 19 of GPBMODS's 31 blocked names.

- **Past 32,767.** Addresses and 16-bit joins overflow: `$A000` windows, VERA addresses, GP.STRPTR,
  GP.ARRPTR, TI, FRE and `lo + hi * 256`. A `#DEFINE` value is a signed int16 too (TODO.md:3210).
- **Taint depth.** "from NAME" in the scan looks one assignment deep. A value that arrives through a
  GOSUB-shared variable or a GP.FN result is not traced.
- **Intermediate results.** Arithmetic runs on the evaluation stack (ifloat32), and a value narrows
  to two bytes when it is stored. What an intermediate result does past 32,767 was not tested.
- **GP.DEFPROC.** Formals and RETURNS variables are shared variables and may take `%`. GP.FN's
  result then has the RETURNS variable's type (`commands/gpdefproc.asm`). Check what every caller
  passes.
- **READ and INPUT.** INPUT and INPUT# hand their targets to READ's common code, which types each
  target (`commands/input.asm`, `commands/read.asm`). A `%` target compiles and truncates like any
  store.
- **GP.SELECT** accepts a `%` selector (`commands/select.asm`).
- **GP.ASM.** A `{NAME}` reference reads a variable's bytes by its type. No blob refers to an
  untyped name today, and the scan blocks any that does.
- **Line length.** BASLOAD's source line cap is 250 characters (`file_init`,
  `BASLOAD-GPC/build/stock/file.inc`), and `#MAXCOLUMN` changes it. With every free and review name
  converted, the longest line is `GPBMODS.BASL:2330` at 229.
- **Short names in GLOBALS.** `GPC-BASIC/GP-BASIC.GLOBALS.md` writes names in a short `.NAME` form
  under each module heading. A whole-name rename does not reach them, so edit them by hand.

## 4. The review names

Line numbers are the working copy's unless the file is a project's own.

| name | what it holds | decision |
|---|---|---|
| STASH.MAPW, SV.MAPW, HELP.SC.MAPW | `32 * 2 ^ INT(...)`, 32 to 256 | Fits, but `^` is a float power and 255.99 stores as 255. Convert only after showing `2 ^ n` is exact on the emulator, or rewrite without `^`. |
| SV.TOPPG | `INT((SV.TOP + 1) / 256)`, 432 | convert |
| SV.MID, SV.LO | the bytes of SV.REST | convert |
| HELP.SC.MID, HELP.SC.LO | the bytes of HELP.SC.REST | convert |
| MENUVERT.PADNOW | `PADRAW - INT(PADRAW / 256) * 256`, 0 to 255 | convert |
| FILE.ERR, FILE.TRK, FILE.SEC | `INPUT#15` drive status | convert |
| DBFILE.ERR | `VAL(LEFT$(DBFILE.MSG$, 2))`, 0 to 99 | convert |
| FILE.DIR.SLOW | a float copy of `FILE.DIR.SLOW%`, which the FILEDIR blob writes | Convert, which merges the two. `FILEDIR.BANK.INC.BL:216` becomes a self-assignment to delete; read the reset at `:150` first. Take the name out of `KNOWN_PAIRS`. |
| FILE.BLOCKS | RETURNS of GP.DEFPROC FILE.SIZE | The one caller already stores into `GM.PBLK%` (`GPBMODS.BASL:2443`), so converting changes nothing for it. |
| HELP.LN2, HELP.TREF, XB.N | `VAL` of a field or an answer | Read the uses. A line or record number can pass 32,767. |
| SV.VA, SV.GCS, SV.GCD, SV.LEFT | page count * 256 | stays float: VRAM offsets and byte counts |
| FILE.LINENO | `lo + hi * 256` | stays float: line numbers reach 63,999 |
| XB.MEM.LOW, XB.MEM.WORK | pages * 256 | stays float |
| DBFILE.WORK | `(WORK - BYTE) / 256`, a 32-bit field | stays float |
| STR.USING.V, STR.USING.NUM | the number being formatted | stays float |
| GM.UVAL | `0.5` | stays float |
| GM.FRELOW | a copy of `FRE(0)` | stays float |

## 5. Method, one module at a time

1. List the module's names. The third column is `file:line`.
   ```
   python source/gpc/int16scan.py --names free GPBMODS
   python source/gpc/int16scan.py --names review GPBMODS
   ```
2. Settle any review names against §4.
3. Rename each name to `NAME%` across the working copy: both twins of the module (`X.INC.BL` and
   `X.BANK.INC.BL` where both exist), every other module, `GPBMODS.BASL`, `GUIFRMT.BASL` and the
   working copy's `*.EXP.BL`.
   - Match `(?<![A-Za-z0-9._])NAME(?![A-Za-z0-9._%$])(?!\s*\()`, case-insensitive. The `.` on both
     sides keeps `GUI.LIST` from matching inside `GUI.LIST.ROW`, and the `(` leaves an array of the
     same name alone.
   - Rename in code and `##` comments. Leave string literals.
   - `--spread GPBMODS` shows where a module's names are used outside it.
4. `python source/gpc/int16scan.py --check GPBMODS GUIFRMT` must report no NEW pair. FILE.DIR.SLOW is
   the one known pair until FILEDIR is converted.
5. Ask, then build in the background: `python source/gpc/modsbuild.py GPBMODS`. Add `GUIFRMT` when a
   module it includes changed.
6. `python source/gpc/int16scan.py GPBMODS`. The variable space must fall by exactly 4 B for each
   converted name. Any other drop means a missed site or a misread object.
7. Hand the build to the user to walk the module's panel. Panels cannot be driven by paste.

| module | GPBMODS bar item (PLAN.md §2) |
|---|---|
| GUI, GUI2 | DIALOG |
| MENUVERT, MENUBAR | LISTS, and the bar itself |
| LINEINPUT | INPUT |
| STASH, STASHFILE, STASHVRAM, STASHVRAMGC | SCREEN |
| STRINGS, STRCASE, STRUSING | STRINGS |
| SORT | DATA |
| THEME | THEME |
| BANKMGR | ABOUT |
| FILEIO, FILEDIR, SHIM.FUTILBANK | FILES |
| APPSYS | program start and exit |
| COMBO | not on the bar; GUIFRMT includes it |

Order:

1. COMBO: 13 names, 23 uses outside itself. It proves the method cheaply.
2. THEME and APPSYS.
3. GUI, GUI2, LINEINPUT, MENUVERT, MENUBAR: 740 B. These are identical in the working copy and
   root, so they reach root by a plain copy.
4. The utilities: STRINGS, STRUSING, STRCASE, SORT, FILEIO, FILEDIR, BANKMGR, STASH, STASHFILE,
   STASHVRAM, STASHVRAMGC and the SHIMs.
5. The names that belong to GPBMODS.BASL and GUIFRMT.BASL.

Keep to one module a commit, when the user asks for commits.

## 6. Root and the projects

The copies on 2026-09-12:

| state | modules |
|---|---|
| working copy = root | COMBO, GUI, GUI2, LINEINPUT, MENUBAR, MENUVERT, THEME (plain and .BANK); SHIM.COMBOBANK, SHIM.GUIBANK, SHIM.THEMEBANK |
| working copy differs from root | APPSYS.INC.BL, KB.INC.BL, SORT.INC.BL, STASH.INC.BL, STASHFILE.INC.BL, STRCASE.INC.BL, STRINGS.INC.BL, STRUSING.INC.BL |
| working copy and XBASE only | APPSYS.BANK, BANKMGR, KB.BANK, STASHVRAM, STASHVRAMGC, STRINGS.BANK, SHIM.UTILBANK |
| working copy only | FILEDIR, FILEIO, SHIM.FUTILBANK, SORT.BANK, STRCASE.BANK, STRUSING.BANK |
| XBASE copy | = working copy, except SHIM.UTILBANK.INC.BL. DB, DBBANK, DBFILE, DBFORM and SHIM.DBBANK are its own. |
| GPC-HELP copy | = root, except MENUVERT.INC.BL |

WARNING: DRIFT RUNS BOTH WAYS. A whole-file copy over a module that differs loses whatever the
target has that the source lacks. Reconcile each one first, as a separate job, and ask before
starting it.

1. **Root `GPC-BASIC/`.**
   - Copy in the converted modules that are identical.
   - Rename in root's examples; `--spread` lists them, among them MENUTST, GUI2TST, STRINGS, SPLITT,
     STRUSING, SORT, ARRAYS and STRCTST.
   - Rename in `GP-BASIC.md` and `GP-BASIC.GLOBALS.md`. They are the MKHELP masters, so the help
     files follow only when the user asks for a regeneration.
2. **XBASE.**
   - Settle SHIM.UTILBANK, then copy the converted shared modules into `samples/XBASE/GPC-BASIC/`.
   - Rename in `XBASE.BASL`, `XBMENUS.BASL` and `XBASE.GUI.TEST.BASL`.
   - Convert the DB modules and the shell's own names (`--names free XBASE`).
   - Run `--check XBASE`, then `python source/gpc/xbasebuild.py XBASE`.
   - The DBBANK verbs take numeric formals DB.A, DB.F and DB.EXACT. DBBANK was not in the
     2026-09-11 build, so the scan has not seen it.
3. **GPB.HELP.**
   - Its copy follows root. Copy the converted root modules in, reading the MENUVERT.INC.BL
     difference first.
   - Rename in `GPB.HELP.BASL` and convert its 68 free names.
   - Run `--check GPB.HELP`, then `python source/gpc/helpbuild.py`.
4. **GUIFRMT** builds from the working copy with GPBMODS, so §5 covers it.

## 7. Not part of this unless the user says so

- samples/edit (APPSYS, GUI, LINEINPUT, MENUBAR, MENUVERT, STASH, STRCASE, THEME), samples/color-test
  (APPSYS, THEME) and samples/cruncher (KB, STRCASE, STRINGS) include their own older copies.
  Converting them is the user's decision.
- PICKDEMO: never built.
- BMXVIEW, COLORTST and EDITOR in `samplesbuild.py`: not measured.
- The compiler. `FOR X% =` stays an error; `for.asm` records an int16 index as measured no faster.

## 8. int16scan.py

```
python source/gpc/int16scan.py [PROGRAM ...]          a table a program
python source/gpc/int16scan.py --names TIER PROGRAM   free | review | blocked | array, reason, file:line
python source/gpc/int16scan.py --check [PROGRAM ...]  a name used plain and with %; exit 1 on a new one
python source/gpc/int16scan.py --spread PROGRAM       where each module's names are used, repo-wide
```

The programs are GPBMODS, GUIFRMT, XBASE and GPB.HELP.

- **Names and file list** come from `drive/<PROGRAM>.SRC.SYM`, which strips suffixes. The suffixes
  come from the sources as they are now, so `--check` and `--names` follow edits without a rebuild.
  A changed `#INCLUDE` list needs a fresh SYM.
- **Variable space and workspace** are read from `drive/<PROGRAM>.PRG`: the bootstrap's two page
  numbers and the first `.varspace` operand.
- **`KNOWN_PAIRS`** holds FILE.DIR.SLOW until FILEDIR is converted.
- **`--spread`** walks `EDIT_ROOTS`. It skips `HELP-TXT/`, `GPC-HELP.md`, `GPC-HELP.WIN.md` and
  `GPC-HELP-TESTING.md`, which are generated.
- **Taint.** A FOR index taints what is assigned from it only when a bound of its own FOR is out of
  range. Nothing inside a PEEK or VPEEK argument counts.
