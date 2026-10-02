---
name: paste-cannot-drive-a-running-program
description: "x16emu -bas paste only feeds the READY prompt, so an interactive compiled program cannot be tested headlessly - build a fixed-answer variant instead"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-29T13:24:26.865Z
---

**`x16emu -bas FILE -pastewarp` types FILE's text at the READY prompt only.** Once a program is
running, the rest of the paste does not reach its `GET` loop — it is dropped, not queued. Padding
the paste with `CHR$(20)` so a startup `CLEAR.KB` drain has something harmless to eat does **not**
help; the keys never arrive at all.

So an interactive front end (`GPC.PRG`, `CRUNCH.PRG`) **cannot be driven headlessly**. What works
instead, and what actually needs testing:

**Generate a fixed-answer variant FROM the real source** and compile that. A script that replaces
each `PR$ = "..." : GOSUB READLINE` / `GOSUB YESNO` with a literal assignment, asserting every
pattern was found, keeps the harness honest — it tests the real file's write path and hand-off,
and only the key-reading loop goes untested. That loop is lifted verbatim from `GPC.BASL` anyway.

This is how the `CRUNCH.INPUT` field format and the chain-load were verified for
[[basl-cruncher-built]] — and it immediately caught a real bug the engine's own tests could not
have: the front end writes CR-terminated output, which the engine's sniffer misread
([[basl-sources-use-all-three-line-endings]]).

**A program can type for itself.** Queue keys before the `INPUT` or `GET` with the KERNAL's
`kbdbuf_put`: `POKE 780, CODE : SYS 65219`, once per key. It works the same in ROM BASIC and in a
compiled program, so one source tests both. The buffer holds 10 keys. This is how the empty-line
INPUT fix was tested ([[gpc-input-empty-line]]).

**The same call drives an unmodified program from the `-bas` driver** (2026-10-02). The driver
is three direct-mode lines: `LOAD"NAME.PRG"`, `A$="keys"`, then one line that loops over `A$`
with `POKE780,K:SYS65219` and ends in `:RUN`. The queue and the `RUN` must share a line. The
paste goes through the same buffer, so a key queued on an earlier line is typed at the READY
prompt. 10 keys a run, and a `/` in the string stands for RETURN. It drove a ROM BASIC program
and a Prog8 PRG. The script is `source/scratch/runkeys.py DRIVE PRG KEYS`. `-echo` also logs
every byte a program writes to a file or to the command channel, so a `P` seek and each record
written show up between the screen lines.

Chain-loading is fine in both directions: **a compiled GPC program chain-loads another compiled
GPC program**, EMBEDDED or SHARED, with `LOAD "NAME"` and no `,8`.

## The same trick on a menu-driven GUI

For a program whose front end is a menu bar and dropdowns, the variant needs three edits, all
scripted off the real source with an assert on each: **disarm the key wait** (`GMX.WAIT` becomes a
bare `RETURN` — a headless `GET` on an empty buffer spins for ever), **replace the first
`GOSUB GMX.CHROME`** with a driver that sets `GM.SEL` / `MENUVERT.SEL` and `PRINT`s what the panel
handed back, and `END`. That runs the REAL panel routines, so a wrong `GP.BSTR` index or a misused
`STR.*` shows up as text in a log rather than as garbage on a screen no script can read.

Two traps. The probe can only name `GP.BANKEDSTR` groups declared ABOVE it
([[gp-bankedstr-literal-text-in-a-bank]]). And **the harness costs object bytes**: on
2026-09-08 GPBMODS sat exactly on the file ceiling and the 445-byte driver would not fit, so the
program had to be trimmed before it could be tested at all
([[object-file-must-fit-under-the-runtime]]).
