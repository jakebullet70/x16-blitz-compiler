# Two files per module: `X.INC.BL` and `X.BANK.INC.BL`

Some modules come in two forms. Same code, same public names; the only difference is how a
caller reaches the entry points.

| file | entry points | needs | costs |
| --- | --- | --- | --- |
| `X.INC.BL` | `THEME.SELECT:` | nothing | nothing — one `GOSUB`, straight in |
| `X.BANK.INC.BL` | `THEME.SELECT.BODY:` | `SHIM.*BANK.INC.BL` above the region | a shim per entry point, plus a bank select and a restore on every call |

**Include one or the other, never both.** Both define the same module, so BASLOAD either takes
whichever it reads first and silently ignores the second, or stops with `DUPLICATE SYMBOL` where
the module has no `#IFNDEF` guard. Neither is a diagnosis.

## Which one

`X.INC.BL` is the default. Use it unless the program is short of low memory.

Reach for `X.BANK.INC.BL` when the p-code no longer fits under the runtime, and bank the modules
the program calls *least often* first — a banked call goes out to a low-memory shim, selects the
bank and comes back. **A region cannot branch to another region** — two regions live at the same `$A000` in
different banks, so the branch has no distance to travel and the compiler refuses it. It can still
*call* one, through the low-memory shim: `SHIM.PUSH` keeps the caller's bank and `SHIM.POP` puts it
back, so the return lands with the right bank selected. What that costs is the shim on every call,
which is why `STRINGS` stays low in XBase: `DB.JOIN` calls it on every record.

The banked form needs three things, not one:

```basic
GOTO MY.LIBEND
#INCLUDE "SHIM.GUIBANK.INC.BL"     ' the shims, in low memory
GP.BANKED SHIM.GUIBANK
#INCLUDE "THEME.BANK.INC.BL"      ' the bodies, in the bank
#INCLUDE "MENUVERT.BANK.INC.BL"
GP.ENDBANKED
MY.LIBEND:
```

A shim file covers every entry point it knows and BASLOAD resolves every label in every file it
reads, so `SHIM.GUIBANK.INC.BL` obliges you to include all six GUI bodies even if you call one.
Leave one out and the build stops with `LABEL NOT FOUND`.

## Why `.BODY` exists

A banked routine cannot select its own bank — by its first instruction fetch the window is already
wrong. So the public name must be a low-memory label that selects the bank and calls the real code,
and the real code needs a name of its own. That is `X.BODY`. Never call it from outside the region.

## This split is meant to be temporary

Banked-or-not is a property of the **program**, not the module, yet today the answer is baked into
the module's label text. The compiler already knows which region a label is in, so it could emit the
bank switch itself and both files could collapse back into one — see item 4 under
`## Compiler work — what is next, ranked` in `TODO.md`. Until then the twins are hand-maintained:
**fix a bug in both**, or a program that banks and a program that does not will disagree about what
the library does.
