# Compiler work — status

Updated 14 September 2026, on `main` after commit `cd57bab`. GPC is V1.1 on runtime 122. This file replaces `COMPILER-HANDOFF.md`, written at `3804728`.

Read this, then `## Compiler work — what is next, ranked` in `TODO.md` (line ~831). That list is
the index of what comes next; this file is the state of the tree and how to work in it.

---

## 1. State of the tree

- **Last compiler change: a GOTO into a region from outside it is refused.** `GOTO`, `GO TO`,
  `IF .. GOTO`, `IF .. THEN <line>` and `ON .. GOTO` into a `GP.BANKED` region, from low memory or
  from another region, stop the compile with `NOT IMPLEMENTED` in pass one. `GPBankGotoGuard` in
  `gpbank.asm` compares the bank of the target line with the bank of the current line;
  `CommandGOTO` and `CompileBranchCommand` (`goto.asm`) call it. The compiler's own GOTOs, the
  bridges and the prologue jump, are not checked, so falling into a region from the line above is
  still allowed and still works only when its bank is selected. Compiler only, 0 runtime bytes.
- **Before that: a call into a banked region selects its bank** (commit `cd57bab`, item 4
  in `TODO.md`). A `GOSUB`, `GP.SUB`, `GP.FN` or `FN` into a `GP.BANKED` region from outside it
  compiles to `.bgosub` (`$F5`). Its handler, `source/gp-runtime/source/commands/bankgosub.asm`,
  selects the region's bank and pushes a `FRAME_BGOSUB` (`$E5`) frame, so `RETURN` restores the
  caller's bank. The compiler side is `GPBankScanLines`, `GPBankLineCall` and `GPBankAddressCall`
  in `source/compiler/source/commands/gpbank.asm`. The `X.BANK.INC.BL` twins and the
  `SHIM.*BANK.INC.BL` files are deleted from both library copies. Record:
  `docs/memory/compiler-emitted-bank-switch.md`.
- **Refused with `NOT IMPLEMENTED`:** `ON n GOSUB` to a label in a region, because an `ON` entry is
  3 bytes and a `.bgosub` 4, and any `GOTO` into a region from outside it. `RESTORE` to a `DATA`
  line inside a region is not checked.
- **Sizes:** `GPC.BIN` is 29,252 B. The embedded core grew 12 B and has 4 B left before `GPBase`
  moves off `$3700`. GPBMODS builds with an 11,619 B resident object (was 12,885), GUIFRMT with
  3,538 B (was 4,098).
- **Before that:** the `GP.FN` string fix (`c55831e`), and `GP.ASM` reading the symbol file once a
  compile into RAM banks 13 and 14 (`798cfa7`, GPBMODS 317 s to 19.8 s). A slow GPBMODS or RGM
  compile now has a new cause; do not re-profile the symbol lookup first.
- **GPC.BIN copies:** `source/application/`, `testing/` and `samples/GPC-HELP/` hold the guard build,
  29,252 B, MD5 `2647c404…`. The runtime files built with it on 13 September (`GPC.RT.122.BIN`,
  `GPB.RT.122.BIN` and `GPC.IMG.122.BIN`) are in `testing/` and `samples/GPC-HELP/`.
  `samples/GPC-HELP/GPB.HELP.PRG` has not been rebuilt since. The copies under `release/TMP/` and
  `work/` are older, and both places are ignored.
- **Test references:** `gpctest.py full` passed on 14 September with the GOTO guard build in 181 s,
  and `banktest3.py` ALL PASS in 190 s.
  The GPBMODS and GUIFRMT inputs in `work/dcref/inputs/` are the merged sources, and their
  references were rebuilt with `acf427f1…`. The pre-merge inputs are kept in
  `work/dcref/inputs-premerge/`. The RGL, RGN and RGM inputs were refreshed for the guard and their
  references rebuilt with `acf427f1…`; the previous ones are in `work/dcref/inputs-preguard/`. The
  other references are older and still hold. The GPBF, GPBH, GPBJ, GPBK, GPBL, GPBR, RGX and XBASE
  files in `work/dcref/inputs/` are pre-merge leftovers and not in `dcref.PROGRAMS`.
- **GUIFRMT** includes bare module names, so it builds in `work/guifrmt/`, a drive holding the
  flattened library.
- **CHAINTST and CHAINTST-E left the test set** when runtime 121 removed the variable carry across a
  LOAD chain. The `CHAINTST*` and `XBASE` directories under `work/gpctest/ref/` are unused.

## 2. Open compiler items

From the ranked list in `TODO.md`, with anything added since:

| # | item | state |
|---|---|---|
| 0 | `GP.FN` string aliasing | FIXED 2026-09-13: `""` concatenated into a temporary, 3 B a string call site |
| 1 | Banked `GP.ASM` | costed at ~58 runtime bytes against 511 of headroom; waiting on a yes. `.bgosub` banks p-code only, and a `SYS` into a banked blob selects nothing |
| 2 | Selective handler inclusion | largest lever on program size; `## Shrinking the runtime` |
| 3 | Dead-code elimination | BUILT in V1.1. Plan: `docs/blitz/DEAD-CODE-ELIMINATION.PLAN.md` |
| 4 | Compiler emits the bank switch; delete the two-file module split | DONE 2026-09-14, `cd57bab`. A `GOTO` into a region from outside it is refused since, by `GPBankGotoGuard`. Possible extra: a call out of a region as `.bgosub` with its own bank |
| 5 | Pass one progress output | DONE 2026-09-13 |
| — | Compiler tests in two tiers | DONE 2026-09-13. `docs/blitz/COMPILER-TESTS.PLAN.md` |
| — | GP.ASM `{VAR}` lookup speed | FIXED 2026-09-13 |
| — | End-of-compile report: lines compiled, banks used per bank | `TODO.md` line ~919, BEFORE RELEASE |
| — | Show removed lines as source file and line | not started; `TODO.md` line ~921 and section 5 below |
| — | `BASLOAD-GPC` end-of-run report in the same shape | `TODO.md` line ~923, after the compiler's report is settled |

## 3. Building

Toolchain is off-PATH. In the Bash tool:

    export PATH=/c/8bitProgramming/make-4.4.1/bin:/c/8bitProgramming/64tass-1.60:/c/Users/Admin/AppData/Local/Programs/Python/Python313:$PATH

| what changed | command | writes |
|---|---|---|
| anything under `source/application/source/` | `make -C source/application build` | `source/application/GPC.BIN` |
| `source/compiler/` (compiler.library) | `make libs` at the root, then the application build | `bin/compiler.library` |
| the runtime, `source/runtime/` or `source/gp-runtime/` | `make -C source/runtime gpc-rt` as well as `make libs` | `testing/GPB.RT.nnn.BIN` and `testing/GPC.RT.nnn.BIN` |

- The application build does **not** rebuild `compiler.library`. `make libs` does not install the
  runtime.
- `bumpbuild.py` bumps neither `buildnum.txt` nor `rtbuild.txt`, so the runtime number stays at
  122. Item 4 changed the runtime and kept the number.
- A new compiler is copied over the other `GPC.BIN` copies only when the user asks. Never copy
  into `OASIS/`.

## 4. Testing a compiler change

The runner is `source/unit-tests/gpctest.py`. The plan and the measured times are in
`docs/blitz/COMPILER-TESTS.PLAN.md`.

    gpctest.py ref    [--gpc FILE] [--only A,B]
    gpctest.py quick  [--gpc FILE] [--only A,B]
    gpctest.py full   [--gpc FILE] [--only A,B]

- The set is `dcref.PROGRAMS`, 17 programs, plus the dead-code tests DC1–DC12.
- `ref` compiles every program with the option off and on, into `work/gpctest/ref/`. Run it with
  the compiler from before the change. The current references are good for the current build.
- `quick` and `full` check each compile against the references: the object, map, every `.Bnn` and
  the OK line; the removed-line list `D.NAME`; and the stripped-source identity (the option-on
  object equals the stripped source compiled with it off). Both also run `dctest` and `dcstrip`.
- `quick` leaves out RGM, compiles GUIFRMT and GPB.HELP with the option off only, and skips the
  stripped compile of GPBMODS. `full` runs every check on every program. Last measured: quick 115 s on
  13 September, full 147 s on 14 September.
- Output is one line per check, then `PASS` or `N FAILED`. The exit code is 0 on `PASS`.
- Seven workers share one pool. Run one `gpctest.py` at a time, and no other emulator job
  alongside it.
- `dcref.py`, `dcstrip.py` and `dctest.py` keep their own command lines and still run alone.
- `gpcprobe.py [NAME [INPUTS [DRIVE]]]` times one compile from its transcript and writes
  `probe.json`. `gpcspans.py DRIVE SYM` turns that record into seconds per source span and per
  file. Only programs built from the GPB-MODS-TESTING library map.
- `GPC.INPUT` has five lines: source PRG, object, map, `SHARED` or blank, and the removed-line
  file name or blank. A four-line engine stops at line four.
- Each compile runs in its own drive under `work/`. `testing/` is shared with other sessions.
- The banner is the finish line, not the file size (`docs/memory/compile-shared-timeout-fakes-success.md`).
- Samples build in place: `build_basl.py --drive DIR` and `compile_shared.py --drive DIR`.
  Do not stage a sample into `testing/`.
- `dcref.snapshot()` copies `testing/NAME.SRC.PRG` and `.SYM` into `work/dcref/inputs/` only when
  they are missing, so an input stays frozen. After a program changes, replace its two input files
  by hand and run `gpctest.py ref --only NAME`.
- **Banked regions:** `source/unit-tests/banktest3.py` runs each marked program against its unmarked
  control on `work/banktest3` and compares the output, `BANKY` included. The `.bgosub` harness was a
  scratchpad script and is not in the repo; its programs `BGA` to `BGD` are in `work/bgosub/`.
  The GOTO refusals are in `banktest3.py`: `BANKH` (GOTO), `BNKGA` (`IF .. GOTO`), `BNKGB`
  (`ON .. GOTO`), `BNKGE` (`IF .. THEN <line>`) and `BGD` (region to region), with the pair
  `BNKGC`/`BNKGD` for a GOTO inside a region and out of one. `BANKI` is no longer used. `BGA`/`BGB`
  and `BGC` are copied in from `work/bgosub/`, so `banktest3` alone covers the banked calls. A
  refused compile ends its emulator run on the error line; it used to wait out the 90 s timeout.
- `build_basl.py --drive DIR BASL PRG` and `compile_shared.py --drive DIR SRC OBJ MAP` build in the
  given drive. `build_basl.py`'s log still prints `testing/`.

## 5. Removed lines as source file and line — worked out, not in the repo

The D file lists tokenised BASIC line numbers, and a large `.SRC.PRG` cannot be LISTed. No
de-tokenised file and no asm are needed.

**Facts the method rests on:**

- BASLOAD numbers BASIC lines 1, 2, 3 … in output order. GPB.HELP has 1,595.
- Each entry in the `LABELS` section of `.SRC.SYM` is `SOURCELINE NAME =BASICLINE;` under a
  `FILE:` heading. The source line is decimal, the BASIC line decimal. Example:
  `000083 THEME.SELECT.X16 =8;` under `FILE: GPC-BASIC/THEME.INC.BL`.
- The `VARIABLES` section maps long names to the short ones in the PRG (`THEME.ID =A2;`).
- A source line makes no BASIC line if it is blank, starts with `#`, or is a label alone.

**Method:** for removed line N, take the label with the greatest BASIC line ≤ N, open its file at
its source line, and count forward over lines that make code until N is reached.

**Self-check:** walk from each label to the next label in the same file; they must agree. On
GPB.HELP, 176 of 185 pairs agreed. The 9 others are labels on the last line of an include
(`THEME.SKIP:` then `#ENDIF`, or `*.MODULE.END:`). Their BASIC number is the next file's first
line, so the walk runs off the end of the file. A dead line is never there. A stale `.SYM` makes
many pairs disagree.

**Plan (TODO.md, under the end-of-compile report):** add the script to the repo as `dclines.py`.
Run it from `build_basl.py` and `compile_shared.py` after a dead-code build. Group the output by
routine, for example `LINEINPUT.ASK  LINEINPUT.INC.BL 164-169  6 lines`. Prog8 has no such
utility.

`source/unit-tests/gpcspans.py` already uses the same SYM walk and self-check to map pass-1 time
to source lines. Its `is_code` and label walk are the parts `dclines.py` shares.

The prototype, run from the drive holding the three files:

```python
#   dclines.py NAME.SRC.PRG -- reads D.NAME.SRC.PRG, NAME.SRC.PRG's .SYM, and the sources.
import re, sys, bisect

prg = sys.argv[1]
sym = prg[:-4] + ".SYM"
dead = [int(n) for n in open("D." + prg).read().split()]

anchors = []                      # (basic, file, srcline, name)
section = file = None
for s in open(sym, encoding="latin-1"):
    if s.startswith(("LABELS", "VARIABLES")):
        section = s.strip()
    elif s.startswith("FILE: "):
        file = s[6:].strip()
    elif section == "LABELS":
        m = re.match(r"\s*(\d+)\s+(\S+)\s+=(\d+);", s)
        if m:
            anchors.append((int(m.group(3)), file, int(m.group(1)), m.group(2)))
anchors.sort()
names = {a[3] for a in anchors}

sources = {}
def source(f):
    if f not in sources:
        text = open(f, encoding="latin-1").read()
        sources[f] = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return sources[f]

def is_code(text):
    t = text.strip()
    if not t or t.startswith("#"):
        return None
    m = re.match(r"([A-Z0-9._]+):(.*)$", t, re.I)
    if m and m.group(1).upper() in names:
        t = m.group(2).strip()
        if not t or t.startswith("#"):
            return None
    return t

def locate(n):
    i = bisect.bisect_right([a[0] for a in anchors], n) - 1
    basic, f, line, label = anchors[i]
    lines, count, ln = source(f), basic, line
    while ln <= len(lines):
        if is_code(lines[ln - 1]) is not None:
            if count == n:
                return f, ln, label, n - basic
            count += 1
        ln += 1
    return f, None, label, n - basic

for n in dead:
    f, ln, label, off = locate(n)
    text = source(f)[ln - 1].strip() if ln else "?"
    print("%5d  %-28s %5s  %-22s %s" % (n, f, ln, "%s+%d" % (label, off), text[:60]))
```

`source/tools/detokenise/detokenise.py` also works on these PRGs, `$CE` tokens included. It prints
the short variable names, so use it only as a fallback.

## 6. Standing rules

- **Ask before writing asm.** Agree `GP.ASM` or 64tass first.
- **No unasked builds** and no help regeneration. **Never build PICKDEMO.**
- **Commit to `main` only when asked.** Stage by name, and never commit `OASIS/`.
- **Other agents run in this repo.** Re-read a file before writing it.
- **Do not edit `TODO.md` without asking.**
- **Run builds and emulator runs in the background.** Keep the last ~20 lines of output.
- Kill `x16emu` by PID only, and only an emulator you started.
- **Grep before reading these, never read them whole:** `TODO.md`, `GPBMODS.BASL`,
  `GP-BASIC.md`, `GP-BASIC.GLOBALS.md` and the `_library.asm` files.
- **Samples build in place.** Never stage a sample's sources or modules into `testing/`.
- **Library modules are edited in `samples/GPB-MODS-TESTING/GPC-BASIC/` first**, then copied whole
  to root `GPC-BASIC/`.
- **No work on XBASE.** It will be dropped.
- **Compact after every step.**
- **The user wants speed.** Act, report briefly, and don't survey options you will not pursue.
