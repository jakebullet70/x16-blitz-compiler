# Handler bank: rarely used handlers in bank 1

Plan for option 3 of selective handler inclusion, item 2 in `TODO.md`
`## Compiler work — what is next, ranked`. Phase A is done. Checked 2026-09-14 at
`867976c`: runtime 122, `RT_ABI` 23. The mode comparison is in `EMBEDDED-VS-SHARED.md`. Paths are from
the repo root.

Six groups of rarely used handlers move from low RAM into bank 1 at `$A000`, in embedded and shared
mode. Low RAM keeps an entry stub for each moved handler. Every program gains the RAM whether it
uses the handlers or not. The compiler scans nothing.

## 1. Decisions

- Bank 1 is reserved for the handlers. The compiler refuses `GP.BANKED 1` and `GP.BANKEDSTR` text in
  bank 1. `BANKMGR.INIT` marks bank 1 taken.
- Both modes move the handlers. Each mode has its own build of the banked code.
- `MOVSPR` and the sprite address routines stay low, so the per-frame sprite path pays no bank
  switch. `SPRMEM` moves.
- The four string sound commands, all of `audioparams.asm`, `CHAR` with the three graphics routines it
  calls, and `TileSetAddress` stay low.
- `π` moves with the polynomials.

## 2. What moves and what stays low

Sizes are from `source/runtime/build/code.lbl` at runtime 122.

| Group | Moves (B) | Low entries | Stays low |
|---|---:|---:|---|
| polynomials | 1,161 | 9 | |
| sprites | 336 | 2 | `MOVSPR`, `SpriteSetAddress`, `SpriteSetAddressInc`, `SpriteSetAddressCommon`: 127 B |
| sound | 215 | 15 | `FMPLAY`, `FMCHORD`, `PSGPLAY`, `PSGCHORD`, all of `audioparams.asm`: 100 B |
| graphics | 200 | 6 | `CHAR`, `GraphicsColour`, `GraphicsCopy2`, `GraphicsCopy1`: 80 B |
| tiles | 53 | 3 | `TileSetAddress`: 130 B |
| mouse | 107 | 5 | |
| **Total** | **2,072** | **40** | |

- Polynomials are SIN COS TAN ATN LOG EXP SQR `^`, entered through the 8 `Link*` wrappers in
  `source/runtime/source/generated/links.asm`. The row includes the wrappers and `UnaryPI`, which
  reads the polynomial constant table through `LoadConstant`. `FloatPI` (8 B) has no callers.
- Sprites: `SPRITE` 203 B, `SPRMEM` 98 B, `MOVSPR` 72 B, the three address routines 55 B.
  `SpriteApplyDepth` (13 B) and `SpriteEnableLayer` move with `SPRITE`.
- 38 stubs at about 5 B and the bank routine at about 25 B come to about 215 B. The net gain is about
  1,860 B. Step 12 replaced the stubs with two entry routines and tables in bank 1, about 26 B low,
  which gains about 185 B more. Step 18 sets the pages. Measured after step 15:
  - **Embedded:** the core ends at `$2E9F`, 97 B below `GPBase`. `GPBase` and `ObjectBase` are 8 pages
    lower than at runtime 122.
  - **Shared:** `code.prg` ends at `$9485`, 2,683 B below `$9F00`. `RTBASE` can move up 10 pages, which
    leaves 123 B.
  - **Bank 1:** 2,434 B: the magic, 2,198 B of handlers and 232 B of tables.

## 3. Call path

- The vector entries of the moved handlers point at `BankEnter`, or `BankEnterShift` in the shifted
  table. Each saves the RAM bank in `handlerBank`, selects bank 1 and jumps through a table in bank 1
  with the X the dispatcher left, which indexes it like the low table. Every moved handler starts
  with `.entercmd` (`plx`), and none reads A on entry. There are no stubs. Agreed 2026-09-15: about
  26 B low, where 38 stubs took about 215 B.
- Banked code exits with `.exitbank`, which jumps to `BankedExit`. That selects `handlerBank` and falls
  into `NextCommand`. `.exitcmd` is `jmp NextCommand` (`source/runtime/source/main/runtime.inc:17-18`),
  so an entry cannot JSR a command handler.
- The polynomial entries are the `Link*` wrappers, which run from `.entercmd` to `.exitcmd` and JSR the
  float routine. They move as they are, with the banked exit macro. A `bcs MapRangeError` cannot reach
  low RAM from `$A000` and becomes a `bcc` over a `jmp MapRangeError`. `MapRangeError` and
  `DivZeroError` stay low for the other wrappers.
- Banked code calls other banked code directly, never through a vector entry, which overwrites
  `handlerBank`.
- Banked code calls low routines directly. Low RAM is visible under every bank.
- A runtime error goes to `RuntimeErrorHandler` and then `EndRuntime`
  (`source/runtime/source/errors/errorhandler.asm:18-63`). When the RAM bank reads 1, the error handler
  selects the saved bank first. `EndRuntime` is unchanged.

## 4. Cost

- A stubbed call adds about 30 cycles, about 4 µs at 8 MHz.
- Measured on runtime 122, 50,000 calls of each, timed with `TI`. Shared and embedded agree within 1
  jiffy. The cycles include working out the arguments.

| Statement | Jiffies | Cycles a call | A stub adds |
|---|---:|---:|---:|
| empty `FOR` loop | 171 | | |
| `MOVSPR 1,X%,Y%` | 484 | about 830 | 3.6% |
| `SPRMEM 1,1,$3000,1` | 514 | about 915 | 3.3% |

- `MOVSPR` stays low, so its cost is not paid. 128 banked `MOVSPR` a frame would add about 0.5 ms of a
  16.7 ms frame.
- `SPRMEM` moves. Keeping it low frees 93 B less, which costs a page in embedded mode (7 to 6) and
  leaves 3 B in shared mode. Step 26 times it again.
- SIN, COS and the other polynomials already cost thousands of cycles: under 1%.
- Sound, mouse and graphics already call the ROM: a few percent at most.
- One RAM bank is lost to programs.

## 5. Loading bank 1

### 5.1 Shared

- The bank code for the shared link is a third runtime file, `GP1.RT.nnn.BIN`. Its first four bytes
  at `$A000` are the core's magic, `GP` and `RT_ABI`, so the check compares with `BBMagic` and adds no
  data. The embedded bank code uses `GE`.
- The bootstrap saves the RAM bank and selects bank 1. After the resident check it compares `$A000`
  with `BBMagic`. A mismatch takes the cold path, which LOADs the core and then the bank code from
  the same place, the current directory or the root. The two always come from one load, so a magic
  without the build number is enough. The bootstrap restores the RAM bank before the handover, so a
  `POKE` to `$A000` with no `BANK` still writes the bank BASIC left selected.
- Room, from `source/application/build/code.lbl`:
  - Page one has 37 B free, `$08DB` to `$08FF`. Page two had 21 B free, `$09DB` to `$09EF`, and has 3
    now, `$09ED` to `$09EF`; only a banked program carries it, so it is no fallback.
  - The change takes about 46 B: 13 for the compare, 22 for the second LOAD from the same place and
    11 to select bank 1 and restore the entry bank.
  - `GPB.RT.nnn.BIN` and `GPC.RT.nnn.BIN` differ only in the third character, and `GP1.RT.nnn.BIN`
    follows suit. One name with that character patched frees 39 B: 15 of string, 23 of the name table
    and `BBLoadX`, and `BBNameIdx`. Page one then has about 30 B left.
- Open: `bootstrap2.asm` selects each region's bank to load it and hands over with the highest still
  selected, as it did before this plan. Restoring the entry bank there takes about 9 B and page two
  has 3 B free, so it waits for room. The handlers do not depend on it: the runtime saves and restores
  the bank around every bank 1 handler.

### 5.2 Embedded

- The banked code jumps into low RAM at fixed addresses. The embedded image is linked at `$0801` and
  the shared runtime at `$6600`, so each link builds its own bank code.
- An embedded object has no bootstrap. The compiler writes the bank code after the p-code, from the
  next page. `StartCode` in `source/application/source/main/00rtimage.header` copies it to bank 1 at
  `$A000`, selects the previous bank and jumps to `StartRuntime`.
- The copy sits in the frame-stack gap and workspace above the p-code, which are unused until
  `StartRuntime`. `PrepareObjectCode` (`source/application/source/compiler/object.asm`) leaves at least
  `MIN_WS_PAGES` (16) pages there. The bank code is 2,432 B, copied as 10 whole pages. A build check
  keeps it under 16.
- Every embedded program copies once it is loaded, so a LOAD chain needs no magic check. The copy
  zeroes its page operand, and a RUN after END, whose workspace no longer holds the bank code, keeps
  bank 1 as it is. The embedded bank code carries a different magic from the shared one, and a shared
  bootstrap that finds it reloads its own.
- The copy takes about 5 ms once. The object file size is about unchanged: the image loses the bytes
  and the tail gains them.

## 6. Checked

- **IRQ.** No runtime source writes `$0314` or contains `sei`, `cli` or `RTI`.
  - Sound reaches the audio ROM through `JSRFAR`, which works from any bank. `FMPLAY` and `PSGPLAY`
    wait on the KERNAL frame IRQ with `WAI`. The KERNAL keeps the RAM bank.
  - Mouse calls `screen_mode`, `mouse_config` and `mouse_get`. `mouse_get` writes to zero page at
    `zTemp0`.
  - Sprites write VERA registers directly. Their scratch bytes are in the `storage` section, in low
    RAM.
- **P-code reads.** No moved handler reads through `codePtr`, directly or through a routine it calls
  (`GetInteger8Bit`, `GetInteger16Bit`, `FloatIntegerPart`, `FloatSetByte`, `FloatNegate`,
  `LoadConstant`, the float routines). Optional arguments are markers on the number stack.
  `RuntimeErrorHandler` prints `codePtr` in hex and reads no p-code. `horner.asm` reads its
  coefficient table through `zTemp0`, and the table moves with it.
- **ROM calls.** Graphics and mouse call KERNAL jump-table entries (`$FEFF`-`$FF6B`), which work under
  any RAM bank. `JSRFAR` reads the `.word` and `.byte` after the call under the current RAM bank, which
  is bank 1 for a moved sound handler.
- **Callers.** Outside the moved code, only `source/runtime/source/generated/vectors.asm` enters a
  moved routine, at the 38 entries the stubs replace.
  - `tiledata.asm` and `gpdraw.asm` use `tileX`, `tileY` and `tileSelect`. These are in the `storage`
    section, in low RAM, like the sprite, power and Horner scratch bytes.
  - `genmapping.py` names the 8 polynomial routines. `floatcom.py` names them for the float library's
    own tests. `genrtimage.py` reads `GPBase`, `ObjectBase`, `VectorTable`, `ShiftVectorTable`,
    `RunCodePage` and `RunWorkspacePage`, none of which move.
  - GP.ASM resolves names from the BASLOAD symbol file only. The 31 absolute `JSR` and `JMP` in the
    samples, the library and the tests all target ROM.
- **Strings.** `CHAR` reads its string through a pointer
  (`source/runtime/source/system-specific/x16/commands/graphics.asm:128-152`). A string literal is a
  pointer into the p-code (`source/runtime/source/support/pushstring.asm:21-31`), so in a region its
  text is in the region's bank.
- **The banked-literal sound bug.** The audio ROM requires the string pointer of `bas_fmplaystring`,
  `bas_psgplaystring`, `bas_fmchordstring` and `bas_psgchordstring` to be in `$0000`-`$9EFF`.
  `X16_Audio_Parameters8_String` passes the string address straight through
  (`source/runtime/source/system-specific/x16/commands/audioparams.asm:54-60`). `FMPLAY 0,"CDE"` in a
  `GP.BANKED` region passes an `$Axxx` pointer today. A string variable and `GP.BANKEDSTR` text are
  in low RAM. `OPEN`, `LOAD` and `SAVE` pass a name pointer to the KERNAL and are not checked.
  - Both routines save the RAM bank and select bank 0 before they parse, because their state is at
    `$ADEF`-`$ADF9` (audio ROM bank 10, `$D508`-`$D50A` and `$D661`-`$D663`). A literal at `$Axxx`
    is read from bank 0.
  - Tested headless, shared (step 7). After `PSGPLAY 0,"T255L32O4CDE"`, voice 0's frequency reads
    `$0374` from low p-code and from a string variable in a region, and `$0000` from the literal in
    the region. `FMPLAY` of the same literal takes 3 jiffies low and 1 in the region: no note plays
    and nothing hangs.
- **Tiles.** `TileSetAddress` is called from
  `source/gp-runtime/source/system-specific/x16/commands/gpdraw.asm:365` and
  `source/runtime/source/system-specific/x16/unary/tiledata.asm:50`.
- **Bank 1 use.** A program that writes bank 1 at run time breaks every later call to a moved handler.
  - `BANKMGR.INIT` reserves only bank 0, so `BANKMGR.GET.FREE.BANK` hands out bank 1 first. GPBMODS
    claims banks 4 to 11, then allocates `GM.DDBANK%` (1), `GM.GUIBANK%` (2) and `GM.DIRBANK%` (3).
    STASH and STASHFILE write the first. `FILEDIR.INC.BL` and XBASE allocate the same way.
  - `GPC-BASIC/MENU.EXP.BL:101` and `GPC-BASIC/SCREEN.EXP.BL:108-126` set `STASH.BANK = 1`.
    `GPC-BASIC/MLCALL.EXP.BL:26-30` POKEs machine code into bank 1. None of the three calls a moved
    handler afterwards. They have no working copies.
  - `GMX.S.FILE` in GPBMODS selects bank 1 only to check that STASHFILE leaves it selected.
    `drive/RGL.BASL` and `drive/RGN.BASL` select it and write nothing.
  - BNK64 in `source/unit-tests/banktest3.py` compiled regions in banks 1 to 64 and expected
    `TOO MANY GP.BANKED REGIONS` at the 64th. `ALL-BANKS.PLAN.md` step 11 retired it for BNK255,
    which uses banks 2, 100, 254 and 255. Both sources are in the untracked `scratch/banktest3/`.
    Apart from the BNK1 and BSTR1 refusals, no test uses bank 1.
  - The other samples use fixed banks 3 and up: the editor 4 and up, GPB.HELP 8 to 10, GUIFRMT 3, 4, 9
    and 10, PICKDEMO 4, 9 and 10, the spike 7 and `GUI.EXP.BL` 8.
  - The compiler uses banks 2 to 14 (`source/compiler/source/system-specific/x16/x16_storage.inc:61-80`).
    Bank 1 is the native test harness's object buffer, which is saved to a file and never run. The
    BASLOAD-GPC engine keeps 2,846 B in bank 1 (`BASLOAD-GPC/RESEARCH.md:131`) and runs under stock
    BASIC. A build can leave bank 1 overwritten before a run, which §5.1's magic check and §5.2's
    copy cover.
  - The runtime selects a bank only for `BANK`, `PEEK`, `POKE`, the load and save commands and
    `.bgosub`. The manual and the help text show no bank 1 example.
- **Errors.** No runtime error runs p-code on.
  - `StartRuntime` installs the only handler, `RuntimeErrorHandler`
    (`source/runtime/source/main/00runtime.asm:56-58`). The compiler installs its own and never runs
    with the runtime. No keyword traps or resumes after an error.
  - `STOP`, Ctrl+C (`source/runtime/source/system-specific/x16/interface/x16_checkstop.asm:22-26`),
    `.deferror` and `LoadSaveError` raise through the same handler.
  - `RuntimeErrorHandler` prints and jumps to `EndRuntime`. Its `txs`
    (`source/runtime/source/commands/end.asm:32-33`) is the only stack reset in the runtime, and its
    `rts` returns to BASIC.
  - An `.error_*` macro is an absolute `jmp` to an `ErrorV_*` entry, which reaches low RAM from `$A000`.
    The messages are in low RAM. The handler prints through `CHROUT`, which keeps the RAM bank.
  - The moved files contain no `jmp`. 57 of the 58 entries end in `.exitcmd`. `TDATA` branches into
    `TATTR`'s tail in the same file. The only error raises are `MapRangeError` and `DivZeroError` in
    `links.asm`, which stay low.
  - `EndRuntime` does not select a bank. The RAM bank is written only by `RETURN` from a `.bgosub`
    (`source/runtime/source/commands/gosub.asm:43`), `BLOAD`, `BVERIFY` and `BSAVE`, and `PEEK` and
    `POKE`, which put it back. A program that ends leaves the last bank it selected, which is a
    region's bank when it ends inside one.

## 7. Steps

### Phase A: measure

1. **Sizes and timing.** Done: §2 and §4.
2. **Handlers that read p-code.** Any moved handler that reads bytes through `codePtr` reads the wrong
   bank when the p-code is in a region. Such a handler stays low. Done: none, §6.
3. **Callers into the moved groups** from the rest of the core runtime, the GP block, the compiler
   scripts and GP.ASM symbol names. Done: only the vector table, §6.
4. **Bank 1 use.** `BANK 1`, `GP.BANKED 1` and STASH writes to bank 1 in the samples, the library and
   the tests. Done: the bank manager, three root examples and BNK64, §6.
5. **Bootstrap room.** Free bytes of the 255 in `source/application/source/compiler/bootstrap.asm`.
   Done: 37 B free against about 46 needed, and one patched runtime name frees 39, §5.1.
6. **Error paths.** Anything besides `EndRuntime` that catches a runtime error and runs p-code on.
   Done: none, and `EndRuntime` selects no bank today, §6.
7. **The string bug.** A headless test runs `FMPLAY` with a literal string in a `GP.BANKED` region.
   Done: the bug is real for `PSGPLAY` and `FMPLAY`, and a string variable is not affected, §6.

### Phase B: the banked-literal sound bug

8. Inside a `GP.BANKED` region the compiler concatenates `""` onto the string argument of `FMPLAY`,
   `FMCHORD`, `PSGPLAY` and `PSGCHORD`, which copies it into a low temporary before the `JSRFAR`. A
   new generator nibble D (`@` in `gencom.py`, `#,@` from `genx16.py`) runs `_GEXLowString` in
   `genexec.asm`, the same 3 B the string `GP.FN` emits. The runtime is unchanged, so embedded
   programs keep their page. The step 7 test passes. This phase can ship alone.
   Done: `BANK LIT PSG 116 3` and `BANK LIT FM 3`, as in low code. The region's overlay grew 9 B for
   three calls (`SNDS.B04` 72 to 81); the low p-code (785 B) and `x16_sound.asm` are unchanged.
   `gendata.asm` now includes `generation/x16_sound.defc`, the file `gencom.py` rebuilds; the
   duplicate under `generated/` is no longer used.

### Phase C: reserve bank 1

9. `HANDLER_BANK = 1` in `source/common-source/source/common.inc`. `GPBankCheckBankNumber` in
   `source/compiler/source/commands/gpbank.asm` refuses it with `BANK 1 IS RESERVED`. `GP.BANKED` and
   `GP.BANKEDSTR` both read their bank through `GPBankReadNumber`, which ends there. `GPBANK_MAXREGIONS`
   and `BXMAXREGIONS` in `source/application/source/compiler/bootstrap2.asm` drop from 63 to 62.
   BNK64 in `banktest3.py` starts at bank 2.
   Done: `banktest3.py` refuses BNK1 (`GP.BANKED 1`) and BSTR1 (`GP.BANKEDSTR 1`) at their header
   lines, and BNK64 at its 63rd region. The check is in compiler space, so programs pay nothing.
   `ALL-BANKS.PLAN.md` then replaced both caps: `GPBANK_MAXREGIONS` is 127, `BXMAXREGIONS` went
   with the bootstrap's region table, and BNK255 replaced BNK64.
10. `BANKMGR.INIT` marks bank 1 taken in `samples/GPB-MODS-TESTING/GPC-BASIC/BANKMGR.INC.BL`. The root
    library has no copy, and XBASE's two copies wait for XBASE work. GPBMODS's data banks become 2, 3
    and 12. `MENU.EXP.BL`, `SCREEN.EXP.BL` and `MLCALL.EXP.BL` in `GPC-BASIC/` use bank 2. The
    manual's §3.12 and its bank table mark bank 1 reserved.
    §3.12's sentence went in with `ALL-BANKS.PLAN.md` step 15; the bank table is still to do.
    Done 2026-09-15. `BANKMGR.INIT` reserves bank 1 after bank 0, and the module header says why.
    GPBMODS claims banks 4 to 11 and then asks `GET.FREE.BANK` for three, so it is handed 2, 3 and 12.
    Its source names no run-time bank number, so it did not change, and it was not run.
    `MENU.EXP.BL` and `SCREEN.EXP.BL` set `STASH.BANK = 2`, and `MLCALL.EXP.BL` defines `ML.BANK 2`.
    The manual has no table of banks; its bank-ownership rule is §4.13's "0 is not a bank" paragraph,
    which now says `INIT` reserves bank 1 for the runtime and `GET.FREE.BANK` hands out bank 2 or
    higher. The help took the render delta. `H049` was taken whole, because it equalled a render of
    the old masters. The index (topic 49, 60 to 62 lines) and the three `.md` copies were patched,
    and the §3.12 reference adds 3.12 to 4.13's see-also line. Not changed: `GMX.S.FILE`'s `BANK 1`,
    which selects the bank and writes nothing, `drive/RGL.BASL` and `RGN.BASL`, XBASE's two
    `BANKMGR` copies, and the staged `drive/BANKMGR.INC.BL`. Nothing was built.

### Phase D: split the runtime, both links

11. **Build flag.** The flag selects the embedded or the shared link. Both assemble the bank code.
    Done 2026-09-15. The flag is a header file on the link line, not a `-D` symbol, like every other
    difference between the links. `source/runtime/source/main/00rtbank.header` opens `gpc-rt`, and
    `source/application/source/main/00rtimgbank.header` opens link one and the runtime's `build` and
    `checkall` test links. Each places the `banked` section at `$A000` and opens it with its magic,
    so step 16 went in here, and a `.cerror` keeps the magic at `$A000`. The four links use
    `$(ASMBANK)`, new in `source/common.make`: `--output-section=code` writes `build/code.prg` and
    `--output-section=banked` writes `build/bank.prg`. With one output 64tass fills the gap up to
    `$A000`. `.gitignore` takes `source/*/build/bank.prg`. Each link was assembled into the
    scratchpad with the old command and the new: `code.prg` is byte-identical for `build` (16,161 B),
    `gpc-rt` (14,052 B) and link one (13,569 B), the labels gain only the header's, and `bank.prg` is
    the 4-byte magic. `checkall` stops with "storage has overflowed into the code" under both
    commands, so that predates this step. A banked section with no header stops with
    `not defined 'banked'`. Nothing was built into the tree, and nothing installs `bank.prg` yet.
12. **Assemble at `$A000`.** The moved groups get the banked exit macro and the low bank-restore
    routine. Their `storage` sections stay in low RAM.
    Done 2026-09-15, in the shape agreed that day: no stubs (§3), `handlerBank` in `storage`, one low
    block then one banked block a file, and the banked section in low RAM for the test links.
    - `.exitbank` (`runtime.inc`) jumps to `BankedExit` in `00runtime.asm`, 5 B that fall into
      `NextCommand`. `NXStartLoop` went: its `ldy #0` now comes before the `bra NextCommand`.
    - Banked: `SPRITE`, `SPRMEM`, `SpriteApplyDepth` and `SpriteEnableLayer`; `PSET` to `RING`,
      `GraphicsColourOptional`, `GraphicsCopy4` and `GraphicsRectCoords`; `TILE`, `TDATA` and
      `TATTR`; `MOUSE` and the four mouse functions; `UnaryPI`; and the whole polynomials library,
      with `coremaths.py` and `mathconstants.py`, which step 13 did not list. `GraphicsCopy4` fell
      through into `GraphicsCopy2`, which stays low, so it now ends with `jmp GraphicsCopy2`.
    - `source/runtime/source/main/zzlowbank.footer` places the banked section inside `code`, over a
      `.fill` with no value, because 64tass does not take a `.dsection` nested in a section. The
      runtime `build` and `checkall` links take it before `testend.asm` and are `$(ASM)` again. The
      polynomials link takes it last.
    - Assembled in the scratchpad, with the runtime and polynomials libraries built there:
      - `gpc-rt`: `code.prg` 14,052 to 12,216 B, and `RTTop` `$9CE2` to `$95B6`.
      - Link one: 13,569 to 11,777 B. `GPBase` `$3700` to `$3000` and `ObjectBase` `$3D00` to
        `$3600`. The core ends at `$2FD0`, 48 B below `GPBase`, where it was 4 B.
      - Both `bank.prg` are 1,850 B: the magic and 1,844 B of handlers.
      - The runtime `build` link is 16,161 B, as before. The banked section is at `$3583`-`$3CB6`,
        below the test object at `$3CFE`. In the polynomials link it is 1,074 B.
      - `checkall` stops on the same storage overflow as before step 11.
    - No code that stays low names a moved label. The `Link*` wrappers and the sound handlers are step
      13. The two generators reproduce their files. Nothing was built into the tree. Step 13
      pointed the vector tables at the entries.
13. **Generated code.**
    - `vectors.py` points the vector entries for moved commands at `BankEnter` and `BankEnterShift`,
      and writes the two tables they jump through into the banked section.
    - `genmapping.py`, which writes `links.asm`, puts the 8 polynomial wrappers in the banked section,
      with the banked exit macro and a `bcc` over `jmp MapRangeError`.
    - `genx16.py` uses the banked exit macro for the moved sound handlers.
    Done 2026-09-15, with step 14.
    - `vectors.py` notes which `;;` markers sit in a `.section banked` and points their entries at
      `BankEnter` or `BankEnterShift`: 8 plain and 32 shifted. `BankVectorTable` and
      `BankShiftVectorTable` run from the first banked opcode to the last, 59 and 57 entries, and a
      gap holds `Unimplemented`. `BankVectors` and `BankShiftVectors` are those tables less the first
      opcode's X, `$08` and `$18`.
    - `genmapping.py` and `genx16.py` open a section for each handler. `pcode.py` numbers the command
      opcodes in the order of the `;;` markers, so the handlers keep their order and no opcode moved.
      A banked wrapper steps over `jmp MapRangeError` with `bcc _Result`. The sound handlers other
      than the four string ones leave through `.exitbank`.
    - Step 12's reorder renumbered 10 opcodes: `CHAR` is now `$A8`, `PSET` to `RING` `$A9`-`$AE`, and
      `MOVSPR`, `SPRITE` and `SPRMEM` `$DDA4`-`$DDA6`. `pcodeconst.py` and `vectors.py` read the same
      order, so a full `make` keeps the compiler and the runtime in step. Step 17's `RT_ABI` change
      covers old objects.
    - `genrtimage.py` sets a bit for a vector entry at or above `GPBase`. The moved entries point at
      `BankEnter` in the core, so their bits stay clear.
    - `links.asm`, `vectors.asm` and `x16_sound.asm` are regenerated in the tree. `x16_sound.def` is
      unchanged.
14. **Entries.** `BankEnter` and `BankEnterShift` in low RAM, as in §3. They jump through step 13's
    tables, so the two steps assemble together.
    Done 2026-09-15: 12 B each, before `BankedExit` in `00runtime.asm`. Assembled in the scratchpad,
    against step 12:
    - `gpc-rt`: `code.prg` 12,216 to 11,900 B, and `RTTop` `$95B6` to `$947A`. `bank.prg` 1,850 to
      2,434 B.
    - Link one: 11,777 to 11,521 B. `GPBase` `$3000` to `$2F00` and `ObjectBase` `$3600` to `$3500`.
      The core ends at `$2E94`, 108 B below `GPBase`.
    - A script read all 192 vector entries from both images as the dispatcher does, and the 40 moved
      ones on through the bank 1 tables: none wrong. The only low instructions that name
      `$A000`-`$BFFF` are `jmp (BankVectors,x)` and `jmp (BankShiftVectors,x)`.
    - `checkall` stops on the same storage overflow as before. The polynomials link is unchanged.
    - The runtime `build` link's object overwrote the last banked byte, an `rts` at `$3DFE`.
      `drive/testend.asm` put `ObjectCodePreHeader` 2 B below the page after the code, and the
      banked section ended at `$3DFF`. Agreed 2026-09-15: `nextPage` counts the 2 B pre-header before
      it rounds up. The link is now 16,673 B, with the object at `$3EFE`.
15. **Errors.** `RuntimeErrorHandler` selects `handlerBank` when the RAM bank reads 1, about
    11 B and nothing on the dispatch path.
    - After Phase C no region is in bank 1, so bank 1 at an error means a moved handler was running.
      The error then leaves the bank the program had before the call, as it does today.
    - `EndRuntime` is not changed. A normal `END` never runs inside a handler, and the saved byte is
      stale by then.
    - Without the restore, bank 1 stays selected at `READY`. A direct-mode `POKE` to `$A000`-`$BFFF`
      then writes the handler code, and the next shared run passes the magic check with broken code.
    Done 2026-09-15: 11 B at the top of `RuntimeErrorHandler`, before it reads Y. The error messages
    are in low RAM, so a moved handler's `.error_*` macro reaches them from bank 1. Assembled in the
    scratchpad: `gpc-rt` `code.prg` 11,900 to 11,911 B, and the embedded core end `$2E94` to `$2E9F`.
    The vector check and the low scan are unchanged, and §2 carries the new pages.
16. **Magics.** The shared and embedded bank code each carry a magic at `$A000` that includes `RT_ABI`.
    The two differ.
    Done with step 11: `GP` and `RT_ABI` in `00rtbank.header`, `GE` and `RT_ABI` in
    `00rtimgbank.header`. The bootstrap's compare is step 20.
17. **Version.** `RT_ABI` 23 to 24, runtime 122 to 123.
    Done 2026-09-15: `RT_ABI` in `common.inc` with its changelog entry, `rtbuild.txt`, and `version.asm`
    from `bumpbuild.py`. Assembled in the scratchpad against step 15: the core magics read `GP24` and
    `GB24`, the bank code `GP24` and `GE24`, and no other byte moved. The compiler links at 31,669 B
    with `GP24`, `GB24` and the three `.123.` names. `shared_test.py` still says `RT_ABI` 20.
18. **Addresses.**
    - Shared: `RTBASE` and `RTGPBASE` move up 9 pages.
    - Embedded: `GPBase` and `ObjectBase` move down 7 pages. The cushion below `GPBase` is re-measured
      from `rtimage.lbl`.
    Done 2026-09-15: `RTGPBASE` `$6600` to `$6F00` and `RTBASE` `$6E00` to `$7700` in `common.inc`,
    and `CodeStart` 28416 in `source/runtime/Makefile`. The embedded pages needed no edit: the link
    page-aligns `GPBase` and `ObjectBase`, which have sat 8 pages lower, at `$2F00` and `$3500`, since
    step 15. Assembled in the scratchpad against step 17: every changed byte in the shared core (986)
    and the shared bank code (206) is its old value plus 9, the embedded core and bank code did not
    change, and the compiler changes 9 bytes, all plus 9, in the bootstrap, `ObjectPrepareShared` and
    `ObjectWriteShared`. `RTTop` is `$9D85`, 379 B below `$9F00`, and the embedded core still ends 97 B
    below `GPBase`. `rtname.py` cuts `GPB.RT.123.BIN` at `$6F00` (11,909 B) and `GPC.RT.123.BIN` at
    `$7700` (9,861 B). `shared_test.py` still says `$6E00`.

### Phase E: shared loading

19. `rtname.py` names the third runtime file, the shared bank code, `GP1.RT.nnn.BIN`.
    Done 2026-09-15: `rtname.py` takes `build/bank.prg` as a second argument and installs it as
    `GP1.RT.nnn.BIN`, named by `bank_filename()`. It refuses a file that does not load at `$A000` or
    whose first four bytes are not the core's magic. The `gpc-rt` recipe passes the file, and
    `release.sh`, `banktest3.py`, `dcref.py` and `.gitignore` list the new name beside the other two;
    `samplesbuild.py` already copied every `.RT.` file. Run in the scratchpad on the step 18 link:
    `GPB.RT.123.BIN` and `GPC.RT.123.BIN` are byte-identical to step 18, `GP1.RT.123.BIN` is
    `bank.prg` (2,432 B at `$A000`), and the embedded bank code (`GE24`), the core file, a missing file
    and the old two-argument form are refused with nothing installed.
20. The bootstrap loads by one name with a patched third character, which frees 39 B. It then checks
    the bank 1 magic after the resident check, takes the cold path on a mismatch and restores the RAM
    bank before the handover, §5.1.
    Done 2026-09-15: `BootEntry` pushes BASIC's bank and selects `HANDLER_BANK`, and one loop compares
    both `RTBASE` and `$A000` with `BBMagic`. The cold path zeroes `$A000`, patches `B` or `C` into
    `BBName` and loads it from the current directory or else the root, then patches `1` and loads the
    bank code from the same place. `BBNameLo` is the name's low address byte, one lower for the root
    form. Both exits pull the bank back. The name table, the second name and `BBNameIdx` are gone, and
    page one has 34 B free, `$08DE` to `$08FF`, after the 3 B `$A000` guard agreed at this step. Linked
    in the scratchpad: the runtime and image links are byte-identical to step 18, and `gpc.prg` differs
    only in page one, the six patch operands in `ObjectWriteShared` and `bootstrap2.asm`'s
    `jsr BBTryLoad`. A 65C02 simulation of the assembled page on the step 19 files passes warm entry
    with and without GPB, the embedded bank code in bank 1, wiped handlers, a cold load from the root,
    its rerun, a rerun after a POKE to `$A000`, GP1 missing beside a loaded core, and an empty disk.
    Each run enters with the entry bank and the stack SYS left, or prints `?RT` and returns with both.
    The extension page's bank is an open item, §5.1.

### Phase F: embedded loading

21. `genrtimage.py` writes into `rtimage.gen.asm` the bank code length and the under-16-pages check.
    The third patch offset moved to step 24, which adds the label it reads, so the tree links between
    the two.
    Done 2026-09-15: `genrtimage.py` takes `build/bank.prg` as its third argument and refuses a file
    that is missing, does not load at `$A000`, does not open with `GE`, or is over 8K. It writes
    `RTIMG_BANKLEN` and a `.cerror` that stops link two when that is over `MIN_WS_PAGES` pages. The
    Makefile passes the file. Run in the scratchpad on step 20's link one: `RTIMG_BANKLEN` is `$0980`,
    2,432 B or 10 pages, `rtimage.gen.asm` gains only those two lines, the installed image is unchanged
    and `gpc.prg` is byte-identical. A 4,096 B bank file links clean, a 4,097 B one stops the link with
    the message, and the four refusals each print their reason.
22. The embedded bank code is a second image file, `GP1.IMG.nnn.BIN`. `genrtimage.py` names and
    installs it, not `rtname.py`: it already reads this link's `build/bank.prg` and names the image.
    Done 2026-09-15: `bankImageName()` is `imageName()` with the third character changed, as
    `GP1.RT.nnn.BIN` is to `GPC.RT.nnn.BIN`, and the install writes `bank.prg` whole, `$A000` load
    address included, beside `GPC.IMG.nnn.BIN`. `release.sh` ships it and its README names it and
    `GP1.RT.nnn.BIN`, `.gitignore` ignores the `drive/` copy, and `dcref.py` and `banktest3.py`
    copy it with the runtimes. Run in the scratchpad on step 20's link one: `GP1.IMG.123.BIN` is
    `bank.prg`, 2,434 B with its load address and opening `GE24`; `GPC.IMG.123.BIN` and
    `rtimage.gen.asm` are unchanged; a run without a destination installs nothing, and a refused bank
    file installs neither. `release.sh` passes `bash -n` and its python parses.
23. The embedded path in `object.asm` writes that file after the p-code from the next page.
    Done 2026-09-15: `ObjReadBankCode` reads `GP1.IMG.nnn.BIN` into compile-time bank 15 before the
    runtime image is opened and before `OBJECT.PRG` is created. It refuses a file that is missing,
    does not load at `$A000`, is shorter than `RTIMG_BANKLEN` or does not open with `GE`, and the
    compile stops with `NO RUNTIME IMAGE` and no object. `ObjEmitBankCode` runs at `BLC_CLOSEOUT`,
    after the pass compare, and writes zero bytes to the next page and then the bank code. The
    compiler library ignores the carry from both end hooks, which is why the file is read first.
    `bumpbuild.py` writes the name as `RTBankFileText`, and `x16_storage.inc` lists bank 15. Linked
    in the scratchpad with step 21's `rtimage.gen.asm`: the log is empty and `gpc.prg` grows 202 B
    to 31,871 B. The two routines, `_CACloseOut` and the embedded `ObjStreamOpen` ran out of that
    `gpc.prg` on a 65C02 simulator with the file routines stubbed, and 28 checks pass. Step 24's page
    is `runtimeEndPage` plus the p-code's pages, which is `newWorkspacePage` less `FrameStackPages`.
24. `00rtimage.header` copies the bank code to bank 1 before `jmp StartRuntime`. The operand that
    holds the bank code's page gets a label, `genrtimage.py` writes its offset as the third patch
    offset, and `object.asm` patches the page as step 23 writes the file.
    Done 2026-09-15: `StartCode` copies the bank code to bank 1 from the page in `RunBankPage`'s
    operand, in whole pages up to `RTImgBankEnd`, a label that `10object.divider` puts at the end of
    the banked section, and selects the entry bank again. It then zeroes the operand, so a RUN after
    END, whose workspace no longer holds the bank code, keeps bank 1. The copy is 45 B, and the core
    has 52 B left below `GPBase` `$2F00`, which did not move. `genrtimage.py` writes `RTIMG_BANKPOFS`
    and refuses an image without `RunBankPage` or whose `RTImgBankEnd` disagrees with `bank.prg`.
    `object.asm` patches the page as `newWorkspacePage` less `FrameStackPages`. The patch put the image
    loop's `bne` out of range, so that is now a `beq` over a `jmp`, and `gpc.prg` grows 21 B to
    31,892 B. Linked in the scratchpad with step 20's libraries, all four link logs empty. On a 65C02
    simulator 39 checks pass: `StartCode` at three pages and again over a used workspace, and six
    embedded objects that `PrepareObjectCode` and `ObjEmitBankCode` wrote, loaded and started by their
    own `StartCode` with bank 1 filled and the entry bank selected again.

### Phase G: build and test

25. `make libs`, then `make -C source/runtime gpc-rt`, in the background.
    Done 2026-09-15: both exit 0 with no errors. `drive/GPC.BIN` is 31,892 B,
    `GPC.IMG.123.BIN` 11,521 B and `GP1.IMG.123.BIN` 2,434 B, the sizes linked in the scratchpad in
    step 24. The runtime installs as `GPB.RT.123.BIN` ($6F00, 11,909 B), `GPC.RT.123.BIN` ($7700,
    9,861 B) and `GP1.RT.123.BIN` ($A000, 2,432 B). The build 122 files are still in `drive/`.
26. **Tests**, in both modes:
    - every moved group, from low p-code and from inside a region (shared)
    - the step 7 `FMPLAY` literal
    - `SQR(-1)` or `LOG(-1)`, then the selected bank checked in assembly (`PEEK(0)` cannot show it)
    - a LOAD chain whose first program POKEs bank 1
    - an embedded program that LOADs a shared one, and back
    - `GP.BANKED 1`, refused
    - the step 1 timing repeated. `SPRMEM` stays low if its loss is larger than §4 says.
    Done 2026-09-15, headless, against the same programs compiled by the build 122 compiler and
    runtime as a control. The bank is read by `SYS` to a routine at `$0780` that stores `$00` for a
    `PEEK`; the runtime's storage fills `$0400` to `$05F4`, so a routine at `$0400` breaks the program.
    - Every moved handler, one statement a line with the bank check after each, from low p-code with
      bank 7 selected in both modes and from a `GP.BANKED 4` region in shared mode: the output is the
      same as build 122 and no check fails.
    - The step 7 program prints `BANK LIT PSG 116 3` and `BANK LIT FM 3`, as low code does.
    - `SQR(-1)` with bank 7 selected leaves bank 7 in both modes, and `LOG(-1)` in a region leaves
      bank 4, as build 122 does.
    - A shared and an embedded program zero the first page of bank 1 and LOAD with bank 1 selected.
      The program they load starts with bank 1 and its moved handlers work.
    - A chain of embedded, shared, embedded and shared programs works at every hop.
    - `GP.BANKED 1` is refused with `BANK 1 IS RESERVED` in both modes, and `GP.BANKEDSTR 1` in
      shared mode. In embedded mode `GP.BANKEDSTR NEEDS SHARED` stops it first.
    - 50,000 calls, in jiffies, shared then embedded: the empty loop 172 and 173, `MOVSPR` 483 and
      486, `SPRMEM` 523 and 529, against 171, 484 and 514 at step 1. `SPRMEM` loses about 24 cycles
      a call shared and 40 embedded, where §4 says 30. Decided 2026-09-15: `SPRMEM` stays in bank 1.
27. GPBMODS compiled: `LOW FREE` and the new p-code cap in each mode.
    Done 2026-09-15 with `GPC.BIN` 31,892 B.
    - GPBMODS shared: `LOW CODE 11520`, `LOW FREE 12288`, eight overlays `.004` to `.011`. Build 122
      gave `LOW CODE 11264` and `LOW FREE 10240`; the source has grown a page since. The
      headroom, `LOW FREE` less 4,096, is 8,192 B, where it was 6,144.
    - GPBMODS embedded stops with `GP.BANKED NEEDS SHARED @ 111` and writes nothing, so the
      embedded figure comes from GPCTEST-E: `LOW CODE 969`, `RUNTIME 11519`, `LOW FREE 24064`.
      Build 122 gave `RUNTIME 13567` and `LOW FREE 22016`.
    - Both reports agree with the fit checks in `object.asm`, so the caps are:

      | mode | max low p-code | build 122 |
      |---|---:|---:|
      | embedded, CORE | 22,528 (88 pages) | 20,480 |
      | embedded, GP.BASIC | 20,992 (82) | 18,944 |
      | shared, CORE | 22,016 (86) | 19,712 |
      | shared, GP.BASIC | 19,968 (78), 19,712 with a banked region | 17,664, 17,408 |

      Embedded gains 8 pages (`GPBase` `$2F00`, `ObjectBase` `$3500`) and shared 9 (`RTBASE` `$7700`,
      `RTGPBASE` `$6F00`).
28. The manual's §7 limits, the memory notes on the shared p-code cap, the runtime limits and the core
    page cushion (52 B), the `.122.` file names (`drive/readme.md`, `help-demo.bat`, `fntest.py` and
    the handoff docs), and TODO item 2 (after asking).
    Done 2026-09-15. The user left `TODO.md` as it is. The manual's section 1 and section 7, their three Markdown
    copies, `H001.HLP` and `H076.HLP` in both `HELP-TXT` folders carry build 123's bases, caps and
    reports. The GPBMODS example is the step 27 compile, which removed no dead code, so `H076` lost
    its `DEAD CODE` line and both indexes give it 81 lines. `README.md`, the GPBMODS `PLAN.md`,
    `gpc-shared-pcode-cap-is-rtbase`, `gpc-blitz-runtime-slack-and-limits`, `two-pass-compiler`
    and `gpc-core-page-cushion-below-gpbase` give the new caps and cushions: 52 B embedded, 379 B
    shared core, 633 B shared GP block. `EMBEDDED-VS-SHARED.md` says its figures are build 122's.
    `drive/readme.md` lists the build 123 files. `help-demo.bat`, `fntest.py` and
    `BUILD-HANDOFF.md` say `nnn`, because `samples/GPC-HELP` still holds build 122's files.
