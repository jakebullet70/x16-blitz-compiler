# GPC EDIT — a text / Markdown editor sample for the Commander X16

A small, MS-DOS-EDIT-styled text editor written in **BASLOAD** and compiled by **GPC**. It is a
sample: a genuinely useful program that also stresses the compiler on the thing interpreted BASIC is
worst at — repainting a full text screen fast. This file is the design/status record for the sample
(distilled from working notes so it travels with the code).

> Status checkpoint committed on branch `editor-sample`. **Not** yet relocated to `samples/editor/`
> (that is milestone M5, still open). See TODO.md → Samples → "Editor sample".

## Files

- **`EDITOR.BASL`** — the editor: screen setup, menu bar, render, key loop, editing, find/goto.
- **`STORE.BASL`** — `#INCLUDE`d storage layer: a banked bump allocator plus a 3-byte-per-line
  pointer table (`DOC.*` labels), length-prefixed line records, load/save/insert/delete-slot. No
  pointers — a "far pointer" is just `(bank, offset)` and access is `BANK n : PEEK/POKE $A000+off`.
- Naming: readable expanded identifiers (`NAME$`, not `NM$`); **dotted** names (`DOC.FILE.NAME$`)
  deliberately dodge BASLOAD's keyword-collision trap (its scanner grabs the maximal `A-Z0-9_.` run
  before a `$`, and if that whole run is a keyword it tokenises as the keyword — so `FN$`/`ON$` break,
  but `DOC.FILE.NAME$` is safe because the whole run is not a keyword).

## What works (M1–M4, verified headless)

- M1 storage + read-only VERA render; M2 editing (insert/overwrite, backspace/delete/join, split,
  save); M3 menu bar (File/Search/Help, dropdowns, cyan prompts, red errors); M4 find (wrapping,
  case-insensitive, hand-coded — no `INSTR`) + go-to-line + discard-confirm.
- Screen modes: `ED.SCREEN.MODE` const = `1` for 80×30 (default) / `3` for 40×30, set via
  `POKE 780,mode : POKE 783,0 : SYS 65375` ($FF5F `screen_mode`, which also clears), dims read back
  with `SYS $FFED`.

## Rendering architecture (this is the point of the sample)

Everything — text area **and** chrome (menu bar, dropdowns, status, prompts, messages) — is written
straight into VERA's text map (bank 1, base `$B000`, cell = `45056 + row*256 + col*2` → `[char, attr]`,
`attr = bg*16+fg`). The KERNAL `LOCATE`/`COLOR`/`PRINT` path was removed: `CHROUT` is a fixed ROM cost
compiling can't touch, and the old space-at-a-time bar padding was O(n²).

Two things make it fast, and both are load-bearing:

1. **O(1) cursor movement.** The original slowness was every arrow key doing a full-screen repaint
   (`ED.REFRESH.FULL` → redraw all ~28 rows to move one cell). Now a plain move restores the old
   caret cell and inverts the new one (~2 cells) via `ED.CARET.REFRESH`; only a real scroll or a
   structural edit repaints more.

2. **FX-text row render.** `ED.RENDER.ROW` uses VERA FX 32-bit cache writes: one `DATA0` write flushes
   4 VRAM bytes = 2 cells `[char,attr,char,attr]`. The attribute is uniform per row, so it is loaded
   into the cache's two attr slots once; the loop then pokes only the two char slots + one flush per
   pair. It writes the attrs (so it is coupling-free — unlike a reverted char-only experiment that
   corrupted a row's attr in the full loop).

3. **Hardware vertical scroll.** A one-line cursor scroll no longer repaints ~28 rows. It bumps VERA
   `L1_VSCROLL` (`$9F39/$9F3A`, map-pixels, +8 per text row) and repaints only 3 rows: the menu bar
   (which must stay put on screen while the map slides under it), the one newly-exposed text row, and
   the status bar. Every VERA write is addressed at map row `(screen_row + ED.MAP.TOP)`, where
   `ED.MAP.TOP = VSCROLL/8`. The map is **64 rows tall, 128 wide** in both 80×30 and 40×30 (probed:
   `L1_CONFIG $9F34 = 96`), read at init so it self-adapts. `ED.MAP.TOP` is bounded to
   `[0, MAP.H − SCREEN.ROWS] = [0, 34]` so the visible window never crosses map row 63 — meaning the
   code **never depends on VERA's vertical wrap**; at the bound it rewinds to 0 (or MAXTOP) + repaints.

## Measured render costs (compiled, real speed, jiffies/100 reps for a 79-char row)

Benchmarked with a plain tokenised `.PRG` (no BASLOAD), timed off `TI` at **real** speed — not
`-warp`, which decouples the jiffy IRQ and wrecks timing.

| method | jiffies/100 | note |
|---|--:|---|
| empty `FOR` loop | 27 | the floor — you cannot out-poke the loop itself |
| VERA-FX uniform fill | 29 | clears / blanks / attr fills |
| **FX-text (2 chars/flush)** | **48** | what the editor now ships |
| char-only (+2) | 50 | fragile — reverted (attr coupling bug) |
| `PRINT` | 54 | no gain from compiling (KERNAL-bound) |
| char+attr (+1) | 80 | the previous renderer |
| VPOKE per cell | 219 | the original — ~1s per full repaint, the lag that started this |

Lessons: text render is **loop-bound** (~half the cost is the BASIC `FOR/NEXT` you cannot out-poke);
`PRINT` does not speed up compiled. A follow-up bench of the *realistic* inner loop (conditional
`PEEK` + address math + FX flush per cell) came out ~4.5× heavier than the bare FX flush, so the
per-cell char-fetch logic dominates — and converting that loop's variables to integer (`%`) bought
only **~4.6%** (2168 → 2069 jiffies/1000 reps). GPC supports `%` (including `FOR I%`, which stock
CBM BASIC rejects), but it is not a speed lever here, and `FOR I%` has a sign bug on negatives.

## Build / test headless

Harness (in the scratch working dir): `build.py EDITOR.BASL EDITOR.OBJ "M4 OK"` — tokenises the
`.BASL` through BASLOAD (pulls the `#INCLUDE`), compiles via `GPC.BLITZ.BIN`, runs, greps the echo.
Set `DEBUG.MODE = 1` (top of `EDITOR.BASL`) to run the self-check and stop: it drives the model/
dispatch programmatically (an `ED.SIM.*` hook bypasses interactive prompts) and `PRINT`s markers a
watcher greps for — chrome/text/caret cells VPEEK'd back, plus a hardware-VSCROLL unit test and an
end-to-end 35-line cursor walk (8 scrolls → correct document lines land at the displayed map rows),
ending in `M4 OK`. Interactive key paths (menu nav, typing) are not headless-tested — key injection
is flaky — but the model they call and the render are each verified. Needs a `TEST.MD` fixture on the
emulator drive (a small Markdown file); the editor opens `TEST.MD` by default.

## Open questions to revisit

- **Why prog8's editor renders faster (`x16-MSEDIT`).** *Hypothesis, not yet proven:* prog8 compiles
  to native 6502 while GPC executes P-code through a runtime, so the same per-cell inner work
  (compare, add, load, store) is a handful of machine instructions in prog8 vs a runtime dispatch
  over 6-byte float operands in GPC — and that dispatch, not the VERA method, is the gap. Measured on
  the GPC side (the table above, the ~4.6% INT result); **not** yet confirmed by profiling GPC's
  dispatch or reading prog8's emitted render loop. That read is the next step.
- **Inline assembly in GPC.** Could GPC gain an inline-ASM escape hatch so hot loops drop to native
  speed without leaving the language? Feasibility is under separate investigation.
- **M5 ship:** relocate to `samples/editor/`, add a real sample `.md` + `readme.md`, wire `make
  samples`, smoke-test.
