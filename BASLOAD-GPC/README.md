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

Nothing here is wired into the build yet. `source/gpc/build_basl.py` still drives the ROM BASLOAD.

## Build

Needs **cc65**, not 64tass — BASLOAD is a cc65 project. Installed at `C:\8bitProgramming\cc65`
(`cl65 V2.19 - Git e11fb5c`, the official Windows snapshot); override with `CC65_HOME`.

```
python BASLOAD-GPC/build.py both     # or: rom | prg
```

| target | config | output |
|---|---|---|
| `rom` | `upstream/conf/basload-rom.cfg` | `build/basload-rom.bin`, 16,384 B, $c000 in ROM bank 15 |
| `prg` | `conf/basload-prg.cfg` | `build/BASLOAD.PRG`, 8,924 B, loads $6000 |

**The `rom` target exists to be checked, not shipped.** It rebuilds the bank and diffs it against
bank 15 of `bin/x16emu/rom.bin`, which answers *"is the vendored source what is actually running?"*
Seven bytes at `$FFF0-$FFF6` is the right answer — the signature string, lowercase `basload` in the
shipped ROM and upper case in the source. **Anything else means upstream has moved.** Re-run it
after every pull.

It builds from `upstream/` alone, with `src/` left out. A canary carrying the fork's own changes
cannot answer the question it is there to answer.

## Test

```
python BASLOAD-GPC/build.py prg
python BASLOAD-GPC/test/runtest.py
```

It tokenises `test/HELLO.BASL` twice — once through the ROM BASLOAD, once through the PRG — and
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

## Calling it

Load `BASLOAD.PRG` at $6000, then:

| | |
|---|---|
| file name | `$BF00`, **RAM bank 0** |
| name length | `R0L`, `$02` |
| device | `R0H`, `$03` |
| call | `SYS $6000` |
| return code | `R1L`, `$04`. 0 is OK |
| message | `$BF00` onward, bank 0 — it overwrites the name you passed |

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
| `line.inc` | `line_meta` points at a 260-byte staging buffer for the whole run; `eol_mark` streams the finished line, and `out_addr` carries the address it *would* have had; the five `out_*` routines that own the output file; the BASIC RAM ceiling test and `mem_top` are gone |
| `loader.inc` | opens the file before pass 2, closes it at exit; the `SAVE` at the end is gone, and with it the `VARTAB`/`ARYTAB`/`STREND` stores |
| `response.inc` | one word: message 15 was `SYMFILE IO ERR`, so a stock BASLOAD reports the wrong error for a `#SAVEAS` with no argument |

**Nothing downstream can tell the program was never in RAM.** GPC reads the two-byte line link, ORs
its halves, tests for zero and never dereferences it (`compiler/api.asm:166`) — so a link is an
opaque non-zero marker, the 16-bit address space it names bounds nothing, and one flat streamed file
needs no compiler change at all.

**Streaming has no fallback, so every failure has to speak.** In-RAM tokenising left the program
listable when the `SAVE` failed; today a file that will not open costs the whole run. `out_open`
reports a missing `#SAVEAS` name, a KERNAL error, and a drive that refuses; `out_close` asks the
drive how it went, because a disk that fills mid-stream says nothing until it is asked.

## Layout

```
upstream/       basload-rom @ caaaaf0, unmodified. BSD 2-Clause, Stefan Jakobsson
src/            the fork: whole copies of the files above, overlaid at build time
conf/           basload-prg.cfg -- ours
test/           HELLO.BASL and the ROM-vs-RAM equivalence test
build.py        both targets, the overlay, and the rom.bin verify
build/          output, not tracked. work/ is the fork's tree, stock/ the canary's
```

## Licence

`upstream/` is BASLOAD, © 2021-2023 Stefan Jakobsson, BSD 2-Clause — see `upstream/LICENSE`, which
every source file also carries in full. Permissive: fork, modify and ship, keeping the notice and
the disclaimer. Two repos exist and this is the live one; `stefan-b-jakobsson/basload` is the
deprecated standalone PRG and is **not** a shortcut — it predates `#TOKEN`, `#SAVEAS`, `#SYMFILE`,
`#DEFINE`, `#IFDEF` and `#INCLUDE`, and GP-BASIC is built on `#TOKEN`.
