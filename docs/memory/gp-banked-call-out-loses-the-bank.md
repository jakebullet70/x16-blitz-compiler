---
name: gp-banked-call-out-loses-the-bank
description: "Code in a GP.BANKED region cannot call a routine in ANOTHER bank and survive the return -- the shim leaves the callee's bank selected and a region may not contain BANK to put its own back."
metadata:
  type: project
---

**The rule for a program with more than one code bank.** A `LIB.GUIBANK`-style shim is
`LABEL: BANK CODEBANK : GOSUB LABEL.BODY : RETURN`, and it deliberately does **not** restore the
caller's bank -- `LIB.GUIBANK.INC.BL` says why: a single holding variable would be overwritten by a
nested call and the outer one would put back the wrong bank.

That is harmless when the caller is in **low memory**, which does not care which bank is selected.
It is fatal when the caller is in a **region**: control returns to $A000+n with the callee's bank
selected, and the next instruction is fetched from the wrong bank.

**And the caller cannot fix it itself**, because the compiler refuses a `BANK` statement inside a
region. There is no `GOSUB X : BANK MY.CODEBANK` to write.

So, for any second region:

- **region -> low memory** is fine, as long as the low-memory routine leaves the bank alone.
- **region -> another region** is out, by two separate mechanisms: directly the compiler refuses it
  (both run at $A000, the branch has no distance, `NOT IMPLEMENTED`), and through a shim the return
  lands under the wrong bank.
- So **a routine that calls the GUI cannot itself be banked** unless it is in the GUI's own bank.

This is what stopped the FILES panel in `GPBFILES.BASL` from being banked: it calls `GUI.SAY`,
`GUI.LISTBOX` and `GUI.INPUT`, so it has to stay in low memory whatever else moves.

See [[gp-banked-region-relocation]] and [[filedir-bank-split]].
