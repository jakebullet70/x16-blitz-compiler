---
name: every-scalar-allocated-six-bytes
description: "FIXED 2026-09-20 -- AllocateBytesForType sized every scalar as a float because callers arrived with A=0 from FindVariable; the five sites now pass the real type, GPBMODS 4,322 -> 3,482 bytes"
metadata: 
  node_type: memory
  type: project
  originSessionId: b52e8c4f-ffdf-4b2a-89c7-8a57e0a20a41
  modified: 2026-09-20T13:38:00.677Z
---

**FIXED 2026-09-20, commit 5cb815a.** The five call sites now pass the real type: the three
scalar sites fetch it back with a balanced `pla`/`pha`, and the two array head slot sites pass
`NSSIFloat+NSSIInt16` unconditionally. GPBMODS scalar space measured **4,322 -> 3,482 bytes**,
and it compiles and runs again. The plan is `docs/blitz/SCALAR-ALLOCATION.PLAN.md`. What follows
is the diagnosis as written before the fix.

`AllocateBytesForType` (`source/compiler/source/storage/create.asm`) decides 2 bytes or 6 from
the type bits **in A**: `and #NSSTypeMask+NSSIInt16` then `cmp #NSSIFloat`, and `NSSIFloat = $00`.

Every caller reaches it straight after `FindVariable` returned CC, and that path
(`_IVNotFound`, `source/compiler/source/storage/findvar.asm`) exits with **A = 0** -- the
end-of-list marker the scan loop just read with `lda (zTemp0) / beq`. Zero is NSSIFloat, so the
test always says float.

**So every scalar takes 6 bytes: `%`, `$` and array head slots alike.** The real type is sitting
in X at that moment (`ExtractVariableName` packs first char AND 31 plus type bits into X, and
`_IVNotFound` restores it), so the fix is to get X into A at the call sites. The call sites are
`variables/refterm.asm` (2), `commands/dim.asm` (2) and `commands/select.asm` (1).

MEASURED on GPBMODS 2026-09-20: varspace 4,322 = 720 slots x 6 + 2, against ~700 named variables.
Converting 168 float names to `%` (GUI.INC.BL and MENU.INC.BL, 1,292 edit sites) moved varspace by
**exactly zero**. That is the proof, and it is why the `%` route frees nothing today.

Why it matters beyond the waste: it is half of why GPBMODS broke. See
[[scalar-variable-space-caps-at-4096]] -- the operand only reaches 4,096 bytes, and over-allocating
every int and string at 6 bytes is what pushes GPBMODS to 4,322. Sizing correctly should land it
near 2,900, under the wall with no source change at all.

It also invalidates the byte columns in [[int16-conversion-planned]] and in
`samples/GPB-MODS-TESTING/INT16-HANDOFF.md`: `source/gpc/int16scan.py` models `%` as 2 bytes, which
is what the code intends but not what it does. The conversion is still worth doing -- it just pays
nothing until this is fixed.

The fix is 64tass in the compiler, so it waits on the user: [[ask-before-writing-asm]].
