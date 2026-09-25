# Stage 4 — the reader: walking the overlay in RAM

Status: **done, and it works.** An embedded program now copies its appended
regions into their banks before the runtime starts, and a probe reads them back
out of the bank byte for byte. Nothing in a shared build changed.

It also found the thing that still stops such a program *running*, which is not
in this stage and not in Stage 3 either. See *The blocker Stage 5 inherits* at
the bottom — the estimate of Stage 5 as "delete three instructions twice" is
wrong.

## What it does

`StartCode`, in the runtime image, gains a second copier beside the one that
moves the bank code into bank 1. It is handed the page the overlay was loaded
to, and walks it where it lies: a bank byte, a page count, that many pages into
`$A000` in that bank, repeated until `BXOVLEND`. Then it selects the bank the
program starts in and hands over to the runtime as before.

## Why `StartCode` and not a second `bootstrap2.asm`

The plan's sketch was an embedded variant of the bootstrap extension page with
the file handling cut out. That page does not exist in an embedded program.
It is `$0900` in a *shared* object, between the 255-byte bootstrap and the
p-code, and an embedded object has neither: it is the runtime image from `$0801`
and its p-code at `ObjectBase`. The one place an embedded program runs code
before the runtime starts is `StartCode`, which is already doing exactly this
job for the bank code — same shape, same registers, the same `stz` on its own
operand at the end.

So there is no new page, nothing new is pinned, and the `.cerror` pair that
pins `GPBSTRBANKS` against the shared extension page
(`source/common-source/_library.asm:340-353`) still guards the only page that
needs guarding. The shared reader is untouched.

## The code

`source/application/source/main/00rtimage.header` — the walk, inserted between
the bank-code copy and the handover:

- **`RunOvlPage`** — the operand the compiler patches with the overlay's page,
  zero for a program with no regions. Zeroed after the walk, exactly as
  `RunBankPage`'s is and for the same reason: the regions sit *in* the
  workspace, the runtime clears the workspace, and a `RUN` after `END` must find
  the banks still filled rather than read the overlay again.
- **`RunStartBank`** — the bank selected at the handover, the last `GP.BANKED`
  region's. A program that falls into a region from the line above gets there by
  a plain `GOTO`, and a `GOTO` selects no bank; `bootstrap2.asm`'s `BXRun` does
  the same thing for a shared program. It is *outside* the walk, because a
  second `RUN` skips the walk and still has to start in the right bank. Zero
  means no region at all, and no region may use bank 0 or bank 1, so zero is
  free to mean "leave the bank alone".

The source pointer's low byte is **not** reset per page. Each region's data
starts two bytes past its header, so after the first region the source is no
longer page aligned; incrementing only the high byte per page is what keeps it
right.

Nothing is checked. `bootstrap2.asm` checks the status at every page because it
is reading a *file*, which can be missing, stale or cut. These bytes arrived
with the p-code.

`source/common-source/source/common.inc`:

- **`BXOVLEND`** moves here out of `bootstrap2.asm`. Both links read it now —
  the compiler link for the shared page, the image link for this walk — and
  `common.inc` is the one file both of them take.

`source/application/scripts/genrtimage.py`:

- **`RTIMG_OVLPOFS`** and **`RTIMG_SBANKOFS`**, found from the `RunOvlPage` and
  `RunStartBank` labels the same way the other three offsets are found, and
  bounds-checked in the same loop.

`source/application/source/compiler/object.asm`:

- **`objOvlPage`** and **`objStartBank`**, worked out in `ObjCheckOverlayFits`
  and substituted into the image by the streamer. Both start at zero, which is
  what a program with no region ships with.
- The page costs nothing to compute: it is the sum the fit test was already
  forming, kept with one `sta` between the `bcs` and the `adc` that follows.
- **`ObjFindStartBank`** — the start-bank rule, lifted out of the shared
  extension-page builder so there is one copy of it. Both modes now ask the same
  routine and hand the answer to a different reader. (It is `ObjFind…` and not
  `ObjStartBank` because 64tass is case-insensitive and the variable had the
  name first.)

## The five patched bytes

An embedded object is now patched in five places as the image streams past,
all in its first page:

| offset | value | for |
|---|---|---|
| `RTIMG_BANKPOFS` `$0018` | `newWorkspacePage - FrameStackPages` | the bank code's page |
| `RTIMG_OVLPOFS` `$0045` | that, plus `ceil(RTIMG_BANKLEN / 256)` | the overlay's page |
| `RTIMG_SBANKOFS` `$0086` | last `GP.BANKED` region's bank | the bank at the handover |
| `RTIMG_CODEPOFS` `$008c` | `runtimeEndPage` | the p-code base |
| `RTIMG_WSPAGEOFS` `$008e` | `newWorkspacePage` | the workspace start |

BANKY, compiled embedded, gets `$37`, `$41`, `$06`, `$36`, `$3F` — and its
overlay is at file offset 14,593, which loads at `$4100`. The reader's page
number and the file's own arithmetic agree.

## The image grew a page

`genrtimage` now reports 11,775 bytes rather than 11,519, and `GPBase` moved
`$2F00` → `$3000` with `ObjectBase` `$3500` → `$3600` behind it. The walk is
about 60 bytes; the rest is the page-alignment `GPBase` sits on, which it
happened to be just under. That is 256 bytes off the largest embedded program,
and it is the ordinary price of adding code to the image.

## Verification

The refusal in `source/compiler/source/commands/gpbank.asm:83-87` was lifted
temporarily again, both libraries were rebuilt, and the lift was then reverted;
`git diff -- source/compiler/` is empty.

**`BNKPK`, a throwaway probe** (left in `scratch/banktest3/`, which is not tracked)
— one region in bank 5 that is never called, and low code that does `BANK 5`
and prints `PEEK(40960)`, `PEEK(40961)`, `PEEK(40962)`:

| build | prints |
|---|---|
| SHARED | `P1` / `P2 184 184 225` |
| EMBEDDED | `P1` / `P2 184 184 225` |

184, 184, 225 are the first three payload bytes of the `.OVL` — the bytes after
the region's two-byte header. The embedded build read them out of bank 5 at
`$A000` having been handed nothing but a page number, and it left no `.OVL`
behind. **That is this stage's acceptance, and it passes.** It is deliberately a
probe that never enters the region: it tests the reader and only the reader.

`source/unit-tests/banktest3.py` stays at **ALL PASS**, twice in a row, which is
what says the shared path did not move. One run between the revert and those two
reported a single failure and did not name it before the output was lost; it did
not reproduce, and the run before the revert and the two after it are clean. The
suite's work directory was full of embedded builds from the throwaway at the
time.

## The blocker Stage 5 inherits

A program that *enters* a region still hangs when it is compiled embedded.
`BANKP`, the suite's own "does the region really execute from the bank" probe,
prints its low-memory reading and stops at the `GOSUB` into the region:

| build | prints |
|---|---|
| SHARED | `P1 LOW CODEPTR 10` / `P2 BANKED CODEPTR 160` / `P3 BANK 5` |
| EMBEDDED | `P1 LOW CODEPTR 54` |

`54` is `$36`, which is right. The region is in its bank, as `BNKPK` shows. What
is wrong is the branch that crosses into it, and it is wrong in the compiler,
not in the reader:

- `source/application/source/compiler/start.asm:41` sets `gpBankRunPage` to
  `(PCODE_PAGE - (ObjectOrigin >> 8)) & $FF` — the buffer-to-run page delta for
  a **shared** program, unconditionally, because until now only a shared program
  could have a region. Its own comment says so. An embedded program's p-code
  runs where it was buffered, so its delta is zero.
- `source/compiler/source/commands/gpbank.asm:641` and `:662` then add one more
  page to it, *"plus one, for the BOOTSTRAP EXTENSION PAGE ... this routine only
  runs for a banked program, so the +1 is unconditional"*. An embedded program
  has no extension page.
- `source/compiler/source/commands/gpbstrflush.asm:351` does the same `+1` for
  text banks.

So every cross-boundary offset an embedded build computes is out by a page and a
bit, which is exactly a call that lands in the middle of nothing. All four sites
have `gpBankShared` to hand already.

**Stage 5 is therefore not just deleting the two refusals.** It is those four
corrections as well, and they are what makes `BANKY`, `BANKZ`, `BANKN` and
`BNK64` run embedded — they compile correctly today and their overlays are
already byte-identical to the shared builds'.

One thing found on the way that the Stage 3 acceptance test should know: a
region is byte-identical between the two modes only when it holds no absolute
addresses. `BANKP`'s region does, through `GP.ASM`'s `{VAR}` substitution, and
its tail differs from the shared `.OVL` for that reason alone. The permanent
test Stage 5 adds should use a program without inline assembly in its regions.

## Still outstanding

Stage 5, with the scope above.
