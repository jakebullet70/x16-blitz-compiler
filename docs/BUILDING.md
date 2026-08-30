# Building GPC from source

Everything here is a plain command you type yourself. No AI, no IDE, no hidden steps.

Three tools, three commands, about a minute. If you only want to *use* the compiler, you don't need
any of this — grab the contents of `testing/` and read the [README](../README.md).

---

## 1. What you need

| Tool | Version | Why |
|---|---|---|
| **GNU make** | 4.x | drives everything |
| **64tass** | 1.60 | the 6502 assembler |
| **Python** | 3.8+ | code generators, the tokeniser, the test harnesses |

The emulator and ROM are already in the repo (`bin/x16emu/`, r49) — you don't install those.

> **Run the build from a POSIX shell.** On Windows that means **Git Bash**, not `cmd` and not
> PowerShell. Every recipe in the tree is POSIX, and `documents/common.make` forces `SHELL := sh`
> to make that work. From `cmd` you will get a wall of syntax errors that look like build failures
> and are not.

### Windows setup, start to finish

```sh
winget install ezwinports.make          # GNU make
# download 64tass and unzip it somewhere, e.g. C:\8bitProgramming\64tass-1.60
```

Then, in Git Bash, put both on `PATH`:

```sh
export PATH="$PATH:/c/Users/$USER/AppData/Local/Microsoft/WinGet/Links:/c/8bitProgramming/64tass-1.60"
```

Add that line to `~/.bashrc` so you don't repeat it. Check all three are visible:

```sh
make --version && 64tass --version && python --version
```

> `python3` is deliberately **not** used. On Windows it resolves to the Microsoft Store stub, which
> is not a Python. `common.make` picks `python` on Windows and `python3` elsewhere.

### Linux / macOS setup

```sh
sudo apt install make python3        # or: brew install make python
# build or install 64tass 1.60 and put it on PATH
```

### If a machine needs different tool paths

Create `documents/local.make` (untracked, `-include`d by `common.make`) and override just what
differs:

```make
TASS   = /opt/64tass/64tass
PYTHON = /usr/local/bin/python3.12
```

---

## 2. Build it

### The whole thing, one command

```sh
./release.sh                    # full build, then package release/gpc-release-<n>.zip
./release.sh zip                # package the CURRENT testing/ build without rebuilding
```

**Use this to cut a release.** Doing the steps by hand is easy to get half-right: the trap is
`C.GPC.ERR.PRG`, the error-line helper, which is compiled in SHARED mode and therefore names the
runtime it was built against *inside itself*. Rebuild the engine without rebuilding that, and the
shipped helper hunts for a `GPC.RT.<old>.BIN` that is no longer in the release. `release.sh` runs
the steps in the order that avoids it, and refuses to package if any required file is missing.

### The steps, if you want them one at a time

```sh
make libs                       # the five bin/*.library files + testing/GPC.BIN (engine)
                                # NB: this BUMPS source/application/buildnum.txt
make release                    # stage the engine, GPC.INPUT and the samples into testing/
make -C source/runtime gpc-rt   # the shared runtime, testing/GPC.RT.<build>.BIN
make -C source/gpc release      # GPC.PRG and GPC.ERR: both tokenised, then compiled SHARED
                                # (builds gpc-rt itself -- the line above is now optional)
```

`testing/` **is** the build: it is what you copy to an SD card or point the emulator at. The zip
`release.sh` writes is a *subset* of it — the four files needed to run, the two `.BASL` sources
under `SRC/`, and the docs. Samples and scratch files stay behind.

Two of those targets need the **emulator** rather than the assembler, and the front end needs it
**twice**: `GPC.BASL` is written in GP.BASIC, so x16emu boots once for BASLOAD to tokenise it into
`GPC.SRC.PRG` and again for `GPC.BIN` to compile that into `GPC.PRG`. `GPC.ERR` is built the same
way. Neither needs Java or prog8.

`GPC.SRC.PRG` is compile-only — nothing in BASIC sits behind the GP tokens, so the ROM can neither
`LIST` nor `RUN` it. Only the compiled `GPC.PRG` can be launched, and being shared it needs
`GPB.RT.<n>.BIN` (the runtime **with** the GP handlers) beside it or it prints `?RT` and stops.

`make -C source/gpc` on its own builds `GPC.PRG` and the runtime it needs — it is the `release`
target that also handles `GPC.ERR`.

Then try it:

```sh
./x16emu.bat GPC.PRG            # Windows; the launcher points the emulator at testing/
```

### What lands where

| Artifact | Built by | Notes |
|---|---|---|
| `bin/*.library` | `make libs` | assembler libraries, not distributables |
| `testing/GPC.BIN` | `make libs` | the compiler engine; reads `GPC.INPUT` |
| `testing/GPC.IMG.<n>.BIN` | `make libs` | the runtime the engine streams into every self-contained object — **it cannot compile without this** |
| `testing/GPC.SRC.PRG` | `make -C source/gpc` | BASLOAD's output — compiler **input**, cannot be run |
| `testing/GPC.PRG` | `make -C source/gpc` | the front end you actually launch, compiled from the above |
| `testing/GPC.RT.<n>.BIN` | `make -C source/runtime gpc-rt` | shared runtime, SHARED mode only |

The engine build number in `source/application/buildnum.txt` **auto-increments on every
`make libs`**. That is expected; it is a daily-work counter, not a release version, and it is what
`GPC.BIN` prints next to `GPC SQUEALING...` so you can tell which engine you are running.

---

## 3. Test it

```sh
export SDL_VIDEODRIVER=dummy                     # headless -- see the warning below

make -C source/ifloat32 run                      # 32-bit float library
make -C source/polynomials run                   # log/exp/trig
make -C source/unit-tests/compiler-runtime all   # six randomised compiler+runtime suites
python source/unit-tests/shared-runtime/shared_test.py   # SHARED mode, cold + warm
```

**How to read the result.** These suites do not print "PASS".

* **Pass** — the emulator exits by itself and prints
  `Dumping system memory. Reason: CPU program counter reached $ffff`.
* **Fail** — the test spins in an infinite loop and the emulator never exits.

So a suite that "hangs" has failed... **unless it simply needs longer**. The replay step
(`make -C source/runtime run`) is **not warped** — it runs at real X16 speed — and the `variables`
and `arrays` suites generate large randomised programs. Several minutes each is normal. Give them
at least 10 minutes before concluding anything.

> **Two things that will bite you.**
>
> 1. **Always set `SDL_VIDEODRIVER=dummy`.** Otherwise every emulator launch opens a window and
>    steals your keyboard focus mid-run. It changes no results — `-echo` and the file side effects
>    work identically.
> 2. **Never kill the emulator by image name.** No `taskkill /IM x16emu.exe`, no `pkill x16emu`:
>    other projects (and other windows of your own) run x16emu too, and you will kill those. Find
>    the specific PID first — `Get-CimInstance Win32_Process -Filter "Name='x16emu.exe'" |
>    Select ProcessId,CommandLine` on Windows — and stop only that one. Note also that x16emu
>    **ignores SIGTERM**, so `timeout` and a plain `kill` will not stop it; it lingers and locks
>    the object file, breaking your next build.

The suites are **randomised and unseeded**, so a bad case can show up roughly one run in thirty and
vanish on a retry. Do not dismiss an intermittent failure — loop it 30–40 times before calling it
a flake.

---

## 4. The memory map, when you need it

Two limits bound a compile. They are separate, and conflating them caused a long-lived bug where
oversized programs miscompiled in silence.

```
$0801 [ runtime ] $3700 [ compiler ] $5300 [ object code -> ... ] $9F00
                  ObjectBase         FreeMemory                   ObjectCeiling

banked RAM, bank 1:  $A000 [ variable names -> ... <- line numbers ] $C000
```

* **Object code** grows up from `FreeMemory` and may not reach `ObjectCeiling` ($9F00, where I/O
  starts). `_CAWriteByte` in `source/application/source/compiler/api.asm` enforces it.
* **The compiler's two tables** live in **banked RAM**, reached through the
  `storage_access` / `storage_release` macros in
  `source/compiler/source/system-specific/x16/x16_storage.inc`.

Both are declared in one place —
[`source/application/source/compiler/start.asm`](../source/application/source/compiler/start.asm) —
and the comment there explains why. `FreeMemory` is simply the end of the engine binary, so **every
256 bytes the compiler itself grows costs a user 256 bytes of program budget**. Re-derive the real
numbers from `source/application/build/code.lbl` after a build rather than trusting any figure
written down elsewhere:

```sh
grep -E '^(FreeMemory|ObjectBase|ObjectCeiling)' source/application/build/code.lbl
```

---

## 5. Two emulators, and why

| | Directory | Used for |
|---|---|---|
| **x16emu r49** | `bin/x16emu/` | all automated tests (`x16emu.bat`) |
| **Box16** | `bin/box16/` | interactive debugging (`box16.bat`) |

They need incompatible `SDL2.dll` versions, which is why each has its own directory. They are not
interchangeable:

* The test `.prg` files are raw machine code at `$0801` with no BASIC stub. Given
  `-prg code.prg,801 -run`, x16emu **SYS**es to the load address; Box16 issues **`RUN`**, which
  gives `?SYNTAX ERROR` — so every suite appears to hang under Box16.
* The host-directory flag is `-fsroot` on x16emu but **`-hypercall_path`** on Box16.
* Box16 does not emulate VERA sprite collision, so anything reading `$9F27` must be run under
  x16emu.

If the emulator dies instantly with `SDL_OpenAudioDevice failed: WASAPI can't find requested audio
endpoint`, that is your sound hardware, not the build — add `-sound none`.

---

## 6. Troubleshooting

| Symptom | Cause |
|---|---|
| Wall of shell syntax errors | you are in `cmd`/PowerShell — use Git Bash |
| `python3: command not found`, or it opens the Store | Windows: it must be `python`; check `common.make` picked the Windows branch |
| `64tass: command not found` | not on `PATH`; add it or set `TASS` in `documents/local.make` |
| A suite never finishes | give it 10 minutes (the replay is unwarped); if it still hangs, it has genuinely failed |
| A build "succeeds" but the object is wrong | check for a stale emulator holding the file — see the kill-by-PID warning above |
| `?RT` when running a SHARED object | `GPC.RT.<n>.BIN` is missing or stale: `make -C source/runtime gpc-rt` |
| `PROGRAM TOO BIG` | the program genuinely exceeds the budget in §4 — it is a real limit, honestly reported |
