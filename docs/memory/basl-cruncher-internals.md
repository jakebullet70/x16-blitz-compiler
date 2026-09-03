---
name: basl-cruncher-internals
description: "How CRUNCHER.BASL is built inside - routine map, the two join properties, the build/test cycle, and the harness that is NOT in the repo"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-03T21:51:32.580Z
---

Resumption notes for [[basl-cruncher-built]]. That file says what it does and what it is worth;
this one says how to work on it.

## Shape

`samples/cruncher/CRUNCHER.BASL`, ~735 lines, is the engine. **Labels are `CX.*`, variables `CR.*`**
— BASLOAD files both in one symbol table and a label spelling a variable is `DUPLICATE SYMBOL`
([[basload-label-and-variable-collide]]). Keep the split; it removes the question entirely.

**It streams.** Joining needs one line of lookahead, never the file, so `LINPUT#` reads channel 2
and `PRINT#` writes channel 3 and a 62K source never lands in RAM. The only bounded buffer is
`CR.BUF$(16)` for `COLLAPSE`.

Routine map, in dependency order:

- `CX.SNIFF` / `CX.RAWLINE` — line-ending detection and the raw read. See
  [[basl-sources-use-all-three-line-endings]] for the trap that cost a debugging round.
- `CX.READINPUT` / `CX.GETFLD` / `CX.OUTNAME` — the eight `CRUNCH.INPUT` fields, each validated
  here because the file can be hand-written and the engine run standalone (as `GPC.BIN` re-checks
  `GPC.INPUT`).
- `CX.CRUNCHFILE` → `CX.READLOOP` → `CX.CLASSIFY` → `CX.EMIT` — the main pass.
- `CX.CLASSIFY` → `CX.MAKEUP`, `CX.CUTREM`, `CX.WALK`, `CX.WORDAT` — everything the packer needs
  about one line.
- `CX.FINDOUT` / `CX.FINDWORD` — find a needle **outside string literals**, optionally as a whole
  word. All correctness about `:` and `THEN` funnels through these two.
- `CX.TRYCOLLAPSE` / `CX.REPLAY` — the `GP.IF` transform.
- `CX.FLUSH` / `CX.PASSTHRU` / `CX.TRACKASM`.

**`CR.UP$` is the analysis copy** — `CR.CODE$` upper-cased, same length, offsets mapping 1:1 — so
BASLOAD's case-insensitivity costs nothing and the OUTPUT keeps the author's case. Assignment
copies the block (`STRCTST.EXP.BL` line 22 says so), so `STRCASE`'s in-place TRIM/UPPER on a copy
cannot reach back into the original.

## Where the correctness lives, and where to relax it

Every line gets two independent properties in `CX.WALK`:

- **`CANSTART`** — may this fold onto the line above? False for: a label, a `GP.` block keyword
  first, `DATA`, a directive.
- **`CANACCEPT`** — may anything fold onto this? False for: any `THEN` outside a string, a block
  keyword last, `DATA`, an unconditional transfer (`GOTO`/`RETURN`/`END`/`STOP`/`GP.EXITDO`), a
  kept trailing `REM`.

Driven by two delimited strings, `CR.BLOCK$` and `CR.STOP$`, matched with
`GP.INSTR(list$, "|" + word$ + "|")`. **This is deliberately over-conservative and the tuning knob
is right there**: every `GP.` block keyword breaks the run both ways, which is a guess, not a
measurement. Relaxing one at a time is the obvious next experiment — a wrong guess costs joins,
never correctness.

`GP.ASM`/`GP.ENDASM` and `#REM 1`/`#REM 0` regions are copied **verbatim**, no join, no REM cut.

## Build and test cycle

`python` and `make` are off-PATH ([[build-toolchain-location]]); Python 3.13 is at
`C:\Users\Admin\AppData\Local\Programs\Python\Python313`. Stage into `testing/` first — BASLOAD
resolves `#INCLUDE` off the drive and `build_basl.py` uses `testing/` as `-fsroot`:

```
cp samples/cruncher/{CRUNCH,CRUNCHER}.BASL samples/cruncher/GPC-BASIC/*.INC.BL testing/
python source/gpc/build_basl.py CRUNCHER.BASL CRUNCHER.SRC.PRG
python source/gpc/compile_shared.py [--embedded] CRUNCHER.SRC.PRG CRUNCH.BIN
```

**Build SHARED while iterating** — it compiles faster and the byte count is the p-code, which is
the number worth watching (front end 1,990, engine 4,657). Ship EMBEDDED (15,046 / 17,713).
**`compile_shared.py` can exceed a 120s tool timeout — allow 400s.** A full editor
crunch → build → self-check cycle is ~10 minutes of emulator round trips.

**Rebuild the runtime if a fresh compile fails oddly**: the engine emits programs wanting the
current `RT_ABI`, and a stale `GPB.RT.nnn.BIN` on the drive gives `SEARCHING FOR :*` and an
`INPUT/OUTPUT ERROR` rather than anything about ABIs. `make -C source/runtime gpc-rt`.

## THE HARNESS IS NOT IN THE REPO

The verification tooling was written in the session scratchpad and **is gone**. Rebuild or, better,
commit it:

- **`flat.py` — the correctness gate.** Reduces two BASL files to a statement sequence (split on
  `:` outside string literals, comments/blanks/directives handled) and to the list of THEN clauses,
  then diffs both. **It must normalise `GP.IF` blocks to `IF c THEN body` in BOTH files** or every
  `COLLAPSE` reads as a mismatch. Editor: 1,317 statements, 96 THEN clauses.
- **`runprg.py`** — run a PRG headless: `SDL_VIDEODRIVER=dummy`, `-warp -echo -prg NAME -run`,
  cwd `testing/`, poll the log for a stop string, kill by PID.

**`-echo` dumps an LF file's whole contents in one blob** because LF is not a PETSCII newline —
grep the summary lines, do not read the log whole.

The second gate is the editor's own `DEBUG.MODE = 1` self-check, byte-identical crunched against
uncrunched. **A `THEN` mistake passes `flat.py` and fails that one**, so never treat the flatten
diff as sufficient.
