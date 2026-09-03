---
name: gpasm-blob-may-use-ztemp
description: "A GP.ASM blob CAN use zTemp0/1/2 ($2C/$2E/$30) - SYS already clobbers zTemp0 to reach it, so indirect addressing is available inside inline assembly"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T11:55:14.277Z
---

**Verified 1st September 2026**, by `GPC-BASIC/SORT.INC.BL`, which uses all three as live pointers
through an entire shell sort and passes eight assertions including a 200-element array.

**`zTemp0 $2C`, `zTemp1 $2E`, `zTemp2 $30` are FREE inside a `GP.ASM` blob.** The blob is reached
through the SYS handler (`source/runtime/source/commands/sys.asm`): it loads the blob's address into
`zTemp0` and does `jsr` / `jmp (zTemp0)`. By the time your first instruction runs that indirection
has already happened, and nothing on the way back out — `php`, the `SYS_Reg_*` stores, `ply`/`plx`,
`.exitcmd`, `NextCommand` — reads any of the three again. They are per-command scratch and a blob
runs inside a command. `NextCommand` uses only `codePtr` and Y.

**This matters because it is the difference between `(ptr),y` and self-patching.** Without zero page
every indirect read has to go into the operand of the instruction that performs it — the
`STA LBL,X` with `X=1`/`X=2` idiom — which is ~12 bytes and has to be redone whenever the pointer
changes. With it, a routine that walks pointers (a sort, a linked list, string blocks) is a straight
transliteration of ordinary 6502.

**What is genuinely NOT free**: `codePtr $22`, `objPtr $24`, the number stack (X) and the
`NSMantissa*` / `NSStatus` slots. SYS restores X and Y around the call, so those two registers are
yours; A is loaded from `SYS_Reg_A` on the way in.

**Also: `CLD` first, in any blob that does arithmetic.** SYS enters with the processor status `plp`'d
from `SYS_Reg_S`, which holds whatever a previous `GP.CALL` left there. One stray decimal flag and
every `ADC`/`SBC` address is wrong.

**`STASH.INC.BL`'s header says the opposite** — "the assembly needs no zero page at all, which
matters because there is none to have". That was written cautiously and is wrong; it is not worth
rewriting, since the module works and its BASIC-computes-the-address split is a good design on its
own merits. But do not take it as the rule.

Related: [[gpasm-implementation-status]], [[gpasm-inline-assembly-research]],
[[gpc-blitz-runtime-slack-and-limits]].
