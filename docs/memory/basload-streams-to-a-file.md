---
name: basload-streams-to-a-file
description: "SHIPPED: BASLOAD-GPC is a forked BASLOAD built as a PRG that streams each line to the output file, killing the 38,655-byte ceiling. Output is 2 bytes shorter than the ROM's and deterministic, and a failed run deletes it. Adds #GPC."
metadata:
  type: project
---

**Shipped 2026-09-06** -- `c0b978f` (the fork), `08443c1` (the build wired to it).
`BASLOAD-GPC/` holds BASLOAD built as a RAM-resident PRG that emits each line to an open file as it
finishes it, instead of accumulating the program in BASIC RAM. `source/gpc/build_basl.py` drives it;
`testing/BASLOAD-GPC.BIN` ships beside `GPC.BIN`.

Measured: **47,765 bytes tokenised** where the ROM stopped at 38,421 with `ERROR: BASIC RAM FULL`,
and GPC compiled and ran it. `GPC.BASL` comes out **byte-identical** to the ROM's output, and the
`GPC.PRG` compiled from it is byte-identical to the committed build.

## The front end, 2026-09-08 -- and the rename that came with it

**`BASLOAD-GPC.BIN` is the engine, `BASLOAD-GPC.PRG` is the front end.** Same division as `GPC.BIN` and
`GPC.PRG`: the engine's only interface is the `$bf00` ABI, so the name a person types has to belong
to the thing a person runs. `build_basl.py` stages **both** into `testing/`.

`BASLOAD-GPC/frontend/BASLOAD-GPC.BASL` is **plain X16 BASIC, not GP.BASIC** -- it has to run from
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

Changed: `line.inc` (staging buffer, `eol_mark`, six `out_*` routines, `mem_top` gone),
`loader.inc` (open before pass 2, close at exit, scratch on failure, `SAVE` gone), `response.inc` (**an upstream bug** --
message 15 pointed at `SYMFILE IO ERR`, so a `#SAVEAS` with no argument always reported the wrong
error).

## FIXED 2026-09-11 -- a failed tokenise now deletes its output

It used to leave one. A run that failed partway still wrote the `$00 $00` terminator and closed, so
the output was a *syntactically perfect* BASIC program that stopped halfway through the source, and
GPC compiled it happily -- which is exactly what cost the XBase build 420 seconds on 11th Sep 2026.

`out_scratch` (`BASLOAD-GPC/src/line.inc`) sends `S:` plus the bare name on channel 15, and
`loader_run` calls it at `exit:` when `KERNAL_R1` is non-zero. Four things about it are load-bearing:

- **`out_created`, not `out_open_flag`.** `out_close` clears the open flag, and a `FILE EXISTS` or
  `WRITE PROTECT ON` at OPEN means the file on disk is a **previous good build** this run never
  touched. `out_created` is set only after OPEN succeeded *and* the drive came back clean, and
  nothing clears it but `line_init`.
- **Strip the `@:`.** Every `#SAVEAS` here carries the overwrite prefix and `@` is not valid inside
  an `S:` command. A bare `@` with no colon is stripped too.
- **No `file_set_status_as_response` afterwards.** It would replace `LABEL NOT FOUND IN
  DB.INC.BL:459` with a generic drive error and destroy the only useful output of a failed run.
- **`out_close` runs first, then the test.** The file has to be closed before the drive will scratch
  it, and `out_close` ends by reading the drive status, so a disk that filled mid-stream is caught
  by the same test.

Engine cost: **9,003 -> 9,185 bytes**. Verified three ways: a 200-line source with an unresolved
label leaves no `.PRG` (the old engine left 3,080 plausible bytes), a good source tokenises
**byte-identical** to the old engine's output, and a pre-existing file under a `#SAVEAS` with no
`@:` survives the `FILE EXISTS` failure intact.

`build_basl.py`'s SUCCESS check is still there and still the first guard: a scratch the drive
refuses would put the fragment back in play.

Still open, and strictly stronger: a **temp file plus rename** would also protect the previous good
build, which `out_open` truncates at the start of pass 2 either way. `S:NAME` then `R:NAME=TMP` on
channel 15 is **measured working on the emulator host FS**; ~90 lines, modelled on `IOScratchFile`
(`file-io/write.asm:106`).

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
