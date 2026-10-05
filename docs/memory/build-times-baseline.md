---
name: build-times-baseline
description: "Expected build times for each program; time every build and flag one that runs 2x over, since a slow build is a defect the user has caught three times"
metadata:
  node_type: memory
  type: feedback
  originSessionId: d662cdc7-bff8-47b0-95f7-b4086f5383d3
  modified: 2026-10-05T04:05:25.114Z
---

Time every build and compare it with this table. A build that takes twice its normal time is a defect: stop and say so before reporting success. The user has caught a bad build three times that a clock would have shown.

| build | step | normal | measured |
|---|---|---|---|
| GPBMODS | tokenise (build_basl.py) | about 50 s | 52 s on 2026-10-05 |
| GPBMODS | compile (compile_shared.py) | about 40 s | 38 s on 2026-10-05, SHARED PRG 13,069 B, OVL 51,483 B; the user's older figure was about 20 s |
| GPBMODS | compile --strip (compile_shared.py) | about 45 s | 43 s on 2026-10-05, PRG 13,065 B, OVL 49,691 B, 276 lines removed |
| TURBO | tokenise (build_basl.py) | about 55 s | 54 s on 2026-10-05 |
| compiler tests | `gpctest.py full` | about 180 s | 183 s on 2026-10-05 with every compile stripping by default; 158 s earlier that day |
| GPC.PRG | `make -C source/gpc`, tokenise and compile | about 10 s | 10 s on 2026-10-05, 1,551 B |
| current programs | `source/scratch/step4.py`, stripped identity on 15 programs | about 3 min | 178 s on 2026-10-05, plus 54 s to tokenise TURBO |
| TURBO | compile (compile_shared.py) | about 45 s | 45 s on 2026-10-05; 10-15 min when the {VAR} cache overflowed, see [[turbo-compile-slow-open]] |

`TURBO-GPC/build.py` prints `took N s` after each step, and before the compile it prints how much of the {VAR} cache TURBO's names need. The cache is 32,768 bytes (banks 24-27); TURBO needs 16,423.

**Why:** the user said on 2026-10-05 that keeping a record of compile times would have caught each bad build.

**How to apply:** put the step times in every build report. Add a row the first time a program is built. A hand compile in a `.bat` window runs without `-warp` and is slower, so do not compare it with these figures.
