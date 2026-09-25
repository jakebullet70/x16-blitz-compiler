---
name: banks-work-in-progress
description: "Where the all-banks and handler-bank work stood on 2026-09-15 -- ALL-BANKS done, HANDLER-BANK finished at step 28, ALL-BANKS and handler steps 8-28 uncommitted"
metadata: 
  node_type: memory
  type: project
  originSessionId: c95b19c9-6122-4f0f-b70e-b6d5d25377da
  modified: 2026-09-14T17:53:34.254Z
---

Two plans in `docs/blitz/`, both untracked, done in this order:

1. `ALL-BANKS.PLAN.md` -- GP.BANKED and GP.BANKEDSTR in banks 2 to 255: `.nnn` names (no `B`), a 32-byte
   bitmap in the bootstrap extension page, `?RAM` from `MEMTOP`. Steps 1 and 2 done 2026-09-14: the asm
   shape is agreed and written into step 2 of the plan. Steps 3 to 7 done: bank 100
   up is no longer refused, `GPBANK_MAXREGIONS` is 127, not 254, because seven region tables use
   a doubled subscript, `ObjBuildOverlayName` writes three digits and no `B`, and `_WOCSExtMap`
   writes the bitmap and the highest bank through `BootExtMapOffset`/`BootExtHighOffset`. The report
   prints the bank three wide. Steps 8 and 9 are done: the page walks the bitmap, pokes three
   digits, defines both offsets and checks `MEMTOP` for `?RAM`, with 3 B free. Step 10 is done: the
   Python overlay filters test `stem + "."` and three digits, and `make libs` built steps 3 to 10
   (exit 0, GPC.BIN 31,669 B). Step 11 is done: banktest3.py passes with BNK255 at 2048K, BNK255
   at 512K (`?RAM`) and BNKOVL (`?OVL`). Step 12 is done: every old `.Bnn` matched its `.0nn`,
   PRGs differ only in the extension page, and `gpctest.py full` passes on the regenerated
   references. Step 13 is done: GPBMODS builds with eight overlays `.004` to `.011`.
   Step 14 is done: `.gitignore` takes `.nnn`, and the `release.sh` GPBMODS glob does too.
   Step 15 is done: the manual, `BANKED-OR-NOT.md` and the help copies say `.nnn`, banks 2 to 255
   and 127 regions. Step 16 is done: the samples, the demo bats and the handoff docs say `.nnn`.
   Step 17 is done: the notes and the `.asm` comments say `.nnn`, banks 2 to 255 and 127 regions.
   **ALL-BANKS is finished.**
2. `HANDLER-BANK.PLAN.md` -- rarely used runtime handlers in bank 1. Steps 1 to 9 done, built and
   tested. Step 10 is done: `BANKMGR.INIT` reserves bank 1, the three `.EXP.BL` samples use bank 2,
   and §4.13 and the help say so. Step 11 is done: `00rtbank.header` (shared, `GP`) and
   `00rtimgbank.header` (embedded, `GE`) open the four links that hold `runtime.library` and place
   the `banked` section at `$A000`, and `$(ASMBANK)` writes that section to `build/bank.prg`.
   Step 12 is done: the moved handlers and the polynomial library assemble in `banked` and leave
   through `.exitbank` and `BankedExit`, and the test links place the section in low RAM with
   `zzlowbank.footer`. Agreed 2026-09-15: no stubs; the vector entries go to `BankEnter` and
   `BankEnterShift`, which jump through tables in bank 1. Steps 13 and 14 are done: `vectors.py` writes the bank 1 tables
   and points 40 entries at `BankEnter`/`BankEnterShift`, `genmapping.py` and `genx16.py` open a
   section a handler so no opcode moves, and the two entries are in `00runtime.asm`. Step 12's
   reorder renumbered 10 opcodes; step 17's ABI change covers it. The runtime `build` test link
   overwrote its last banked byte; `testend.asm` now counts the 2 B pre-header (agreed).
   Step 15 is done: `RuntimeErrorHandler` selects `handlerBank` when the RAM bank reads 1, 11 B.
   Step 16 was done with step 11. Step 17 is done: `RT_ABI` 24 and runtime 123, and the magics read
   `GP24`, `GB24` and `GE24`. Step 18 is done: `RTGPBASE` `$6F00` and `RTBASE` `$7700`, 379 B below
   `$9F00`, and the embedded pages needed no edit. Step 19 is done: `rtname.py` installs the shared bank code as `GP1.RT.nnn.BIN` and checks its magic. Step 20 is done: the shared bootstrap checks `$A000` in bank 1 and loads the
core and `GP1.RT.nnn.BIN` by one patched name; `bootstrap2.asm` restoring the entry bank waits for room
(plan §5.1). Step 21 is done: `genrtimage.py` reads `build/bank.prg` and writes `RTIMG_BANKLEN` with a
16-page `.cerror`; the bank page's patch offset moved to step 24, with its label. Step 22 is done: `genrtimage.py` installs the embedded bank code as `GP1.IMG.nnn.BIN`
beside the image. Step 23 is done: the compiler reads it into bank 15 before the object is created
and writes it after the p-code at `BLC_CLOSEOUT`. Step 24 is done: `StartCode` copies it to bank 1 from the page `object.asm` patches and zeroes that
page, so a RUN after END keeps the copy. Step 25 built the tree: `GPC.BIN` 31,892 B, build 123 image and runtime files in `drive/`.
Step 26 passed against a build 122 control: every moved group in both modes and in a region, the bank
after a runtime error, the bank 1 LOAD chains, a mixed chain and the refusals. Embedded `SPRMEM` loses
about 40 cycles a call, above §4's 30; the user kept it in bank 1.
Step 27 is done: GPBMODS shared reports `LOW CODE 11520` and `LOW FREE 12288` (was 10240), and the
caps are 8 pages up embedded and 9 shared; the table is in the plan. GPBMODS cannot compile embedded.
Step 28 is done: the manual, the help copies, README, the notes and the `.122.` names carry build
123. The user left `TODO.md` as it is. **HANDLER-BANK is finished.**

Uncommitted: all of ALL-BANKS, and handler steps 8 and 9 (`common.inc`, `gpbank.asm`, `bootstrap2.asm`, `banktest3.py`,
`gencom.py`, `genx16.py`, `genexec.asm`, `gendata.asm`, `generated/x16_sound.def` and `.defc`, the
build outputs), handler step 10 (`BANKMGR.INC.BL`, the three `.EXP.BL` samples, the manual and the
help), handler step 11 (the two bank headers, `source/common.make`, the runtime and application
Makefiles), handler step 12 (the moved handler files, the polynomial sources and generators,
`runtime.inc`, `00runtime.asm`, `zzlowbank.footer`, the runtime and polynomials Makefiles), handler steps 13 and 14 (`vectors.py`, `genmapping.py`,
`genx16.py`, the three generated files, `00runtime.asm`, `drive/testend.asm`), handler step 15 (`errors/errorhandler.asm`), handler step 17 (`common.inc`, `rtbuild.txt`,
`generated/version.asm`), handler step 18 (`common.inc`, `runtime/Makefile`), handler step 19 (`rtname.py`, `runtime/Makefile`, `release.sh`,
`samplesbuild.py`, `banktest3.py`, `dcref.py`, `.gitignore`), handler step 20 (`bootstrap.asm`), handler step 21 (`genrtimage.py`, application `Makefile`), handler step 22 (`genrtimage.py`, application
`Makefile`, `release.sh`, `.gitignore`, `dcref.py`, `banktest3.py`), handler step 23 (`object.asm`, `api.asm`,
`bumpbuild.py`, `x16_storage.inc`), handler step 24 (`00rtimage.header`, `10object.divider`,
`genrtimage.py`, `object.asm`, application `Makefile`), handler step 28 (the manual, the three help Markdown
copies, `H001.HLP`, `H076.HLP` and `GPB.HELP.IDX` in both `HELP-TXT` folders, `README.md`, the GPBMODS
`PLAN.md`, `drive/readme.md`, `help-demo.bat`, `fntest.py`, `BUILD-HANDOFF.md`, four notes), both plans and `docs/blitz/EMBEDDED-VS-SHARED.md`. Another agent changed
`source/compiler/source/main/compiler.asm`; check it before staging.

`banktest3.py` passed in full on 2026-09-14, with BNK64 retired.

Offered and not accepted: the commit, deleting the unused `x16_sound.def`/`.defc`, a TODO.md entry for
the banked-literal bug, copying SNDBNK.BASL into the repo.

**Why:** the session was restarted for a bug in mid-work, and git does not say which step is next.
**How to apply:** read the plan's Phase A before doing anything. Commit only when asked. Delete this
note when both plans have landed. See [[ask-before-writing-asm]] and [[region-overlay-ovl-file]].
