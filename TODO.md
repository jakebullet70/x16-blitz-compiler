# TODO — Blitz-X16

Replaces the original `TODO.txt`, which was written against **R43** and predated everything R44 added
(sprites, ovals, tiles, `MOD`). This list is derived from **R49** and nothing on it is inherited on trust:

- the keyword set was decoded straight out of BASIC ROM bank 4 of `bin/x16emu/rom.bin` — 76 base
  keywords at `$C142`, then 81 extended ones in two blocks at `$C242` and `$C32C`;
- what the compiler can actually *compile* was read off the `.def` files
  (`source/compiler/source/generation/*.def` and `.../system-specific/x16/generation/*.def`);
- the gap between the two is below.

**52 of the 81 extended keywords compile today. 29 do not.**

Tiers 1 and 2 are done — `MOD`, `OVAL`, `RING`, `POWEROFF`, `REBOOT`, `SPRITE`, `SPRMEM`, `MOVSPR`,
`TILE`, `TDATA` and `TATTR` all compile, and every one is checked against the R49 ROM rather than
against a reading of the manual. What follows is what is left.

## How to decide whether a keyword is worth having

Not by the manual's **TYPE** column. That is a hint, not a rule: `LOAD` and `NEW` are both typed
*Command*, yet the manual documents using both from inside a running program. Triage on semantics instead:

> **Blitz compiles to a standalone binary. At runtime there is no BASIC program in memory, no editor
> and no interpreter.** A keyword that acts on the BASIC *environment* has nothing to act on. A keyword
> that drives the *hardware* is worth having.

That single test sorts all 40.

## Worth implementing (11 left)

### Tier 1 — DONE

`MOD` `$CEDE` · `OVAL` `$CEBF` · `RING` `$CEC0` · `POWEROFF` `$CEAD` · `REBOOT` `$CEAC`

- `MOD(<dividend>,<divisor>)` is the truncated remainder, so it takes the sign of the *dividend*.
  It leans on `Int32Divide`, which already computes a remainder and leaves it in `S[X]` — `DivideInt32`
  simply throws that half away. It also zeroes only the *mantissa* of `S[X]`, so the dividend's status
  byte (its sign) survives the divide untouched, which is exactly the sign a truncated remainder wants:
  there is no sign fixup in `MOD` at all. Checked against the R49 ROM across all four sign combinations
  — Blitz and stock BASIC agree exactly. The ROM caps `MOD` at 16-bit operands; ours is a full 32-bit
  remainder, a superset.
- `OVAL`/`RING` were the freebie predicted here: `GRAPH_draw_oval` takes the same bounding box and
  carry-as-fill flag that `GRAPH_draw_rect` does, so they reuse `GraphicsRectCoords` verbatim.
- `POWEROFF`/`REBOOT` are one I2C write each to the SMC ($42), offsets 1 and 2. `bench/run-bench.sh`
  no longer has to substitute `I2CPOKE 66,1,0`, so both benchmark columns now run identical source.

**A bug found and fixed on the way.** `GraphicsRectCoords` ended with `stz 8,x` / `stz 9,x`, commented
"zero rounding". At that point `X` is `X16_r1` (4), so those write to 12/13 — that is **r5**, which is
not an input to anything. The corner radius `GRAPH_draw_rect` reads is **r4** (10/11), at offset 6. So
`RECT` and `FRAME` had been handing the KERNAL an uninitialised corner radius all along.

### Tier 2 — DONE

`SPRITE` `$CEBB` · `SPRMEM` `$CEBC` · `MOVSPR` `$CEBD` · `TILE` · `TDATA` `$CEDC` · `TATTR` `$CEDD`

These write VERA directly, because unlike the audio keywords there is **no ROM layer to call**. The
KERNAL does have `sprite_set_image` and `sprite_set_position`, and neither is the right shape:
`sprite_set_position` only handles sprites 0-31 where `MOVSPR` takes 0-127, and `sprite_set_image`
converts pixel data out of host RAM where `SPRMEM` merely points a sprite at pixels already in VRAM.
BASIC writes the attributes itself and so do we.

**Optional parameters are read-modify-write, and that is a requirement, not a nicety.** The compiler
already had `OptionalParameterCompile`, which pushes **255** when its comma is missing; chaining it
gives "and the rest are optional", and 255 is out of range for every one of these fields (the widest
is a nibble), so the runtime reads it as *leave this one alone*. The manual's own example is why:

```BASIC
20 SPRMEM 1,1,$3000,1
30 SPRITE 1,3,0,0,3,3
```

`SPRITE` omits the colour depth. Defaulting it to 0 would silently undo the 8bpp `SPRMEM` set on the
line before.

**How they were verified.** Sprites are invisible to a text-diffing harness, so the test reads the
attributes *back* with `VPEEK` and compares against stock R49 running the identical program — 8
attribute bytes x several configurations, plus `PEEK($9F29)` for the sprite-layer enable, which is an
I/O register and not reachable by `VPEEK`. Every byte matches: z-depth, both flips, both size fields,
palette offset, the 17-bit pixel address, sprite 0 and sprite 127 (which is the one that exercises the
`$FC + 3 = $FF` carry in the attribute address), the negative-coordinate wrap (`MOVSPR 0,-1024,2048`
lands on 0, as the manual says it must), and preserve-on-omit. Identical VERA state means identical
rendering, which is as close as anything can get to proving a sprite is on the screen from inside a
program.

Two bugs found on the way, both mine, both caught by that comparison:

- `SpriteSetAddress` used `spriteTemp` as scratch, and `SPRMEM` computes an attribute byte into
  `spriteTemp` *before* calling it to find out where the byte goes. One byte of the pixel address came
  out as 0 instead of 9. It now has its own private scratch, and says so.
- `_SSACommon` was a cheap local branched into from another global's scope. 64tass `_locals` do not
  cross a global label — the same trap already documented in `x16_i2c.asm`.

### Tier 3 — data in and out

- **Binary load/save:** `BLOAD` `BVLOAD` `BSAVE` `BVERIFY` `VLOAD`. The manual types these *Command*,
  and the old TODO put them on its "Add" list; both are beside the point. Loading binary data (a
  sprite sheet, a level, a tile map) is exactly what a compiled game wants, so they stay.
- **Banking:** `BANK`
- **Input:** `LINPUT` `LINPUT#` `BINPUT#`. NB their tokens were **swapped** in Blitz's table
  (`LINPUT#` is `$CEB3`, `LINPUT` is `$CEB4`); the order is fixed now, so they will tokenise correctly
  the moment a handler exists.
- **String:** `RPT$`

### Tier 4 — one loose end

`RESET` `$CE8F` — a warm reset, where `REBOOT` is a cold one through the SMC. Now that `REBOOT` exists
this is close to a duplicate, but it is a couple of bytes and it is the one keyword the first pass of
this list never classified at all. Cheap to finish.

## Rejected (16) — nothing for them to act on

`MON` `DOS` `OLD` `GEOS` `TEST` `CODEX` `BOOT` `KEYMAP` `MENU` `REN` `HELP` `EXEC` `EDIT` `BASLOAD`
`HBLOAD` `BANNER`

These drive the editor, the monitor, the DOS shell or the BASIC program text — none of which exist in a
compiled binary. Same reasoning retires `LIST` `NEW` `RUN` `CONT` `CLR` from the base set. (`HBLOAD` and
`BANNER` have no manual entry at all; `BASLOAD` is a development-time loader.)

## Undecided (2)

`POINTER` `STRPTR` — they hand back the address of a BASIC variable or string. Blitz lays variables out
its own way at compile time, so these would either mean something different or nothing. The original
author rejected them outright; leaving them parked rather than deciding in the abstract.

## Bugs

### `FMPLAY` / `FMCHORD` / `PSGPLAY` / `PSGCHORD` hard-crashed — FIXED

All four string-playing audio commands go through `X16_Audio_Parameters8_String` (`audioparams.asm`),
and it set up its `JSRFAR` payload with a **`jsr`** where every other call site in the tree uses a
`.word`:

```asm
        jsr     X16_JSRFAR
        jsr     X16A_bas_playstringvoice     ; <-- assembles to 20 0c c0
        .byte   X16_AudioCodeBank
```

`JSRFAR` takes its target from the *three bytes following the `jsr`* — address, then bank. Those bytes
were `20 0c c0`, so it far-called **address `$0C20` in bank `$C0`**: the middle of the compiled
program's own code, in a bank that does not exist. On return it landed on the stray `$0A` bank byte and
executed it as `ASL A`. Confirmed by rebuilding with the bug: `FMPLAY 1,"CDEFGAB"` `BRK`s straight into
the machine-language monitor and hangs. With the `.word` it plays and the program runs on.

The suites never caught this because **nothing tests audio** — the nine suites are float, then
compiler-runtime (binary/compare/unary/parenthesis/variables/arrays). Worth remembering the next time
a runtime command "obviously works".

### Values past 2^31 — FIXED, in two halves

The mantissa holds 31 bits plus a sign (in `NSStatus`), so `2147483647` is the largest integer it can
hold *bare*. Anything larger has to become a float, mantissa x 2^exponent. Two independent things
stopped that working, and both are now fixed:

1. **The literal parser wrapped silently.** `ESTAShiftDigitIntoMantissa` (`tofloat.asm`) did
   `mantissa = mantissa*10 + digit` with no overflow check at all — `FloatShiftLeft` is a `rol` chain,
   so bits pushed out of bit 31 were simply dropped. `2196679407` compiled to `-49195759`,
   `2147483648` to `-0`. Now the quick path runs only while the result still fits and the rest goes
   through `FloatMultiply`/`FloatAdd`.

2. **`PRINT` could not show a positive exponent.** `MakePlusTwoString` (`tostring.asm`) rendered the
   **mantissa** in base 10 and never looked at `NSExponent`, so a correctly-held 3e9 printed as
   `1500000000`. Now `FloatToStringScientific` handles it in E notation, as BASIC does.

The arithmetic was **fine all along**, which is why (2) went unnoticed for so long: the values were
right, only `PRINT` lied about them.

### The one that is left: the float ops truncate, and truncation is biased

`PRINT 1E15` gives `9.99999999E+14`, where stock BASIC gives `1E+15`. Everything else matches stock
exactly — `3E+09`, `2.19667941E+09`, `2.14748365E+09`, `5E+09`, `1E+10`. The drift only shows on large
powers of ten, and it **grows with the exponent**, which is the tell:

| literal | Blitz | stock |
|---|---|---|
| `1E15` | `9.99999999E+14` | `1E+15` |
| `1E20` | `9.99999998E+19` | `1E+20` |
| `1E30` | `9.99999997E+29` | `1E+30` |
| `1E38` | `9.99999996E+37` | `1E+38` |

This is **not** a printer bug. `FloatMultiplyShort` and `Int32ShiftDivide` both **truncate** — they
never round to nearest — so every operation lands slightly LOW, and because the error always points
the same way it accumulates instead of cancelling. `FloatScalePower10` applies a power of ten a
tableful (10^9) at a time, so `1E38` is four chained multiplies and comes out about four ulp light.
The printer then faithfully reports the value it was given.

Measured, so it is not a guess: `b = 1E15 : PRINT b/1000000` gives exactly `999999999`, and
`PRINT b/1000000 - 999999999` gives exactly `0`. The true quotient is `999999999.574`, and the nearest
value the format can hold is `999999999.5` — so the divide lost a full ulp *below even truncation*.
Had it rounded, the printer's own rounding would have carried it to `1000000000` and printed `1E+15`.

**The fix is round-to-nearest in `FloatMultiplyShort` and `Int32ShiftDivide`** (keep the guard bit,
increment when it is set). It would make every float operation slightly more accurate, at a cost of a
few bytes and cycles. It is a core numerical change, so it wants its own pass and its own verification
— and note the suites **cannot see it**: they assert through `f.cmp`, which is `FloatCompare`, and that
deliberately ignores the low 12 bits. Check it with the raw-float-bytes probe instead.

### Cosmetic

- **`PRINT` keeps a leading zero.** Blitz prints `0.5`, X16 BASIC prints `.5`. The trailing zeros and
  the rounding are already fixed.
- **Integers below 2^31 print in full**, where stock switches to E notation above 9 digits: we print
  `2147483647`, stock prints `2.14748365E+09`. This is deliberate — we hold it exactly, so printing it
  exactly is *more* precise, not less. Only mentioning it because it is a visible difference.

## Performance

`02_floatmath` is **1.73×** (was 1.25× — see `bench/RESULTS.md`), and no longer the outlier. What is
left is fixed overhead rather than an algorithmic hole: `FloatMultiply` and `FloatAdd` normalise **both**
operands on every call, and for an integer operand that is work the new byte-skip immediately undoes.
Diminishing returns; only worth revisiting if float-heavy code matters more than features.

## Build / infrastructure

- Copy the object code *down* after compiling, rather than leaving it above the compiler and its
  libraries (must stay on a page boundary). Inherited from the old TODO and still true.
- **`release` copied `CHANGES.txt` unconditionally** — the original author's 2023 changelog, deleted
  in "Del old files from previous build". `make libs` then failed at the packaging step, well after
  the assembler had already succeeded, which reads like a build break but is not one. It is copied
  only if present now. Same class as the five blockers that once made this repo unbuildable anywhere:
  a recipe asserting on a file nothing guarantees.

## Notes that are easy to lose

- The randomised test suites **cannot see a 1-ULP error** — they assert through `f.cmp`, which is
  `FloatCompare`, and that deliberately ignores the low 12 bits of a float difference. Green suites
  prove nothing about precision. To check float internals, hand-build the stack slots in a throwaway
  `.asm`, `jsr` the routine, and read the raw bytes out of the emulator's `-dump R` image.
- `x16emu` will not overwrite an existing dump — it silently writes `dump-1.bin`. Delete the old one or
  you will read stale bits.
- If the emulator exits instantly with `SDL_OpenAudioDevice failed`, that is the host's audio device,
  not the build. Pass `-sound none`.
