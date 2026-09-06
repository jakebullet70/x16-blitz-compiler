---
name: color-test-sample-state
description: "Where samples/color-test stands after 2026-09-06, and the four loose ends left open when it was parked"
metadata:
  node_type: memory
  type: project
---

**`samples/color-test` is built, verified and pushed** (`0a444c5`, plus the `TODO.md` entries a later
sweep took). Parked 2026-09-06 with "we will get back soon". The readme carries the design rules --
one colour a role, the HILITE bar convention, why the controls are never drawn in the scheme. This
note is only the things that are written down nowhere else.

**Four loose ends, none of them blocking:**

1. **The X16 power-on colour pair was never verified.** `TODO.md`'s themes item asked for it to be
   read out of `$0376` on a freshly booted R49 rather than typed from memory, and named `$61` and
   `$6E` as the candidates. That was not done -- `X16` simply kept the old `CLASSIC` values
   (`6*16+1`, white on blue). If the real pair turns out to be `$6E`, `THEME.LOAD.X16` is wrong.

2. **`GRAY`'s `DIMMED` and `WARN` are invented.** XFMGR's `MODULE theme` defines neither, so
   `11*16+12` and `11*16+2` are guesses. Everything else in `GRAY` is lifted verbatim.

3. **The editor and GPC-HELP were never rebuilt** against the five-theme `THEME.INC.BL`. It adds
   roughly twenty lines of p-code to each, and their theme key now cycles five rather than three.
   Neither has been run since.

4. **`TODO.md`'s "Two more themes, `x16` and `grey` -- TODO" is stale and diverged.** It expected
   `x16` and `grey` at `THEME.ID` 3 and 4. What shipped renames `CLASSIC` to `X16` at 0 (the entry
   itself observed that `x16` "is less a new look than the exact one"), puts `GRAY` at 3 and
   `CUSTOM` at 4. Nothing moved, so no caller changed.

**The `S` save key is not in the sample** -- see [[file-io-error-in-gpdo-key-loop]] for the bug and
the seven shapes already ruled out. The array-loading `THEME.LOAD` in `TODO.md` would close the same
loop a different way, by letting a scheme be carried as data instead of pasted by hand.

Related: [[compile-shared-not-embedded]], [[headless-basl-build-recipe]].
