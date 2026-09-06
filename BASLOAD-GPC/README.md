# BASLOAD-GPC

BASLOAD, built from upstream source, as a **RAM-resident PRG** instead of a ROM bank.

`RESEARCH.md` is why. This file is how.

## Why it exists

BASLOAD is the tokeniser every Blitz build runs first, and it is a bank of the X16 ROM. It builds
the tokenised program in BASIC RAM, so **38,655 bytes is the ceiling on a `.BASL` plus every
`#INCLUDE` it pulls in** — and `samples/GPB-MODS-TESTING/GPBMODS.BASL` is 783 bytes under it. The
two-pass compiler moved GPC's size wall; this one is now in front of it.

Changing that means changing BASLOAD, and changing BASLOAD meant shipping a custom `rom.bin` and
flashing real hardware. **It does not.** The upstream source builds and runs as an ordinary PRG with
no source changes at all — only a linker config. That is what this folder holds.

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
| `prg` | `conf/basload-prg.cfg` | `build/BASLOAD.PRG`, 8,742 B, loads $6000 |

**The `rom` target exists to be checked, not shipped.** It rebuilds the bank and diffs it against
bank 15 of `bin/x16emu/rom.bin`, which answers *"is the vendored source what is actually running?"*
Seven bytes at `$FFF0-$FFF6` is the right answer — the signature string, lowercase `basload` in the
shipped ROM and upper case in the source. **Anything else means upstream has moved.** Re-run it
after every pull.

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

The last two bytes are excluded. BASLOAD writes two bytes past the end of the program that differ
run to run; `source/gpc/build_basl.py` documents the same thing and skips its up-to-date check
because of it.

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

## Layout

```
upstream/       basload-rom @ caaaaf0, unmodified. BSD 2-Clause, Stefan Jakobsson
conf/           basload-prg.cfg -- ours, the only thing this fork adds
test/           HELLO.BASL and the ROM-vs-RAM equivalence test
build.py        both targets, plus the rom.bin verify
build/          output, not tracked
```

**`upstream/` stays pristine.** Every change belongs beside it, so `diff` against a fresh clone
always shows the whole fork. Today that diff is empty and the fork is one linker config — worth
keeping true for as long as it can be.

## Licence

`upstream/` is BASLOAD, © 2021-2023 Stefan Jakobsson, BSD 2-Clause — see `upstream/LICENSE`, which
every source file also carries in full. Permissive: fork, modify and ship, keeping the notice and
the disclaimer. Two repos exist and this is the live one; `stefan-b-jakobsson/basload` is the
deprecated standalone PRG and is **not** a shortcut — it predates `#TOKEN`, `#SAVEAS`, `#SYMFILE`,
`#DEFINE`, `#IFDEF` and `#INCLUDE`, and GP-BASIC is built on `#TOKEN`.
