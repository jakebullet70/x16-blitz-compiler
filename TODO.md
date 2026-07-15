# TODO — Blitz-X16

Replaces the original `TODO.txt`, which was written against **R43** and predated everything R44 added
(sprites, ovals, tiles, `MOD`). This list is derived from **R49** and nothing on it is inherited on trust:

- the keyword set was decoded straight out of BASIC ROM bank 4 of `bin/x16emu/rom.bin` — 76 base
  keywords at `$C142`, then 81 extended ones in two blocks at `$C242` and `$C32C`;
- what the compiler can actually *compile* was read off the `.def` files
  (`source/compiler/source/generation/*.def` and `.../system-specific/x16/generation/*.def`);
- the gap between the two is below.

**63 of the 81 extended keywords compile today. 18 do not** — and every one of the 18 is a
deliberate rejection, not a gap. There is nothing left on the "worth implementing" list.

Tiers 1 to 4 are done. Every keyword below compiles, and every one is checked against the R49 ROM
rather than against a reading of the manual — which caught the manual being **wrong** about
`BVERIFY`'s signature, and then caught *this file* being wrong about `RESET` and `REBOOT`. `ST` was
added along the way: not one of the 81, but `LINPUT#` and `BINPUT#` are unusable without it.

**The extended keyword vector table is at `$C0A0` in BASIC ROM bank 4**, and it is C64 style, so
each of the 81 entries holds its handler's address *minus one*. 66 statements (`$CE80`-`$CEC1`) then
15 functions (which re-anchor at `$CED0`), and it ends exactly where the base keyword text begins at
`$C142`. That is the fact to start from next time a keyword's real behaviour is in doubt — it is how
the `RESET`/`REBOOT` mix-up below was found, and it beats reading the manual.

## How to decide whether a keyword is worth having

Not by the manual's **TYPE** column. That is a hint, not a rule: `LOAD` and `NEW` are both typed
*Command*, yet the manual documents using both from inside a running program. Triage on semantics instead:

> **Blitz compiles to a standalone binary. At runtime there is no BASIC program in memory, no editor
> and no interpreter.** A keyword that acts on the BASIC *environment* has nothing to act on. A keyword
> that drives the *hardware* is worth having.

That single test sorts all 40.

## Worth implementing — ALL DONE

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
- `POWEROFF` is one I2C write to the SMC (`$42`), offset 1. `bench/run-bench.sh` no longer has to
  substitute `I2CPOKE 66,1,0`, so both benchmark columns now run identical source.
- `REBOOT` was **wrong**, and Tier 4 is what found it — it did the offset-2 SMC write, which is
  `RESET`'s job, so a compiled `REBOOT` hard reset the machine. See the bug below. This tier was
  written from an assumption about which keyword was which, and the assumption was backwards.

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

### Tier 3 — DONE

`BLOAD` `BVLOAD` `VLOAD` `BSAVE` `BVERIFY` · `BANK` · `RPT$` · `LINPUT` `LINPUT#` `BINPUT#`

**The manual's `BVERIFY` signature is wrong.** It documents
`BVERIFY <filename>,<device>,<bank>,<start address>,<end address>` and that form is a hard
`?SYNTAX ERROR` in the R49 ROM — run it. It takes **four** arguments. BSAVE's signature looks to have
been copied by mistake, and four is what the KERNAL implies anyway: `LOAD` with `A=1` verifies and has
no end address at all, because the length of the file bounds the comparison. Every other signature
here was probed against the ROM rather than read off the manual, after that.

**`BANK` needed one line.** Its runtime handler had existed all along, and already read `$FF` as "ROM
bank not given" — exactly what `OptionalParameterCompile` pushes for a missing optional. It was only
ever missing its `.def` entry.

**`ST` had to be built first.** `LINPUT#` and `BINPUT#` report end-of-file through `ST`, and Blitz had
no `ST` — without it a read loop *cannot terminate*, because at EOF `LINPUT#` hands back an empty
string and that is indistinguishable from a blank line in the file. `ST` is not a keyword and never
gets tokenised: like `TI` and `TI$` it is a reserved CBM *name*, so it arrives at the compiler as an
ordinary identifier. `FindVariable` already had the mechanism for exactly this (it returns a fake
address with bit 7 of Y set, and `GetSetVariable` dispatches on the high byte) — `ST` is `$A0`
alongside TI's `$80` and TI$'s `$C0`. Two significant characters, as CBM has it, so `STATUS` is the
same name as `ST` and is reserved too, which is what stock does.

Checked against stock R49, byte for byte, and the interesting case is the one `ST` exists for:

| | blank line in the file | end of file |
|---|---|---|
| `LEN(A$)` | 0 | 1 |
| `ST` | **0** | **64** |

`BINPUT#` short-reads at EOF (asked for 20, got 3, `ST=64`), a custom `LINPUT#` delimiter works, and
`LINPUT` on the keyboard is the same P-code on channel 0 — channel 0 *is* the KERNAL's screen editor,
so the manual's warnings (an empty line comes back as one space, trailing spaces are lost) are the
editor's doing and we inherit them for free.

Two P-codes serve all three keywords. The channel is not their business: the `#` forms compile with
the `C:` (channel execute) prefix, which sets `currentChannel` around the command and puts it back —
exactly how `INPUT` and `INPUT#` already share one runtime.

### Tier 4 — DONE

`RESET` `$CE8F`

This was written up above as "a warm reset, where `REBOOT` is a cold one through the SMC", and as a
near-duplicate worth a couple of bytes. **Both halves of that were wrong**, and it is the reason the
keyword is worth having rather than a reason to skip it. The ROM (bank 4, vectors at `$C0A0`):

| keyword | handler | what it actually does |
|---|---|---|
| `POWEROFF` `$CEAD` | `$E7BC` | `ldy #1` → I²C write, SMC `$42`. Cuts the power. |
| `RESET` `$CE8F` | `$E7B8` | `ldy #2` → I²C write, SMC `$42`. The SMC asserts the reset **line** — a **hard** reset, the same as the physical reset switch. |
| `REBOOT` `$CEAC` | `$E6EF` | `jmp ($FFFC)` — a **soft** reset. No hardware is reset at all; the KERNAL just starts again through its own reset vector. |

They are the exact opposite way round from the claim, and the three keywords are genuinely three
different things. The manual agrees with the ROM on all three ("*RESET … instructs the SMC to assert
the reset line … a hard reset*", "*REBOOT … a software reset … by calling the ROM reset vector*") — so
for once the manual was right and this file was wrong. All three now live in `machine.asm`, which
leaves `x16_i2c.asm` holding only `I2CPEEK`/`I2CPOKE`, as its name says.

**`REBOOT` cannot be written the way BASIC writes it, and cannot be written naively either.** BASIC
copies a six byte stub (`stz $01` / `jmp ($FFFC)`) to `$0100` and jumps to *that*, because it is the
ROM it is banking away — `stz $01` executed in place would pull BASIC out from under its own program
counter. We run from RAM, so the two instructions can stand where they are.

But the `stz` itself is not optional, and that is the interesting part: **`$C000-$FFFF` is banked, and
only bank 0 has a real reset vector.** Bank 4 — the bank a compiled Blitz program is running under,
measured, not assumed (`PRINT PEEK(1)` gives `4`, under Blitz *and* under stock) — has `$AA` filler at
`$FFFA-$FFFF`. Bank 4 gets away with that because its `$FF00` page is a table of trampolines into
bank 0, which is also why every KERNAL call in the runtime works without ever touching `$01`.

Proved rather than argued: built once with the `stz` commented out, and `REBOOT` breaks straight into
the machine-language monitor at **`PC = $AAAB`**, with `RO 04` in the register dump. That negative test
is doing real work — `RESET` and `REBOOT` are observationally *identical* from outside (both reboot the
machine), so it is the only thing that distinguishes "`REBOOT` really does take the `$FFFC` path" from
"`REBOOT` is still quietly doing an SMC write". An SMC write would have rebooted with or without the
`stz`.

Both are byte-for-byte conformant with stock R49: the program prints its marker, and then the whole
KERNAL boot banner is printed a second time.

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

### The `storage` section had silently run off the end of its 1K hole — FIXED

`common.inc` places the `storage` `.dsection` at `$0400` and the code at `$0801`. That is **1025
bytes, and no more** — the section simply carries on over the top of the BASIC stub when it runs
out, and nothing says a word. It *had* run out. `IONameBuffer` sat at `$07F1` with 64 bytes declared
and only 15 of them below `$0801`:

```text
IONameBuffer  = $07F1
"SOURCE.PRG" + ",S,R" + NUL  =  15 bytes  ->  $07F1 .. $07FF
```

It fit by **one byte**, and only because the two filenames were hardcoded and both were ten
characters. A twelve-character name would have written straight over the BASIC link pointer at
`$0801` and destroyed the running program. Nobody had ever been able to reach that, because nobody
could change the names.

`GPC.INPUT` makes the names arbitrary, so this went from latent to certain — it is what the first
`GPC.INPUT` build actually did (`?SYNTAX ERROR`: the blanking loop wiped the BASIC stub). The
compiler's buffers — `IONameBuffer`, `SourceLine`, `newWorkspacePage` and the three control lines —
are now in the **`code`** section, which lands above `ObjectBase` and is discarded when the object
code is written, so they cost a compiled program nothing. `storage` is back to `$0400..$06F0`.

There is now a `.cerror` in `common.inc` that fails the build if `storage` ever crosses `$0801`
again. **Nothing warned. That is the whole lesson** — a `.dsection` given a fixed origin will
happily overrun whatever is above it, and the failure surfaces as a corrupt program somewhere else
entirely.

### `REBOOT` was a hard reset — FIXED

`REBOOT` did the offset-2 I²C write to the SMC, which makes the SMC assert the system reset line.
That is a **hard** reset — the physical reset switch — and it is `RESET`'s job, not `REBOOT`'s.
`REBOOT` is supposed to be a *software* reset through the ROM's own reset vector, touching no
hardware at all. Tier 1 implemented one keyword's behaviour under the other's name, and because
Blitz had no `RESET` at all there was nothing to collide with and nothing to notice.

Nothing caught this, and nothing could have: on the emulator the two are indistinguishable — both
restart the machine and reprint the boot banner — and no suite or benchmark uses `REBOOT` (they all
use `POWEROFF`). It took reading the ROM's dispatch table to see it, which is the same lesson as
`BVERIFY`: **the keyword's behaviour is whatever bank 4 says it is.** Now `RESET` is the SMC write
and `REBOOT` is `stz $01` / `jmp ($FFFC)`.

### `OPEN` and `CLOSE` clobbered the interpreter's instruction pointer — FIXED

**`Y` is not a spare register. It is the live instruction pointer.** `NextCommand` fetches every
P-code byte with `lda (codePtr),y`, and `FixUpY` only folds `Y` back into `codePtr` when it crosses
`$80`. So between folds, `Y` *is* how far into the program we are. A command handler must therefore
hand `Y` back exactly as it found it (or advanced past the inline operand bytes it consumed, which
for `OPEN` and `CLOSE` is none).

`CommandXOpen` and `CommandClose` did not. Both call the KERNAL, which is free to trash `Y` — and
`SETLFS` does not merely trash it, it **takes `Y` as an argument**: `Y` is the secondary address. So
every `OPEN` resumed execution at `codePtr` + *the secondary address the user asked for*, and every
`CLOSE` at `codePtr` + whatever `CLOSE` happened to leave behind.

Whether a program survived that was pure luck of code layout, which is why the symptoms made no
sense and every pattern anyone fitted to them was a coincidence:

| what it looked like | what it actually was |
|---|---|
| long filenames fail, short ones work | different name lengths → different code offsets |
| the `"$"` directory open fails | one-character name, so a short offset that happened to land badly |
| every *second* `OPEN` fails | the float-stack bug below, a genuinely separate fault |
| `OPEN` fails after a `BSAVE` | `BSAVE`'s P-code moved the `OPEN` to a different offset |

It also explains why the runtime error it raised pointed nowhere: `RuntimeErrorHandler` reports
`codePtr + Y`, so a clobbered `Y` produces a garbage `@ $xxxx` — and that garbage address is what
sent every earlier attempt at this bug looking in the wrong place. The fix is `phy` after `.entercmd`
and `ply` before `.exitcmd`, and it is four lines.

**Every other KERNAL caller in the runtime was already correct** (audited: graphics, mouse, joy, I²C,
sound, sleep, `TI`, `ST`, `LINPUT`, `BLOAD`/`BSAVE`, and the `XPrintCharacterToChannel` /
`XGetCharacterFromChannel` interface routines all bracket the call with `phy`/`ply`). `OPEN` and
`CLOSE` were the only two, and they were also the only two that skipped the `ldx #$FF` below. The
tell for the whole class is a `jsr X16_…` inside a `;; [pcode]` handler with no `phy` above it.

### `OPEN` after any load or save — FIXED, same cause

`BSAVE "F",8,0,A,B` followed by `OPEN 1,8,2,"F,S,R"` raised an I/O error while the same `OPEN` on its
own worked perfectly. This was the `Y` bug above: `BSAVE` is more P-code, so the `OPEN` after it sat
at a different offset, and the KERNAL's leftover `Y` sent execution somewhere fatal from *there* and
somewhere harmless from where it had been tested alone. `BSAVE` was never at fault — which is exactly
what the old note here concluded, having ruled out the bank registers, the written file, and the
logical file number one by one, and then looked for the fault in `BSAVE` anyway because that is what
the reproducer named. Now `BSAVE` → `OPEN` → `CLOSE` → `OPEN` → `CLOSE` is byte-identical to stock.

### `OPEN` and `CLOSE` never emptied the float stack — FIXED

Every command in Blitz ends `ldx #$FF`, because a command consumes all of its arguments and the next
one's are pushed from slot 0. `CommandXOpen` and `CommandClose` were the only two that did not, so
OPEN left the stack pointer at 3 and CLOSE at 0.

That is not a leak, it is a corruption: **`CommandXOpen` reads its arguments from slots 0-3
ABSOLUTELY** (`NSMantissa0+0` … `+3`), which only works if the stack started empty. So the *second*
`OPEN` in any program read whatever happened to be sitting in those slots, handed the KERNAL a junk
filename pointer and a junk logical file number, and took the machine down. File I/O had only ever
worked for the first `OPEN` in a program.

### A failed I/O operation named a line at random — FIXED

Same root cause, one level down. Every error exit — `XPrintCharacterToChannel`, `XGetCharacterFromChannel`,
the I²C commands, the SMC ones, and all five of `loadsave.asm` — jumped straight to `.error_channel`
with `Y` still holding whatever the KERNAL had left in it. `RuntimeErrorHandler` reports `codePtr + Y`,
so the `@ $xxxx` on a runtime I/O error pointed at a line chosen by the KERNAL rather than the line
that failed. **That false address is what hid the `OPEN` bug**: it sent every previous investigation
looking at the wrong statement, which is why the fault kept seeming to be in whatever came *before*
the `OPEN` — `BSAVE`, usually.

`loadsave.asm` needed a small restructure to fix: `LoadSaveError` unwinds a `jsr`'s worth of stack to
reach the saved `Y`, and `BVERIFY`'s mismatch case reached it by a bare `jmp`, at a different depth.
The mismatch now goes through `sec` / `jsr LoadSaveCheckError` like every other failure, so there is
exactly one stack shape to unwind.

Verified by putting the same failing `BLOAD` at two different points in a program: `@ $0017` at the
top, `@ $003A` after five `PRINT`s — a delta of 35 bytes, which is 7 bytes of P-code per `PRINT`.
The address tracks the code now. A `BVERIFY` mismatch is still detected and a matching one still
passes silently.

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
increment when it is set). It is a core numerical change, so it wants its own pass and its own
verification — and note the suites **cannot see it**: they assert through `f.cmp`, which is
`FloatCompare`, and that deliberately ignores the low 12 bits. Check it with the raw-float-bytes probe
instead (hand-build the stack slots in a throwaway `.asm`, `jsr` the routine, read the result bytes out
of the `-dump R` image; `bin/x16emu` dump.bin is a flat RAM image so byte offset == address).

**`Int32ShiftDivide` — DONE.** The divide now rounds to nearest. The wrinkle is the 31-bit mantissa
(normalised to bit 30, not bit 31): `Int32ShiftDivide` yields floor((a<<30)/b) as a 30- OR 31-bit
value, and rounding has to respect the `FloatNormalise` that follows. Bit-30 set → 31-bit, one guard
bit rounds it; bit-30 clear → 30-bit, so run one extra division step to make the new low bit a real
quotient bit (drop the exponent to match) then round, and renormalise a carry out of bit 31. Verified
126/126 against exact round-to-nearest with the probe; the old code failed ~half. A naive single guard
bit does **not** work — it double-counts in the bit-30-clear case and overshoots.

**`FloatMultiplyShort` — DONE.** The multiply now rounds to nearest. Measured with the probe, the old
truncating multiply was wrong in ~55% of large-product cases (56/102) and by up to ~1.9 ULP. The "up to
two ULP" looked like truncation compounding as bits fell off, but it is **not** — the shift-add loop
already keeps the top 31 bits *exactly* (proved by simulation: the kept mantissa plus every dropped bit
reconstructs the full product, so the accumulator is exact `floor(P / 2^Y)`, error strictly < 1 ULP).
The extra ULP is the **same bit-30 wrinkle as the divide.** The product of two normalised mantissas is
in `[2^60, 2^62)`, so the 31-bit result lands in `[2^30, 2^31)` (bit 30 set) *or* `[2^29, 2^30)` (bit 30
clear); in the second case `FloatNormalise` shifts it left one place afterwards, which moves the rounding
point out from under a single guard bit. So capture **two** dropped bits at both shift points (`FMulGuard`
= 0.5 ulp, `FMulGuard2` = 0.25 ulp): if bit 30 is set, round on the guard; if bit 30 is clear but bit 29
set, fold the guard in as the real low bit it now is (`dey` to match the ×2) and round on guard2; if
neither is set the value is too small to have dropped a bit, so leave the whole normalise to
`FloatNormalise`. Verified **106/106** within 0.5 ULP with the probe. A single guard bit gets 88/102 —
the 14 it misses are exactly the bit-30-clear cases, where it rounds on a bit that is about to become a
real mantissa bit. The `>>=8` fast path did not have to change: it drops bits 0–7, so bit 7 is the new
guard and bit 6 the new guard2, and the suites (incl. the fast-path-heavy compiler-runtime `binary`) stay
green.

### Cosmetic

- **`PRINT` padded a number with a space, stock pads with a cursor-right — FIXED.** After printing a
  number `PrintNumber` (`print/printvalues.asm`) emitted `$20` where stock emits `$1D` (CRSR-RIGHT).
  Both advance one column, so on screen they are indistinguishable — but they are different *bytes*,
  so a numeric `PRINT#` to a file, or a `PRINT` through `CMD`, wrote something stock would not. Now
  `PrintNumber` emits `$1D`; verified byte-for-byte against stock R49 (`[`,`$20`,`5`,`$1D`,`]` for a
  positive, `[`,`-`,`5`,`$1D`,`]` for a negative). The leading space (the sign column) was always
  correct — it comes from `FloatToString` — only the trailing pad was wrong. A terminal diff could
  not see this, because `$1D` renders as nothing; found by hexdumping `PRINT n;"X"`.
- **`PRINT` kept a leading zero — FIXED.** Blitz printed `0.5` where stock X16 BASIC prints `.5` (and
  `-0.5` where stock prints `-.5`). `FloatToString` (`utility/float/tostring.asm`) writes the integer
  part first, so a pure fraction came out with a `0` in front. It now drops that zero when it is the
  whole integer part — the character before it is the sign/space, not another digit — so `10.5` and
  `100.5` keep theirs. Verified with the raw-buffer probe against stock: `.5`, `-.5`, `.25`, `.125`,
  `10.5`, `100.5`, and a whole `0` is untouched. The trailing zeros and the rounding were already
  fixed.
- **Integers below 2^31 print in full**, where stock switches to E notation above 9 digits: we print
  `2147483647`, stock prints `2.14748365E+09`. This is deliberate — we hold it exactly, so printing it
  exactly is *more* precise, not less. Only mentioning it because it is a visible difference.

## Performance

`02_floatmath` is **1.73×** (was 1.25× — see `bench/RESULTS.md`), and no longer the outlier. What is
left is fixed overhead rather than an algorithmic hole: `FloatMultiply` and `FloatAdd` normalise **both**
operands on every call, and for an integer operand that is work the new byte-skip immediately undoes.
Diminishing returns; only worth revisiting if float-heavy code matters more than features.

## Wanted

### Name the output after the source — DONE, but by the caller

The ask was for Blitz to derive the output name from the input, so that compiling `DIR.PRG` produced
`C.DIR.PRG`. It does better than that now: **it takes both names from `GPC.INPUT`**, a three-line
control file (source, object, options — options are read but ignored). So the caller says what the
output is called, and `C.DIR.PRG` is just what you happen to type. Compiling several programs into
one directory no longer clobbers anything, and the compiled and interpreted versions of a program
can sit side by side on the disk.

There is **no fallback**: without a readable `GPC.INPUT` the compiler prints `NO GPC.INPUT FILE` and
stops. A compiler that guesses at what it was asked to build is worse than one that refuses. Every
caller in the tree — `source/application/Makefile`, `bench/run-bench.sh`, the reproductions under
`fixes/` — therefore writes one.

`GPC.PRG` (`source/gpc/GPC.P8`, prog8) is the front end: it asks for the two names, writes the file,
and hands the machine over to the compiler.

## Build / infrastructure

- Copy the object code *down* after compiling, rather than leaving it above the compiler and its
  libraries (must stay on a page boundary). **The part that matters is DONE** — a saved `OBJECT.PRG`
  already reclaims the compiler's ~5.5K: `WriteObjectCode` writes runtime + object as two pieces so the
  object lands at `ObjectBase` on reload, with an adaptive low workspace (commit "Reclaim the compiler's
  memory from compiled programs"). What is *not* done is the in-memory "RUN the compiler a second time"
  path, which still runs the object where it was generated (up at `FreeMemory`, workspace hardcoded at
  `$8000`). **Parked as a low-value dev-path cleanup:** it only affects testing a program in the
  compiler's own memory without reloading the saved file — the shipped `OBJECT.PRG` is unaffected. The
  one real wrinkle is a size ceiling on that path (object code over ~14K grows past `$8000` and the
  in-memory run's workspace stomps it, even though the saved file is fine). If it is ever worth doing:
  insert a `RelocateObject` routine *below* `ObjectBase` (so the copy cannot overwrite itself), reached
  by the NOP fall-through `PatchOutCompile` already leaves at `StartCode`; guard it on `RunCodePage+1
  == FreeMemory>>8` (false in the saved file, so it self-skips), forward-copy `FreeMemory`→`ObjectBase`
  (dst < src, overlap-safe), patch the `RunCodePage`/`RunWorkspacePage` immediates in RAM, then fall
  through to run. Length must come from `newWorkspacePage` (a code-section byte that survives), not
  `objPtr` (zero page, gone once BASIC re-runs).
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
