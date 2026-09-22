# Folding the `.OVL` into an EMBEDDED `.PRG`

**For the agent picking this up.** This is a worked plan, not a brief. The
investigation is done and the numbers below were measured on 21st Sep 2026, not
reasoned about. Read this, then start at Stage 1 — do not re-derive the
findings.

**Goal:** let a `GP.BANKED` region (and `GP.BANKEDSTR` text) work in an
EMBEDDED build by carrying the overlay inside the single `.PRG`. SHARED keeps
its separate `NAME.OVL` and does not change.

**Why it matters:** `samples/edit` must ship as one file, which today means no
regions, which means all 18 KB of its p-code sits in low RAM. The editor has
about 2.8 KB of p-code growth left before `PROGRAM TOO BIG`.

---

## Compact discipline — read this first

This task reads assembly across several large files and runs emulator builds
that print long transcripts. It will eat context fast.

- **Compact after every stage below, not at the end.** Each stage is sized to
  be a compact boundary. Cost is context size times turns, so a compact
  deferred across three stages is paid for on every turn of all three.
- The stage headings carry a `COMPACT HERE` marker. Honour them.
- **Never read whole:** `TODO.md` (3,377 lines), `GPC-BASIC/GP-BASIC.md`
  (1,813), `GPC-BASIC/GP-BASIC.GLOBALS.md` (524),
  `samples/GPB-MODS-TESTING/GPBMODS.BASL` (3,453), and the `_library.asm` files
  under `source/`. Grep for the name, then read ±40 lines. `CLAUDE.md` has the
  full table.
- Build runs print hundreds of lines. Keep the last ~20 and the numbers that
  matter (object size, `OK LOW CODE`, `LOW FREE`, the overlay `.nnn` sizes).
  Do not echo a whole log.

---

## What is already settled — do not re-investigate

**An embedded `.PRG` already carries an appended payload and already copies it
into a RAM bank at startup.** This is shipping code, not a proposal:

- `source/application/_library.asm:3330-3333` —
  > THE EMBEDDED BANK CODE, GP1.IMG.nnn.BIN, goes after the p-code from the
  > next page, and StartCode copies it to bank 1 as the program starts. It sits
  > in the frame stack gap and the workspace, which are unused until then, and
  > it is under MIN_WS_PAGES pages (genrtimage.py checks), so
  > PrepareObjectCode's room for the workspace is room for it.
- `ObjEmitBankCode`, `source/application/_library.asm:3399` — the writer. It is
  **embedded-only**: SHARED returns immediately, because that bootstrap loads
  `GP1.RT.nnn.BIN` from disk instead. It pads the object to a page boundary and
  appends `RTIMG_BANKLEN` bytes.
- `ObjReadBankCode`, `source/application/_library.asm:3345` — reads
  `GP1.IMG.nnn.BIN` in before the object is created.

So the job is **extending a path that works**, not proving one. That is the
single most important thing to carry into the work.

The `.OVL` format is trivial and self-describing, and a reader for it already
exists in `source/application/source/compiler/bootstrap2.asm` (the SHARED
bootstrap extension page at `$0900`):

    per region:  [bank byte] [page count] [that many pages]
    then:        [BXOVLEND]              ; = 1

`source/unit-tests/banktest3.py:89-99` walks that format in Python and is worth
reading as the concise spec.

---

## The three measured constraints

Reproduce any of these with `work/ovltest/` (see **Test rig** at the bottom).

### 1. The workspace is zeroed before the first BASIC statement

Appended bytes read back as `0` from BASIC — and they still read `0` under
`x16emu -randram`, which fills unwritten RAM with noise. **Zeros that survive
`-randram` were written, not left over.**

*Consequence:* the overlay must be consumed in startup, at the same point
`GP1.IMG` is consumed. Anything that tries to read it after the runtime is up
will find zeros. This is where the work goes; it is not a surprise, it is the
same place the existing mechanism works.

### 2. The ceiling is `$9F00`, with 4 KB reserved

`MIN_WS_PAGES = 16` (4 KB) — `source/common-source`, visible in
`source/unit-tests/shared-runtime/shared_test.py:61`. A blob ending *exactly*
at `$9F00` ran fine.

### 3. Overrunning `$9F00` FAILS SILENTLY — this is the one that bites

A blob running **8 KB past `$9F00`**, through the I/O page and into the `$A000`
bank window, **still ran to completion with no error whatsoever.**

*Consequence:* the fit check must be a compile-time refusal. There is no
runtime symptom to catch, no crash to debug, and a near-miss will scribble on
VERA registers and a RAM bank while appearing to work. **Do not defer this
check to "later" — it is the difference between a contained change and a
three-hour bug hunt.**

---

## The design

Mode-driven, no new flag:

| | SHARED | EMBEDDED |
|---|---|---|
| overlay | separate `NAME.OVL`, unchanged | appended to the `.PRG` |
| reader | `bootstrap2.asm` opens the file | walks it in RAM, no file I/O |

**A program with no regions has no overlay and so compiles byte-identically to
today.** That is the regression safety, and it comes free — gated by "does this
program have regions", not by a switch. It is strictly better than an option
because there is no off-path to rot.

Keep writing the `.OVL` exactly as now and concatenate it at end-of-compile.
Region pages are flushed mid-compile at `BLC_REGIONDONE`
(`source/compiler/source/main/compiler.asm:655`, *"out to its own overlay while
the bank still holds it"*), so appending inline would interleave with the
p-code write cursor. Concatenating at the end avoids that entirely.

### The payoff is self-consistent

Worth understanding before starting, because it looks circular and is not.
Moving 8 KB of p-code into a region **shrinks the image by 8 KB**, which moves
the workspace start down by 8 KB — which is exactly the transient room the 8 KB
overlay needs while it is copied out. For the editor:

    today            image ends $8580, 6,528 bytes to $9F00
    with one 8K region   image ends ~$6580, overlay lands ~$8582,
                         ceiling $9F00 - 4K = $8F00          -> fits

`LOW FREE` should rise by roughly the 8 KB moved. **Confirm that from the
compiler banner rather than trusting this arithmetic** — see *Reading the
banner* below.

---

## The work

### Stage 1 — read the two halves properly  · COMPACT HERE when done

Nothing is written in this stage. The estimate below is held at *moderate*
confidence precisely because this reading has not been done.

1. `ObjEmitBankCode` body, `source/application/_library.asm:3399-3437`. How it
   pads to the page boundary, how it appends, what it does in SHARED.
2. `StartCode`'s copy of the bank code into bank 1. Grep for `StartCode`.
   Establish **exactly when the workspace is zeroed relative to that copy** —
   constraint 1 above says it is zeroed, this finds the instruction.
3. `bootstrap2.asm` region-placement loop, and which part is file I/O
   (`X16_SETNAM` / `X16_SETLFS` / `X16_OPEN` / `CHRIN`, plus the `BXNAMEMAX = 48`
   baked-in name) versus which part places pages into banks. The placement half
   is what gets reused; the I/O half is what gets dropped.

**Output:** a short note naming the insertion point in the writer, the copy
point in startup, and the reusable half of the reader. Then compact.

### Stage 2 — the fit check, alone  · COMPACT HERE when done

Do this **before** the feature, not after. It is small, it is the one guaranteed
silent failure, and landing it first means every later stage is protected.

- New compile-time refusal when `image end + overlay length > $9F00 - (MIN_WS_PAGES * 256)`.
- Follow the existing error idiom: `jsr CallErrorHandler` followed by inline
  `.text "...", 0`. See `GPBankNeedsShared`,
  `source/compiler/source/commands/gpbank.asm:998-1000`.
- **Register the message with the test harness.** `banktest3.py:16-36` scrapes
  error strings out of `source/common-source/source/generated/errors.asm` *and*
  out of every `CallErrorHandler` + `.text` pair under `source/compiler` and
  `source/application`. A compiler-space message is found by that second scan,
  so the inline form above is what makes a rejection test work.

**Acceptance:** a deliberately oversized program is refused by name. Add it to
`BAD` in `banktest3.py`.

### Stage 3 — writer: append the overlay  · COMPACT HERE when done

At end-of-compile, for EMBEDDED only, stream the `.OVL` onto the object and
delete it. Record whatever the reader needs (length and/or offset) where the
startup code can see it.

**Acceptance:** an embedded program *with* a region produces one file whose
tail is byte-identical to the `.OVL` a SHARED build of the same source
produces. Compare with `banktest3.py`'s `overlays()` walker
(`banktest3.py:89-99`) pointed at the object's tail.

### Stage 4 — reader: walk it in RAM  · COMPACT HERE when done

The embedded variant of `bootstrap2.asm`: delete the `SETNAM`/`SETLFS`/`OPEN`/
`CHRIN` path and the 48-byte name, walk memory instead. **The region loop —
bank byte, page count, copy, repeat until `BXOVLEND` — is unchanged.**

This variant is strictly *smaller* than the shared one, so it cannot outgrow
its page. That matters: the extension page is pinned and the constant is
checked at both ends with `.cerror`
(`source/common-source/_library.asm:340-353`, *"THE ADDRESS IS PINNED BY THIS
CONSTANT AND CHECKED AT BOTH ENDS"*), with `GPBSTRBANKS` sitting at `$09F0`.
**The classic version of this bug fails at assembly time, not at 3am.**

### Stage 5 — lift the refusals, LAST  · COMPACT HERE when done

Only now. Two sites, the same three instructions on the same `gpBankShared`
flag:

- `source/compiler/source/commands/gpbank.asm:83-87` — `CommandGPBankedCompile`,
  `lda gpBankShared / bne _CGBCShared / jmp GPBankNeedsShared`
- `source/compiler/source/commands/gpbstr.asm:80-82` — same shape for
  `GP.BANKEDSTR`

Consider lifting **`GP.BANKED` only** in the first landing and leaving
`GP.BANKEDSTR` refused. It halves the surface, and code regions are the bigger
prize (most of 18 KB of p-code, against ~900 bytes of text).

---

## Regression suite — this already exists, use it

`source/unit-tests/banktest3.py` is the `GP.BANKED` suite: ~30 programs in
`work/banktest3/`, compiled and run, marked-versus-control output comparison,
rejection tests, overlay-content checks, and a truncated-overlay test
(`BNKOVL` must stop with `?OVL`). Run it after **every** stage:

    & "C:\Program Files (x86)\Python314-32\python.exe" source\unit-tests\banktest3.py

It must stay at `ALL PASS` throughout, because every one of its programs is
SHARED and **SHARED must not change at all**. That is the single best guard
against this work leaking sideways.

Then add embedded pairs: each existing `BANKx` program compiled `--embedded`,
printing the same output as its SHARED build.

---

## Tripwires

- **`GP.ASM` needs `#INCLUDE "GPB.INC.BL"`**, which carries
  `#TOKEN GP.ASM 52826` (`GPB.INC.BL:377`). Without it BASLOAD treats `GP.ASM`
  as a *variable name*, the block is never assembled, and **nothing reports
  it**: tokenise passes, compile prints `OK LOW CODE`, and the program throws
  `SYNTAX ERROR @ $nnnn` at run time. The tell is the symbol file listing
  `GP.ASM` under VARIABLES. This cost two compiles during the investigation.
- **A failed compile can still print `OK`.** A statement the compiler cannot
  compile is rolled back into a `.deferror` throw-stub. Find them with
  `python source\common-scripts\deferscan.py OBJ.PRG <codelen> OBJ.MAP`, where
  `codelen` is the `OK LOW CODE nnnn` from the banner.
- **`build_basl.py` does not notice an edited `#INCLUDE`.** Delete
  `NAME.SRC.PRG` before re-tokenising or you will compile the old source.
- **Kill `x16emu` by PID only, never by image name** — other emulators run on
  this box. Both build scripts already do this; keep any new one doing it.
- **Do not run the emulator demos** (`help-demo.bat`, `bmx-demo.bat`,
  `menu-demo.bat`, `editor-demo.bat`). The user tests those personally.
- A second dot in a filename breaks `x16emu -prg`: `OVLA.TEST.PRG` reaches the
  drive as `:*` and loads nothing. Use single-dot names.

---

## Reading the banner

The banner is the authoritative memory report and the build script **deletes
it on success** (`source/gpc/compile_shared.py:201`). To capture it, run the
compile as a background job and poll-copy the log while it runs:

```powershell
$job = Start-Job -ScriptBlock { param($PY,$ROOT,$T)
  & $PY "$ROOT\source\gpc\compile_shared.py" --drive $T --embedded IN.SRC.PRG OUT.PRG OUT.MAP
} -ArgumentList $PY,$ROOT,$T
while($job.State -eq "Running"){ Start-Sleep -Milliseconds 400
  if(Test-Path "$T\GPCCOMP.LOG"){ try{ Copy-Item "$T\GPCCOMP.LOG" $keep -Force }catch{} } }
Receive-Job $job; Remove-Job $job
```

What the fields mean (`GP-BASIC.md` §7, lines 2729-2799): `LOW FREE` is *"what
is left in low memory for variables, strings and arrays — the number that runs
out"*. **`LOW FREE` minus 4,096 is how much more low-memory p-code will fit**,
because `WriteObjectCode` refuses to leave less than 4 KB of workspace.

---

## Test rig

`work/ovltest/` — built for the investigation, kept for re-verification.
Nothing in the repo proper was modified.

| file | does |
|---|---|
| `OVLA.BASL` | walks low RAM in 1 KB steps and prints what it finds |
| `ovlblob.py` | appends a known pattern to an object; `--over` deliberately overruns `$9F00` |
| `runovla.py` | runs a `.PRG` headless and prints its output; extra args pass to the emulator, e.g. `-randram` |

    $T = "work\ovltest"
    & $PY source\gpc\build_basl.py --drive $T OVLA.BASL OVLA.SRC.PRG
    & $PY source\gpc\compile_shared.py --drive $T --embedded OVLA.SRC.PRG OVLA.PRG OVLA.MAP
    & $PY $T\ovlblob.py $T\OVLA.PRG 16384
    & $PY $T\runovla.py OVLAT.PRG PDONE -randram

---

## Estimate

**1–3 days**, at moderate confidence — the writer and reader halves both exist,
but Stage 1's reading has not been done and that is what would firm it up.

The staging is deliberately ordered so the riskiest unknown is cheap and early
and the irreversible step is last: read (Stage 1), guard (Stage 2), write
(Stage 3), read back (Stage 4), and only then open the gate (Stage 5). Nothing
before Stage 5 changes the behaviour of any program that compiles today.

---

## Environment

- `python` resolves to the Microsoft Store alias stub. Use
  `C:\Program Files (x86)\Python314-32\python.exe`.
- `git` is not on PATH. Use `C:\Program Files\Git\cmd\git.exe`.
- Uncommitted before this work started: `samples/edit/*` and
  `source/gpc/compile_shared.py` (an opt-in `--strip` flag for dead-code
  removal). `main` was 1 commit ahead of `origin/main`.
