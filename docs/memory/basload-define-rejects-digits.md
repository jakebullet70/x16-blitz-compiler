---
name: basload-define-rejects-digits
description: "BASLOAD #DEFINE and #IFNDEF reject any symbol name containing a digit (INVALID PARAMETER), though variables and labels accept them; plus BASLOAD resolves every label in a file, so an #INCLUDE is never optional"
metadata: 
  node_type: memory
  type: project
  originSessionId: e11f586d-dff2-4c86-8740-8aa7445ee4e2
  modified: 2026-09-03T08:05:52.534Z
---

**`#DEFINE` and `#IFNDEF` will not accept a DIGIT anywhere in the symbol name.** BASLOAD stops with
`ERROR: INVALID PARAMETER IN <file>:<line>` and writes the 6-byte PRG that then "compiles" to
`OK CODE 11` -- the same misleading signature as a nesting failure ([[tests-share-the-products-memory]]).

**Variables and labels take digits happily.** Proved 2026-09-03 with three one-file builds:

| | |
| --- | --- |
| `#IFNDEF GUI2.DEFS` | INVALID PARAMETER |
| `#DEFINE GUI2.UP 145` | INVALID PARAMETER |
| `#IFNDEF GUILIST.DEFS` | fine |
| `GUI2.SEL = 7`, `GOSUB GUI2.SUB`, `GUI2.SUB:` | fine, 66-byte PRG |

**BASLOAD's own manual is wrong here** -- its Identifiers section explicitly allows `0-9` after the
first letter. Only the preprocessor is stricter, so the manual will not warn you.

**What this means for a module named with a digit** (`GUI2.INC.BL`): everything a caller touches --
entry labels, in/out variables -- keeps the digit, because those are labels and variables. Only the
`#DEFINE` constants and the `#IFNDEF` guard cannot have it.

**The answer there was to drop the directives, not to rename them.** `GUI2.INC.BL` shipped first
with a `GUILIST.*` constant block; the user's call was **"no defines"** -- a second name space for
one module is worse than a number written where it is used, and the include is the switch, so the
guard went with them. **It costs nothing: `#DEFINE` is compile-time text, and `OK CODE 6199` is
the figure before and after.** So GUI2 is the one module in `GPC-BASIC/` with no preprocessor
directives at all; #INCLUDE it once. See [[no-backward-compatibility-needed]] and
[[comments-light-code-should-flow]] for the same instinct.

**Unrelated, found in the same session and just as costly: an `#INCLUDE` is never optional.**
BASLOAD resolves every label in the file, not the ones a path can reach, so `GUI.INC.BL` needs
`MENUVERT.INC.BL` and `LINEINPUT.INC.BL` present even in a program that only calls `GUI.YN` --
without them the tokenise stops at `LABEL NOT FOUND`. Its header said "GUI.MENU only" / "GUI.TEXT
only"; that is true of the calls and false of the build, and has been corrected.

Related: [[headless-basl-build-recipe]] (which also carries the `#SAVEAS` trap), [[no-backward-compatibility-needed]].
