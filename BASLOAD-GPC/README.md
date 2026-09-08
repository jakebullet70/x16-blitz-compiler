# BASLOAD-GPC

BASLOAD, built from upstream source, as a **RAM-resident PRG** that streams its output to a file —
instead of a ROM bank that builds it in BASIC RAM.

`RESEARCH.md` is why. This file is how.

## Why it exists

BASLOAD is the tokeniser every GPC build runs first, and it is a bank of the X16 ROM. It built the
tokenised program in BASIC RAM, so **38,655 bytes was the ceiling on a `.BASL` plus every
`#INCLUDE` it pulls in** — and `samples/GPB-MODS-TESTING/GPBMODS.BASL` is 783 bytes under it. The
two-pass compiler moved GPC's size wall; this one was then in front of it.

Changing that means changing BASLOAD, and changing BASLOAD meant shipping a custom `rom.bin` and
flashing real hardware. **It does not.** The upstream source builds and runs as an ordinary PRG with
no source changes at all — only a linker config. That is what made the rest of this possible.

**The ceiling is gone.** The fork writes each line to an open file as it finishes it, so one line —
260 bytes of staging buffer — is all that is ever resident, and the output is bounded by the disk.
A source that died at 38,421 bytes with `ERROR: BASIC RAM FULL` now tokenises to 47,765 and
compiles. See [The fork](#the-fork).

`source/gpc/build_basl.py` drives this build now, not the ROM's, and stages both files into
`testing/` beside `GPC.BIN`.

## Build

Needs **cc65**, not 64tass — BASLOAD is a cc65 project. Installed at `C:\8bitProgramming\cc65`
(`cl65 V2.19 - Git e11fb5c`, the official Windows snapshot); override with `CC65_HOME`.

```
python BASLOAD-GPC/build.py all     # or: rom | prg | front
```

| target | from | output |
|---|---|---|
| `rom` | `upstream/conf/basload-rom.cfg` | `build/basload-rom.bin`, 16,384 B, $c000 in ROM bank 15 |
| `prg` | `conf/basload-prg.cfg` | `build/BASLOAD.BIN`, 9,003 B, loads $6000 — **the engine** |
| `front` | `frontend/BASLOAD.BASL` | `build/BASLOAD.PRG`, 842 B — **the front end you launch** |

**`BASLOAD.BIN`, not `BASLOAD.PRG`.** The engine's only interface is an ABI, so the name a person
types belongs to the front end — the same division as `GPC.PRG` and `GPC.BIN`. Only `front` needs
the emulator; the other two need only cc65.

**The `rom` target exists to be checked, not shipped.** It rebuilds the bank and diffs it against
bank 15 of `bin/x16emu/rom.bin`, which answers *"is the vendored source what is actually running?"*
Seven bytes at `$FFF0-$FFF6` is the right answer — the signature string, lowercase `basload` in the
shipped ROM and upper case in the source. **Anything else means upstream has moved.** Re-run it
after every pull.

It builds from `upstream/` alone, with `src/` left out. A canary carrying the fork's own changes
cannot answer the question it is there to answer.

## The front end

`BASLOAD.PRG` is what you `RUN`. It asks for a source file, hands it to the engine, prints what
comes back, and asks again — an empty answer quits.

```
BASLOAD -- BASL SOURCE TO TOKENISED PRG

SOURCE FILE: HELLO.BASL

TOKENISING HELLO.BASL ...

SUCCESS
```

It **loads `BASLOAD.BIN` itself**, so both files have to be on the drive, and nothing else does.

**Plain X16 BASIC, not GP.BASIC** — `frontend/BASLOAD.BASL`, tokenised like any other `.BASL`. It
has to run from `READY.` with nothing on the disk but itself and the engine, so it cannot want
`GPC.BIN` or a runtime. The key reader is `GPC.BASL`'s, written out in plain BASIC, and `INPUT` is
not used on purpose: it splits a name on a comma, answers a bare RETURN by leaving the variable
alone rather than emptying it, and prints `?REDO FROM START` at its own discretion.

Two things in it are not obvious:

- **The engine is loaded once, behind a guard.** `LOAD` inside a running program restarts it *and*
  clears variables, so the guard is a POKEd byte at `$0400` — golden RAM, which the engine backs up
  and restores around every run, so it survives a tokenise and the loop never reloads. It is
  checked together with the engine's own first byte (`$4C`, a `JMP`), so a cold boot that happens
  to have 42 sitting at `$0400` still cannot `SYS` into nothing.
- **The name is re-poked every time.** The engine answers in the buffer it was asked in — the
  message at `$BF00` overwrites the name — so a launcher that poked once would hand its own error
  text to the engine as the next file name.

There is no prompt for the output name and there cannot be: that is the source's own `#SAVEAS`.
The device is 8.

**The poked-name path is untouched.** A caller that sets up the ABI itself still gets exactly what
it always did — `test/runtest.py` and `source/gpc/build_basl.py` both still call the engine direct.

## Test

```
python BASLOAD-GPC/build.py all
python BASLOAD-GPC/test/runtest.py      # the engine: ROM vs RAM
python BASLOAD-GPC/test/runfront.py     # the front end, end to end
```

`runtest.py` tokenises `test/HELLO.BASL` twice — once through the ROM BASLOAD, once through the PRG — and
compares. That is the only claim worth testing: a RAM build that runs but tokenises *differently*
is worse than one that does not run.

```
  PASS -- 34 bytes identical, ROM and RAM builds agree
```

**The RAM build's file is two bytes shorter, and that is the fork working.** The ROM build SAVEs up
to `line_code`, four bytes past the last line — two of them the zero link that ends a program, two
whatever was in RAM, and those two differ run to run. `source/gpc/build_basl.py` documents the same
thing and skips its up-to-date check because of it. The streaming build writes the zero link itself
at close and stops there, so the compare is `rom[:-2]` against the whole of the PRG's output.

`runfront.py` drives the front end. **An interactive program cannot be pasted at** — `x16emu -bas`
types at the `READY.` prompt only, and once a program is running the rest is dropped, not queued —
so it generates a **fixed-answer variant from the real source**, asserting on every substitution.
Only the key reader goes untested. The three answers are a **missing file, then a good one, then
nothing**, which is the arrangement that catches the name not being re-poked, and the verdict is
the screen rather than the output file: a run that fails partway still writes a complete, valid,
wrong program.

```
  PASS -- the front end loaded the engine, tokenised HELLO.BASL to 34 bytes, and quit
```

**The raw bytes in `RUN.LOG` are not on the screen.** `-echo` hooks CHROUT, so it catches what the
engine *streams to the output file* as well.

## Calling the engine

This is the ABI the front end drives, and any other caller can drive it the same way. Load
`BASLOAD.BIN` at $6000, then:

| | |
|---|---|
| file name | `$BF00`, **RAM bank 0** |
| name length | `R0L`, `$02` |
| device | `R0H`, `$03` |
| call | `SYS $6000` |
| return code | `R1L`, `$04`. 0 is OK |
| message | `$BF00` onward, bank 0 — it overwrites the name you passed |
| source line | `R1H`..`R2H`, `$05`-`$07`, 24 bits — **0 when the fault has no line to name** |

A message that ends in a colon is the one expecting that number after it; `SYMBOL TABLE FULL` and
the rest do not, and get a zero rather than a line. Print the number only when it is non-zero.

**`BANK 0`, not `POKE 0,0`.** X16 BASIC saves and restores the RAM bank around every `PEEK` and
`POKE`, so `POKE 0,0` selects nothing and the name lands in whichever bank was live. The symptom is
silent: `SYS` returns cleanly, no file is written, and `$BF00` still reads back what you poked.

`test/runtest.py` has a working driver, including the re-entry guard — `LOAD` inside a BASIC program
restarts it *and* clears variables, so the guard is a POKEd byte, not a variable.

The output file is whatever `#SAVEAS` names, opened `,P,W`. **Prefix it `@:` to overwrite**, exactly
as with `SAVE`; `test/HELLO.BASL` does. Without a `#SAVEAS` the run now fails with
`FILENAME NOT SPECIFIED`, because streaming has nowhere else to put the program.

## The fork

`upstream/` stays exactly as it was vendored. `src/` holds a **whole copy** of each file changed, so

```
diff BASLOAD-GPC/upstream/line.inc BASLOAD-GPC/src/line.inc
```

is the fork, in full, with no tooling and nothing to apply. Every changed hunk also sits inside a
`;=== GPC begin ===` / `;=== GPC end ===` banner, so it is greppable from inside the file — which is
the question that actually gets asked six months later, in a 24 KB file nobody here wrote.

Each build copies `upstream/` to `build/work/`, drops `src/` over it, and assembles there. A file
removed from `src/` goes back to being upstream's on the very next build, and a half-finished edit
can never leave the vendored tree dirty.

| file | what changed |
|---|---|
| `line.inc` | `line_meta` points at a 260-byte staging buffer for the whole run; `eol_mark` streams the finished line, and `out_addr` carries the address it *would* have had; the five `out_*` routines that own the output file; `gpc_emit`; the BASIC RAM ceiling test and `mem_top` are gone |
| `loader.inc` | opens the file before pass 2, closes it at exit; the `SAVE` at the end is gone, and with it the `VARTAB`/`ARYTAB`/`STREND` stores |
| `option.inc` | one directive, `#GPC` — see below |
| `response.inc` | one word: message 15 was `SYMFILE IO ERR`, so a stock BASLOAD reports the wrong error for a `#SAVEAS` with no argument |

**Nothing downstream can tell the program was never in RAM.** GPC reads the two-byte line link, ORs
its halves, tests for zero and never dereferences it (`compiler/api.asm:166`) — so a link is an
opaque non-zero marker, the 16-bit address space it names bounds nothing, and one flat streamed file
needs no compiler change at all.

**Streaming has no fallback, so every failure has to speak.** In-RAM tokenising left the program
listable when the `SAVE` failed; today a file that will not open costs the whole run. `out_open`
reports a missing `#SAVEAS` name, a KERNAL error, and a drive that refuses; `out_close` asks the
drive how it went, because a disk that fills mid-stream says nothing until it is asked.

## `#GPC` — a directive channel BASLOAD never has to understand

One table entry buys the compiler an unlimited directive namespace. `#GPC` passes the rest of its
line through into the tokenised program as a `REM`, verbatim, and BASLOAD never learns what any of
it means:

```
#GPC OBJECT "GPBMODS.PRG"        ->   1 REM#GPC OBJECT "GPBMODS.PRG"
#GPC SHARED                      ->   2 REM#GPC SHARED
```

**The `#` is kept, and there is no space after the `REM` token.** That is what a reader matches on:
`$8f` then `#GPC`, which no ordinary comment produces by accident. GPC already consumes REM-carried
payload — `GP.ASM` blocks are written as `REM` lines and read back by `commands/gpasm.asm` — so this
is that mechanism made first-class. Every future compiler directive is then a GPC-side change alone.

Three things it does that are easy to get wrong:

- **Both passes emit.** A directive line normally leaves `index_dst` at zero and `eol` rewinds the
  destination line number, spending none; `#GPC` spends one. If only pass 2 knew, every line number
  after it would shift and every label pass 1 resolved would point one line short.
- **It goes to `eol_mark`, not `eol`**, so `#SOURCELINES` cannot append `:REM #nnn` *inside* the
  directive, where a reader has no way to tell where the directive stopped.
- **A hidden `#IFDEF` block emits nothing**, the same test `#DEFINE` already makes.

It costs a line number and the bytes of the text. Nothing reads these yet — the channel ships before
its first caller, deliberately, because adding it later would mean another BASLOAD build.

## Layout

```
upstream/       basload-rom @ caaaaf0, unmodified. BSD 2-Clause, Stefan Jakobsson
src/            the fork: whole copies of the files above, overlaid at build time
conf/           basload-prg.cfg -- ours
frontend/       BASLOAD.BASL, the launcher. Plain X16 BASIC, tokenised by the engine
test/           HELLO.BASL, the ROM-vs-RAM equivalence test, and the front-end test
build.py        all three targets, the overlay, and the rom.bin verify
build/          output, not tracked. work/ is the fork's tree, stock/ the canary's
```

## Licence

`upstream/` is BASLOAD, © 2021-2023 Stefan Jakobsson, BSD 2-Clause — see `upstream/LICENSE`, which
every source file also carries in full. Permissive: fork, modify and ship, keeping the notice and
the disclaimer. Two repos exist and this is the live one; `stefan-b-jakobsson/basload` is the
deprecated standalone PRG and is **not** a shortcut — it predates `#TOKEN`, `#SAVEAS`, `#SYMFILE`,
`#DEFINE`, `#IFDEF` and `#INCLUDE`, and GP-BASIC is built on `#TOKEN`.
