---
name: basl-cruncher-built
description: "samples/cruncher BUILT 2026-09-03 - what it does, the 255-lines-255-bytes result, and the five options refused by name"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-03T15:58:48.947Z
---

**`samples/cruncher/` — BUILT 2026-09-03.** `CRUNCH.PRG` (front end) writes `CRUNCH.INPUT` and
chain-loads `CRUNCH.BIN` (engine), the GPC shape. Both GP.BASIC compiled by GPC, **EMBEDDED** so
the folder stands alone without a versioned `GPB.RT.nnn.BIN`. X16-native, **not** the host-side
Python `TODO.md` asked for.

**The result, on `EDITOR.BASL` release: 1,571 -> 1,316 BASIC lines, object 26,411 -> 26,189.
255 lines, 255 bytes, one for one** — exactly what [[program-too-big-fires-early]]'s note
predicted. `HOIST` + REM-stripping reaches 26,156.

**Three findings that contradicted the guesses:**

- **`KEEP` (comments break the join run) costs only 32 lines of 481.** The fear that 42%
  comment/blank content would block most joins was wrong. It is the better default — comments stay
  above the code they describe.
- **Trailing-REM stripping is OFF by default and asked for.** A REM on its own line is free;
  only trailing ones cost (~2 bytes), and cutting one throws the text away.
- **`COLLAPSE` (`GP.IF` block -> plain `IF`) is nearly worthless in practice.** `EDITOR.BASL` has
  **exactly one** `GP.IF`. The tree has 93 openers, 85 of them inside the cruncher itself. The
  2 KB prize of dropping the GP block never fires — every file using `GP.IF` also uses other GP
  keywords that pull it in.

**Not built, and the engine refuses each BY NAME rather than ignoring it:** scope `TREE`/`LIST`,
output `INPLACE`/`DIR`, the `LABELS` transform, the map file, on-device `VERIFY`.
**`LABELS` cannot be per-file** — a label defined in `GUI.INC.BL` may be referenced only from
`EDITOR.BASL`, so the engine must walk the whole `#INCLUDE` tree for the reference set even when
rewriting one file. DOS `R0:new=old` rename is **verified working** on the emulator's host
filesystem, so `INPLACE` is viable.

**Tested two ways, and the second is the one that matters:** a host-side flatten-and-diff
(statement sequence + THEN clauses, `GP.IF` blocks normalised so a collapse compares equal —
1,317 and 96, identical), then the editor's `DEBUG.MODE = 1` self-check **byte-identical**
crunched against uncrunched. A `THEN` mistake passes the first and fails the second.

See [[basl-sources-use-all-three-line-endings]] and [[basload-autonum-breaks-strcase]].
