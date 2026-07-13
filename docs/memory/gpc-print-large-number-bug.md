---
name: gpc-print-large-number-bug
description: "RESOLVED — PRINT of any number >=32768 crashed with ?ILLEGAL QUANTITY; cause was op_printi's range-checked float->word cast for the testbench mailbox"
metadata: 
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

RESOLVED 2026-07-08. Symptom: a GPC-compiled program `PRINT`ing any number >= 32768 (or < -32768)
crashed with `?ILLEGAL QUANTITY ERROR IN <curlin>` and produced NO output for that number. Surfaced via
`demo/DIR.PRG` (`c.dir.prg`): it printed every directory entry then died on the trailer line
`65535 BLOCKS FREE.` — the HostFS "blocks free" count is 65535 ($FFFF) > 32767. Native BASIC prints it
fine, so this was a real compiler bug (a compiler must run like BASIC, just faster). The `IN 10` in the
error is a red herring: it's the leftover `curlin` from the debranded `10 SYS ..` stub — the ROM error
handler read it when a ROM routine the VM called threw.

**Root cause:** `op_printi` (src/runtime/vm.p8) did `last_printed = stack[sp] as word` BEFORE printing.
Prog8's `float as word` / `as uword` casts on cx16 are **range-checked by the ROM and JMP to the BASIC
error handler (ILLEGAL QUANTITY) when the value is outside the signed/unsigned 16-bit range** — a warm
start that never returns into the VM loop. `last_printed` is a **testbench-only** mailbox convenience
(headless numeric asserts), yet its cast crashed real PRINT output. FOUT itself handles the full float
range; only that cast was the problem.

**Fix:** guard the cast — `if pv >= -32768.0 and pv <= 32767.0 { last_printed = pv as word } else {
last_printed = 0 }`, then `print_float(pv)`. The bound is provably throw-free: a float <= 32767.0 can't
round up to the 32768 throw threshold, and >= -32768.0 can't round below -32768. Out-of-word-range
values leave the mailbox 0 (no test inspects it for those — they assert printed TEXT via EMU_CHROUT).
Corpus stayed green: the largest mailbox value the suite asserts is $04b0=1200, and any test needing a
mailbox >= 32768 would already have been crashing, so none exist.

**General trap (applies project-wide):** any `float as word|uword` in vm.p8 is a latent ILLEGAL QUANTITY
if the float can exceed 16-bit range. Audited the rest: POKE/PEEK/SYS/WAIT address casts, MID$ start,
array subscripts, and AND/OR/NOT (`as_bits`) all either stay in range for valid programs or throw exactly
where CBM BASIC also throws (correct). `op_ftoi` (the `%`-int coercion, e.g. `A%=40000`) still throws,
but that only fires for `%` vars and CBM V2 also errors on out-of-range integer-var assignment, so it's
defensible; left as-is. Pure-float V2 programs (no `%`) never emit FTOI, so `op_printi` was the only
false crash. See [[gpc-x16basic-look-act]] (the same "run/look like BASIC" directive) and [[gpc-project]].
