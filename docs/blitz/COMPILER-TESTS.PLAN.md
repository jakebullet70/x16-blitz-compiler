# Compiler tests in two tiers

Plan. Agreed 13 September 2026. Steps 1 to 4 done, and the lookup fix that section 5 found.

One runner, `source/unit-tests/gpctest.py`, replaces running `dcref.py chk`, `dcref.py chk --dead`,
`dcstrip.py` and `dctest.py` by hand. A quick tier runs after every compiler change in about 2
minutes. A full tier runs before a commit in about 3. Section 5 is a separate measure-only step.

## 1. Measured cost

Wall seconds per compile, as logged on 13 September under a pool of six emulators. The same
compile varies by up to 40% between runs.

| group | option off | option on | on + stripped |
|---|---:|---:|---:|
| 15 small: CHAINTST, CHAINTST-E, GPCTEST, GPCTEST-E, RGN, GPC, FORMEXP, MENUDEMO, MENUTST, COLORTST, MENUEXP, RGT, GUI2TST, GUIEXP, RGL | 182 | 137 | 332 |
| GUIFRMT, GPB.HELP, XBASE | 398 | 331 | 784 |
| RGM | 458 | 411 | 289 |
| GPBMODS | 367 | 509 | — |
| RGX, GPBJ, GPBH, GPBK, GPBL, GPBF, GPBR | 3,335 | 1,334 (RGX, GPBF, GPBR) | 300 (RGX) |
| DC1–DC12 | — | — | 199 |

Sources: `work/dcref-chk-off6.log`, `work/dcref-chk-dead4.log`, `work/dcstrip6.log`.

- GPBJ, GPBH, GPBK, GPBL, GPBF and GPBR are `GPBMODS.BASL` cut off at 2,085 to 3,425 lines. RGM
  and RGX are GPBMODS's library with a stub main. All eight write the same B04–B08 overlay sizes.
- Compile time follows the library, not the line count: RGM has 1,765 lines and takes 458 s, RGL
  has 3,431 lines and takes 16 s.
- A full session today is about 20,000 emulator-seconds and runs 2–3 hours.

## 2. The test set

- `dcref.PROGRAMS` loses RGX, GPBJ, GPBH, GPBK, GPBL, GPBF, GPBR, XBASE, CHAINTST and CHAINTST-E.
  Their sources in `testing/` and their inputs in `work/dcref/inputs/` stay on disk.
- CHAINTST tested the variable carry across a LOAD chain, which runtime 121 removed.
- `dcstrip.SLOW` and `--all` are deleted. All four of their programs are gone.
- 17 programs remain, plus DC1–DC12.

| tier | compiles |
|---|---|
| quick | the 13 small programs: off, on, stripped |
| | GUIFRMT, GPB.HELP: off |
| | GPBMODS: off, on |
| | DC1–DC12: `dctest` check and `dcstrip` identity |
| full | all 17 programs: off, on, stripped |
| | DC1–DC12: `dctest` check and `dcstrip` identity |

Measured on 13 September with `GPC.BIN` of 28,563 bytes, 7 workers, every check identical:

| tier | jobs | emulator-seconds | wall | set by |
|---|---:|---:|---:|---|
| ref | 40 | 2,674 | 597 s | GPBMODS on, 597 s |
| quick | 54 | 1,906 | 562 s | GPBMODS on, 562 s |
| full | 60 | 4,326 | 1,040 s | GPBMODS on then stripped, 781 + 258 s |

- ref and full ran with XBASE still in the set. XBASE took 364 of ref's emulator-seconds and 642
  of full's. Without it full is about 3,700 emulator-seconds; the wall does not move, because
  GPBMODS's one job sets it.
- CHAINTST and CHAINTST-E left after these runs, so quick is now 50 jobs and full 54.
- Logs: `work/gpctest-ref.log`, `work/gpctest-full.log`, `work/gpctest-quick.log`.

## 3. Three compiles a program

For program P:

1. **off** — compile P with the option off. Compare the PRG, MAP, every `.Bnn` and the OK line
   against `ref/off/P`.
2. **on** — compile P with the option on. Compare the PRG, MAP, every `.Bnn`, `D.P` and the OK line
   against `ref/on/P`.
3. **stripped** — delete `D.P`'s lines from P's source, compile with the option off, and apply the
   `dcstrip` identity against compile 2. When `D.P` is empty the stripped source is P, so the
   identity runs against compile 1 and there is no third compile.

Compiles 1 and 2 are separate pool jobs. Compile 3 runs in compile 2's job, after it.

Compile 1 is `dcref chk`. Compile 2 is `dcref chk --dead`. Compiles 2 and 3 are `dcstrip`.

A DC test is one pool job that calls `dctest.check` unchanged. The DC identity is one pool job
that calls `dcstrip.one`. A DC program compiles twice with the option on, once for each check.

## 4. The runner

    gpctest.py ref    [--gpc FILE] [--only A,B]
    gpctest.py quick  [--gpc FILE] [--only A,B]
    gpctest.py full   [--gpc FILE] [--only A,B]

- `ref` runs compiles 1 and 2 for all 17 programs and writes `work/gpctest/ref/off/<tag>/` and
  `work/gpctest/ref/on/<tag>/`. Run it with the compiler from before the change. The first use of
  `quick` or `full` needs one `ref` run.
- Every compile in a run shares one `ThreadPoolExecutor` of 7 workers.
- Jobs go in slowest first: GPBMODS, RGM, GPB.HELP, GUIFRMT, then the rest, a program's on
  job before its off job, and the DC tests last.
- Output is one line per check as it finishes, then `PASS` or `N FAILED` and the wall time. The
  exit code is 0 on `PASS`.
- Drives: `work/gpctest/off/<tag>/`, `on/<tag>/` and `stripped/<tag>/`, with the stripped source in
  `in-stripped/<tag>/`. DC tests keep `work/dctest/` and `work/dcstrip/`.
- It imports `split`, `tag`, `outputs`, `snapshot` and `compile_one` from `dcref`; `strip`,
  `identity` and `one` from `dcstrip`; and `EXPECT` and `check` from `dctest`. `identity` is the
  comparison split out of `dcstrip.one`. The three scripts keep their command lines.
- One run at a time. A second runner, or any other emulator job, oversubscribes the 8 cores.

Not in either tier: `banktest3.py`, `fntest.py`, `bstrtest.py`, the `compiler-runtime` make targets,
`md5` and `shared-runtime`. Each runs with the feature it covers.

## 5. Measure: where the library's compile time goes

Measure only. No asm, no compiler change, and no fix without a separate yes.

- The compiler prints a dot every 64 source lines in each pass (`ShowProgress` in
  `source/compiler/_library.asm`), and `PASS n` before each pass.
- `-echo raw` copies every character to the host's stdout, with the object and map bytes written
  through CHROUT between them.
- BASLOAD numbers BASIC lines 1, 2, 3 … so dot k of a pass ends at BASIC line 64k.

**M1. Time the dots.** A probe script runs one GPBMODS compile, option off, with no other emulator
running. It polls `CMP.LOG` every 0.1 s and records the time of each new dot and each `PASS n`. First
check that the dots reach the file as they print and not in 4 KB blocks. If they arrive in blocks,
go to M3.

**M2. Map dots to source.** Turn each 64-line span into a file and line range with the
`dclines.py` method (`source/application/COMPILER-HANDOFF.md` section 5). Output: seconds per span
for each pass, and seconds per include file, highest first.

**M3. Fallback: bisect.** Split RGM's `#INCLUDE` list in halves. Tokenise and compile each half in
its own `work/` drive. Output: seconds per module.

**M4. Report.** List the slow files and line ranges, which pass the time falls in, and what those
lines hold: `GP.ASM` blocks, `GP.BANKEDSTR` groups, label count, `$CE` tokens. Stop there.

### Result, 13 September

One GPBMODS compile, option off, alone: 317 s. Pass 1 took 153 s and pass 2 took 164 s. The same
compile took 448 s in the quick tier's pool.

- The dots reach `CMP.LOG` one at a time, not in 4 KB blocks. M3 was not needed.
- A dot counts main-loop lines only. `GP.ASM` and `GP.BANKEDSTR` read their own body lines, the
  closer included, without `ShowProgress`. GPBMODS has 4,096 BASIC lines: 2,902 main-loop lines
  give 45 dots, and 1,194 lines are block bodies. The mapping allows for this. It predicts 45 dots
  and 45 printed. The label walk agreed on 426 of 426 pairs.
- `CMP.LOG` stops growing 11 times in pass 1, for 149 of its 153 s, and at the same 11 places in
  pass 2, for 152 of its 164 s. Each stop is a span that holds a `GP.ASM` block. A span without one
  takes 0.3 s or less.

| `GP.ASM` blocks, by opener line | pass 1 s | pass 2 s | statements | label refs | `{VAR}` | pass 1 s per `{VAR}` |
|---|---:|---:|---:|---:|---:|---:|
| STASH.INC.BL 126, 186, 217 | 12.2 | 18.3 | 43 | 6 | 14 | 0.87 |
| SHIM.UTILBANK.INC.BL 139 | 1.6 | 2.2 | 5 | 0 | 2 | 0.80 |
| STRCASE.BANK.INC.BL 87, STRINGS.BANK.INC.BL 219 | 12.6 | 11.1 | 89 | 21 | 10 | 1.26 |
| SORT.BANK.INC.BL 105 | 39.8 | 43.0 | 136 | 31 | 36 | 1.11 |
| SHIM.THEMEBANK.INC.BL 119 | 2.8 | 2.8 | 5 | 0 | 2 | 1.40 |
| SHIM.GUIBANK.INC.BL 160 | 2.6 | 3.5 | 5 | 0 | 2 | 1.30 |
| SHIM.COMBOBANK.INC.BL 90 | 3.3 | 4.1 | 5 | 0 | 2 | 1.65 |
| SHIM.FUTILBANK.INC.BL 128 | 3.0 | 4.5 | 5 | 0 | 2 | 1.50 |
| FILEIO.BANK.INC.BL 374 | 3.1 | 4.1 | 27 | 7 | 2 | 1.55 |
| FILEDIR.BANK.INC.BL 235, 374 | 63.8 | 54.8 | 180 | 34 | 37 | 1.72 |
| GPBMODS.BASL 2748 | 4.3 | 3.5 | 5 | 0 | 2 | 2.15 |
| total | 149.1 | 151.9 | 505 | 99 | 111 | |

Blocks that fall in one span share one row.

- The time follows the `{VAR}` references, not the statements or the labels. FILEIO's block has
  27 statements and 2 references and takes 3.1 s, the same as a five-statement shim with 2.
- The cost of one reference follows where its name sits in the symbol file. Divide the pass 1
  seconds per reference by the mean byte offset of the names in `GPBMODS.SRC.SYM`: every row gives
  0.24 to 0.35 s per 10 KB. The file is 73,620 bytes, its `VARIABLES` section starts at byte
  30,857, and GPBMODS.BASL's own names come last.
- The code agrees. Each `{VAR}` calls `BLC_SYMLOOKUP`. `SymbolLookup` in
  `source/application/_library.asm` opens the symbol file and reads it line by line, from the
  banner to the name. Nothing is kept between calls, and both passes do it: 222 opens and reads
  for 111 references, 301 of the 317 s.
- The `GP.BANKEDSTR` groups and the `$CE` tokens cost nothing that shows at 0.1 s.
- Not measured: RGM, and the option on. RGM carries the same library blocks. The option on adds
  pass zero, a third set of lookups, which fits GPBMODS on taking longer than off in every tier.

Scripts: `source/unit-tests/gpcprobe.py` for M1 and `source/unit-tests/gpcspans.py` for M2.

Logs: `work/gpcprobe-m1.log`, `work/gpcprobe-m2.log`, `work/gpcprobe/GPBMODS/probe.json`.

### Fix, 13 September

`source/application/source/compiler/symfile.asm` reads the symbol file once a compile. The first
`{VAR}` copies every `VARIABLES` entry into RAM banks 13 and 14: the name, a zero, and the two bytes
of the crunched name. Every later lookup searches the banks. `CompileCode` resets the state. Names
that do not fit both banks fall back to reading the file for each lookup, as before. GPBMODS's
names take 8,656 of the 16,384 bytes. `GPC.BIN` is 28,911 bytes, 348 more.

| | before | after |
|---|---:|---:|
| GPBMODS off, alone | 317 s | 19.8 s |
| pass 1 | 153 s | 5.0 s |
| pass 2 | 164 s | 14.0 s |
| quick tier, 54 jobs, wall | 562 s | 115 s |
| full tier, wall | 1,040 s | 170 s |

- GPBMODS's object, map and `.Bnn` files are identical to `ref/off`. Every quick-tier and
  full-tier check passes. The full tier had 60 jobs before and 58 after, since XBASE left it.
- The fallback was forced with GPBMODS's symbol file padded to 87,220 bytes by 400 extra names.
  That compile takes 336 s (pass 1 173 s, pass 2 163 s) and its output is identical to `ref/off`.
- Logs: `work/gpcfast/probe-fast.log`, `work/gpcfast/probe-big.log`, `work/gpctest-quick-fast.log`,
  `work/gpctest-full-fast.log`.

## 6. Order of work

1. Trim `dcref.PROGRAMS`. Delete `dcstrip.SLOW` and `--all`. Correct the header of `dctest.py`,
   which still says the OK line "ends DEAD <lines> <bytes>".
2. Write `gpctest.py`.
3. Acceptance: `gpctest.py ref`, then `gpctest.py full` and `gpctest.py quick` with the same
   `GPC.BIN`. Every check reads identical. Put the measured times into the section 2 table.
4. Section 5.

Emulator runs go in the background. Each step ends with a short report.
