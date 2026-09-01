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

## `POINTER` / `STRPTR` — CLOSED, not undecided

Both hand back the address of a BASIC variable or string, and Blitz lays variables out its own way at
compile time. `testing/POINTER.PRG` makes the mismatch concrete: it treats the result as a CBM
`[len, ptr-lo, ptr-hi]` descriptor and walks it, and Blitz stores `[MaxLen][Control][ActLen][Data]` —
a different shape — so that walk reads garbage whatever address is returned. **There is no address
Blitz can hand back that makes an existing descriptor-walking program behave.**

Both tokens are *recognised* by `x16_unary.def`, so tokenised BASIC using them still loads and
round-trips, and both route to `UnsupportedCompile`, which raises `NOT IMPLEMENTED @ <line>`. That is
the answer, and it is a deliberate fail-loud one: emitting *some* address would compile and then read
the wrong memory.

**And the need they were parked against is met.** `GP.STRPTR` returns Blitz's own block address with
the layout documented, which is the only variant with clean semantics — and it is now load-bearing:
`STRCASE.INC.BL` is built on it, as `SORT.INC.BL` is on `GP.ARRPTR`. Nothing is waiting on a decision
here.

## Bugs

### `AND`/`OR` leaked the top half of an out-of-range operand — FIXED

`AND` and `OR` are 16-bit operations here, as they are in stock — but `AndOrCommon` reached
`GetInteger16Bit` directly, and that only ever touches `Mantissa0/1`. `Mantissa2/3` kept the top half
of the left operand and rode straight through into the result:

| | GPC (was) | as hex | truth |
| --- | --- | --- | --- |
| `4294967295 AND 0` | `4294901760` | `$FFFF0000` | `0` |
| `2147483647 AND 0` | `2147418112` | `$7FFF0000` | `0` |
| `70000 AND -1` | `70000` | `$00011170` | `70000` is out of range |
| `65535 AND 0` | `0` | `$00000000` | correct, by luck — nothing above 16 bits |

**Stock does not compute a wrong answer here, it refuses.** Measured against R49: an operand outside
`-32768..32767` raises `?ILLEGAL QUANTITY ERROR`, so masking the high bytes off would have been the
wrong repair. `AndOrGet16` now truncates to an integer and range checks before converting, raising
`OUT OF RANGE` (GPC's spelling of the same refusal — what `MID$` and `SQR` already raise). The check
must happen on the **magnitude, before the two's complement conversion**: afterwards `-32768` and
`-40000` both leave a high byte with bit 7 set and cannot be told apart.

Verified case by case against stock — every value stock accepts, GPC accepts with the same result;
every value stock rejects, GPC now rejects:

| | stock R49 | GPC |
| --- | --- | --- |
| `32767 AND -1` | `32767` | `32767` |
| `-32768 AND -1` | `-32768` | `-32768` |
| `3.7 AND -1` | `3` | `3` |
| `32768 AND -1` | `?ILLEGAL QUANTITY` | `OUT OF RANGE` |
| `65535 AND -1` | `?ILLEGAL QUANTITY` | `OUT OF RANGE` |
| `65536 AND -1` | `?ILLEGAL QUANTITY` | `OUT OF RANGE` |
| `-32769 AND -1` | `?ILLEGAL QUANTITY` | `OUT OF RANGE` |
| `70000 AND -1` | `?ILLEGAL QUANTITY` | `OUT OF RANGE` |
| `-1 OR 32768` | `?ILLEGAL QUANTITY` | `OUT OF RANGE` |

**Why no suite caught it, and why MD5 did not.** `testing/MD5` needs 32-bit bitwise ops and gets them
by splitting every value into 16-bit halves — `FNUW(FNSW(XH) AND FNSW(YH))` at line 3320 — so it
never hands `AND` anything above 16 bits and never touched the broken path. That is worth remembering
before assuming MD5's green tick covers the bitwise operators: it covers exactly the 16-bit case.

### `FOR I%` compiled and then ran wrong — FIXED by rejecting it, as stock does

`FOR` with an integer index compiled here and silently produced wrong values:

```basic
FOR I%=2 TO -2 STEP -1 : PRINT I%; : NEXT
```

printed `2 1 0 1 2` — the magnitudes — and left `I%` at `3` rather than `-3`. The trip *count* was
always right, because `NEXT` compares the float in the frame, so it was a silent wrong answer rather
than a crash, and no positive-only loop could expose it (magnitude == value there).

Half a feature. The compiler detected `NSSIInt16` and flagged bit 15 of the reference; the runtime's
`FOR` recorded it at frame offset 4 bit 7 — and **nothing ever read that bit back**. `next.asm` tested
only bit 6 (the optimised path) and then did an unconditional six-byte `ReadFloatZTemp0Sub` /
`WriteFloatZTemp0Sub`, so `NEXT` left a raw sign-magnitude iFloat32 in a two-byte slot while every
later read took those two bytes as two's complement.

**Stock X16 BASIC does not allow an integer loop index at all** — `FOR I%=1 TO 10` is `?SYNTAX ERROR`
there — so the fix is to reject it rather than finish it. `CommandFOR` masked `NSSTypeMask` ($40)
alone, which only tests float-vs-string; it now masks `NSSTypeMask|NSSIInt16` ($60). The error defers
to runtime through the existing `DeferStatementToRuntime` stub, so a program only fails when the line
is actually reached — which is what the interpreter does too:

| | stock R49 | GPC |
| --- | --- | --- |
| `20 FOR I%=2 TO -2 STEP -1` | `?SYNTAX ERROR IN 20` | `SYNTAX ERROR @ $0014` → line 20 |

**Nothing is lost by rejecting it.** Benchmarked compiled over 20,000 iterations (jiffies), an int16
index is *not* faster than a float one — the earlier claim in the notes that it was "marginally
slower" was reasoned from the code and is also wrong; it is a wash either way:

| | `FOR I` | `FOR I%` |
| --- | --- | --- |
| empty loop, ascending | 65 | 65 |
| body reads the index | 261 | 257 |
| descending (never optimised) | 175 | 174 |

And no program written for stock could contain one — a grep of every `.bas`/`.BASL` in `samples/`,
`testing/` and `source/` found zero. Use `%` to shrink arrays (`DIM A%(n)` really is two bytes an
element), not to speed up a loop.

Verified against stock: `FOR I=1 TO N% STEP S%`, an `%` inside the body, `DIM A%()`, `STEP 0`, plain
`K%=-22` and nested loops all still match exactly. The runtime's bit-15/bit-7 plumbing is left in
place with the masking that already neutralises it, so a stale object file that still sets the bit
stores a flag nothing acts on rather than a bogus address.

**A latent second defect is now unreachable but still there.** `AllocateBytesForType`
(`compiler/storage/create.asm`) reads the type from **A**, but its only scalar caller
`GetReferenceTerm` reaches the call with A = 0 — so its `ldx #2` branch is dead and *every* scalar,
including `%` and `$`, gets 6 bytes. That over-allocation is the only reason the `FOR I%` bug
corrupted no memory. If anyone ever corrects that caller, re-check this: int scalars would drop to 2
bytes and any remaining six-byte write into one would overwrite the next variable.

### READ/INPUT kept the leading spaces stock BASIC strips — FIXED

Turned up while differentially testing `OPEN` on a missing file. The standard idiom

```basic
OPEN 15,8,15 : INPUT#15,EN,EM$,ET,ES
```

gave `EM$ = " FILE NOT FOUND"` under GPC and `"FILE NOT FOUND"` under stock, because the drive really
does send a space after the comma — the raw `GET#15` byte dump is identical both ways. So any program
testing `EM$="FILE NOT FOUND"` silently failed.

Not specific to the error channel: `GetStringToBuffer` in `commands/read.asm` is shared by
`READ`/`DATA`, `INPUT` and `INPUT#`, and its "skip all leading spaces" loop did

```asm
    cmp     #' '
    bcs     _RBNoSpace
```

`cmp` sets carry when A **equals** the operand, so a space took the exit branch — the loop only ever
skipped the control characters below `$20`. `cmp #' '+1` makes `bcs` mean "greater than a space",
which is what the comment always claimed. Numeric fields were already right; they go through
`val.asm`, which does its own skipping.

Verified against stock R49 with a fixture whose fields carry leading and trailing spaces
(`A, HELLO ,  C` on one line, two space-padded numbers on the next):

| | before | after (= stock) |
| --- | --- | --- |
| `INPUT#1,A$,B$,C$` | `[A][ HELLO ][  C]` — 1/7/3 | `[A][HELLO ][C]` — 1/6/1 |
| `READ A$,B$,C$` | `[A][ HELLO ][  C]` — 1/7/3 | `[A][HELLO ][C]` — 1/6/1 |
| `INPUT#15,EN,EM$` | `62/ FILE NOT FOUND` | `62/FILE NOT FOUND` |

Trailing spaces are kept, by both — that is also what stock does. All six compiler-runtime suites,
the ifloat32 suite and the MD5 end-to-end still pass.

`OPEN` on a missing file itself is **correct** and was never a bug: stock lets the `OPEN` succeed,
reports the failure only on the DOS command channel, leaves `ST` at 64, and gives `ST`=66 with an
empty string on the first `GET#`. GPC matches it exactly.

### A runtime error named the line AFTER the one that failed — FIXED

Found by the GPC.ERR pass above, and it was the runtime's fault, not the decoder's. `NXCommand`
consumes the opcode (`iny`) **before** `jmp (VectorTable,x)`, so on entry to a handler `codePtr + Y`
already points *past* that handler's own instruction. `RuntimeErrorHandler` reports `codePtr + Y`.
So any error raised during a command's **execution** — rather than while its arguments are being
evaluated — reported one byte too far.

That only crosses a line boundary when the failing opcode is the **last one on its line** — which is
a one-statement line, i.e. how most BASIC is written. Measured before the fix:

| faulting statement | reported | GPC.ERR said |
|---|---|---|
| `RETURN` with no `GOSUB` on line 110 | `STRUCTURE IMBALANCE @ $005D` | line **120** |
| a failing `BLOAD` on line 110 | `INPUT/OUTPUT ERROR @ $006D` | line **120** |

`$005D` and `$006D` are *exactly* line 120's first byte in those maps. The worst part was the
wording: an address that lands on a line start is an exact hit, so GPC.ERR printed the confident
"IS **ON** BASIC LINE 120" rather than "ON/NEAR". It read as certain and was wrong.

`READ A,B,C` running out of data was **right** all along, and that is the tell: it fails on the second
of three ops, so the over-advanced address is still inside its own line.

The fix is a 16-bit decrement in `RuntimeErrorHandler` (`errorhandler.asm`) — report the opcode that
failed, not the one after it. Every raise site is at least one byte into its statement (operand fetches
`iny` past the byte they read), so `-1` can never leave the failing statement, and at worst lands on
its first byte.

Verified across the error set — 16 programs compiled and run, **0 decoding to the wrong line**:
`BAD ARRAY INDEX`, `DIVIDE BY ZERO`, `OUT OF DATA`, `STRUCTURE IMBALANCE` (from both `RETURN` and
`NEXT`), `INPUT/OUTPUT ERROR`, and `OUT OF RANGE` (from both `MID$` and `SQR`). The cases that prove
`-1` cannot overshoot are the two with the fault on **line 10**, where there is no earlier line to fall
back into: a bare `RETURN` reports `$0007` against a line starting at `$0006` — one byte of margin, and
it holds. End to end afterwards: a `RETURN` alone on line 80 reports `$0037`, and GPC.ERR answers
"ON/NEAR BASIC LINE 80" (it used to answer "ON BASIC LINE 90").

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

### The float ops truncated, and truncation is biased — FIXED, re-measured 2026-07-31

**The drift below is gone.** Re-measured against stock R49 after both rounding fixes landed, every
literal in the table now prints exactly as stock does:

| literal | Blitz (was) | Blitz (now) | stock |
|---|---|---|---|
| `1E15` | `9.99999999E+14` | `1E+15` | `1E+15` |
| `1E20` | `9.99999998E+19` | `1E+20` | `1E+20` |
| `1E30` | `9.99999997E+29` | `1E+30` | `1E+30` |
| `1E38` | `9.99999996E+37` | `1E+38` | `1E+38` |

The controls (`3E+09`, `1E+10`, `2.19667941E+09`, `SQR(2)`, `1/3`, `.5`, `-.5`) still match too. What
follows is the original diagnosis, kept because it explains *why* the two rounding fixes below were
the right ones — not because any of it is still outstanding.

Of the three divergences that remained after it, one is fixed and two are left:

- **`LOG(1)` gave `3.2277181E-10` where stock gives `0` — FIXED.** `FloatLogarithm` computes
  `log(f) + k*log(2)`; at exactly 1 those are `-log(2)` and `+log(2)`, so the answer is the
  difference of two nearly equal numbers and is only as exact as the polynomial is at the very END
  of its fitted interval (`f = 0.5, k = 1`). It was not. Every other logarithm measured already
  agreed with stock, so `log.asm` special-cases the single value rather than disturbing the
  polynomial: normalised, 1.0 is the only value with mantissa `$80000000` and exponent `-31`, so
  the test is an exact identity. **Deliberately not `FloatCompare`** — that ignores the low 12 bits
  of the difference ("almost equal", ~1 part in 500,000), so it would also swallow everything just
  either side of 1 and return 0 for logarithms that are genuinely non-zero. Verified: `LOG(1)` is
  now `0`, `LOG(2)`/`LOG(10)`/`LOG(.5)`/`LOG(100)`/`LOG(1000)` still match stock exactly, and
  `LOG(1.0001)`, `LOG(.9999)`, `LOG(1.000001)` still return non-zero.

  Logs *near* 1 differ from stock in the last digits either way (`LOG(1.000001)`: stock
  `1.00043122E-06`, ours `9.9930152E-07`, true `9.99999E-07` — ours is marginally closer). That is
  inherent cancellation in `log(1+e)`, present in both implementations, and untouched by the fix.
- **`EXP(2)` gives `7.38905609`, stock `7.3890561`** (true value `7.389056099`) — one in the 9th
  significant digit, again polynomial accuracy.
- **`999999999.4` prints `999999999`, stock prints `1E+09`.** Stock's 40-bit format cannot hold the
  `.4`, rounds up to `1000000000`, and switches to E notation past 9 digits; we hold it and print the
  correctly-rounded 9 digits. Ours is the more accurate answer, so this belongs with the deliberate
  "integers below 2^31 print in full" deviation rather than with the bugs.

The original diagnosis follows. This was **not** a printer bug. `FloatMultiplyShort` and `Int32ShiftDivide` both **truncate** — they
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

## Shrinking the runtime

The runtime is copied **verbatim** into every compiled program — one pre-linked image — and there is
no per-program dead-code elimination: `10 PRINT"HI"` ships the sprite engine, the disk loader and the
transcendental library it never calls.

**Re-anchored 1st September 2026.** The figures below were measured when `ObjectBase` was `$3300` and
the GP block did not exist; the argument is unchanged but every number had drifted. Current:

| | |
|---|---:|
| core runtime, `$0801`–`GPBase $3700` | **12,031** (`RT` of a GP OUT program) |
| GP block, `$3700`–`ObjectBase $3b00` | **1,024** (1,010 used, 14 free) |
| whole image, GP IN | **13,055** |

The original breakdown, at 10,956 bytes total: `runtime.library` 7,288 (the VM plus all 158 command
handlers), `ifloat32` 2,349, `polynomials` 860, `common` 415, the BASIC stub 44. The core has grown
about 1,075 bytes since — proportions, not the split, are what to reason from.

For scale: the vintage **C64 Blitz!** runtime is roughly **half** ours — its compiled `C/DIR` is
6,244 B against our own 10,992 B build of the same program (0.57× whole-program), and subtracting the
compiler's runtime-less `Z/DIR` intermediate (444 B) *estimates* the embedded runtime at ~5.8K — a
rough difference, not an exact extraction. It stays small two ways, both where our extra bytes went:
it calls the C64 ROM for floating point and number↔string conversion (verified — the compiled `C/DIR`
makes the ROM/KERNAL float calls, the runtime-less `Z/DIR` makes none), and C64 BASIC V2 has no
graphics/sprite/sound keywords to compile at all. We spend ~3.2K on our own 32-bit float (by design,
over the ROM's 40-bit) and ~2K on X16 hardware handlers. Two ways to give a program back the bytes it
does not use, neither small, plus a cheap first step that both depend on.

### Runtime without graphics — selective handler inclusion

A pure text/math program never calls `PSET`/`LINE`/`RECT`/`FRAME`/`OVAL`/`RING`/`CHAR`
(`graphics.asm`, **280 B**), and usually not `SPRITE`/`MOVSPR` (**463 B**), `TILE`/`TDATA`/`TATTR`
(**244 B**), `MOUSE` (**107 B**), the FM/PSG sound handlers (**328 B**), nor `I2CPOKE`/`VPOKE`/`BLOAD`
— ~**2 KB** of hardware handlers in all. Every one is reachable **only** through its keyword's
`VectorTable` slot, and the emitted p-code addresses commands by *token*, never by handler address —
so the compiler already has everything it needs to ship only the handlers a program references.

The obstacle is layout, not information. The runtime is one image copied whole, and these handlers sit
in the **middle** of it, so dropping one means either repointing its dead vector slot at a stub (which
reclaims nothing — the bytes stay) or a per-program relocating link (which reclaims them but is a real
linker). The honest first cut is to **group the optional hardware handlers at the tail** of the image,
in dependency order, so an unused group truncates with `ObjectBase` lowered to match — no relocator.

### Runtime on X16 ROM floats

`ifloat32` + `polynomials` are **3,209 B — 29 % of the runtime** — of custom 32-bit float and
transcendentals. The X16 has a complete 40-bit floating-point BASIC in ROM (bank 4, which a compiled
program is already running under), so calling it — the way C64 Blitz calls the C64 ROM — would drop
most of that and move the runtime toward the C64 figure. But the saving is **gross, not net**: the
marshalling glue below is added back, and it is not a drop-in — which is the whole reason to weigh it
against the cost:

- the number format changes (31-bit mantissa + separate status/exponent → 40-bit FAC), so **numeric
  results change** and the suites move with them — `f.cmp` tolerance would have to be re-baselined;
- every operand marshals through FAC1/FAC2 instead of the custom **12-deep zero-page number stack**,
  and that stack currently lives in the same zero page the ROM's FAC scratch wants;
- the integer fast-paths the 32-bit format buys (`FloatInt8Multiply`, integer add/compare) go away —
  which is exactly the speed the fork spent those 3.2K to get.

It is the single biggest lever and the single biggest rewrite. Parked as the deliberate
size-for-speed trade to revisit only if footprint ever outweighs it.

### The cheap first step both of the above want

`polynomials` (860 B, the transcendentals) and the string→float parser inside `ifloat32` (~518 B,
reached at runtime **only** by `VAL`) already sit at the very **tail** of the runtime image
(`$2f71`…`$3300` is entirely `FloatSine`/`Cosine`/`Exponent`/`Logarithm`/… and their coefficient
tables). A program that uses no `SIN`/`COS`/`^`/`SQR`/… and no `VAL` could therefore ship a runtime
**truncated** below them, `ObjectBase` lowered to match — no relocation, the handlers below keep their
addresses, the dropped vector slots just never execute. It needs the compiler to scan the emitted
p-code for those opcodes and pick the trimmed image, and the generated `vectors.asm`/`links.asm`/
`pi.asm` made conditional (repoint the dropped slots to a range-error stub, inline `PI`'s constant).
Bounded work, ~**1.4 KB** off a non-trig/non-`VAL` program, and it builds the conditional-runtime
machinery the two larger items above both need.

### DONE 01/09/26 — `GP.SELECT`'s frame is dead weight for a variable selector

Noted 30th August 2026 while costing a block `GP.IF`; nothing here is urgent, it is the first move if
opcode or GPB pressure ever does bite.

`GP.SELECT` costs **127 B** — 112 of code (`gp.select` 44, `gp.case` 42, `gp.else` 4, `gp.endsel` 10,
`SelectFindFrame` 12) plus 12 of vector slots. **98 of those 127** (`gp.select` + `gp.case` + the
finder) exist for one property: the selector is evaluated **once**, into `FRAME_SELECT`, because
`new.line` resets the number stack at every source line and a value left there would be gone by the
first `GP.CASE`.

**Every `GP.SELECT` in the tree selects on a plain variable**, so not one of them needs it:
`BMX.DEPTH` ([BMX.INC.BL:401](../GPC-BASIC/BMX.INC.BL)), `INPHELP.CODE`, `MENUHELP.CODE`,
`INPHELP.KEY` (`FORM.EXP.BL`), `KEY.CHAR` and `CLASSIFY.N` (`SELECT.EXP.BL`). Re-reading a variable
per alternative gives the identical result and is, if anything, cheaper than `gp.case`'s six-byte
frame copy plus `SelectFindFrame`.

**THAT VERDICT IS REVERSED AS OF 1st SEPTEMBER 2026, and only because the boundary moved.** It was:
*deleting the keyword frees no program bytes, which is why it stays* — 1,970 B used of a page-aligned
2,048, so 1,970 − 98 = 1,872, still above the 1,792 that would give a page back. Bytes inside the
block are headroom, not program size, until they cross a page.

The block is **1,108 B used of a page-aligned 1,280** now, after the stash, the sort and the in-place
string statements left it. **1,108 − 98 = 1,010, which is under 1,024** — so removing the general path
drops `ObjectBase` `$3c00` → `$3b00` and hands back **512 bytes to every GP program**, object and
workspace floor both.

Nothing about the code changed; check which side of a page a change lands on before costing it, because
that is the whole answer. (The 12 B of vector slots are still in the core, which carries ~40 B of
padding below `GPBase`, and still move nothing.)

**SHIPPED 1st September 2026, as option 2 below.** The selector is a plain numeric scalar
(`compiler/commands/select.asm` refuses an expression or an array element and says why), all four
keywords are markers aliased to `CommandXIfMark` in the core, `gp-runtime/commands/select.asm` is
deleted, and only `GP.DO` opens a stack frame any more — `.unwind` and the FixBranches depth walks
count loops alone. `ObjectBase` `$3c00` → `$3b00`, image 13,311 → 13,055, and a program whose only
GP keyword is a select is now **GP-BASIC OUT** at `RT 12031`, exactly as `GP.IF` already was.
Verified: SELR/SELP/SELQ/SELS/SELBUG/SELN probes, `UNWIND.EXP.BL` (its three selectors now assign
to `UT.SEL` first), `SORT.EXP.BL` 8/8, `STRCTST` 20/20, `ISO.EXP.BL`.

**The first attempt was reverted on FALSE evidence, and the day went to finding that out.** The
headless harness's `readable()` filter kept only printable runs of 4+ characters — built to keep
object bytes out of a compile log, applied to RUN output — so every probe that printed a 2-character
verdict (`B1`, `A0`…) looked like it printed nothing, in exactly the programs whose long-printing
twins passed. The “miscompile” chased for hours did not exist; the p-code dump that proved every
branch correct was what finally pointed back at the harness. Rule: when output LOOKS missing, read
the raw log before reading the compiler.

`GP.DO`'s frame is not the same case and is not a candidate: it holds the loop counter and the return
position, which a counted loop genuinely needs. Only `GP.SELECT`'s is dead weight, and only when the
selector is a plain variable.

Two steps, and they buy different things:

1. **A compile-time fast path.** When the selector parses as a plain numeric variable, emit the
   variable reference directly at each alternative instead of `gp.select`/`gp.case`, and skip the
   frame entirely. Compiler-side, so free against the runtime budget, and it keeps
   `GP.SELECT RND(1)*3` correct on the general path. **This buys speed, not bytes** — both paths
   still have to exist. (Watch the p-code: a variable reference is ~3 B against `gp.case`'s 1, so a
   long alternative list may come out slightly *larger*. Measure before believing it is free.)
2. **Restricting the selector to a variable** — the general path deleted, a volatile selector spelled
   `T = RND(1)*3 : GP.SELECT T` by hand. Only then do the **98 B** and **2 sub-256 opcodes** actually
   come back, and even then as GPB headroom (78 → 176 B) rather than program size.

Related: the same survey found `GP.SELECT` and an `GP.IF`/`GP.ELSEIF` chain within ~3 bytes of each
other on INPHELP's real seven-way dispatch (~75 B against ~78 B), so the two constructs are a
readability choice, not a size one.



## `BMX.INC.BL` wants the `GP.ASM` treatment

**The BMX loader is the last big BASL routine still doing per-byte work in BASIC**, and it is the
one place left where that is measurable to a user: a bitmap is 320×240 at 8bpp, so the paint loop is
counted in tens of thousands of iterations rather than the hundreds a menu or a dialog costs.
Everything else that mattered has already moved — `samples/editor`'s two renderers went to `GP.ASM`
and came back **123× and 109×** faster, and the p-code got *smaller* because the `FOR` loops removed
were bigger than the assembly that replaced them.

The shape is known and is the same one `STASH.INC.BL` and `SORT.INC.BL` use: BASIC works out the
address of a row or a run and the assembly moves the bytes. BMX is a better fit than either, because
the destination is VERA's auto-incrementing data port — a fixed address — so the inner loop is a
`LDA`/`STA` pair with no pointer arithmetic in it at all, and the `FX` 32-bit cache write the editor
uses to flush four bytes per store applies directly.

Not started. Worth measuring `BMXSPD.EXP.BL` before and after, since that sample exists precisely to
say how long a paint really takes.

## GP.ASM `{VAR}` under BASLOAD — DONE, by reading `#SYMFILE`

`{VAR}` reaches a BASIC variable from inside a `GP.ASM` block, and it now does so under BASLOAD,
which is the workflow everything in `GPC-BASIC/` uses.

**The problem was that BASLOAD renames variables and does not rename REM text with them.** It
crunches `N%` to `A%` in the code — that is how it offers 64 significant characters on a two
character BASIC — while the REM carrying `LDA {N%}` is stored byte for byte, which is the very
property that lets an assembly body survive tokenisation at all. The two halves of the feature
wanted opposite things from the same tool.

**`#SYMFILE` is BASLOAD's own record of the mapping, and the compiler reads it.** The source says

```
#SYMFILE "@:PROG.SYM"
```

at the top, named to match the PRG — compiling `PROG.PRG` reads `PROG.SYM`, the convention
`source/gpc/build_basl.py` already followed. Nothing in the syntax changed: `{N%}` is still written
the way the variable was written.

- `BLC_SYMLOOKUP` (api.inc) is the seventh compiler-to-application call.
  `source/application/source/compiler/symfile.asm` does the scanning, because the file name is
  derived from `GPC.INPUT`'s source line and that is an application symbol — the same reason
  `ScanGPUsage` lives there. The two buffers are the compiler's, which the application can see
  because it links the compiler library; the other direction is what breaks the standalone build.
- **The sigil is not in the symbol file** — `PR$` is filed as `PR`, because BASLOAD crunches the
  identifier and the `$` or `%` rides along separately. So one entry serves `N`, `N$` and `N%`, and
  the compiler re-attaches the type itself.
- **The LABELS section is skipped.** Its lines have the same shape but its values are BASIC line
  numbers, so a label could otherwise answer for a variable of the same name.
- **A missing symbol file is detected by the banner, not by the open.** CMDR-DOS opens a file that
  is not there quite happily and only reports it on the first read, so a missing file arrived
  looking exactly like an empty one and was reported as "the name is not in it". Every symbol file
  starts `BASLOAD n.n.n SYMBOL FILE`; that is what is checked.
- Both errors are compiler-only text, in compiler space rather than the shared error table — that
  table is in `common.library`, below `GPBase`, and is copied into every compiled program, so a
  message there would cost every program bytes for a diagnostic only the compiler can print.

Verified on R49 three ways: a BASL program whose `COUNTER%`/`RESULT%` BASLOAD crunched to `A`/`A0`
compiles and prints `COUNTER= 65 / RESULT = 66`; deleting the symbol file gives
`NO SYMBOL FILE FOR {} @ 5` and no object; and a `{VAR}` naming a variable BASIC never used gives
`UNKNOWN VARIABLE IN {} @ 3` and no object.

## Growing the object buffer — DONE, by moving the runtime out of RAM

**12,800 -> 23,296 bytes.** `FreeMemory` `$6D00` -> `$4400`. The compiler is no longer what limits
program size in any mode: every run-side ceiling (18,432 embedded GP-BASIC OUT, 17,664 shared GP-BASIC OUT,
16,384 embedded GP-BASIC IN, 15,616 shared GP-BASIC IN) is now below the buffer, where all four used to be
above it.

**The fix was not the banked-RAM plan this section used to describe.** That plan wanted 22 pages of
*compiler* moved to `$A000-$BFFF`, and its own conclusion was that the bytes are in code, and code
in banks is a whole-compiler audit. The measurement that killed it also replaced it: of the 14,079
bytes of runtime sitting in low RAM through every compile, the compiler *calls* nothing at all in
`runtime.library`, `polynomials.library` or `gp.library` — 10,892 bytes — and referenced them in
exactly **two instructions**, both `gpscan.asm` reading `VectorTable`. The runtime was in RAM only
so that `WriteObjectCode` could copy it into the output file.

So it is a file now. `GPC.IMG.nnn.BIN`, linked at `$0801` by its own pass over the same libraries in
the same order, streamed into `OBJECT.PRG` a page at a time at write time. What changed:

- **Two links** (`source/application/Makefile`). Link one is the image; link two is the compiler,
  taking only `common.library` and `ifloat32.library` — the subset
  `source/unit-tests/compiler-runtime` has linked for years.
- **`genrtimage.py`** is the only thing that crosses between them: `GPBase`, `ObjectBase`, the two
  patch offsets, and `GPUsageBits`.
- **`ScanGPUsage` reads a 32-byte bitmap** instead of the runtime's 386-byte vector tables. It never
  wanted the handler address, only "is it above `GPBase`", which is one bit — computed at build time
  against the image's own linked table, so the question is still asked by address and still follows a
  handler that moves into or out of `gp-runtime/`.
- **`PatchOutCompile` and the in-memory "RUN a second time" path are gone.** They cannot work without
  a resident runtime. That path was a dev convenience with a size ceiling of its own and was already
  parked here as a cleanup; it is now deleted rather than fixed.
- **The image is build-numbered** from the same `rtbuild.txt` stamp as the shared runtime, for the
  same reason: under a fixed name a stale image is still *found*, and produces a program that loads
  and then misbehaves. Numbered, a stale one is absent and the compile stops with `NO RUNTIME IMAGE`
  before `OBJECT.PRG` is created.
- **`10object.divider` fills its own alignment.** A bare `.align 256` emitted nothing once the
  compiler stopped following it — 64tass writes alignment fill only to place the bytes after it — so
  the image came out 78 bytes short and every byte of p-code would have landed at the wrong address.

**Verified**, not just built: the runtime half of a compiled `OBJECT.PRG` is byte-identical to the
image for all 12,031 bytes of the GP-BASIC OUT cut, with the only differences the two patched immediates
(`$00` -> `$37` code page, `$00` -> `$48` workspace), and the object runs.

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

`GPC.PRG` (`source/gpc/GPC.BASL`, BASLOAD source) is the front end: it asks for the two names, writes
the file, and hands the machine over to the compiler.

## Samples

A `samples/` tree of real programs that show off what the compiler buys you, one directory per sample
with its own `readme.md`. `make samples` mirrors the whole tree into `testing/samples/` (the emulator
drive and the root of the release zip), so every sample is runnable in the emulator and ships in the
release; `samples/` is the tracked master and `testing/samples/` is a wiped-and-recopied build
artifact. Three exist:

- **`samples/prg2basload/`** — the X16 ROM BASLOAD detokenizer written as BASLOAD source, whose own
  header measures the win: the 919-line, 17,883-byte paint program converts in 12:22 interpreted and
  1:51 compiled, ~6.7x. The template: a genuinely useful program, plus a readme that names the speed
  number rather than asserting "it's faster".
- **`samples/shared-vars/`** — two programs (`PRG1`/`PRG2`) chained by `LOAD`, sharing variables across
  the chain, compiled in SHARED mode. Built and verified 2026-07-21 (see the findings below).
- **`samples/editor/`** — GPC EDIT, an MS-DOS-EDIT-styled text/Markdown editor whose two renderers are
  inline `GP.ASM`. The speed number it names: a text row 2320 → **18.8** jiffies/1000 renders, a chrome
  field 2538 → **23.3** — a full-screen repaint from ~1.2 s to ~10 ms. Unshelved and shipped 2026-08-30
  (see the findings below).

### Shared-vars sample — findings from building it (verified in emu, R49)

Measured while building `samples/shared-vars/`, worth keeping:

- **Interpreted, variables do NOT survive a program-mode `LOAD` on the X16** (they come back zero/empty).
  This is NOT the old C64 chain behaviour — so the sample is inherently a *compiled-only* demo. This
  contradicts the earlier assumption that CBM chaining preserves variables here; it does not.
- **Compiled, string and numeric *scalars* carry across cleanly** via [[blitz-load-chain]] (runtime keeps
  vars/strings in high RAM ~`$8100`, the loaded program skips its clear on the chain signature).
- **A string ARRAY does not carry.** The loaded program needs a `DIM` to use the array and that `DIM`
  re-initialises it, wiping the carried data; omitting the `DIM` leaves the array with no descriptor on
  the loaded side (crashes/hangs). The sample uses scalars and documents this. Open question if ever
  worth chasing: can an array descriptor be made to survive the chain like a scalar does?
- **Both programs must first-touch the shared variables in the same order** — the compiler assigns
  addresses by first appearance, so a differing order silently misaligns them.
- SHARED-mode compiled programs are tiny (~0.5K each here) because they share one `GPC.RT.nnn.BIN` (~11K).

### Editor sample — DONE, and it closed the prog8 render question

`samples/editor/` (`EDITOR.BASL` + `STORE.BASL`, readme with the measurements). Shelved on branch
`editor-sample` on 2026-07-21 because the perf question driving it was unanswered; unshelved and
finished 2026-08-30, when `GP.ASM` made the answer buildable.

- **It compiled on the current engine untouched.** The shelved source needed no porting — the whole
  cost of bringing it forward was a real `TEST.MD` fixture (the committed one was a stray copy of
  `GPC.BASL`, so the self-check's find assertions were passing over a document with no "bullet" and no
  "markdown" in it) and the move to `samples/`.
- **M5 shipped** — relocated to `samples/editor/`, real sample `.md`, `readme.md` naming the numbers,
  picked up by `make samples`, self-check green (`M4 OK`).
- **The speed fix is `GP.ASM`, not the block-blit command this entry used to recommend.** The old
  recommendation was a native built-in that streams a row buffer to `DATA0`, chosen to dodge inline
  ASM's authoring and ABI hazards. `GP.ASM` shipped first and dodges them by itself, so the block-blit
  command is **not needed** — and it would have cost runtime bytes in every program, which `GP.ASM`
  does not. Measured with both versions in one program (`EDBENCH.BASL`, real speed, loop floor
  subtracted, cells read back and blanked between variants): text row **2320 → 18.8** jiffies/1000
  (123×, ~31 cycles/cell), chrome field **2538 → 23.3** (109×). P-code went *down*, 7190 → 7101
  bytes, and on the assembly alone the program was still `GP-BASIC OUT`.
- **The key dispatch is `GP.SELECT`, and that is what made it `GP-BASIC IN`.** `ED.DISPATCH.KEY` replaced
  an eighteen-deep `IF` ladder; the select is **9 bytes** of p-code, but one core keyword pulls in
  the whole 2 KB GP block — `RT 12031 → 14079`, object 19,134 → 21,647, max p-code 18,432 → 16,384.
  A readability trade, taken deliberately. The two ranged keys (Commodore+letter, printable) live in
  `ED.KEY.RANGE` off `GP.OTHER`, because `GP.CASE` takes a list of expressions and not a range.
  Nothing jumps out of the select: `GP.ENDSEL` releases the selector frame, and the self-check runs
  400 consecutive dispatches to prove none leaks.
- **It is now faster than the editor it was losing to.** prog8's `x16-MSEDIT` real render loop is 67
  jiffies/1000 rows; this is 18.8 — **3.6× faster** — and within 1.4× of the hand-assembled raw-write
  floor of 13, which does no bounds check and no space padding. The cause was settled earlier and is
  written up in `docs/blitz/inline-asm-feasibility.md`: same VERA path both sides, the gap was pure
  codegen.
- **What it cost the compiler: six bytes.** `{VAR}` took letters and digits only, so `{DOC.GOT.OFF}`
  read the name as `DOC` and reported `UNKNOWN VARIABLE IN {}` with nothing pointing at the dot —
  and dotted names are the house style precisely because they dodge BASLOAD's keyword trap.
  `AsmParseBrace` now takes `.` as a name character. Underscore, the other character BASLOAD allows,
  is deliberately still out: what byte it arrives as through PETSCII was never measured.

### Shared-runtime, THREE programs sharing variables — TODO

Extend the two-program `samples/shared-vars/` to **three** programs A→B→C that accumulate state (A sets,
B reads and adds, C prints the total) — the original ask. Same rules as above (scalars, identical
first-appearance order, all compiled SHARED). See [[blitz-shared-runtime]] and [[blitz-load-chain]].

### Ideas for more samples — TODO

Candidates, each meant to demonstrate one concrete reason to reach for the compiler:

- **A benchmark pair** — the same program shipped as `FOO.PRG` (interpreted) and `C.FOO.PRG` (compiled)
  next to each other on the disk, with a one-screen driver that times both off `TI` and prints the
  ratio. `bench/` already has the numbers; this makes them runnable by a user on real hardware.
- **A graphics / demo program** where the interpreter is visibly too slow — something animating with
  `RECT`/`OVAL`/`LINE` or the sprite keywords that stutters interpreted and runs smooth compiled, so
  the speedup is *seen*, not read off a clock.
- **A tight numeric loop** (Mandelbrot, a sieve, a fractal) — the case the compiler helps most, since
  it is all float math and control flow with no I/O to hide behind.
- **Something using the X16 hardware keywords** the compiler now supports (`MOD`, `OVAL`/`RING`, tiles,
  `FMPLAY`/`PSGPLAY`) so the samples double as a living check that those handlers still work.
- **A "convert an old C64/CBM BASIC program and compile it" walkthrough** — feed a tokenised program
  through PRG2BASLOAD to get BASLOAD source, then compile that with GPC. Ties the first sample to the
  rest and shows the whole pipeline end to end.

## To check

### Check GPC.ERR — DONE

`GPC.ERR` (the runtime error decoder; `testing/GPC.ERR.BASL` → `GPC.ERR.PRG`, freshened on release by
`build_basl.py GPC.ERR.BASL GPC.ERR.PRG`) was given a pass. **Both halves check out, and the pass found
a bug in the runtime rather than in GPC.ERR** — see "A runtime error named the line after the one that
failed" below.

- **The `.PRG` is up to date with its `.BASL`.** Rebuilt through BASLOAD under a scratch name: 1949
  bytes both, and the only differing bytes are offsets 1947-1948 — exactly the two nondeterministic
  trailing bytes past the end marker that `build_basl.py` documents.
- **The decoding is right, 16/16**, checked against answers computed independently from the map file:
  a real error address, a whole `<err> @ $XXXX` line pasted in, an address with no `$` sigil, exact line
  starts, the last byte of a line's range, `$0000` (before the first mapped line), and the 65024/65535
  setup-code entries. The boundary pair is the one that matters and it is exact: `$0041` → line 80 and
  `$0042` → line 90 are adjacent bytes across a line edge.

**`-bas` cannot drive GPC.ERR as shipped, and that is a harness limit, not a fault.** Both `GPC.ERR` and
`GPC.PRG` open with `GOSUB CLEAR.KB`, and a `GET`-drain loop eats the *entire* remaining paste — measured,
a 46-character tail after `RUN` vanished completely and the program then waited forever at its first
prompt. `-pastewarp`, and dropping `-warp`, change nothing. To test it headlessly, rebuild the same
`.BASL` with only `CLEAR.KB` stubbed to a bare `RETURN` and drive that; the decode logic under test is
untouched. (`LINPUT` programs such as `testing/MD5` are unaffected — no drain loop.)

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
