---
name: basload-label-and-variable-collide
description: "BASLOAD gives DUPLICATE SYMBOL when a label and a variable share a name -- and a trailing $ does not make them different, so a GOSUB target FOO and a string FOO$ cannot coexist"
metadata:
  type: project
---

**A label and a variable may not share a name, and `$` is not part of the name for this
check.** `GUI.LISTBOX.FOOT:` as a GOSUB target and `GUI.LISTBOX.FOOT$` as the string it builds
stopped the tokenise with `ERROR: DUPLICATE SYMBOL IN GUI2.INC.BL:307`, pointing at the
**variable**, not the label -- so the line it names is the innocent one if you think of the label
as the owner of the name.

Proved 03/09/26 building `GPC-BASIC/GUI2.INC.BL`; renaming the string to `GUI.LISTBOX.EDGE$` fixed
it with no other change, and the 16-case regression went green.

**A longer name is fine** -- `GUI.OPEN` and `GUI.OPEN.DRAW` are both labels, `GUI.SCREEN` is a
label beside the variables `GUI.SCREEN.ROWS` and `GUI.SCREEN.COLS`. It is only the exact same name
that collides.

**The failure signature is the usual one**: the 6-byte PRG, `OK CODE 11 FREE 22016 ... GP-BASIC
OUT`, and then the emulator running off into `CPU program counter reached $ffff` -- identical to a
missing `#SAVEAS` or a rejected `#DEFINE`. The cause is only ever in `TOK.LOG`, so read it before
believing anything about the compile.

Related: [[basload-define-rejects-digits]], [[headless-basl-build-recipe]].
