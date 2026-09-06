---
name: basload-runs-from-ram-unmodified
description: The BASLOAD ROM source builds and runs as an ordinary PRG with NO source changes -- only a new linker config. Proven 2026-09-06.
metadata: 
  node_type: memory
  type: project
  originSessionId: bd07b4f1-99e6-4093-b015-3bc230589125
  modified: 2026-09-06T15:37:35.181Z
---

**A non-ROM BASLOAD needs no source changes at all.** Only a new cc65 linker config. Proven
2026-09-06: it tokenised a source and produced a program **byte-identical** to the ROM BASLOAD's,
apart from the two nondeterministic trailing bytes `build_basl.py` already documents.

This kills the "patching BASLOAD means shipping a custom rom.bin and flashing real hardware"
objection. It would ship in `testing/` beside `GPC.BIN`.

## What was established

- **`C:\8bitProgramming\cc65\`** — `cl65 V2.19 - Git e11fb5c`, official Windows snapshot. The
  BASLOAD Makefile wants `cl65`, not 64tass. See [[build-toolchain-location]].
- **The checked-out `basload-rom` source IS what is in the ROM.** Built and diffed against bank 15
  of `bin/x16emu/rom.bin` (offset 245,760; find it by grepping the ROM for `BASIC RAM FULL`).
  **7 bytes differ, all at $FFF0-$FFF6: the signature, lowercase `basload` in the ROM and uppercase
  in the source.** Preserve the ROM's case when splicing a bank.
- **The bridge works from RAM unchanged.** `bridge.inc` copies 42 bytes to golden RAM that switch
  ROM bank, `jsr`, and switch back. It reads BASIC's token table out of ROM bank 4, which is needed
  wherever BASLOAD runs. This was the one mechanism expected to be ROM-only and is not.
- Sizes: CODE $221A (8,730 B), VARS $0400-$06D3, RAM1 2,846 B at $A000 bank 1, ZP $22-$2F.
  `main_backup_ram` / `main_restore_ram` already save and restore golden RAM and ZP, so a
  RAM-resident build is no ruder than the ROM one.

## Calling it

Filename at **$BF00 in RAM bank 0**, length in R0L (`$02`), device in R0H (`$03`), then `SYS` the
load address. Return code comes back in **R1L (`$04`)**, and `response_set` overwrites $BF00 with
the message text.

**Use `BANK 0`, not `POKE 0,0`.** Stock X16 BASIC saves and restores the RAM bank around every
PEEK/POKE, so `POKE 0,0` selects nothing and the filename is written to whatever bank was live.
The symptom is silent: SYS returns cleanly, no output file, and $BF00 still reads back what you
poked. Cost five emulator cycles. Same trap as [[gpc-bank-statement-not-poke-zero]], one level over.

Also: `-prg` and `-bas` are alternatives in x16emu, not a pair, and `LOAD "X.PRG",8,1` inside a
BASIC program restarts it with variables cleared -- guard the re-entry with a POKEd flag, not a
variable.

## Why it matters, and what it does NOT fix on its own

RAM-resident **alone is worse**: the code has to sit somewhere below `MEMTOP`, and BASLOAD builds
its output upward from $0801, so a build at $6000 drops the tokenise ceiling from 38,655 to ~22 KB.

It only pays off **combined with streaming the output to a file** -- then BASIC RAM is not the
output area at all, the PRG can sit at $0801, and neither change constrains the other. The two want
each other. See [[basload-basic-ram-is-the-tokenise-ceiling]].
