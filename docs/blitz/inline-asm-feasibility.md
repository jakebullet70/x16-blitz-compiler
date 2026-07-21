# Inline assembly in GPC — feasibility note

**Question:** can GPC gain an inline-assembly escape hatch so a BASLOAD program can drop hot loops to
native 6502 speed without leaving the language?

**Verdict:** yes, mechanically it is a good fit. The runtime already jumps to arbitrary machine code,
the code generator is one-line extensible, a variable-length byte-blob operand type already exists, and
bytes embedded in the p-code stream need **no relocation**. The real cost is not the compiler plumbing
— it is the *authoring pipeline* (no assembler on the X16 itself, and the tokeniser can't mint a new
keyword for free) and the *ABI for sharing BASIC variables* (custom 6-byte float, dynamically-based
variable storage). This note is source-verified against the compiler tree; file references are given
so the next person can start from the code, not from this prose.

## What GPC actually is (this shapes every answer)

GPC is a **Blitz-style bytecode compiler**: it turns tokenised X16 BASIC into a stack-based p-code plus
an ~11 KB 6502 runtime that interprets it. It is **not** a native-code compiler and **not** an
interpreter copied into the output — it is a bytecode VM.

- Runtime VM main loop: `NextCommand`, `source/runtime/source/main/00runtime.asm:77-176` — fetch a byte
  via `(codePtr),y`; `$80+` is a command → `jmp (VectorTable,x)`; `0-63` push a short constant; `64-119`
  load/store a variable; `120-127` indirect. Handlers open with the `.entercmd` macro and close with
  `.exitcmd` (`jmp NextCommand`), `source/.../runtime.inc:13,17`.
- P-code encoding is documented in `source/common-scripts/pcode.py:145-170`; the byte→handler map is
  `source/runtime/source/generated/vectors.asm` (`$b0 → CommandPOKE`, `$cea2 → CommandSYS`; `$ce` is a
  shift prefix for a second table bank).
- Compile-time is table-driven: each `commands.def` row compiles to `<len><token-lo><token-hi><action
  nibbles>` and `GeneratorProcess` (`source/compiler/source/generation/generator.asm:22`) runs the
  nibbles through `GeneratorExecute`'s vector table (`.../genexec.asm:47`). Nibble `3` runs an arbitrary
  compile-time generator — the `X:CommandXXX` routines in `source/compiler/source/commands/*.asm`.

Concretely, `POKE $9F25,64` compiles to `<push $9F25> <push 64> $B0` (`commands.defc:89-91`); at runtime
`CommandPOKE` (`source/runtime/source/commands/poke.asm:21-37`) pops the byte then the address and calls
`XPokeMemory`. That per-byte fetch-decode-dispatch, over 6-byte float operands, is the cost native code
would remove.

## Why it is mechanically a good fit

1. **The jump-to-arbitrary-code hatch already exists.** `SYS` compiles to `<push addr> $CE $A2`; runtime
   `CommandSYS` (`source/runtime/source/commands/sys.asm:21-54`) loads the CBM register block
   `$30C-$30F` into A/X/Y/P and does `jmp (addr)` — effectively a JSR, since the return address stays on
   the 6502 stack, so a plain `RTS` returns to the VM. `USR(n)` does the same via `$311`
   (`.../functions/number/usr.asm`). Neither *emits* code — the machine code must already be resident.
2. **Code-gen is one-line extensible.** A new keyword is one `commands.def` row + one generator + one
   `VectorTable` slot. A **variable-length byte-blob operand already exists**: `.string`/`.data` use size
   `$FF` in `MOFSizeTable` (`pcode.py:52-53`), exactly the machinery an "emit N literal bytes" op needs.
3. **No relocation for in-stream bytes.** The object is copied verbatim to its run address and `codePtr`
   points straight at it (`source/runtime/source/main/00runtime.asm:30-72`), so bytes embedded in the
   p-code stream sit at an address the VM already holds (`codePtr`+`Y`) and can execute **in place**.

## The catch that decides whether it is worth it

A per-cell ASM *stub called through the VM* still pays the dispatch tax on every call — you gain almost
nothing. To reach native speed you must host the **whole hot loop** (ideally the whole row render) in
ASM, so the loop touches VERA and the BASIC variables directly. That raises the bar to the variable ABI:

- A scalar is a **6-byte iFloat32** (`NSStatus, NSMantissa0..3, NSExponent`,
  `source/ifloat32/source/data.inc:41-61`); `%` integers are 2 bytes; strings are a 2-byte pointer.
  When `NSExponent == 0` the mantissa bytes are a plain 32-bit little-endian integer, so **integer in/out
  is trivial**; float in/out means understanding iFloat32.
- Variables are allocated 6 bytes (float) / 2 bytes (else) by `AllocateBytesForType`
  (`source/compiler/source/variables/create.asm:98-116`), and the load/store op stores the variable's
  **halved** offset (`.../readwrite.asm:22-55`); at runtime `address = variableStartPage:00 + offset`.
  **`variableStartPage` is patched per build** (different for self-contained vs shared), so ASM cannot
  hard-code a variable's absolute address — it goes through the value stack or reads the base page.
- The VM owns zero page and the registers: `codePtr`, `zTemp0..2`, and the 12-deep `NS*` value stack are
  live; **X = value-stack pointer, Y = codePtr offset**. Inline ASM must save/restore precisely and
  return through `NextCommand`, or it corrupts the VM.

## The two hard parts (neither is the compiler)

1. **No assembler on the X16 itself.** The host build uses 64tass; the compiler running on-device has no
   assembler and its input is tokenised BASIC. You hand-assemble hex, assemble host-side, or build a mini
   assembler in. This is the biggest lift.
2. **The tokeniser gates new syntax.** A brand-new `ASM` keyword must be a token the front end actually
   emits — you can't invent one for free; overload an existing keyword, or carry bytes inside a
   `REM`/`DATA` directive and re-parse.

## Two implementation paths

- **Option A — convention only, works today, zero engine change.** Assemble a routine host-side (or by
  hand), make it resident (POKE from `DATA`, or `BLOAD`), and `SYS` to it (args via `$30C-$30F`). The
  program manages the memory. This is enough to *measure* whether native code closes the gap before
  committing to a language feature.
- **Option B — a real inline-bytes directive.** Add one `commands.def` row for an `ASM`-style keyword
  whose generator parses hex and emits a new variable-length op `PCD_INLINE <len> <bytes…>`, plus one
  `VectorTable` + one `MOFSizeTable` entry (size `$FF`). The handler computes the in-stream address
  (`codePtr`+`Y`), `JSR`s to the bytes in place, advances `Y` past `len`, and `jmp NextCommand`.
  Variables reach the ASM via the value stack, or the generator resolves a named variable to its offset
  and emits it as an immediate the ASM adds to `variableStartPage`.

## Option A, measured

To ground the "native would be faster" claim, a native char+attr row-render (assembled with 64tass,
POKEd into golden RAM `$0400`, entered by `SYS`, looping internally) was benchmarked against the
GPC-compiled row renders in the **same** compiled program, same `TI` clock, real speed, `RP=1000` reps
of an 80-cell row (`scratchpad` `nrow.asm` / `BENCH5`):

| render of one 80-cell row | jiffies / 1000 rows | per 100 | vs native |
|---|--:|--:|--:|
| **native char+attr (SYS'd 6502)** | **13** | 1.3 | 1× |
| GPC char+attr, same algorithm | ~800 | 80 | **~62× slower** |
| GPC FX-text (GPC's fastest) | ~480 | 48 | **~37× slower** |

The native output was VPEEK-verified correct (cell = char 65 / attr 1), so this is a real render, not an
empty loop. The native number is also physically sound: ~21 cycles/cell × 80,000 cells ≈ 1.71M cycles ≈
12.8 jiffies at 8 MHz. GPC's ~1300 cycles/cell is the per-cell VM cost — two `POKE`s per cell, each a
push-float-address / push-float-value / dispatch / `XPokeMemory`-with-bank-save-restore.

**What this does and does not settle.** *Measured:* native row-render is ~37× GPC's best compiled
render, so the render cost is almost entirely per-cell VM dispatch, not the VERA write path (we already
matched the fast VERA path in the editor). That strongly supports the standing *hypothesis* that GPC's
P-code dispatch — not the VERA method — is why its render trails prog8's native MSEDIT. It does **not**
fully close it: prog8's MSEDIT itself was not profiled here, and this routine is a clean char+attr row,
not MSEDIT's exact render. The remaining step to prove the causal claim is to measure MSEDIT directly.

First hazard, learned the hard way: the very first attempt POKEd this routine to `$0400` and used
zero-page `$FB/$FC` from inside a **compiled** program, and it crashed (PC ran wild to `$B438`) — the GPC
runtime owns that zero page and its workspace sits low. The working version touches **no** zero page
(counter in absolute RAM in the blob) and was hosted from interpreted BASIC where `$0400` is free. That
is exactly the ABI discipline Option B's design must enforce for the programmer.

## Recommendation

Do Option A first (it needs nothing new) and read the number above. If native decisively beats GPC's
best compiled render, Option B is a modest, well-scoped engine change worth building; the assembler /
authoring story is the part that needs the most design thought, not the VM plumbing.
