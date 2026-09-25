---
name: gp-fn-string-returns-aliases
description: FIXED 2026-09-13 -- two GP.FN calls on one string verb in one expression gave the second answer twice; a string GP.FN now concats "" into a temporary
metadata:
  type: project
---

**FIXED 2026-09-13, in the compiler only.** `GPFNCompile`
(`source/compiler/source/commands/gpdefproc.asm`) ends with a `GetSetVariable` read of the
`RETURNS` variable. A string term is a reference to that variable, so
`GP.FN(V,A$) + GP.FN(V,B$)` left two references to one variable and printed the second answer
twice. When the `RETURNS` type is a string, the compiler now emits `PCD_CMD_STRING`, `0`,
`PCD_CONCAT` after the read: concatenating `""` copies the value into a temporary. `.fnsave`
moves the temporary base below the caller's live temporaries, so the copy survives the next call.

**Cost:** 3 bytes of p-code per string `GP.FN` call site, 0 on numeric verbs, 0 runtime bytes.
`GPC.BIN` 28,911 to 28,932 B.

**Verified:** `scratch/gpfnalias/FNALIAS.BASL` compiled with the old and new `GPC.BIN`. The old
compiler printed `D1 TWO!TWO!` and `D2 -1`, the new one `D1 ONE!TWO!` and `D2 0`. The nested,
assignment, numeric and `+ "-" +` cases printed the same with both. Object 519 to 546 B, nine call
sites. `gpctest.py quick` PASS in 113 s: no program in the set changed, because GPBMODS's only
`GP.FN` is the numeric `FILE.SIZE`.

**Docs updated the same day:** the `GP-BASIC.md` section 8 entry is gone (four known bugs became
three), the one-call-per-expression WARNING is out of both `STRCASE` headers, and the `TODO.md`
bug entry and ranked item 0 read FIXED. The generated `GPC-HELP.md` copies still carry the old
entry until the help is regenerated. `fntest.py` cannot run: its `DEFFN*` sources are gone from
`drive/`.

Related: [[gp-defproc-one-line-calls]], [[gpc-string-blocks-never-shrink]].
