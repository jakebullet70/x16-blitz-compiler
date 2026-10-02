---
name: file-io-error-in-gpdo-key-loop
description: "FIXED in runtime build 131, 2026-10-02: CLS and COLOR passed garbage as the channel, and PRINT# never released its channel; the help text and three notes still describe the bug as open"
metadata:
  node_type: memory
  type: project
  originSessionId: 5991fdbe-eb9a-440f-bf52-e169789d2edb
  modified: 2026-10-02T08:27:40.266Z
---

**Root cause found on 2026-10-02 and fixed in runtime build 131.** Build 130 and older have the
defects.

The symptom, from 2026-09-05 on `GPC-BASIC-TOOLS-SRC/color-test`: a save routine reached from the
program's `GP.DO` key loop wrote its file correctly, then the program stopped with
`INPUT/OUTPUT ERROR @ $005B`. A plain `PRINT` after the `CLOSE` hid it. The loop was never the
cause. The redraw after the save was.

**Three defects, all in the runtime:**

1. `CLS` and `COLOR` called `XPrintCharacterToChannel` with X holding the float stack pointer or
   the colour table index, not a channel. `COLOR n` ran `CHKOUT n`. With file n open for output,
   the colour code went into the file. Measured: `OPEN 2` for write, `COLOR 2`, `PRINT#2,"AB";`
   gave a file of `1C 41 42`.
2. A statement with a channel never ran `CLRCHN`. The KERNAL's output stayed on the file after
   `PRINT#`, and through the `CLOSE`. A disk command sent with `PRINT#15` did not run until
   something else released the channel, so a seek followed by a write wrote in the wrong place.
3. `XPrintCharacterToChannel` tested `READST` after `CHKOUT`, not the carry flag. A failed
   `CHKOUT` went unseen while the status was zero, which is what kept defect 1 quiet.

Together: `PRINT#`, `CLOSE`, then `COLOR`. The first colour code went to the closed file and set
the status. The next one found the status set and raised the error. Six lines reproduce it on the
old runtime: `OPEN`, `PRINT#`, `CLOSE`, `COLOR 1,6` three times.

**The fix:**

- `SetChannel` (`commands/print/print.asm`) runs `CLRCHN`. The compiler emits it before and after
  every statement that names a channel, so each one ends released, as in ROM BASIC.
- `x16_printchar.asm` tests carry after `CHKOUT`.
- `x16_text.asm` sends its control codes through `VectorPrintCharacter`, which loads the channel.

It costs 4 bytes of core. The embedded cushion is now 2 bytes, see
[[gpc-core-page-cushion-below-gpbase]].

**Behaviour that changed:** a `PRINT#` to a file that is open no longer raises
`INPUT/OUTPUT ERROR` when the status is non-zero, for example after another file reached its end.
A `PRINT#` to a file that is not open still raises it.

**The text that described the bug is gone** (2026-10-02, the user's ask). The section "File I/O
in a GP.DO key loop" is out of `GPC-BASIC/GP-BASIC.md`, and the help was rendered again:
`H074.HLP` is 55 lines and the index has 165 rows. The "Not here" section is out of
`color-test/readme.md` and the warning is out of `docs/blitz/GPC-ERR-GUI.PLAN.md`.
`ERR.CHANNEL.KICK` and its four calls are out of `GPC.ERR.BASL`. GPC.ERR was rebuilt SHARED at
10,521 bytes, 23 fewer, and installed in `GPC-HELP`. It was not run by hand after that.

**Tests:** the six randomised compiler and runtime suites were not run against the fix. The
SHARED test was, see [[shared-test-warm-step-is-stale]].

**How to apply:** an `INPUT/OUTPUT ERROR` far from any file statement means a routine handed
`XPrintCharacterToChannel` the wrong X. Check the caller before the file code.

Related: [[headless-basl-build-recipe]], [[cmdr-dos-modify-mode-measured]].
