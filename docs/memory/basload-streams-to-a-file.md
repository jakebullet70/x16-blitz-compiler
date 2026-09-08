---
name: basload-streams-to-a-file
description: "SHIPPED: BASLOAD-GPC is a forked BASLOAD built as a PRG that streams each line to the output file, killing the 38,655-byte ceiling. Output is 2 bytes shorter than the ROM's and deterministic. Adds #GPC."
metadata:
  type: project
---

**Shipped 2026-09-06** -- `c0b978f` (the fork), `08443c1` (the build wired to it).
`BASLOAD-GPC/` holds BASLOAD built as a RAM-resident PRG that emits each line to an open file as it
finishes it, instead of accumulating the program in BASIC RAM. `source/gpc/build_basl.py` drives it;
`testing/BASLOAD.BIN` ships beside `GPC.BIN`.

Measured: **47,765 bytes tokenised** where the ROM stopped at 38,421 with `ERROR: BASIC RAM FULL`,
and GPC compiled and ran it. `GPC.BASL` comes out **byte-identical** to the ROM's output, and the
`GPC.PRG` compiled from it is byte-identical to the committed build.

## The front end, 2026-09-08 -- and the rename that came with it

**`BASLOAD.BIN` is the engine, `BASLOAD.PRG` is the front end.** Same division as `GPC.BIN` and
`GPC.PRG`: the engine's only interface is the `$bf00` ABI, so the name a person types has to belong
to the thing a person runs. `build_basl.py` stages **both** into `testing/`.

`BASLOAD-GPC/frontend/BASLOAD.BASL` is **plain X16 BASIC, not GP.BASIC** -- it has to run from
`READY.` with nothing on the disk but itself and the engine, so it cannot want `GPC.BIN` or a
runtime. `build.py front` tokenises it **with the engine it just built**, which exercises the fork
end to end on every build.

Two things in it that are not obvious, and both are load-bearing:

- **The name must be re-poked on every pass.** The engine answers in the buffer it was asked in, so
  a launcher that poked once hands its own error text to the engine as the next file name. The test
  asks for a **missing file, then a good one**, which is the only arrangement that catches it.
- **The re-entry guard is a POKEd byte at `$0400`**, because `LOAD` inside a running program
  restarts it *and* clears variables. It survives a tokenise only because the engine backs up and
  restores golden RAM. It is checked together with the engine's first byte (`$4c`, a `JMP`), so a
  cold boot that happens to have 42 there cannot `SYS` into nothing.

The source line number is **`R1H..R2H`, `$05-$07`, 24 bits, and ZERO when the fault has no line** --
`SYMBOL TABLE FULL` and friends. Print it only when non-zero, or the message reads `...FULL0`. A
missing source file comes back as the **drive's own status line**, `62, FILE NOT FOUND,00,00`, not
one of the nineteen messages.

## The two invariants to remember

- **The output is 2 bytes SHORTER than the ROM's, and that is correct.** The ROM SAVEd up to
  `line_code`, four bytes past the last line -- two of them the end-of-program zero link, two
  whatever was in RAM. Streaming writes the zero link itself and stops. So `rom[:-2] == streamed`.
- **The output is deterministic.** Those two RAM bytes were the only nondeterminism, so
  re-tokenising an unchanged source now produces an identical file. Up-to-date skips are an
  optimisation, not a necessity.

## Structure

`upstream/` is pristine; `src/` holds **whole copies** of the three changed files, overlaid into
`build/work/` at build time, so `diff upstream/line.inc src/line.inc` is the fork. Every hunk sits
in a `;=== GPC begin/end ===` banner. The `rom` target builds from `upstream/` **alone** and must
still come out 7 bytes from `rom.bin` at $fff0-$fff6.

Changed: `line.inc` (staging buffer, `eol_mark`, five `out_*` routines, `mem_top` gone),
`loader.inc` (open before pass 2, close at exit, `SAVE` gone), `response.inc` (**an upstream bug** --
message 15 pointed at `SYMFILE IO ERR`, so a `#SAVEAS` with no argument always reported the wrong
error).

## KNOWN DEFECT -- a failed tokenise leaves a valid-looking partial program

A run that fails partway still writes the `$00 $00` terminator and closes, so the output is a
*syntactically perfect* BASIC program that stops halfway through the source. GPC compiles it
happily. `#SAVEAS "@:NAME"` already truncated the previous good build at OPEN.

**`build_basl.py`'s SUCCESS check is the entire guard.** It reads BASLOAD's `$bf00` message out of a
sentinel file the driver writes, and only the literal `SUCCESS` continues.

The fix is a temp file plus rename; `S:NAME` then `R:NAME=TMP` on channel 15 is **measured working
on the emulator host FS**. ~90 lines, modelled on `IOScratchFile` (`file-io/write.asm:106`). One
wrinkle: strip a leading `@:` before it goes into an `S:` or `R:` command.

## Traps already paid for

**Logical file 12** for the output -- sources take 2..11 (`file_open` rejects >= 12) and the symfile
takes 1. `bridge_setaddr` clobbers A, so issue it *before* loading A/X/Y for a KERNAL call. The
4 header bytes and the body are counted in **separate loops**, because `4 + index_dst` overflows a
byte on a long line. `out_write_line` cannot see `index_dst` (scoped inside `line_pass2`), so the
length is passed in A. Overwrite is the `#SAVEAS` name's job: **`@:` prefix**, as with `SAVE`.

**$0801 is NOT free** even though nothing accumulates in BASIC RAM -- it is where the BASIC program
*driving* BASLOAD lives. Building the PRG there gives `?SYNTAX ERROR IN 8200`, BASIC interpreting
the binary that just overwrote it. It stays at $6000. Tried and reverted, same session.

## `#GPC` -- the directive channel

`#GPC <anything>` emits the rest of the line into the tokenised program as a `REM`, verbatim, and
BASLOAD never learns what it means. Shipped `1adaa64`. **Nothing reads these yet.**

    #GPC OBJECT "GPBMODS.PRG"    ->   1 REM#GPC OBJECT "GPBMODS.PRG"

**Match on `$8f` then `#GPC`** -- the `#` is kept and there is NO space after the REM token. GPC
already reads REM-carried payload (`GP.ASM` blocks, `commands/gpasm.asm`), so a reader is the same
shape.

Three traps, all paid for: **both passes must emit** (a directive line normally leaves `index_dst`
at zero and `eol` rewinds the line number, so if only pass 2 spent a line every label pass 1
resolved would point one short); the emit goes to **`eol_mark`, not `eol`** so `#SOURCELINES` cannot
append `:REM #nnn` inside the directive; and a hidden `#IFDEF` block emits nothing. The handler
**cannot sit beside `comment:`/`rem:`** in `option.inc` -- the dispatch reaches those with 8-bit
branches and 15 more bytes mid-chain puts `beq rem` out of range.

Option handlers cannot emit: `index_dst` and `line_code` are scoped inside `line_pass1`/`line_pass2`.
So `option.inc` returns a new code `$f9` ($fa was already ENDIF WITHOUT IF) and `line.inc` does the
work at both call sites.

See [[basload-basic-ram-is-the-tokenise-ceiling]] and [[basload-runs-from-ram-unmodified]].
