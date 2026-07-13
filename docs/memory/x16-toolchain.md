---
name: x16-toolchain
description: Toolchain paths and headless build/run recipe for X16 / Prog8 development on this machine
metadata: 
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

Toolchain (Windows, use via Git Bash paths):
- Java 19: `/c/dev/b4x/java19/bin/java.exe`
- Prog8 compiler jar: `/c/dev/CmdrX16/dos_tools/BLITZ-COMPILER/prog8c.jar` (v12.2.1; also `C:\8bitProgramming\prog8-12.2.1\prog8c-12.2.1-all.jar`)
- 64tass 1.60 at `/c/8bitProgramming/64tass-1.60` — Prog8 shells out to `64tass` by name, so put that dir on PATH.
- Emulator: `/c/8bitProgramming/x16emu/x16emu.exe`; ships ROM symbol maps (`basic.sym`, `kernal.sym`, …) and `rom.bin`.

Build a Prog8 program: `java -jar $PROG8C -target cx16 -out <dir> <src>.p8` → `<dir>/<name>.prg` (loads at `$0801`, BASIC stub SYSes to entry).

Headless test (testbench mailbox): program writes result bytes to `$0400+` then executes `stp`. Derive entry = decimal SYS addr at prg file offset 8 (`od -An -c -j 8 -N 6 prg | tr -cd 0-9`, format `%04X`). Run: `printf 'RUN <entry>\nRQM 0400\n...' | x16emu -testbench -warp -prg <prg>`; RQM hex replies come after the `STP` line. The sibling `../BLITZ-COMPILER/scripts/` has `env.sh`, `build.sh`, `assert-mailbox.sh`, `tokenize.py` (text BASIC → tokenized `.prg`). See [[gpc-project]].
