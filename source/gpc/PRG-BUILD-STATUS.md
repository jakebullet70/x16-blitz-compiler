# Which PRGs are not building — handoff

State of every program the tree is meant to produce, measured on 12th September 2026 off the
files themselves. The companion document `BUILD-HANDOFF.md` says how to run the build and
diagnoses the two defects behind most of this; that one is the method, this one is the
inventory and the damage downstream of it.

Nothing here was rebuilt to find it out. Every number is a file size, a timestamp or a byte
signature already on disk.

---

## 1. The verdict

`samplesbuild.py` holds five programs. Two build.

| Program | Verdict | Fails at | Cause |
|---|---|---|---|
| **GPBMODS** | **green** | — | — |
| **COLORTST** | **green** | — | — |
| **GPB.HELP** | **fails** | compile | the stem — `BUILD-HANDOFF.md` defect 1 |
| **BMXVIEW** | **fails** | tokenise | the `#SAVEAS` name — defect 2 |
| **EDITOR** | **fails** | tokenise | the `#SAVEAS` name — defect 2 |

A sixth program has no build entry at all.

| Program | Verdict |
|---|---|
| **C.MENU** | **never built** — `GPC-BASIC/MENU.EXP.BL` is in no script |

The compiler's own programs are built by `make -C source/gpc release`, not by
`samplesbuild.py`. Rebuilt against runtime 121 on 12th September 2026: `GPC.PRG` 1,284 bytes,
`GPC.BIN` 25,755, `GPC.IMG.121.BIN` 13,569, `C.GPC.ERR.PRG` 1,751.

---

## 2. Three sources fail, two causes

Both causes are diagnosed in full in `BUILD-HANDOFF.md` §6. In one line each:

**GPB.HELP** — `samplesbuild.py:185` strips two extensions, so `GPB.HELP.BASL` reduces to the
stem `GPB`. The tokenise succeeds and writes `GPB.HELP.SRC.PRG`; the compiler is then asked for
`GPB.SRC.PRG` and dies on the missing input. The fix is in `samplesbuild.py` and touches
nothing tracked as source.

**BMXVIEW and EDITOR** — BASLOAD writes whatever the source's own `#SAVEAS` says, and these two
say the object's name rather than the tokenised source's.

| Source | `#SAVEAS` | `#SYMFILE` | |
|---|---|---|---|
| `samples/GPB-MODS-TESTING/GPBMODS.BASL` | `@:GPBMODS.SRC.PRG` | `@:GPBMODS.SRC.SYM` | ok |
| `samples/GPC-HELP/GPB.HELP.BASL` | `@:GPB.HELP.SRC.PRG` | `@:GPB.HELP.SRC.SYM` | ok |
| `samples/color-test/COLORTST.BASL` | `@:COLORTST.SRC.PRG` | `@:COLORTST.SYM` | ok |
| `GPC-BASIC/BMXVIEW.EXP.BL` | `@:BMXVIEW.PRG` | `@:BMXVIEW.SYM` | **wrong** |
| `samples/editor/EDITOR.BASL` | `@:EDITOR.PRG` | `@:EDITOR.SYM` | **wrong** |

Those two lines are tracked source. Agree the edit before making it.

---

## 3. What is on disk is not what it looks like

Three files read as finished programs and are not. This is the part that costs an afternoon if
nobody says it first.

**`testing/EDITOR.PRG` and `testing/BMXVIEW.PRG` are tokenised BASL, not objects.** The
tokeniser wrote them under the name reserved for the compiler's output. The first eight bytes
separate the two kinds with no ambiguity:

| File | Head | Reads as |
|---|---|---|
| `testing/EDITOR.PRG` 27,316 B | `01 08 09 08 01 00 89 35` | line 1, token `$89` `GOTO` — **tokenised source** |
| `testing/BMXVIEW.PRG` 4,182 B | `01 08 09 08 01 00 89 34` | **tokenised source** |
| `testing/COLORTST.SRC.PRG` 4,051 B | `01 08 09 08 01 00 89 31` | **tokenised source** |
| `testing/COLORTST.PRG` 3,039 B | `01 08 13 08 0a 00 9e 20` | line 10, token `$9e` `SYS` — **object** |
| `samples/editor/C.EDITOR.PRG` 26,411 B | `01 08 13 08 0a 00 9e 20` | **object** |

A `.MAP` beside the file says the same thing: the compiler writes one and the tokeniser does
not. Neither `EDITOR.MAP` nor `BMXVIEW.MAP` exists.

**`samples/GPC-HELP/GPB.HELP.PRG` was compiled EMBEDDED while the table said SHARED. FIXED on
12th September 2026** by the rebuild against runtime 121: `helpbuild.py` produced a 14,595-byte
SHARED object and installed `GPB.RT.121.BIN` and `GPC.RT.121.BIN` beside it. A SHARED object
carries the name of the runtime it wants; an EMBEDDED one carries the runtime itself and names
nothing. Searching each object for a runtime filename, after that rebuild:

| Object | Runtime name inside | Mode |
|---|---|---|
| `testing/GPBMODS.PRG` | `GPB.RT.121` | SHARED |
| `testing/COLORTST.PRG` | `GPB.RT.121` | SHARED |
| `testing/GPC.PRG` | `GPB.RT.121` | SHARED |
| `samples/editor/C.EDITOR.PRG` | none | EMBEDDED, as its table entry says |
| `samples/GPC-HELP/GPB.HELP.PRG` | `GPB.RT.121` | SHARED, matching its table entry |

It had been a hand build from 08:08 that `samplesbuild.py` failed to replace, and failed to
delete either, because it deleted the stale `GPB.PRG` under the wrong stem. The 121 rebuild
replaced it: the drive is SHARED now, and the `runtimes` entry in the program table copies
`GPB.RT.121.BIN` and `GPC.RT.121.BIN` in beside the object.

**`samples/editor/C.EDITOR.PRG` is a real object from 3rd September**, nine days behind its
source. It is not a placeholder and not this build's.

---

## 4. The demos

| Bat | Runs? | Why |
|---|---|---|
| `gpbmods-demo.bat` | yes | its drive is `testing/`, and the object is current |
| `color-demo.bat` | yes | same drive, same |
| `help-demo.bat` | yes | on the EMBEDDED 08:08 object, not on this build's |
| `bmx-demo.bat` | **no** | `demo/` does not exist |
| `menu-demo.bat` | **no** | `demo/` does not exist, and nothing builds `C.MENU.PRG` |

`demo/` is build output and is not in git. `samplesbuild.py` creates it when BMXVIEW installs,
so it appears the moment BMXVIEW builds. `C.MENU.PRG` does not: `MENU.EXP.BL` appears in no
`.py`, no `.sh` and no makefile, so `menu-demo.bat` stays dead until a sixth entry is added to
the program table.

`help-demo.bat` checks for `GPB.HELP.PRG` and for `HELP-TXT/GPB.HELP.IDX`. It does not check
for the runtime, so once GPB.HELP is genuinely SHARED a missing `GPB.RT.nnn.BIN` on that drive
becomes a run-time failure with no warning from the bat.

---

## 5. release.sh does not notice any of this

Two things make a broken sample invisible to the packaging step.

**No exit check.** `release.sh` has no `set -e`, and line 62 is a bare
`python source/gpc/samplesbuild.py` with nothing testing its status. `samplesbuild.py` exits 1
when any program fails. The run continues to staging regardless.

**A missing program is stubbed, not reported.** Each sample stanza names one `fake` file. When
that file is absent, `stub()` writes a placeholder PRG in its place and appends to
`placeholders`, not to `missing`.

Staged from the tree as it stands:

| Sample | What lands in the package |
|---|---|
| GPBMODS | the real 12,885-byte object and its eight overlays |
| COLORTST | the real 3,039-byte object |
| EDITOR | `samples/editor/C.EDITOR.PRG` — real, and from 3rd September |
| BMXVIEW | **a placeholder** — `demo/C.BMXVIEW.PRG` does not exist |
| GPB.HELP | the EMBEDDED 08:08 object, staged at the package root |

The BMX images are globbed rather than listed, and 8 of the original 28 remain in
`samples/BMXVIEWER/SAMPLES` — the other 20 are staged deletions in git. The package takes
whatever is in the folder, so that count follows the tree with no error either way.

---

## 6. Order to fix them in

1. **`samplesbuild.py:185`** — strip `.BASL`, `.EXP.BL` and `.BL` by name instead of stripping
   two extensions by counting dots. This alone fixes GPB.HELP, and it is the only fix that
   touches no tracked source.
2. **The two `#SAVEAS` lines**, plus the `#SYMFILE` beside each, to `.SRC.PRG` and `.SRC.SYM`.
   This fixes BMXVIEW and EDITOR and makes all five sources consistent. Tracked source — agree
   it first. The alternative is to have `samplesbuild.py` read the `#SAVEAS` line out of the
   source and ask for that name, which changes no source at all.
3. **Delete `testing/EDITOR.PRG` and `testing/BMXVIEW.PRG`** before the next run. They are
   tokenised source under object names. `samplesbuild.py` removes them itself at the top of
   each build, so this only matters if something reads them first.
4. ~~**Rebuild GPB.HELP** and confirm the object names a runtime and that `GPB.RT.nnn.BIN`
   arrives in `samples/GPC-HELP`.~~ DONE 12th September 2026 -- both confirmed, on 121.
5. **A `set -e`, or a status check on line 62 of `release.sh`**, so a failed sample stops the
   packaging rather than being stubbed into it.
6. **A sixth program-table entry for `MENU.EXP.BL`**, if `menu-demo.bat` is meant to work.

---

## 7. What this does not cover

The help content is not built by any of this. `MKHELP.PY` writes the topics, the index and the
two Markdown files, the viewer reads `HELP-TXT/GPB.HELP.IDX` at run time, and the two rebuild
independently of each other.

XBase is absent from `samplesbuild.py` on purpose. It has its own script, `xbasebuild.py`, and
is built by hand.

`GPC.PRG`, `GPC.BIN`, `GPC.IMG.121.BIN` and `C.GPC.ERR.PRG` were checked for presence, size and
build mode. They have since been rebuilt against runtime 121, but not run.
