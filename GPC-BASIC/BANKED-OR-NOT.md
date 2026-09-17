# Running a module from a RAM bank

Every module is one file, `X.INC.BL`. The program that includes it decides whether its p-code runs
in low memory or from a RAM bank. Nothing in the module or in its callers changes.

| where | how | what a call costs |
| --- | --- | --- |
| low memory | `#INCLUDE "X.INC.BL"` | one `GOSUB`; from inside a region, a bank select on the call and a restore on `RETURN` |
| a RAM bank | the same `#INCLUDE` between `GP.BANKED n` and `GP.ENDBANKED` | from outside the region, a bank select on the call and a restore on `RETURN` |

## Which one

Low memory is the default. Bank a module when the program's p-code no longer fits under the
runtime, and bank the modules the program calls least often first. A call that stays inside one
region, or inside low memory, costs nothing extra. A call into a region, or out of one to low
memory, switches the bank twice and is one byte longer.

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
- **A call out of a region to low memory is a `.bgosub` too**, with the region's own bank. A low
  routine that executes `BANK` returns into the region under the right bank.
- **A `GOTO` into a region from outside it is refused**, from low memory or from another region.
  A `GOTO` carries no bank to select. `IF ... GOTO`, `IF ... THEN <line>` and `ON ... GOTO` are
  refused the same way.
- **`ON ... GOSUB` cannot make a banked call.** It compiles when the caller and every target are in
  low memory, or all in one region. Into a region, out of one to low memory, or from one region to
  another, the compile stops with `ON GOSUB IN OR OUT OF GP.BANKED`. Write a `GP.SELECT` or one
  `IF ... GOSUB` a case instead.
- **Jump over the region with a `GOTO`.** `GP.BANKED` leaves a bridge, so falling into a region
  works while the bootstrap's code bank is still selected, and fails once anything selects another.
- **`#DEFINE` the bank number above the `GP.BANKED` line.** BASLOAD resolves a `#DEFINE` only if it
  has already read it. `GP.BANKED` takes a decimal constant, so the number is fixed when the
  program compiles.
- **Claim the bank.** Call `BANKMGR.CLAIM` on each code bank before anything asks `BANKMGR` for a
  free one, or the program can be handed its own code as scratch.
- **A module that holds a `BANK` statement stays in low memory.** The compiler refuses `BANK`
  inside a region, so `STASH` and `STASHFILE` cannot be banked.
- **A `GP.ASM` block inside a region is assembled into the region's bank.** A block that writes
  `$00`, the RAM bank register, must be `GP.ASM LOW`, which stays in low memory and needs a
  `#SYMFILE`. `FILEDIR` writes its two blocks this way. GP-BASIC.md §3.9 has the check and what it
  does not see.
- **A region holds at most 8K.** Past that the build stops with `GP.BANKED REGION OVER 8K`. Split
  the modules across two regions.
- **Include a module that reads another's `#DEFINE`s after it.** The GUI modules read `THEME`'s
  role numbers, so `THEME` comes first.
- **Build shared.** The regions are in a `NAME.OVL` file and an embedded program is one file, so
  an embedded compile stops at the first `GP.BANKED` with `GP.BANKED NEEDS SHARED`. Ship the
  runtime file and the `.OVL` with the program.

`samples/GPB-MODS-TESTING/GPBMODS.BASL` banks the utilities, the file modules, `THEME`, the GUI,
the combo box and two of its own dropdown handlers, in six regions.
