---
name: basload-define-eats-a-longer-name
description: "A #DEFINE whose name is the front of a variable's name is substituted inside it: FILEPICK.BOXW% became 44% and raised SYNTAX ERROR at run time"
metadata:
  type: project
---

BASLOAD substitutes a `#DEFINE` name wherever it starts a longer identifier. With
`#DEFINE FILEPICK.BOXW 44`, the line `FILEPICK.BOXW% = FILEPICK.BOXW` tokenised as
`44% = 44`. Measured 2026-10-03 while writing the TURBO file picker:

- `FILEPICK.BOXW%` compiled clean and raised `SYNTAX ERROR @ $0C:B3C7` when the line ran.
- `FILEPICK.TAIL$` against `#DEFINE FILEPICK.TAIL 10` stopped the compile with
  `TYPE MISMATCH`, at a BASIC line, not a source line.

**Why:** neither failure names the define, and the run-time one only shows when the line
executes.

**How to apply:** never give a variable a name that begins with a define's full name. Name the
define for the constant (`FILEPICK.BOXW`) and the variable for its use (`FILEPICK.BOX.WIDTH%`).
To place a run-time `$bb:AAAA` error, find the address in the program's `.MAP` (`bb:AAAA line`
rows), then the nearest label at or below that BASIC line in the `.SYM` file (`=line;`).
Related: [[basload-define-rejects-digits]], [[basload-label-and-variable-collide]].
