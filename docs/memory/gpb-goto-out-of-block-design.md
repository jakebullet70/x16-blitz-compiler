---
name: gpb-goto-out-of-block-design
description: "BUILT 2026-08-31 - a plain GOTO may leave a GP.DO with the frame closed, zero runtime bytes; since 01/09/26 GP.SELECT has NO frame at all"
metadata: 
  node_type: memory
  type: project
  originSessionId: b55260da-8747-488d-aedc-fab566bdcc78
  modified: 2026-08-30T19:47:38.809Z
---

**SUPERSEDED IN PART 2026-09-01: `GP.SELECT` no longer opens a frame at all.** Its
selector is now a plain numeric variable each `GP.CASE` re-reads, all four select keywords
are core markers, and `.unwind` plus both FixBranches depth walks count `GP.DO`/`GP.LOOP`
only — a GOTO out of a select needs no unwinding because there is nothing to close.
`UNWIND.EXP.BL` still proves both halves. Everything below stays true for `GP.DO`, which
is the one block frame left.

**BUILT 2026-08-31.** Designed 2026-08-30; the design below is what shipped, with one change. The user wants a plain `GOTO` to be legal
anywhere inside `GP.DO` / `GP.SELECT` and leave the frame clean. Today `GP.ENDSEL` /
`GP.LOOP` are what release the frame, so jumping past them leaks one per pass — a select
frame is 7 bytes against a 4 KB frame stack, so **~585 leaks to OUT OF MEMORY**, which in a
key loop is 585 keystrokes.

**The answer is ZERO runtime bytes.** Nothing new in the runtime, no vector slot, nothing in
the 2 KB GP block. Three opcodes that already exist do the whole job:

| opcode | p-code | already does |
| --- | --- | --- |
| `.exitdo` | 3 B | closes the innermost `FRAME_LOOP` **and everything above it**, then branches to a `FixBranches`-patched offset |
| `gp.endsel` | 1 B | closes the innermost `FRAME_SELECT` **and everything above it**, falls through |
| `gp.other` | 1 B | a real no-op (`plx / jmp NextCommand`) — the padding |

Verified in `pcode.py`: only `.goto` and `.exitdo` carry operand bytes; `gp.endsel`,
`gp.other`, `gp.do`, `gp.select` are bare 1-byte opcodes.

Two properties make it work, and they are the whole trick:

- **`StackFindFrame` discards everything above the frame it lands on** (`stack/frames.asm`),
  so one `.exitdo` sweeps every select and stray `FOR` between it and the loop frame. Nothing
  has to count strays.
- **`.exitdo`'s operand is a `.goto`-shaped branch offset filled in by `FixBranches`**, so it
  can be pointed anywhere — *including at another `.exitdo`*. That is what makes the chain
  possible:

```
        .exitdo  -> L1      ; inner GP.DO + every select above it
L1:     .exitdo  -> target  ; outer GP.DO, landing on the GOTO's destination
```

Selects with no enclosing loop to anchor on: one `gp.endsel` each, falling through, then the
`.goto`. The last hop goes straight to the target, so a trailing `.goto` is often not needed.

**What has to be built — all compiler, and the constraint that shapes it:** `FixBranches`
**patches in place** and cannot insert bytes without moving every address after it. So slots
are reserved when the `GOTO` is compiled:

1. At `GOTO`, emit one closer placeholder per enclosing block. The compiler already tracks
   block nesting (that is what raises `BLOCK MISMATCH`) and knows each enclosing block's
   *type*, which is all that is needed to size the slot — 1 B for a select, 3 B for a `GP.DO`.
   What it does not yet know is whether the target is inside or outside each one.
2. Record the open-block stack at each line start so the fixer can look up the target's. This
   is where the forward/backward `GOTO` distinction dissolves — the fixer sees the whole
   program, so a forward target is no harder than a backward one.
3. In `FixBranches`, compare the block stack at the `GOTO` with the one at the target. Blocks
   the target is *outside*: activate the placeholder, chain its offset to the next hop. Blocks
   the target is still *inside*: blank the placeholder to `gp.other` — 1 byte, or three of
   them for an unused `.exitdo` slot, since `gp.other` takes no operand and pads exactly.

`GP.EXITDO` keeps working unchanged; it becomes the case where the target happens to be past
the matching `GP.LOOP`.

**A dead end, recorded so it is not re-proposed:** `GP.EXITSEL` (the structured twin of
`GP.EXITDO`) does **not** solve this — it exits to just past `GP.ENDSEL`, which is not a GOTO
to an arbitrary target. Also rejected: self-healing reuse-on-entry at the opener (the
`ReuseForFrame` trick from `49195f6` that makes `GOTO` out of a `FOR` safe). It needs a
construct id in the select frame and a ~60-byte shared walker — about 79 bytes against the 78
free in the GP block, i.e. one instruction from costing every GP IN program 256 bytes.

Related: [[gpc-blitz-runtime-slack-and-limits]], [[gpb-block-if-design]],
[[gpb-block-openers-must-not-defer]], [[answer-the-question-asked]].

## As built (2026-08-31)

**The chained-`.exitdo` plan did NOT survive, and the reason is worth keeping.** Emitting a bare
`gp.endsel` as an unwind breaks `_FBCaseScan`, which counts select nesting **on**
`gp.select`/`gp.endsel` — an extra one inside a case body captures that body's own `.caseend` and
sends it to the wrong place. The unwind must be a token the scanners do not count.

**So: one new opcode, `.unwind <count>`**, 2 p-code bytes, emitted by `CommandGOTO` in front of any
GOTO compiled at block depth > 0. `FixBranches` fills the count in: it keeps a running block depth
over its own walk (`_FBBlockDepth`), and for each `.unwind` it reads the following GOTO's line
number, `STRFindLine`s it, and re-walks from the object start counting depth at the target. The
difference is the count. Handler closes that many `FRAME_LOOP`/`FRAME_SELECT` frames, discarding
strays without counting them, stopping at `$FF`.

**Measured cost: ZERO runtime bytes after all.** `RT 12031` GP-BASIC OUT and `RT 14079`
GP-BASIC IN, both unchanged — the vector slot came out of the core's ~40-byte cushion and the
handler out of the GP block's 78-byte padding. What it DID cost: **`FreeMemory` `$4700` -> `$4800`,
so max program size 22,528 -> 22,272**, and 2 p-code bytes per GOTO that is inside a block.

**Four traps, each of which cost a build:**

1. `blockDepth` went in the compiler's `storage` section, which is **uninitialised RAM**. It has to
   be `stz`'d in `compiler.asm`'s start-up or every GOTO emits an unwind it does not need.
2. **`NXCommand` consumes the opcode byte before dispatching**, so on entry to a handler `Y` ALREADY
   points at the first operand. A leading `iny` reads the byte after the operand and desynchronises
   everything downstream.
3. Growing the `FixBranches` dispatch pushed `beq _FBFixVarSpace` and its `bra _FBNext` out of
   branch range. That file already carries trampolines (`_FBExitDoFar`) for exactly this.
4. The compiler library **cannot name `FreeMemory`** (application symbol). To rewind `objPtr` to the
   object start, call `BLC_RESETOUT` again — `_CAResetOut` is a pure `.set16` with no side effects.

`RT_ABI` 21 -> 22, because the vector table changed shape.

Regression test: `GPC-BASIC/UNWIND.EXP.BL`, and its counts are the proof — 1200 passes leaking one
7-byte frame each would have died at ~585, so reaching the end IS the assertion. It also pins that
**one-line `GP.CASE 29 : GOSUB X` works**, which it always did.

