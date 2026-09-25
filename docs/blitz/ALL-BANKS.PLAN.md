# All banks: GP.BANKED and GP.BANKEDSTR in banks 2 to 255

Plan for programs that use every RAM bank a 2MB X16 has, including programs that count down from
bank 255. Checked 2026-09-14 at `867976c`, plus `HANDLER-BANK.PLAN.md` steps 8 and 9, which are
uncommitted: runtime 122, `RT_ABI` 23. Paths are from the repo root.

The runtime already takes any bank. `.bgosub`, `RETURN` from a `.bgosub` frame, `BANK` and `GP.BSTR`
each store the bank as a full byte and check no range. Three limits sit in front of it, and all three
are in the compiler and in the bootstrap extension page that each program carries: the two-digit
overlay name, the one-byte-a-region table, and the 62-region count.

Do this before step 10 of `HANDLER-BANK.PLAN.md`. Both plans change `banktest3.py`. This plan changes
`bootstrap2.asm`, and that plan's step 20 changes `bootstrap.asm`.

## 1. Decisions

- Regions and text may use banks 2 to 255. Bank 0 is the KERNAL's and bank 1 is `HANDLER_BANK`.
- An overlay file is `<object>.nnn`: three decimal digits and no letter, `.002` to `.255`. The
  digits are the number the programmer wrote.
- The bootstrap's region table becomes a 32-byte bitmap, one bit a bank.
- A program may have 127 regions, code and text together. `GPBANK_MAXREGIONS` becomes 127: seven
  region tables are two bytes a region and are read with the region doubled into X or Y, and 127 is
  the most a byte holds doubled. It does not limit the bank numbers. Its three checks and
  `TOO MANY GP.BANKED REGIONS` stay.
- The extension page calls `MEMTOP` before loading anything. If the machine has no bank as high as
  the program's highest, it prints `?RAM` and returns to READY.
- The runtime does not change, so `RT_ABI` does not change.

## 2. The limits today

| Site | What it limits | Change |
|---|---|---|
| `GPBankCheckBankNumber`, `source/compiler/source/commands/gpbank.asm` | refuses bank 100 and up: `BANK OVER 99 HAS NO OVERLAY NAME` | the refusal goes; `HANDLER_BANK` stays refused |
| `ObjBuildOverlayName`, `source/application/source/compiler/object.asm` | writes `B`, a tens and a units digit | writes a hundreds, a tens and a units digit, and no `B` |
| the template writer in `object.asm`, before `_WOCSExtNameLong` | bakes `...B00` into the page | bakes `...000` |
| the digit loop after `BXNext`, `source/application/source/compiler/bootstrap2.asm` | pokes two digits | pokes three |
| `BXTable`, `bootstrap2.asm`, and `_WOCSExtTable`, `object.asm` | one byte a region, 62 regions | 32-byte bitmap |
| `GPBANK_MAXREGIONS = 62`, `gpbank.asm` | `CommandGPBankedCompile`, `GPBankScanLines`, `BStrRegister` in `gpbstrflush.asm`, and the region tables | 127 |
| `BXMAXREGIONS = 62`, `bootstrap2.asm` | table size | removed with the table |
| `_PBRLine`, `source/application/source/compiler/memreport.asm` | the report's `BANK nn` column, width 2 | width 3 |

Checked and clear:

- **Number reader.** `GPBankReadNumber` reads one byte and raises BAD VALUE on carry, so 256 and up is
  already refused.
- **`BANKMGR`.** All five copies keep a 32-byte bitmap and read a `MEMTOP` of 0 as 256.
- **Compile-time bank 63.** `BStrStorageBank = 63` is the compiler's while it compiles. A program may
  use bank 63.
- **Runtime.** `source/runtime/source` and `source/gp-runtime/source` have no constant that bounds a
  bank number.
- **Scripts.** The Python scripts match `.B` plus `isdigit()`, so three digits already match.

## 3. The extension page

From `source/application/build/code.lbl` at the current build.

| Item | Address | Bytes |
|---|---|---:|
| code, `BXEntry` to `BXErrDone` | `$0900` | 96 |
| `BXTable` | `$0960` | 63 |
| `BXNameLen`, `BXName` | `$099F` | 49 |
| `BXBase`, `BXWS`, `BXWSEnd`, `BXIndex` | `$09D0` | 4 |
| `BXErrText` | `$09D4` | 6 |
| pad | `$09DA` | 22 |
| `BXBStrBanks` | `$09F0` | 16 |

The bitmap frees 31 bytes, so 53 are free before new code. The highest-bank byte takes 1, which
leaves 52 for the hundreds digit, the bitmap walk, the `MEMTOP` check and `?RAM`. The estimate is 30
to 40. The `.cerror` against `GPBSTRBANKS` stops the build if the page overflows.

## 4. Cost

- **Programs:** 0 bytes. The extension page is a fixed page.
- **Object names:** the template is one character longer, so an object name with overlays may be one
  character shorter before `OBJECT NAME TOO LONG FOR AN OVERLAY`.
- **`GPC.BIN`:** 19 bytes a region in its code-section tables: 13 in `gpbank.asm` and 6 in
  `main/compiler.asm`. 65 more regions add 1,235 bytes, from 30,434 to about 31,670. `FreeMemory`
  moves from `$7F00` to about `$8400`. A compiled program pays nothing for this: the object counts
  from `$0000`, not from `FreeMemory` (see `source/application/source/compiler/start.asm`).

## 5. Steps

The asm steps wait for the user's agreement on their shape (the standing asm rule).

### Phase A: measure and agree

1. **Budget.** Confirm §3 from `code.lbl` and `FreeMemory` after a clean `make libs`. Confirm that
   `x16emu -ram 2048` gives a 2MB machine and the default gives 512K.
   Done: §3 matches the 18:05 build, which is newer than every source it uses, so no rebuild.
   `FreeMemory` is `$7F00`. `MEMTOP` with carry set returns A = 64 at the default (512K), 128 at
   `-ram 1024` and 0 at `-ram 2048`. A bank exists when its number is below A, with 0 read as 256.
2. **Asm shape.** Put the options to the user and wait.
   Done: agreed 2026-09-14. No asm is written yet. A full draft of the page counts 133 B of code
   and 118 B of data, 251 of 256, so 5 B spare.
   - **Bit order.** Bank n is byte n/8, bit (n AND 7), with bit 0 worth 1. `BANKMGR` uses the same
     order: bank 19 is byte 2, mask 8.
   - **Walk.** X counts banks up from 0. When (X AND 7) is 0, the next map byte is copied to a work
     byte, `BXByte`. Each bank shifts one bit out of it with `LSR`. A set bit saves X in `BXIndex`,
     selects the bank, writes the digits and loads.
   - **Digits.** One loop over a table of 100, 10 and 1. X is the name length and the digits are
     written at `BXName-3,x`: each is set to `'0'`, then gets one `INC` per subtraction. 30 B plus the
     3-byte table. `ObjBuildOverlayName` keeps its own copy of the loop: it is in `GPC.BIN`, and the
     page runs inside the compiled program.
   - **Re-run guard.** The walk ends at `BXHigh`: `CPX BXHigh`, `INX`, `BCC BXNext`, because `INX`
     leaves the carry alone. `STZ BXHigh` after the last load leaves a second RUN only bank 0 to look
     at. A missing overlay leaves `BXHigh` as it is, so a second RUN retries every load.
   - **`MEMTOP` check.** `SEC`, `JSR $FF99`, `DEC A`, `CMP BXHigh`, `BCC BXNoRam`. `DEC A` turns the
     bank count into the highest bank the machine has, and 0 wraps to 255. `BXNoRam` loads X with the
     offset of its own text, `"?RAM",13,0`, and branches into the `?OVL` print loop.
   - **Rejected.** Shifting the map bytes in place saves about 12 B. A missing overlay stops the walk
     part way, the bits already shifted out are gone, and a second RUN would run whatever an earlier
     program left in that bank.

### Phase B: compiler

3. `GPBankCheckBankNumber` refuses only `HANDLER_BANK`. `GPBankReadNumber`'s header says 2 to 255.
   The `gpbank.asm` header drops "SIXTY-THREE IS THE LIMIT" and the two-digit reasoning.
   Done 2026-09-14, not built: the `cmp #100` test and its message are gone. The header paragraph
   on banks 1 to 63 now says 2 to 255. The one on the 1K hole and the sixty-third region is
   step 4's.
4. `GPBANK_MAXREGIONS = 127`. The three checks and `TOO MANY GP.BANKED REGIONS` stay.
   Done 2026-09-14, not built. The plan said 254, but `gpBankStarts` and six other tables are read
   with the region doubled into X or Y, so 127 is the most a byte reaches. The user chose the cap
   over splitting each table in two. The `gpbank.asm` header paragraphs on the 1K hole and the
   sixty-third region are replaced, and the `main/compiler.asm` layout comment says 13 and 127.
5. `ObjBuildOverlayName` writes three digits and no `B`. The template writer bakes `...000`.
   Done 2026-09-14, not built. The digits use step 2's loop over 100, 10 and 1, with one `INC` a
   subtraction, and come to 7 bytes more. The template writer needed no code change: it builds the
   name for bank 0, which now comes out as `...000`. The `object.asm` comments on two digits and
   bank 99 are rewritten. The same day the user dropped the `B`: the extension is the bank alone,
   and the code is 6 bytes shorter again, 1 byte more than the two-digit code in all.
6. `_WOCSExtTable` sets one bitmap bit a region from `gpBankBanks[0..gpBankCount)`, which holds text
   banks as well as code regions. It patches the highest bank into a new byte in the page.
   Done 2026-09-14, not built. The loop is `_WOCSExtMap`. It takes the mask from an 8-byte table,
   `_WOCSExtBits`, which sits after the `OBJECT NAME TOO LONG` text because the error handler never
   returns. It holds the mask in zTemp0, which is free once the template has been copied, and ORs it
   into `imageBuffer+BootExtMapOffset,y` with Y = bank / 8. The same pass keeps the largest bank in
   `imageBuffer+BootExtHighOffset`, whose template byte is 0. Step 8 defines both offsets:
   `BootExtTableOffset` is gone.
7. `_PBRLine` prints the bank at width 3.

   Done 2026-09-14, not built. `lda #2` became `lda #3` before `PrintDecimalField`. The report's header
   example is realigned, and the two "sixty-three banks is 516,096 bytes" comments now say 127 banks
   is 1,040,384, which still needs the 24-bit total. The help and manual examples wait for Phase E.

   The TOTAL could not print seven digits: `PrintDecimal`'s top power was 100000, and gpbstrflush.asm
   caps the entries at 127, so 1,000,000 bytes or more (about 123 full banks, 2MB machines only) printed
   its first digit as `:`. Fixed the same day: 1000000 heads the three power tables, the loop ends at
   `cpx #6` and the padding counts from `lda #7`. The field widths print as before. 3 bytes.

### Phase C: bootstrap

8. `bootstrap2.asm`: the bitmap replaces `BXTable` and `BXMAXREGIONS`. The walk loads each set bit
   and pokes three digits. The re-run guard follows step 2. The page defines `BootExtMapOffset`
   and `BootExtHighOffset` in place of `BootExtTableOffset`, for step 6.

   Done 2026-09-14, not built. The walk, the digit loop and the re-run guard follow step 2. The page
   assembles on its own with stubs: 121 B of code, `BXEntry` to `BXErrDone`, and 23 B free below
   `BXBStrBanks` for step 9, which needs about 20. `BXPow10` is the 3-byte table. The `bootstrap2.asm`
   comments listed in step 17 went in with it.

9. `BXEntry` calls `MEMTOP` with carry set before the first load. A of 0 means 256. If the highest
   bank is not below A, print `?RAM` and return to READY the way `BXFail` does.

   Done 2026-09-14, not built. The check follows step 2 and uses the `X16_MEMTOP` equate. `BXNoRam`
   loads X with `BXRamText - BXErrText` and branches into the `?OVL` print loop. The page assembles on
   its own with stubs: 135 B of code, `BXEntry` to `BXErrDone`, and 3 B free below `BXBStrBanks`.

### Phase D: build and test

10. The overlay filters in `source/unit-tests/dcref.py`, `source/gpc/modsbuild.py`, `xbasebuild.py`
    and `samplesbuild.py` test for `stem + ".B"` and digits, so steps 12 and 13 would find no
    overlays. They test for `stem + "."` and three digits instead. Then `make libs` in the
    background. The runtime is not rebuilt.

    Done 2026-09-14. Each filter matches a name that starts with `stem + "."`, is four longer
    than the stem and ends in three digits. `gpctest.py` and `dcstrip.py` take their list from
    `dcref.outputs`. `make libs` exits 0 with steps 3-9 in it: `compiler.library` 535,793 B and
    `GPC.BIN` 31,669 B.
11. `source/unit-tests/banktest3.py`:
    - `emu` takes a RAM size per run.
    - BNK64 is retired.
    - BNK255 has code regions in banks 255, 100 and 2 and text in bank 254. Each is called and
      prints. At `-ram 2048` it prints all four, and `BNK255.255`, `.100`, `.002` and `.254`
      exist. At 512K it prints `?RAM` and nothing from the program.
    - BNKOVL is BNK255 with `.100` deleted, at 2MB. It prints `?OVL`.
    - BNK1 and BSTR1 are still refused. Every pair and BANKY pass.

    Done 2026-09-14. `emu` passes `-ram`, `run_one` keeps the bootstrap's `?RAM` and `?OVL`
    lines, and `compile_one` deletes a program's old overlays first. BNKOVL is written from
    BNK255.BASL on every run. ALL PASS: six pairs, fourteen refusals, both overlay sets
    (`002 100 254 255`), BANKY, BNK255 at 2048K and at 512K, and BNKOVL.
12. `source/unit-tests/gpctest.py`:
    - Before regenerating references, compare each old `.Bnn` byte for byte against the new `.0nn`.
    - The PRGs may differ only in the extension page.
    - Then regenerate with `dcref.py` and run the suite.

    Done 2026-09-14. The old references went to `work/gpctest/ref-old/`, and `gpctest.py ref`
    regenerated `ref/` from dcref.py's set. All 34 compiles match: every `.Bnn` is byte for
    byte its `.0nn`, and the MAP, `D.NAME` and verdict are identical. The seven banked
    programs' PRGs differ in 160 to 166 bytes, all inside the extension page ($0900-$09FF);
    every other PRG is identical. `gpctest.py full` PASS in 156 s: 17 off, 17 on, 17 stripped,
    12 dctest, 8 dcstrip.
13. GPBMODS, built in place with `modsbuild.py`: eight overlays `.004` to `.011`, with sizes as
    before and `LOW FREE` as before. Never build PICKDEMO.

    Done 2026-09-14. GPBMODS includes its modules by bare name, so it still builds staged in
    `drive/`, which is what `modsbuild.py` does. It tokenised to 73,586 bytes and compiled to
    an 11,087-byte PRG with eight overlays: `.004` 7,682, `.005` 7,426, `.006` 4,354, `.007`
    4,866, `.008` 1,794, `.009` 770, `.010` 770, `.011` 3,074. Against the step 12 reference,
    seven overlays have the same size and `.004` is one page smaller. The workspace starts at
    `$3F00` instead of `$3E00`, so `LOW FREE` is 9,984, down from 10,240. The cause is the
    source, not the compiler: the library copies were crunched after the 10:50 snapshot, and
    the reference compiled from that snapshot by the same compiler still starts at `$3E00`.
    The extension page is byte for byte the reference's. The `.B04` to `.B11` files from the
    05:13 build are still in `drive/`.

### Phase E: names and docs

14. `.gitignore:260` `drive/*.B[0-9][0-9]` becomes `drive/*.[0-9][0-9][0-9]`. The "nn reaches 63" comments in
    `source/gpc/modsbuild.py`, `xbasebuild.py` and `samplesbuild.py`. `release.sh:119`.

    Done 2026-09-14. `.gitignore` ignores `drive/*.[0-9][0-9][0-9]` and its comment names the
    three-digit suffix. The three build scripts already said `.nnn`: their comments changed with
    their overlay loops earlier in the plan. `release.sh:119` says `.nnn`. `release.sh:203` was a
    live bug the step did not list: the GPBMODS glob took `GPBMODS.B` plus digits, so a release
    would have shipped the stale `.B04` to `.B11` and none of the new overlays. It now takes
    `GPBMODS.` plus exactly three digits, which matches `.004` to `.011` and nothing else in
    `drive/`. The 74 stale `.Bnn` files in `drive/` now show as untracked.
15. `GPC-BASIC/GP-BASIC.md`:
    - Grep for `.Bnn`, `banks 1 to 63`, `B04` and `in decimal`. The region count, the name and the
      GPBMODS overlay table change.
    - The GPC-HELP markdown copies and `H032`, `H034`, `H056` and `H075.HLP` follow.
    - The HLP files carry hand edits; the help regen is the user's call.
    - `GPC-BASIC/BANKED-OR-NOT.md` names the overlays too.

    Done 2026-09-14. `GP-BASIC.md` names the overlays `.nnn` at every site. §3.12's region-count
    paragraph says banks 2 to 255 and at most 127 regions, bank 1 reserved, `?RAM` on a machine
    without the bank, `GP.BANKEDSTR` banks counted in, and the message for one region or one text
    bank over. The overlay-files sentence gives `NAME.004` and `NAME.122`. The §4.20 GPBMODS table
    and its totals take the step 13 build: `.004` 7,682, `.007` 4,866, `.008` 1,794, the object
    11,087 bytes, the overlays 30,736. `BANKED-OR-NOT.md` says `.nnn` twice. The help copies took
    the render delta, old and new masters rendered into scratch and the diff patched in: `H032`,
    `H033`, `H034`, `H056`, `H075`, the index and the three `.md` copies. The longer paragraph moves
    "The overlay files" from `H032` to `H033`, and the index keeps 149 rows. The committed `H027`
    and the first `H034` hunk still carry the older NEEDS SHARED wording, which names no overlay,
    so those hunks had nothing to change.
16. Samples:
    - The GPBMODS ABOUT text: grep `OVERLAYS 8` and `.B07` in `samples/GPB-MODS-TESTING/GPBMODS.BASL`.
    - The `XBASE.B04` checks in `xbase-demo.bat` and the comment in `gpbmods-demo.bat`.
    - The tables in `samples/GPB-MODS-TESTING/readme.md`, plus `drive/readme.md`,
      `source/gpc/BUILD-HANDOFF.md` and `docs/blitz/EMBEDDED-VS-SHARED.md`.
    - The staged copies in `drive/` stay as they are.

    Done 2026-09-15. `GPBMODS.BASL` says `.nnn` in its two banner comments. The ABOUT / MEMORY
    overlay rows read `.004` to `.011`, the MODULE SIZES headings `.007` and `.004`, and the
    fourth column's bank prefixes `008` to `011`. Every literal keeps its length, so the text pools
    do not move. `gpbmods-demo.bat` says `.004` through `.011`. `xbase-demo.bat` checked for
    `XBASE.B04`, which a build no longer writes, so a stale copy passed the check and a missing
    `XBASE.004` did not stop it; the check, its message and the comment now say `XBASE.004`.
    `samples/GPB-MODS-TESTING/readme.md` names the files `GPBMODS.004` to `.011` and the breakdown
    rows `.004` to `.011`. `drive/readme.md` lists `*.nnn`. `BUILD-HANDOFF.md` gives `.002` to
    `.255` and `?RAM`. `EMBEDDED-VS-SHARED.md` says `.nnn` five times. The sizes in the readme and
    the two GPBMODS panels are unchanged: they are one build's snapshot, and the step 13 build moved
    `.004`, `.007`, `.008` and the object, so updating them is a remeasure against
    `drive/GPBMODS.MAP` and `GPBMODS.SRC.SYM`, not a rename. `GUI-CUA-PLAN.md`,
    `GUI-PAGE-PLAN.md` and `samples/XBASE/` still say `.Bnn`; they are history or XBASE, and the
    step did not list them.
17. Notes:
    - `docs/memory/region-overlay-ovl-file.md` ("Two digits, so the bank caps at 99") and its
      `MEMORY.md` line.
    - `HANDLER-BANK.PLAN.md` §6, which says TOO MANY fires at the 64th, and its step 9 cap of 62.
    - The `bootstrap2.asm` comments that say two digits, 99 or `B00` went in step 8. The `object.asm`
      ones went in step 5.
    - `.Bnn` in the comments of `api.asm`, `start.asm`, `read.asm`, `memreport.asm`, `gpbank.asm`,
      `gpbstr.asm` and `gpbstrflush.asm`. The `write.asm` paragraph on the orphan sweep says every
      extension this project uses begins with B, which the overlays no longer do.
    - `CLAUDE.md` ("the overlay `.Bnn` sizes") and the memory notes that name `.Bnn`: grep
      `docs/memory`.
    - A `TODO.md` entry, if the user asks for one.

    Done 2026-09-15. The comments in `api.asm`, `start.asm`, `read.asm`, `write.asm`,
    `memreport.asm`, `gpbank.asm`, `gpbstr.asm`, `gpbstrflush.asm` and `x16_storage.inc` say `.nnn`.
    `write.asm`'s orphan-sweep paragraph says the wildcard ate the source while the overlays were
    `.Bnn`, and that the overlays now begin with a digit but no wildcard goes through
    `IOScratchFile`. Two `gpbank.asm` comments that steps 3 and 4 missed are rewritten: the
    paragraph on overlay names, bank 100 and `.B:0`, which headed the deleted refusal and now
    keeps only its compiler-space reason and says every bank from 2 up has a name; and the region
    table's cost, now 13 bytes a region and 2,413 at 127. `region-overlay-ovl-file.md` describes
    the bitmap, the three-digit template, `?RAM`, the 127 cap and BNK255.
    `wildcard-scratch-eats-the-source.md`, `second-region-for-the-utilities.md`, five other notes,
    `CLAUDE.md` and both `MEMORY.md` lines follow. `HANDLER-BANK.PLAN.md` §6 records BNK64 retired,
    and its step 9 records both caps replaced. No `TODO.md` entry. Nothing was built, so the
    `_library.asm` copies keep the old comments until `build.py` sweeps them at the next make.
