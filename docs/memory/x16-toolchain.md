---
name: x16-toolchain
description: Toolchain paths and headless build/run recipe for X16 / Prog8 development on this machine
metadata: 
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

Toolchain (Windows, use via Git Bash paths):
- Java 17 (Temurin) is on PATH as `java`. Checked 2026-10-02.
- Prog8 compiler jar: `C:\8bitProgramming\prog8\prog8c-12.0.1-all.jar`. The same folder holds
  11.4.1, 12.0 and a 12.1 snapshot. The two 12.2.1 paths this note named are gone.
  `samplesbuild.py` names the jar in `PROG8C`. It accepts a source named `NAME.P8` and writes
  `NAME.prg`.
- 64tass 1.60 at `/c/8bitProgramming/64tass-1.60` — Prog8 shells out to `64tass` by name, so put that dir on PATH.
- Emulator: `/c/8bitProgramming/x16emu/x16emu.exe`; ships ROM symbol maps (`basic.sym`, `kernal.sym`, …) and `rom.bin`.

Build a Prog8 program: `java -jar $PROG8C -target cx16 -out <dir> <src>.p8` → `<dir>/<name>.prg` (loads at `$0801`, BASIC stub SYSes to entry).

Headless test (testbench mailbox): program writes result bytes to `$0400+` then executes `stp`. Derive entry = decimal SYS addr at prg file offset 8 (`od -An -c -j 8 -N 6 prg | tr -cd 0-9`, format `%04X`). Run: `printf 'RUN <entry>\nRQM 0400\n...' | x16emu -testbench -warp -prg <prg>`; RQM hex replies come after the `STP` line. The sibling `../BLITZ-COMPILER/scripts/` has `env.sh`, `build.sh`, `assert-mailbox.sh`, `tokenize.py` (text BASIC → tokenized `.prg`). See [[gpc-project]].

The emulator takes Ctrl+F and its other command keys, Ctrl+V to paste among them, before the program sees them. `-noemucmdkeys` leaves them to the program; `USER-RUNS/turbo-gpc-demo.bat` passes it so the editor gets Ctrl+F. Found 2026-10-03.
