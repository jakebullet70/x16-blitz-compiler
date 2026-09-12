# Building the sample programs — handoff

Written 12th September 2026, straight after the first full run of `samplesbuild.py`.
That run built two programs of five. **The script is new and it is not finished.** Two
defects are named below, both fully diagnosed, and both are a small edit. Read section 6
before you run anything.

`PRG-BUILD-STATUS.md` beside this file is the other half: which programs are green, which
files on disk are not what their names say, and what `release.sh` stages while they are
broken.

---

## 1. The one command

```
python source/gpc/samplesbuild.py                  every program
python source/gpc/samplesbuild.py GPB.HELP         one, by name
python source/gpc/samplesbuild.py --list           the table, no build
```

`source/gpc/helpbuild.py` is a shim over `samplesbuild.py GPB.HELP` and nothing more.
`xbasebuild.py` and `modsbuild.py` are the older one-program scripts that
`samplesbuild.py` was modelled on; they still work and are still the fallback if the new
script is in your way.

Budget **six to ten minutes per program**. GPBMODS alone was 6m 11s on this machine.

---

## 2. What actually happens

There is no host-side compiler. GPC is a native X16 program, so both steps boot the
bundled emulator in warp and drive the real thing.

**Step 1 — tokenise.** `build_basl.py <NAME.BASL> <NAME.SRC.PRG>` runs BASLOAD-GPC over
the source in `testing/` and leaves a tokenised PRG. Everything happens in `testing/`;
that folder *is* the emulator's drive.

**Step 2 — compile.** `compile_shared.py [--embedded] <src.prg> <obj.prg> [map]` writes a
four-line `testing/GPC.INPUT` (source, object, map, mode), boots `GPC.BIN`, and waits.

Both send the emulator transcript to a **log file, not to stdout**, so a stage that is
working prints nothing for minutes. That is why `samplesbuild.py` runs a heartbeat beside
each stage printing elapsed time and the size of the files being written.

### The stop condition, and why it matters

`compile_shared.py` stops on the literal string `OK CODE` in the log and on nothing else.

- **Size is not progress.** The two-pass compiler writes the object *as* it compiles, so
  the file appears early and grows in bursts. The old "hasn't grown for 0.6s" rule killed
  a warp-mode lull mid-compile and left a **513-byte object with no map** under a cheerful
  "compiled" line. If you ever see 513 bytes, that is what happened.
- **Do not widen the match to an error word.** GPC echoes its whole error-message *table*
  just after its banner, so `OUT OF RANGE`, `SYNTAX ERROR` and `TYPE MISMATCH` are all in
  the log of a perfect build.
- A `READY.` *after* the banner means the compiler gave up; the lines between are its own
  account of the failure and go in the message.
- `TIMEOUT` is 900 s. GPBMODS with seven regions needed ~450 s; 420 killed it mid-overlay.

---

## 3. Files that must be there before you start

| File | Where | If missing |
|---|---|---|
| `x16emu.exe`, `rom.bin` | `bin/x16emu/` | both scripts die immediately |
| `GPC.BIN` | `testing/` | the compiler engine — `make -C source/gpc` |
| `BASLOAD-GPC.BIN`, `BASLOAD-GPC.PRG` | `testing/` | the tokeniser; `build_basl.py` stages it from `BASLOAD-GPC/build/` if that is newer |
| `GPB.RT.121.BIN`, `GPC.RT.121.BIN` | `testing/` | `make -C source/runtime gpc-rt` |

`121` is the **runtime** build number from `source/application/rtbuild.txt`. It is pinned
and does not auto-bump, and moving it strands every SHARED object built against the old one
-- the name is baked into the object by `bootstrap.asm`, so they all need recompiling.
It is *not* the product version, which is `buildnum.txt`.

`samplesbuild.py` stages the rest itself: every `*.INC.BL` from the program's own module
folder, then the source, then any extras.

> **`GPB.INC.BL` always comes from root `GPC-BASIC/`, never from a sample folder.** A
> sample copy silently downgrades the keyword set. This is a standing order and the script
> already honours it at `samplesbuild.py:129`.

---

## 4. The program table

`samplesbuild.py:36`. One dict per program: `src` (folder, file), `lib` (upstream module
folder), `extras`, `shared`, `install` (destination, name — `None` leaves it in `testing/`,
which is already the drive its demo bat mounts), `data`.

| Program | Source | Mode | Installs to |
|---|---|---|---|
| GPBMODS | `samples/GPB-MODS-TESTING/GPBMODS.BASL` | SHARED | stays in `testing/` |
| GPB.HELP | `samples/GPC-HELP/GPB.HELP.BASL` | SHARED | `samples/GPC-HELP/` + both runtimes |
| COLORTST | `samples/color-test/COLORTST.BASL` | SHARED | stays in `testing/` |
| BMXVIEW | `GPC-BASIC/BMXVIEW.EXP.BL` | EMBEDDED | `demo/C.BMXVIEW.PRG` + the BMX images |
| EDITOR | `samples/editor/EDITOR.BASL` | EMBEDDED | `samples/editor/C.EDITOR.PRG` |

**SHARED vs EMBEDDED is not a preference.** A SHARED object carries no runtime and asks
the **drive root** for `GPB.RT.nnn.BIN` when the program uses a GP keyword and
`GPC.RT.nnn.BIN` when it does not (`bootstrap.asm:285`). The choice is made at compile
time and flips silently, so both files get copied. It is fetched with a **leading slash**
— from a subdirectory the unslashed name is not found. EMBEDDED carries its own copy,
about 12 K, and needs nothing on the drive.

- BMXVIEW is EMBEDDED because `bmx-demo.bat` mounts `demo\`, which has never carried a
  runtime.
- EDITOR is EMBEDDED per step 2 of `samples/editor/readme.md`.
- **Overlays** (`.Bnn`, one per `GP.BANKED` region, `nn` in decimal up to 63) are LOADed
  from **beside the program**, not from the drive root. `?OVL` is the failure message.
  They must travel with the object.

**XBASE is deliberately absent.** It builds (`xbasebuild.py`) but no database ships with
it, so it is not in a release.

---

## 5. Getting feedback out of it

`samplesbuild.py` streams each child line by line (`Popen` with `-u`) and ticks every ten
seconds with the sizes of `GPCCOMP.LOG`, the object and the map.

> **It watches three files on purpose.** `GPCCOMP.LOG` stops at 285 bytes as soon as the
> engine has echoed its banner and sits there for the whole compile, which reads exactly
> like a wedged emulator. The object is what grows after that.

**Always redirect to a file as well as watching it.** On the 08:29 run the stream went
only to the terminal, the session dropped, and ten minutes of build output was lost while
the build itself carried on headless:

```
python source/gpc/samplesbuild.py 2>&1 | tee testing/SAMPLESBUILD.LOG
```

Fixing the script to open that log itself is the first thing worth doing.

---

## 6. What the 08:29 run actually did — read this

Two of five. Times and sizes are off the files, not off the lost transcript.

| Program | Tokenise | Compile | Verdict |
|---|---|---|---|
| **GPBMODS** | 08:30:26, 77,062 B | 08:36:37, **12,885 B** | **green** — MAP 28,303, 8 overlays B04–B11 (7,938 / 7,426 / 4,610 / 4,354 / 1,538 / 770 / 770 / 3,074) |
| **COLORTST** | 08:37:07, 4,051 B | 08:37:10, **3,039 B** | **green** — MAP 2,047. Three seconds looks impossible but see below |
| **GPB.HELP** | 08:37:00, 19,738 B | died in ~1 s | **failed at compile** — defect 1 |
| **BMXVIEW** | died | never ran | **failed at tokenise** — defect 2 |
| **EDITOR** | died | never ran | **failed at tokenise** — defect 2 |

COLORTST is green on an indirect but sound argument: `compile_shared.py` removes
`testing/GPCCOMP.LOG` **only on the success path**, a tokenise failure returns before the
compile is reached so no compile ran after COLORTST's, and the log is gone. Its map is
present too, which the script checks for explicitly. Warp boots in two to three seconds
here — the 6 s tokenise says so as plainly as the 3 s compile does.

### Defect 1 — the stem is computed wrong (diagnosed)

`samplesbuild.py:185` strips **two** extensions so `BMXVIEW.EXP.BL` reduces to `BMXVIEW`:

```python
stem = os.path.splitext(os.path.splitext(prog["src"][1])[0])[0]
```

`GPB.HELP.BASL` therefore reduces to **`GPB`**, not `GPB.HELP`. The script asked the
compiler for `GPB.SRC.PRG`, BASLOAD had written `GPB.HELP.SRC.PRG`, and
`compile_shared.py` died on the missing input in about a second. The same wrong stem also
means it deleted `GPB.PRG` instead of the stale `GPB.HELP.PRG`, which is why an 08:08
object is still sitting there looking plausible.

Strip `.BASL` / `.EXP.BL` / `.BL` by name instead of counting dots.

### Defect 2 — the output name is fixed by the source, not by the caller (diagnosed)

**BASLOAD writes whatever the source's own `#SAVEAS` line says.** `build_basl.py` cannot
override it; it can only look for the file it asked for. Three of the five sources
already say `.SRC.PRG` and two do not:

| Source | `#SAVEAS` | |
|---|---|---|
| `samples/GPB-MODS-TESTING/GPBMODS.BASL` | `@:GPBMODS.SRC.PRG` | ok |
| `samples/color-test/COLORTST.BASL` | `@:COLORTST.SRC.PRG` | ok |
| `samples/GPC-HELP/GPB.HELP.BASL` | `@:GPB.HELP.SRC.PRG` | ok |
| `GPC-BASIC/BMXVIEW.EXP.BL` | `@:BMXVIEW.PRG` | **wrong** |
| `samples/editor/EDITOR.BASL` | `@:EDITOR.PRG` | **wrong** |

The two wrong ones left `BMXVIEW.PRG` + `BMXVIEW.SYM` and `EDITOR.PRG` + `EDITOR.SYM` in
`testing/` and no `.SRC.PRG` at all, so `samplesbuild.py` reported a dead tokenise and
skipped the compile.

Worse, `BMXVIEW.PRG` and `EDITOR.PRG` are **the names of the compiled objects**. The
tokenised source is landing on top of the object. Anything in `testing/` under those two
names right now is a tokenise, not a compile — do not trust the 27,316-byte `EDITOR.PRG`.

Two ways out. Editing the `#SAVEAS` in the two sources to `.SRC.PRG` makes all five
consistent and is what the other three already do; it changes tracked source, so agree it
first. Otherwise have `samplesbuild.py` read the `#SAVEAS` line and ask for that name.

A trap sits behind this either way. `build_basl.py:build_tool` **skips** when the output
PRG is no older than the source:

```python
if os.path.exists(prg) and os.path.getmtime(prg) >= os.path.getmtime(basl):
    print("  build_basl: skip -- testing/%s is up to date (source no newer)" % prg_name)
```

`samplesbuild.py` deletes the stale outputs before each build precisely to defeat this,
but it deletes them **by the wrong stem** for GPB.HELP (defect 1), and a changed
`.INC.BL` is invisible to the check in any case.

### One thing to know before you diagnose anything

`compile_shared.py` **deletes `GPCCOMP.LOG` on success**, and the next compile overwrites
it. Its absence tells you nothing about an earlier failure. Copy it aside the moment a
stage fails, and keep the wrapper's own log (section 5).

---

## 7. Diagnosing a failure

1. `testing/GPCCOMP.LOG` is the compiler's transcript — but only until the next compile
   overwrites it, and it is deleted on success. Copy it aside the moment a stage fails.
2. A **513-byte object with no map** is a run killed mid-compile, never a real result.
3. A tiny PRG out of step 1 is a BASLOAD failure, and BASLOAD's failures are silent or
   misdirected. BASLOAD leaves a NUL-terminated message at `$bf00` in bank 0; the driver
   writes it to `testing/BASLDONE`. The nineteen return codes are in
   `testing/MSEDIT/BASLOAD.MD`. Reach for the `basload` agent before blaming the compiler.
4. `?OVL` at run time means an overlay was not found beside the program.
5. The emulator transcript is long. Keep the last ~20 lines and the numbers — object size,
   the `.Bnn` sizes, the PASS count. Do not echo the whole log.

---

## 8. Standing orders

- **Kill `x16emu` by PID only, never by image name.** An interactive session of the user's
  is usually running. List with
  `Get-CimInstance Win32_Process -Filter "Name='x16emu.exe'"` and kill only the `-warp`
  ones. Both build scripts already use `Popen.kill`.
- **No unasked builds.** "Commit and push" does not include a build. Ask, then wait.
- **Never copy `GPB.INC.BL` from a sample folder.** Root is upstream for that one file.
- **Do not run the emulator demos** — `help-demo.bat`, `bmx-demo.bat`, `menu-demo.bat` are
  the user's to run.
- **Run builds in the background.** A typed message cancels an in-flight foreground tool,
  and you lose the build with it.
- The user runs concurrent agents in this tree. **Re-read a file before you write it.**
- **Never read these whole:** `TODO.md`, `samples/GPB-MODS-TESTING/GPBMODS.BASL`,
  `GPC-BASIC/GP-BASIC.md`, `GPC-BASIC/GP-BASIC.GLOBALS.md`. Grep for the place, then
  `sed -n` around it.
- No ship language. Committed, pushed, built, green.

---

## 9. Loose ends this build does not cover

- **`demo/` does not exist.** Both `bmx-demo.bat` and `menu-demo.bat` mount it.
  `samplesbuild.py` creates it and fills it with `C.BMXVIEW.PRG` and the BMX images once
  BMXVIEW builds, but **`C.MENU.PRG` has no build entry in any script**, so `menu-demo.bat`
  stays broken until one is added.
- **`release.sh`** now calls `samplesbuild.py` after `make -C source/gpc release`, puts
  `COLORTST.PRG` at the zip root and everything else flat under `SAMPLES/`. Flat is
  deliberate: overlays load from beside the program, and the shared runtime is fetched
  from the drive root, so a folder per program would put a level between them.
- **`GPB.HELP` content is a separate command.** `MKHELP.PY` generates the topics, the
  index and the two Markdown files from four hand-written inputs; the viewer reads
  `HELP-TXT/GPB.HELP.IDX` at run time, so program and content rebuild independently.
  Never hand-edit `HELP-TXT/`, `GPC-HELP.md` or `GPC-HELP-TESTING.md`. See
  `samples/GPC-HELP/HANDOFF.md`.
- Nothing from this work is committed.
