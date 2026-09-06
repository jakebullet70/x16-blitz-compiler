# BASLOAD — the tokenise ceiling, and what it would take to move it

Researched 6th September 2026. `README.md` is how to build what came out of this.

## 1. The problem, and how it was found

Adding `FILEIO.INC.BL` and `FILEDIR.INC.BL` to `samples/GPB-MODS-TESTING/GPBMODS.BASL` produced a
clean tokenise, then a compile that stopped with `UNKNOWN LINE NUMBER @ 2494` — a line number GPC
was sent to and could not find.

The tokenised PRG was truncated. Its text stopped mid-way through `GMX.S.FILL`; `GPBDIR`,
`SAVEARRAY` and `DIRECTORIES` appear nowhere in it. It was 38,419 bytes, and 38,419 + $0801 = $9E14,
hard against the $9F00 I/O page. **BASLOAD had run out of BASIC RAM.**

It says so, and we were throwing the message away:

```
SAVING @:GPBMODS.SRC.PRG
ERROR: BASIC RAM FULL
READY.
```

It prints `SAVING` *first*, writes the short file, and only then reports. `build_basl.py` polled for
the file, checked it loaded at $0801, deleted the echo log unread, and printed `OK`. Fixed in
`4577b50` — it now reads the log and fails on `ERROR:`.

## 2. The numbers

| | bytes |
|---|---:|
| BASLOAD's ceiling (`38655 BASIC BYTES FREE`) | 38,655 |
| `GPBMODS.BASL` with the twelve modules | 37,872 |
| **headroom** | **783** |
| `FILEIO` + `FILEDIR` | ~7,200 |
| a FILES panel for them | ~8,000 |

783 bytes is about 45 lines. `FILEIO` + `FILEDIR` were measured off `FILEDIRT.BASL`, which tokenises
to 9,449 with a ~2,250-byte driver.

**~17.5 tokenised bytes per non-comment source line**, from two real builds — GPBMODS 16.9,
FILEDIRT 18.2. Good enough to size a change, not to bet a build on.

Dropping `SORT` and `STRCASE`, the two modules with no panel, buys ~5,950. Still ~8,300 short. There
is no arrangement of the current library that fits.

**This ceiling is now in front of GPC's.** The two-pass rebuild took away the compiler's size wall;
a program can be compiled that cannot be tokenised.

## 3. What the source says

`upstream/loader.inc`, `line.inc`.

**It is already two-pass.** `line_pass = 1` walks every line building the symbol table, then the
source is re-opened and pass 2 emits. Forward labels are resolved before a byte is written — which
is the property that makes everything below possible.

**Pass 2 emits one line at a time, strictly forward.** `line_meta` points at the current line's
4-byte header, `line_code` at `line_meta + 4`, and body bytes go to `(line_code),y` where `y` is
`index_dst`, an index *inside that one line*. At `eol_mark` it writes the terminator, computes the
next line's address, stores it back into `(line_meta)` as the link, writes the line number after it,
and moves both pointers on.

**The only back-patch is into the current line's own header, four bytes behind.** Nothing reaches
back into a line already finished.

There is a single read-back — `lda (line_code),y` at `line.inc:1119` — and it peeks at the byte just
written in the same line, to drop a colon before a `REM`. Also inside the current line. **This was
the one thing that could have invalidated the analysis, and it does not.**

So a staging buffer of one line — 4 header bytes plus up to 255 body bytes — is sufficient, and none
of the 17 `sta (line_code),y` sites has to change.

### The edit

| where | what | ~lines |
|---|---|---:|
| `line_init` | pointers at a staging buffer; a 16-bit `out_addr` counter from $0801 | 20 |
| `eol_mark` | link from `out_addr`, fill the header, flush `4 + index_dst` bytes, advance | 40 |
| the `mem_top` check | an `out_addr` overflow test instead | 5 |
| `file.inc` | an output channel — OPEN/CHKOUT/CHROUT/CLOSE, and the two load-address bytes | 60 |
| `loader.inc` | skip the `VARTAB`/`ARYTAB`/`STREND` store and `KERNAL_SAVE`; bracket pass 2 | 20 |

**~150 lines of 65C02 across three files, no restructuring.** The switch already exists —
`loader.inc` tests `saveas_len`. Streaming is arguably what `#SAVEAS` should always have meant:
build a *file* when a file is asked for, build in RAM only when you want to `LIST` and `RUN`.

That estimate is the change that can be seen, not the debugging, and it rests on the emit path and
the pass structure rather than all 24 KB of `line.inc`.

### One flat file buys 1.6x. Many buy the lot.

BASIC line links are 16-bit absolute addresses, so streaming to **one** file moves the wall from
`MEMTOP` to the address space — about 63 KB from $0801. Enough for the job in hand (GPBMODS 37,872
+ 7,200 + 8,000 ≈ 53,000, with ~10 KB spare) but a bigger room, not an unbounded one.

**A file per `#INCLUDE` removes the cap.** Each part restarts at $0801, so no part is ever large.
Pass 2 already knows which source file it is in. Line numbers stay globally ascending and are 16-bit,
so 65,535 lines is not the next wall — GPBMODS uses about 3,000.

Two things it must not become:

- **Pass 1 stays whole-program, in one run.** The symbol table is global. It resolves a `GOSUB` in
  the driver to a label in `GUI.INC.BL`, and it allocates the short BASIC names — `GM.TELL$` becomes
  `J2$`. Separate runs collide on both. Splitting the *output* is cheap; splitting the *analysis*
  is a different and much larger job.
- **GPC needs a "next part" hook.** `source/application/source/file-io/read.asm` opens the source
  with `CHKIN` on logical file 3 and streams it — it never loads it, so source size is not a
  constraint on the compiler at all. **Open: whether GPC uses the BASIC line *links* to find line
  boundaries.** Across a part break those point nowhere. If it scans for the null terminator
  instead, this is nearly free. Not yet checked.

## 4. Running it out of RAM — done, and it needed no source changes

The objection to patching BASLOAD was distribution: it is a ROM bank, so a patched one means a
custom `rom.bin` and a flash on real hardware.

**It builds and runs as an ordinary PRG with no source changes.** One linker config. Proven: it
tokenised a source and produced a program byte-identical to the ROM BASLOAD's, bar the two
nondeterministic trailing bytes. `test/runtest.py` is that comparison, kept.

What made it easy:

- **The bridge works from RAM unchanged.** `bridge.inc` copies 42 bytes into golden RAM that switch
  ROM bank, `jsr`, and switch back, plus two more that read BASIC's token table out of ROM bank 4 —
  needed wherever BASLOAD runs. This was the mechanism expected to be ROM-only. It is not.
- **It already tidies up after itself.** `main_backup_ram` / `main_restore_ram` save and restore
  golden RAM ($0400-$07FF) and ZP $22-$7F, so a RAM-resident build is no ruder than the ROM one.
- **One documented entry point.** `jmp main_entry`, taking the file name at $BF00 in bank 0, the
  length in R0L and the device in R0H. Nothing in it depends on being in ROM.

Sizes: CODE $221A (8,730 B), VARS $0400-$06D3, RAM1 2,846 B at $A000 in bank 1, ZP $22-$2F.

### What this does not fix on its own

**RAM-resident alone is a step backwards.** The code has to live below `MEMTOP`, and BASLOAD builds
its output upward from $0801, so the build at $6000 drops the ceiling from 38,655 to about 22 KB.

It only pays off **combined with the streaming change**. Then BASIC RAM stops being the output area
at all, the PRG can sit at $0801, and neither constrains the other. The two want each other.

## 5. What was verified, and what was not

Verified: the two-pass structure; the emit model and the single read-back; that the vendored source
is what `rom.bin` runs, to within seven bytes of signature case; that it builds as a PRG and
tokenises identically; that GPC streams its source through `CHKIN` rather than loading it;
`cl65 V2.19` builds it on this machine.

Not verified: the whole of `line.inc`, so there may be RAM-dependent code not on the emit path;
whether GPC walks line links; what an upstream merge costs once there is a real diff to carry.

## 6. Recommendation

Not urgent, and not as a fork if it can be helped.

Against doing it now: a second demo program solves today's problem with no new toolchain, no third
versioned artefact and no upstream to track.

For doing it eventually: GPC can now compile more than BASLOAD can tokenise, which by the standing
rule that a build-side wall is a bug makes this a bug rather than a limit. The change is small, the
delivery problem turned out not to exist, and a `#SAVEAS`-streams mode is generally useful — so the
right shape is a pull request to `basload-rom`, not a fork carried forever.

**Next step if it is taken up:** check how GPC finds line boundaries. That is the one open question
that changes the design, and it is a grep away.
