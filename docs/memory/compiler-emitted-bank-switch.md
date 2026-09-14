---
name: compiler-emitted-bank-switch
description: TODO ranked item 4 -- steps 1-2 (runtime .bgosub, compiler emits it) BUILT and tested 2026-09-13; step 3 (twin modules merged, shims deleted) DONE the same day; step 4 built and tested 2026-09-14, gpctest ref PASS and banktest3 ALL PASS; docs committed, compiler code not
metadata:
  type: project
---

**Steps 1 to 4 are done and tested. The docs are committed; the compiler code is not.** A GOSUB, GP.SUB, GP.FN or FN
into a `GP.BANKED` region from outside it now selects the region's bank itself, and `RETURN` puts
the caller's bank back. No `BANK` statement and no shim is needed.

## Step 1, the runtime

- `.bgosub` = `$F5`, appended in `source/common-scripts/pcode.py` with size 3. Layout
  `.bgosub lo hi bank`: the offset is a `.gosub`'s, measured from its first byte, and the bank byte
  follows it.
- The handler is `source/gp-runtime/source/commands/bankgosub.asm`, in the GP block. It opens
  `FRAME_BGOSUB` (`$E5`), saves the position, and writes the caller's **hardware** bank
  (`SelectRAMBank`) at +1. It reads the offset **before** it selects the target's bank, because a
  caller in another region has its operand under its own bank.
- `StackFindFrame` (`frames.asm`) does `eor requiredFrame / lsr a`. It ignores bit 0 and returns
  it in carry. `$E4` and `$E5` are the only two markers that differ in bit 0 alone. `FixUpY` starts
  with `clc`, so `NEXT` does not see the change.
- `RETURN` (`gosub.asm`) does `bcc` after `StackLoadCurrentPosition`, which leaves carry alone.
  Then `ldy #1`, and it writes the saved bank to `SelectRAMBank`. `Y = 1` also steps over the bank
  byte.
- **`ramBank` is never touched.** It is `$FF` until `BANK` is used, and PEEK and POKE switch to it
  around each access. The first draft copied it into the register, which would have selected bank
  255 on RETURN.
- Bytes: embedded core +12 B, **4 B left** before GPBase moves off `$3700` (see
  [[gpc-core-page-cushion-below-gpbase]]). SHARED: 542 B of core free, 633 B free in the GP block.

## Step 2, the compiler

- **Both passes must emit the same bytes**, and `.bgosub` is one byte longer than `.gosub`. Pass
  one only has line numbers, so `GPBankScanLines` (`gpbank.asm`), called from `compiler.asm` before
  the first pass, reads the source once and records each region's first line, last line and bank
  in `gpBankLinesIn` / `gpBankLinesOut` / `gpBankBanks`, count `gpScanCount`.
- `WriteBranchTo` (`goto.asm`) calls `GPBankLineCall` for a target named by line;
  `WriteBranchToAddress` calls `GPBankAddressCall` for a target named by address (FN, GP.SUB,
  GP.FN). Both go through `GPBankSide`. When the target's bank is nonzero and differs from the bank
  of the caller's line, the opcode becomes `.bgosub`, and `EmitBranch` writes `branchBank` after
  the offset. FN, GP.SUB and GP.FN use the same `.bgosub`; there is no separate banked `.fngosub`.
- `GPBankMakeOffset` allows a region-to-region crossing only for `.bgosub`. **A GOTO from one region
  into another is still `NOT IMPLEMENTED`**. A GOTO that selected a bank would break the plain
  GOSUBs already open on the stack: they save no bank, so their RETURN would land at `$A0xx` in the
  wrong bank. The compiler cannot see what is open when a GOTO runs. "No frame to restore from" is
  the short form of this, and on its own it misled the user.
- **`ON n GOSUB` refuses a banked target** with `NOT IMPLEMENTED` (`on.asm`, after
  `CompileBranchCommand`): `CommandXOn` and `CommandMoreOn` step over 3 bytes an entry, and a
  `.bgosub` is 4. `samples/XBASE/XBMENUS.BASL`'s 8 `ON ... GOSUB` lines are not affected: every
  target (`XB.DISP.*`, `XB.CMD.*` in `XBASE.BASL` and `XBASE.GUI.TEST.BASL`) is in low memory.
- `GP.BANKEDSTR` shares the same three tables. `BStrRegister` appends its text regions at
  `gpBankCount` only after pass one ends, which is never below `gpScanCount`, so the scanned code
  regions are not overwritten.
- `source/application/GPC.BIN` is 29,201 B.

## Tests

The harness is `bgosubtest.py` in the session scratchpad, **not in the repo**; the programs are in
`work/bgosub/`.

- `BGA.BASL` has no `BANK` statement. It covers GOSUB region 5 to region 6 and back, region to low
  memory and back, region 6 to low memory to region 5, and GP.SUB, GP.FN and FN into region 5 from
  low memory and from region 6. `BGB` is the same file with the region lines turned into `:`. Both
  print the same 34 lines.
- `BANKY`, which the compiler used to refuse, now compiles and runs.
- `BGC` (ON into a region) and `BGD` (GOTO region to region) are refused with `NOT IMPLEMENTED`.
- All `banktest3` pairs still match their controls, and its refusals give the same errors.
- `gpctest.py quick`: 7 FAILED, all expected. They are the on and off compiles of the four programs
  with regions, GPBMODS, RGL, RGN and GUIFRMT (GUIFRMT off only). Each `.Bnn` keeps its size and
  only the PRG grows, one byte a low-memory call into a region: GPBMODS off +75 B (CODE 43,520 to
  43,776), on +58 B, RGL +3, RGN +4, GUIFRMT +29. The shim calls account for most of it. GPBMODS'
  dead-code count goes from 1,583 to 1,600 bytes saved, and the 17 B difference is exactly the
  off/on gap. The references in `work/gpctest/ref` are stale for these programs until
  `gpctest.py ref` is run again.

**BASLOAD trap found on the way:** `FNT(1)` tokenises as the array `FNT`, not as `FN T`, and the
compile succeeds and prints 0. Write `DEF FN T(X)` and `FN T(1)` with the space.

## Step 3, the merge (2026-09-13, not built)

- `samples/GPB-MODS-TESTING/GPC-BASIC/` lost its 18 `X.BANK.INC.BL` twins and 5 `SHIM.*BANK.INC.BL`
  files. Root `GPC-BASIC/` lost its 7 twins and 3 shims, and its 7 `X.INC.BL` are copies of the
  working copy's. The twins differed from the low forms only in headers and banked-only comments,
  so the low form was kept. Each module header now says to put its `#INCLUDE` inside a `GP.BANKED`
  region, and `GPC-BASIC/BANKED-OR-NOT.md` is rewritten as the rules for doing that.
- **The three verbs moved into their modules.** `FILE.SIZE` (FILEIO) and `STR.UCASE` / `STR.LCASE`
  (STRCASE) are declared by `GP.DEFPROC` on the line above the body and have **no label**: a verb
  is a name, and a label of the same name is `DUPLICATE SYMBOL`. Nothing used `GOSUB FILE.SIZE`.
- **The bank numbers moved into the programs**, because the shims held the `#DEFINE`s. GPBMODS:
  `GM.GUICODE 4`, `GM.UTILCODE 7`, `GM.FUTILCODE 8`, `GM.THEMECODE 9`, `GM.COMBOCODE 10`,
  `GM.MODSCODE 11`. GUIFRMT `GF.*CODE` and PICKDEMO `PD.*CODE`: GUI 4, THEME 9, COMBO 10. The names
  end in CODE because `GM.GUIBANK%` is already a variable.
- GPBMODS' own MODS shim is gone: `GMX.STRINGS.BODY` and `GMX.FILES.BODY` are `GMX.STRINGS` and
  `GMX.FILES` again. The five `SHIM.*` rows left GMX.B.SIZES (left column 8 to 3), and **`BS.B.NUMS`
  is stale** until the step 4 build is measured.
- PICKDEMO dropped `MENUBAR.INC.BL`, which was there only because the GUI shim file named its labels.
- Not touched: XBASE (to be dropped), the `samples/GPC-HELP/GPC-BASIC/` copies, the sample plan docs,
  `testing/`.
- **2026-09-14, the help and the rest:** root `GPC-BASIC/STRCASE.INC.BL` is now the working copy's,
  verbs included. `GP-BASIC.md` (§1, §3.11, §3.12, §4 intro and topic, §4.8, §4.13, §4.14, §4.20,
  §7), `GP-BASIC.GLOBALS.md` §4 and its STRCASE entry, and `README.md` describe `.bgosub` with no
  shims. The `.HLP` files, `GPC-HELP.md` and `.WIN.md` were patched from two renders; H001 and H067
  carry hand edits, so they took patches, not whole files. `GPC-HELP-TESTING.md` was regenerated.
  TODO item 4 is rewritten. **§4.20's bank sizes and the 12,885 B resident figure are the pre-merge
  build's** until step 4 remeasures.

## Step 4, the tests (2026-09-14)

- `samplesbuild.py GPBMODS` (still staged in `testing/`): resident object **11,619 B, was 12,885**.
  The code overlays kept their sizes (B04 7,938, B07 4,354, B08 1,538, B09 770, B10 770, B11 3,074);
  text pool B06 went from 4,610 to 4,354. Overlays total 30,224.
- `gpctest.py full --only GPBMODS,GUIFRMT`: every compile OK and both stripped identities hold
  (GPBMODS 218 lines, 1,600 B; GUIFRMT 148 lines, 1,463 B). The only failures are the byte compares
  against references that predate steps 2 and 3. GPBMODS off is still CODE 43,776 FREE 8,192, as
  after step 2, because gpctest compiles a frozen 2026-09-12 copy of the source (see Closed below).
  That `full` run did not test the merged GPBMODS.
- Sizes remeasured with `gpbsizes.py` (scratchpad, not in the repo): the MAP is split into low
  memory and regions, and each line is charged to the file of the label above it, in a space where
  that file has a label of its own. `BS.B.NUMS`, `BS.B.MEM`, `GP-BASIC.md` §4.20 (and the help) and
  the table in `samples/GPB-MODS-TESTING/readme.md` carry the figures; a rebuild after the edit gave
  the same sizes.
- **`banktest3.py` is stale twice over.** `T` is `testing/`, but its 27 sources are in
  `work/banktest3`, so every test is TOKFAIL. And `BANKY` is still in its reject list, though step 2
  made it compile. A scratch copy pointed at `work/banktest3` with `build_basl.py --drive`: 5 pairs
  SAME OUTPUT, 7 of 8 rejections hold, BANKY the one failure. That drive's `GPC.BIN` was the old
  `a76c0cdf` build and is now the current one.

## Closed 2026-09-14

- `gpctest.py ref` run with the current `GPC.BIN`: every program stored, PASS in 86 s.
- **gpctest's inputs are frozen.** `dcref.snapshot` copies `testing/NAME.SRC.PRG` into
  `work/dcref/inputs` only when the copy is missing, so gpctest's GPBMODS is the 2026-09-12 source,
  shims and all (77,062 B against 73,953 now). That is why its dead-code count stayed 1,600 B and
  its FREE stayed 8,192 through step 4. Delete an input to refresh it.
- The current GPBMODS (`testing/GPBMODS.PRG`, 11,619 B): workspace `$4000`..`$6600`, 9,728 B;
  `.varspace` 3,292. §4.20, H056 and the readme carry it.
- `banktest3.py`: `T` is `work/banktest3`, `build_basl.py` gets `--drive`, the current `GPC.BIN`
  and runtime files are copied onto the drive first, and BANKY left the reject list for a run check
  that wants Q1, Q2, Q3. Run after the fix: ALL PASS.
- §3.12 said `BANK`, `BLOAD` and `BSAVE` are refused in a region. `gpbank.asm` refuses `BANK`
  alone; §3.12 and H032 say so now.
- `memreport.asm` comments: `GPB.RT` is handlers and core, `GPC.RT` core only, and the frame stack
  gap is 2K.
- `samples/GPB-MODS-TESTING/readme.md`: the twins, shims and root-drift paragraphs are rewritten,
  and the bank table and workspace figures are the step 4 build's.

**Possible extra:** a region routine calling low memory could use `.bgosub` with its own bank, so a
low-memory routine that changes the bank no longer breaks the caller.

**Undecided:** a GOTO from low memory into a region compiles, and works only if that bank is already
selected. Refusing it too is the user's call.

Related: [[gp-banked-call-out-loses-the-bank]], [[gpc-core-page-cushion-below-gpbase]],
[[pcode-runs-from-a-bank-proven]], [[gpc-return-unwinds-frames]], [[gp-banked-region-relocation]].
