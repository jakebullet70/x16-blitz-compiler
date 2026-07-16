---
name: blitz-x16-runtime-footprint
description: The runtime is 10,956 B copied verbatim into every compiled program (VM+handlers 7.3K, ifloat32 2.3K, polynomials 0.9K); ~2x the C64 Blitz runtime (est. ~5.8K) because we bundle our own 32-bit float+transcendentals (~3.2K) and ~2K of X16 hardware handlers. The size counterpart to the speed yardstick.
metadata:
  type: project
  originSessionId: e067067c-f194-41ca-978d-951f2d4c1c2e
---

The **size** counterpart to [[blitz-c64-benchmark-yardstick]] (which is about speed). Every number
below was measured from `source/application/build/code.lst` and then adversarially re-verified from
primary sources (build listings, the D64 images) before saving.

## What ships in every program

The runtime is **one pre-linked image copied VERBATIM** into every `OBJECT.PRG` — `object.asm`
`WriteObjectCode` "Part one" streams `$0801`→`ObjectBase` ($3300) and touches only **3 sites (5
bytes)**: `PatchOutCompile` NOPs the 3-byte `JMP CompileCode` at `$0815` (so a reloaded copy runs the
runtime, not the compiler), then two streamed immediates — the code page (always `$33`) and the
workspace page (the one byte that varies per program). There is **no per-program dead-code
elimination**: `10 PRINT"HI"` ships the sprite engine, the disk loader and the transcendental library
it never calls. So shrinking anything means changing the image and lowering `ObjectBase` at *build*
time — never a per-program edit. **Total 10,956 bytes:**

| Component | Bytes | Share |
|---|---:|---:|
| `runtime.library` — P-code VM + 158 handlers + dispatch | 7,288 | 66% |
| `ifloat32` — 32-bit float arithmetic + number↔string conversion | 2,349 | 21% |
| `polynomials` — transcendentals (SIN/COS/TAN/ATN/EXP/LOG/SQR/`^`) | 860 | 8% |
| `common` — error vectors | 415 | 4% |
| BASIC stub (`SYS 2069:REM GPC!`) | 44 | 0.4% |

Inside `runtime.library`, ~1.15K is dispatch overhead — fixed **only as long as all handlers ship**
(drop a handler under selective inclusion and its slot + glue go too): the two dispatch tables hold
**158 slots (92 command in `VectorTable` + 66 shift in `ShiftVectorTable`) × 2 = 316 B**, per-handler
`.entercmd`/`.exitcmd` glue is `plx` + `jmp NextCommand` = 4 B × ~158 ≈ 632 B (`runtime.inc`, measured
634), and the `Link…` math trampolines ~207 B (`links.asm`). The rest is the handlers.

**Key enabler for shrinking:** emitted p-code addresses commands by **token → `VectorTable`**
(`00runtime.asm` `jmp (VectorTable,x)`), never by handler address, and branches use **offsets**. The
object code is already decoupled from runtime layout — the compiler knows what a program uses.

## Why the C64 Blitz runtime is ~half (est. ~5.8K)

The **exact, direct** comparison: C64 Blitz compiles `DIR` to **6,244 B** (`demo-c64/utils.d64`
`C/DIR`); our own build of the same program (`release/C.DIR.PRG`) is **10,992 B** — **0.57×**
(whole compiled program, not runtime-only). Subtracting the compiler's runtime-less intermediate
(`Z/DIR`, 444 B — the "scratch" file the [[blitz-c64-benchmark-yardstick]] method note names)
**estimates** the embedded C64 Blitz runtime at **~5.8K** — a rough difference, *not* a byte-exact
extraction (`Z/DIR` is not a substring of `C/DIR`). ~5–6K is the right ballpark, and it is ~half ours
(runtime-to-runtime ≈ 1.9×) for two reasons, both deliberate choices here, not C64 cleverness:

1. **C64 Blitz calls the C64 ROM for math.** Disassembling the C64 `BLITZ` binary shows calls to ROM
   `FOUT $BDDD` (float→string), `FIN $BCF3` (string→float), `ROUND $BC1B`, `MOVFA $BBFC`, and KERNAL
   I/O (`CHROUT $FFD2`…) — and it bundles **no** float library. (The compiled `C/DIR`, which embeds the
   runtime, makes the same ROM/KERNAL calls while the runtime-less `Z/DIR` makes none — so those calls
   live in the *runtime*, not just the compiler.) We spend **~3.2K** (`ifloat32` + `polynomials`) on a
   custom 32-bit float — a design choice over the X16 ROM's own 40-bit FAC floats (present in bank 4,
   where compiled code already runs); the rationale is speed, evidenced in
   [[blitz-c64-benchmark-yardstick]], not in this size analysis.
2. **C64 BASIC V2 has no graphics/sprite/sound keywords** (VIC/SID via PEEK/POKE), so C64 Blitz has no
   such handlers. We add X16 hardware handlers a text program never calls: sprites 463, FM/PSG sound
   328, VERA graphics 280, loadsave 242, tiles 244, mouse 107, plus vpoke 70 / i2c 60 / open 45 / joy
   47 / reset 35 — **~1.9K enumerated** (~2.3K counting every X16-only handler).

`~3.2K + ~2K ≈ 5.2K` — essentially the whole gap between ~11K and ~5.8K.

## Levers to shrink it (see TODO.md "Shrinking the runtime")

- **Selective handler inclusion (graphics-less etc.)** — ship only the handlers a program's tokens
  reference. ~2K of hardware handlers is droppable for a text/math program, but they sit mid-image, so
  it needs either dead-slot-stub (reclaims nothing) or a relocating link. Tractable form: group optional
  handlers at the image tail so an unused group truncates with `ObjectBase` lowered — no relocator.
- **X16 ROM floats** — call the ROM's 40-bit BASIC floats instead of bundling `ifloat32`+`polynomials`
  (~3.2K **gross**). Big rewrite, and the **net** saving is less than 3.2K: the whole compiled ABI runs
  on the custom 12-deep zero-page number stack, so every op would need FAC1/FAC2 marshalling code added
  back. The format change also moves numeric results (re-baseline `f.cmp`) and drops the integer-exact
  fast paths. The size-for-speed trade, inverted.
- **Cheap first step both want** — `polynomials` (860 B) and the `VAL`-only string→float parser (~518 B)
  already sit at the image TAIL ($2f71→$3300 is all `FloatSine`/`Cosine`/`Exponent`/`Logarithm`/coeff
  tables). A program with no `SIN`/`COS`/`^`/…/`VAL` can ship a runtime truncated below them — no
  relocation. ~1.4K, and it builds the conditional-runtime machinery the two big items need. Requires
  conditional generation of `vectors.asm`/`links.asm`/`pi.asm` (repoint dropped slots to a range stub,
  inline PI's constant); dead `FloatPI` (8 B) can go too.

Dependencies verified: `polynomials`→`ifloat32` is one-way (never reverse), so transcendentals drop
cleanly; float→string (~475 B, PRINT/STR$) is near-universal and stays; the VM stores **all** numbers as
iFloat32 so core arithmetic can never be dropped. Related: [[blitz-x16-build-setup]] (memory layout /
`ObjectBase`), [[blitz-c64-benchmark-yardstick]] (speed).
