---
name: pcode-runs-from-a-bank-proven
description: "PROVEN 2026-09-05 on the machine: GPC p-code executes from $A000-$BFFF. Two GP.ASM blobs, no compiler or runtime change; and RETURN out of a bank needs no bank restore"
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-05T14:37:51.632Z
---

**GPC p-code executes from a RAM bank.** Proven on x16emu R49 with `samples/GPB-MODS-TESTING/SPIKE.BASL`,
which changes nothing: no ABI change, no runtime change, no compiler change, two `GP.ASM` blobs and
a copy loop.

**The method, and it is the design in miniature.** `GOSUB SPIKE.CAPTURE` runs `SPIKE.MARK = 111 :
RETURN` in low RAM, after a blob records `codePtr + Y` -- which IS the address of that statement,
because `CommandSYS` leaves Y pointing at the next p-code byte. 64 bytes are copied from there into
bank 7 at `$A000` with the literal `111` changed to `222`. `GOSUB SPIKE.JUMP`'s blob selects the
bank and points `codePtr` at `$A000`. The copy runs and `RETURN`s. `MARK` comes back **222**, which
only the bank copy can produce.

```
T1 LOW RAM MARK 111   T2 SOURCE AT 2714   T3 PATCHED 1   T4 BANK MARK 222
```

**THE RETURN PATH NEEDS NO BANK RESTORE**, and this is the simplification worth keeping. `RETURN`
pops the frame the entering `GOSUB` pushed and puts `codePtr` back in LOW RAM -- below `$A000`,
where banking does not apply. The bank only matters while `codePtr` is inside the window. A bank
byte in the GOSUB frame is therefore about re-entering a banked routine, not about leaving one.

**What the blobs need, measured:**

- `codePtr` is at **`$28`**; `objPtr` `$2A`, `zTemp0` `$2C`, `zTemp1` `$2E`, `zTemp2` `$30`
  (`common.inc` zeropage section, confirmed in `runtime/build/code.lbl`).
- **`CommandSYS` restores Y from the 6502 stack after the blob**, so a blob cannot set Y by loading
  it -- it must write the SAVED copy. At blob entry the handler has pushed X, then Y, then the JSR
  return, so **the saved Y is at `$0103 + S`** (`tsx`, then `sta $0103,x`). X sits at `$0104 + S`.
- A `GP.ASM` blob called FROM banked p-code works unchanged: the blob pool is appended at the object
  tail in low RAM and the `.word` operand is absolute.

**The stack offset is the fragile part** and is why this is a spike and not a shipped mechanism. It
depends on `CommandSYS`'s exact prologue. The shipped version wants a real opcode instead -- see
`TODO.md`, *How much of the GUI library fits in a bank?*, and `samples/GPB-MODS-TESTING/PLAN.md` §6.

Gate cleared beforehand: [[kernal-preserves-ram-bank]]. Related: [[gpasm-blob-may-use-ztemp]],
[[gpasm-implementation-status]], [[gpc-return-unwinds-frames]].
