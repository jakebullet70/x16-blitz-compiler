# Embedded and shared object modes

Research for selective handler inclusion, item 2 in `TODO.md` `## Compiler work — what is next, ranked`.
Checked 2026-09-14 at `462b2ae`: runtime 122, `RT_ABI` 23. Paths are from the repo root.

Build 123 (`RT_ABI` 24) moved the rarely used handlers to bank 1, and the figures below are build
122's. `GPBase` is now `$2F00`, `ObjectBase` `$3500`, `RTGPBASE` `$6F00` and `RTBASE` `$7700`;
step 27 of `docs/blitz/HANDLER-BANK.PLAN.md` has the new p-code caps.

## 1. Selecting the mode

`GPC.INPUT` line 4 selects the mode. `S` (`SHARED`) gives a shared object, blank an embedded one
(`source/application/source/compiler/object.asm:68-73`).

## 2. Side by side

| | Embedded | Shared |
|---|---|---|
| Object holds | the runtime from `GPC.IMG.122.BIN`, then the p-code | a 255-byte bootstrap, then the p-code |
| Runtime sits | low, `$0801` up to the cut | high, loaded from its own file |
| P-code starts | `$3700` with no GP keyword, `$3D00` with one | `$0900`, or `$0A00` with a `GP.BANKED` region |
| Files to run | the object | the object and `/GPB.RT.122.BIN` or `/GPC.RT.122.BIN` |
| LOAD chain | every program carries its own runtime | a resident runtime is reused, no LOAD |
| Runtime ABI change | built programs are unaffected | every shared program needs a recompile |
| `GP.BANKED`, `GP.BANKEDSTR` | refused, the object is one file | supported, `.nnn` files |

## 3. Embedded

- The object is the image from `$0801` up to the cut, then the p-code on the next page.
- The cut is `GPBase` (`$3700`) when `gpUsed` is 0 and `ObjectBase` (`$3D00`) when it is 1
  (`object.asm:75-86`, `source/application/rtimage.gen.asm:5-6`). `GPScanByte` sets `gpUsed` in
  pass one from the 32-byte `GPUsageBits` map (`source/application/source/compiler/gpscan.asm`).
- The core, `$0801`-`$3700`, is 12,031 B. The GP block, `$3700`-`$3D00`, is 1,536 B.
  `rtimage.gen.asm` gives `RTIMG_LENGTH` 13,567 B.
- The image is absolute code with no relocation. The compiler knows only what `rtimage.gen.asm`
  holds: the two bases, the load address and length, two patch offsets, and `GPUsageBits`.
- The copy patches `RunCodePage` and `RunWorkspacePage` in the image header.
- The image is streamed as one run and the p-code starts on the next page, so a cut can only drop a
  page-aligned tail that nothing below it calls into.
- 4 B are left below `GPBase`. Crossing it moves every embedded program's p-code up a page
  (`docs/memory/gpc-core-page-cushion-below-gpbase.md`).

## 4. Shared

- The object is a 255-byte bootstrap at `$0801` and p-code at `PCODE_PAGE` `$09`
  (`source/common-source/source/common.inc:149`).
- The bootstrap compares the 4-byte magic at `RTBASE`, and a second magic below it, and skips the
  LOAD when the runtime is resident (`source/application/source/compiler/bootstrap.asm:17-18, 60-72`).
- Otherwise it LOADs from the root directory (`bootstrap.asm:101-102, 283-290`; `common.inc:113-114`):

  | File | Holds | Loads at | Size |
  |---|---|---|---|
  | `GPB.RT.122.BIN` | GP handlers and core, for a program using a GP keyword | `RTGPBASE` `$6600` | 14,052 B |
  | `GPC.RT.122.BIN` | core only | `RTBASE` `$6E00` | 12,004 B |

- Both files come from one link. The core starts at exactly `RTBASE`, the GP block is padded up to
  it, and the top is guarded at `$9F00`.
- It jumps to `RT_ENTRY`, `RTBASE+4`, with the workspace end page in Y: `RTBASE>>8` without GP
  handlers, `RTGPBASE>>8` with them (`bootstrap.asm:188-192`, `common.inc:115`).
- `RT_ABI` 23 is the magic `GP23` (`common.inc:266`). `RTBASE`, `RT_ENTRY`, the token numbers and the
  runtime file name are fixed in every shared object.

## 5. Banked regions

- An embedded object is one file, and each region is a `.nnn` file. An embedded compile stops at
  the first `GP.BANKED` with `GP.BANKED NEEDS SHARED`, or at the first `GP.BANKEDSTR` with
  `GP.BANKEDSTR NEEDS SHARED`. Both read `gpBankShared`, which `CompileCode` sets from `GPC.INPUT`
  line 4 (`source/application/source/compiler/start.asm`).
- A banked program carries a second bootstrap page at `$0900`,
  `source/application/source/compiler/bootstrap2.asm`, which LOADs each region's `.nnn` file into
  its bank. Its p-code starts at `$0A00` (`bootstrap.asm:170-171`).
- An embedded object has no bootstrap to LOAD the `.nnn` files. A banked program ships its `.nnn`
  files anyway, so the runtime file beside them costs nothing.
- Region relocation in pass one needs the p-code run page. It is the shared constant `PCODE_PAGE`
  (`start.asm`).

## 6. Largest low p-code

From `docs/memory/gpc-blitz-runtime-slack-and-limits.md:140-143`:

| Mode | No GP keyword | GP keyword |
|---|---|---|
| Embedded | 20,480 (80 pages) | 18,944 (74) |
| Shared | 19,712 (77) | 17,664 (69), 17,408 with a banked region |

## 7. What a handler cut does in each mode

- **Embedded.** A byte cut from the image is a byte more for p-code. The `GPBase`/`ObjectBase` cut
  is the only cut built. Each further cut adds run pages. A banked program is unaffected, because
  it cannot be embedded.
- **Shared.** The runtime is one resident file at a fixed address. A smaller file frees nothing
  unless its load address moves, and a moved address is an `RT_ABI` change. `GPB.RT`/`GPC.RT` is the
  only cut built (`docs/blitz/GP-BASIC.TIERS.md`).
- **Shared, LOAD chain.** A runtime variant needs its own magic. The resident check skips the LOAD
  on a magic match, so a chained program would run on the previous program's handlers.

## 8. Unchecked and stale

- `common.inc:93-94` names the files `GPC.RT` (full) and `GPC.RC` (core). The bootstrap uses
  `GPB.RT` and `GPC.RT`.
- `docs/memory/blitz-x16-runtime-footprint.md` gives 10,956 B and `ObjectBase` `$3300`.
- `docs/blitz/GP-BASIC.TIERS.md` gives `RTGPBASE` `$6400`. `common.inc:113` has `$6600`.
- `docs/memory/gpc-core-page-cushion-below-gpbase.md` says the tests compile shared only, so no test
  sees an embedded page move. `gpc-blitz-runtime-slack-and-limits.md` cites an embedded report.
  Which mode `gpctest.py` uses is not checked.
- A scan found no core code calling into the GP block. No scan covers the hardware handlers in the
  middle of the core (`source/runtime/source/system-specific/x16/commands/`).
