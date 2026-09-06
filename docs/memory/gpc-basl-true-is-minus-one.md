---
name: gpc-basl-true-is-minus-one
description: "TRUE is -1 in the GPC-BASIC library as of 06/09/26 -- every flag it hands back, because NOT wants -1 and IF only tests non-zero"
metadata:
  type: project
---

**Every boolean the library writes is -1 for true, 0 for false**, swept 06/09/26: `GUI.OK`
`GUI.ANSWER` `GUI.DONE` `GUI.STASHED` `GUI.LISTBOX.DONE` `LINEINPUT.DONE` `MENUVERT.DONE`
`MENUVERT.HOTHIT` `SORT.OK` `STASH.OK` `STASH.MOVE` `THEME.READY` `THEME.FIRST` `BANKMGR.OK`
`BANKMGR.READY` `FILE.OK` `FILE.KEEP` `FILE.DIR.FULL` `FILE.DIR.MORE` `APPSYS.IS.EMULATOR`.
**Write -1 in new code.** The user's call: *"-1 is the standard going forward."*

**Why, read out of the compiler rather than assumed:**

- A comparison evaluates to **-1**. `ReturnTrue` in `ifloat32/source/utility/float/compare.asm`
  stores mantissa 1 AND sets `NSStatus` to `$80`, the sign bit.
- `IF` tests **non-zero**, not -1: `CommandIF` compiles a `.goto.z` past the end of the line and the
  handler is `FloatIsZero`. So `IF FLAG THEN` works whatever the true value is.
- `NOT` is **-x-1** (`runtime/source/functions/number/not.asm`), so `NOT -1` is 0 but `NOT 1` is -2,
  which is still true. That is the only place the two values behave differently, and it is why -1.

**The two spellings that break under -1**, both found by grep in the sweep: `IF FLAG = 1 THEN`
(there were four, including `ED-MENUS.BASL` and `GPB.HELP.BASL`), and printing a flag through
`MID$(STR$(N), 2)` -- that idiom strips the leading space `STR$` puts on a POSITIVE number, so it
eats the minus and prints `1`. Use `STR$` whole for anything that can be negative.

**A flag the CALLER sets is still read as non-zero** (`LINEINPUT.MASK`, `STASH.MOVE`), so old callers
passing 1 keep working.

Documented in `GP-BASIC.GLOBALS.md` §5. Related: [[gpc-if-semantics]],
[[write-readable-code-user-crunches]].
