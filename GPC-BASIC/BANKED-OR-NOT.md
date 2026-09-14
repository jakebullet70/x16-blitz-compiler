# Running a module from a RAM bank

Every module is one file, `X.INC.BL`. The program that includes it decides whether its p-code runs
in low memory or from a RAM bank. Nothing in the module or in its callers changes.

| where | how | what a call costs |
| --- | --- | --- |
| low memory | `#INCLUDE "X.INC.BL"` | one `GOSUB` |
| a RAM bank | the same `#INCLUDE` between `GP.BANKED n` and `GP.ENDBANKED` | from outside the region, a bank select on the call and a restore on `RETURN` |

## Which one

Low memory is the default. Bank a module when the program's p-code no longer fits under the
runtime, and bank the modules the program calls least often first. A call from inside the region
costs nothing extra. A call from low memory or from another region switches the bank twice.

```basic
#DEFINE MY.GUICODE 4
GOTO MY.LIBEND
GP.BANKED MY.GUICODE
#INCLUDE "THEME.INC.BL"
#INCLUDE "MENUVERT.INC.BL"
GP.ENDBANKED
MY.LIBEND:
```

## The rules

- **A call into a region selects its bank.** `GOSUB`, `GP.SUB`, `GP.FN` and `FN` into a region
  from outside it compile to `.bgosub`, which saves the selected bank and selects the region's.
  `RETURN` puts the saved bank back. The caller may be in low memory or in another region.
- **A `GOTO` from one region into another is refused**, and so is `ON ... GOSUB` to a label inside
  a region. A `GOTO` carries no bank to select. A `GOTO` from low memory into a region compiles,
  and lands in whatever bank is selected.
- **Jump over the region with a `GOTO`.** `GP.BANKED` leaves a bridge, so falling into a region
  works while the bootstrap's code bank is still selected, and fails once anything selects another.
- **`#DEFINE` the bank number above the `GP.BANKED` line.** BASLOAD resolves a `#DEFINE` only if it
  has already read it. `GP.BANKED` takes a decimal constant, so the number is fixed when the
  program compiles.
- **Claim the bank.** Call `BANKMGR.CLAIM` on each code bank before anything asks `BANKMGR` for a
  free one, or the program can be handed its own code as scratch.
- **A module that holds a `BANK` statement stays in low memory.** The compiler refuses `BANK`
  inside a region, so `STASH` and `STASHFILE` cannot be banked.
- **A region holds at most 8K.** Past that the build stops with `GP.BANKED REGION OVER 8K`. Split
  the modules across two regions.
- **Include a module that reads another's `#DEFINE`s after it.** The GUI modules read `THEME`'s
  role numbers, so `THEME` comes first.
- **Build shared.** `GP.BANKED` refuses an embedded build with `NOT IMPLEMENTED`.

`samples/GPB-MODS-TESTING/GPBMODS.BASL` banks the utilities, the file modules, `THEME`, the GUI,
the combo box and two of its own dropdown handlers, in six regions.
