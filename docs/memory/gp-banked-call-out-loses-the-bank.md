---
name: gp-banked-call-out-loses-the-bank
description: "A region may not contain BANK, and a call through a BANK shim returned under the wrong bank. Since 2026-09-13 every GOSUB/GP.SUB/GP.FN/FN into a region is a compiler-emitted .bgosub and the library shims are deleted."
metadata:
  type: project
---

**Changed 2026-09-13 (uncommitted):** a direct call into a region from outside it is now a
`.bgosub`, which selects the region's bank and makes `RETURN` restore the caller's. See
[[compiler-emitted-bank-switch]]. Step 3 deleted the library's shims the same day, so what is
below holds only where a shim is still used (XBASE).

**The shim problem.** A `SHIM.GUIBANK`-style shim is
`LABEL: BANK CODEBANK : GOSUB LABEL.BODY : RETURN`, and it deliberately does **not** restore the
caller's bank -- `SHIM.GUIBANK.INC.BL` says why: a single holding variable would be overwritten by a
nested call and the outer one would put back the wrong bank.

That is harmless when the caller is in **low memory**, which does not care which bank is selected.
It is fatal when the caller is in a **region**: control returns to $A000+n with the callee's bank
selected, and the next instruction is fetched from the wrong bank.

**And the caller cannot fix it itself**, because the compiler refuses a `BANK` statement inside a
region. There is no `GOSUB X : BANK MY.CODEBANK` to write.

So, for any second region:

- **region -> low memory** is fine, as long as the low-memory routine leaves the bank alone.
- **region -> another region, called directly** now works (`.bgosub`).
- **region -> another region, through a shim** still returns under the wrong bank.
- **GOTO region -> another region** is still refused with `NOT IMPLEMENTED`.
- So, where a shim is still used, **a routine that calls through it cannot itself be banked** unless it is
  in the GUI's own bank.

This is what stopped the FILES panel in `GPBFILES.BASL` from being banked: it calls `GUI.SAY`,
`GUI.LISTBOX` and `GUI.INPUT`, so it has to stay in low memory whatever else moves.

See [[gp-banked-region-relocation]] and [[filedir-bank-split]].
