# Stage 3 — the writer: appending the overlay

Status: **done.** An embedded object now ends with the overlay a shared build of
the same program writes, byte for byte, and the separate `.OVL` is scratched.
Nothing in a shared build changed. The permanent test cannot be added until
Stage 5 lifts the refusal; see *Acceptance* at the bottom.

## What it does

At `BLC_CLOSEOUT`, for an embedded build that has regions, the compiler pads the
object up to a page boundary, copies the whole of `<object>.OVL` onto the end of
it, closes the object, and scratches the `.OVL`.

The copy is the plain, whole file: the per-region `[bank][pages][pages...]`
headers and the single `BXOVLEND` byte after the last of them. Nothing is
rewritten on the way through, which is what makes the acceptance test a byte
comparison rather than a re-parse.

## Why it is copied back rather than written in place

Each region goes out to the `.OVL` as it *closes*, in the middle of pass two,
while the low code is still streaming into the object behind it
(`ObjEmitRegion`, from `BLC_REGIONDONE`). Two streams, one file each: they
cannot share a file while they are being written. The `.OVL` is what lets them,
and by the time `BLC_CLOSEOUT` runs it is closed and complete.

That it is also exactly what a shared build leaves on disk is the useful part.
The two builds now differ in where the overlay ends up, not in what it contains.

## The code

`source/application/source/compiler/object.asm`:

- **`ObjCloseOut`** — the whole of the closeout sequence, moved here out of
  `api.asm`: the bank code, the append, `objStreamLive`, the close, the delete.
  It is in this file because `api.asm` cannot afford the bytes. Its dispatch
  table at the top reaches every handler with a `beq`, and adding two
  instructions to `_CACloseOut` put `_CARead` three bytes out of range. `api.asm`
  is now one `jmp` and stays small.
- **`ObjAppendOverlay`** — the pad, the reopen, the copy, and a check that the
  last byte copied is `BXOVLEND`.
- **`ObjDeleteOverlay`** — the scratch, after the object is closed.
- **`ovlWritten`** — set beside `ovlStreamLive` in `ObjStartOverlay` and never
  cleared. `ovlStreamLive` is zeroed when the overlay closes at the end of pass
  two, and by closeout the append still needs to know whether a file was ever
  created. `layoutCount` would not do: `GP.BANKEDSTR` text banks write to the
  same overlay, and this flag counts them too.

`source/application/source/file-io/read.asm`:

- **`IOOpenOverlayRead`** and **`IOOverlayIn`** — the overlay's own logical file,
  7, opened again for read. The write file is closed by then, so the number is
  free. `IOOverlayIn` sets `ioOutSel` to `$FF`, as `IOSelectSource` does, or the
  next `IOSelectObject` would skip the `CHKOUT` it needs on the way back.

`source/application/source/compiler/api.asm`:

- `_CACloseOut` is now `jmp ObjCloseOut`.

## The two paddings

There are two, and they pad to the same kind of boundary for different reasons.

**Before the bank code**, `ObjEmitBankCode` fills out the page the low code
stopped in, so that the bank code starts where `RTIMG_BANKPOFS` told the runtime
to copy it from — `newWorkspacePage - FrameStackPages`, patched into the image as
it streams past. **This counted from the wrong pointer.** It was `ldx objPtr`,
and with `GP.BANKED` regions in the program `objPtr` is not where the low code
ends: it has run on up through the regions to the top of the topmost, and the
regions are not in this file at all. It is now `ldx objBufBase`, which the last
flush of pass two leaves one past the last byte that actually went into the
object.

It is the same defect Stage 2 found in `PrepareObjectCode`, in the same file, for
the same reason, and it would have failed the same way: silently, and only for
embedded programs with regions, which nothing could compile yet.

The pad is not hypothetical. In the four programs checked it ran for 221, 162,
134 and 98 bytes. With `objPtr` it would have been zero every time — the top of
the topmost region is page aligned by construction — and the bank code would have
landed part way into a page, a hundred-odd bytes below where the runtime copies
from.

**After the bank code**, `ObjAppendOverlay` fills out the page *it* stopped in.
`RTIMG_BANKLEN` is 2,432 bytes, which is nine and a half pages, so without this
the overlay would start part way through one. Stage 4's reader is handed a page
number and nothing finer. The whole file loads at `$0801` in one piece, so a page
boundary in the file is a page boundary in RAM.

## A page at a time, through `imageBuffer`

Both files are open together and the KERNAL has one input channel and one output,
so a byte at a time would be a `CHKIN`/`CHKOUT` pair per byte. This is the same
arrangement, and the same buffer, as the runtime image in `ObjStreamOpen`:
`imageBuffer` is a page of compiler RAM that is dead once the image has been
streamed. The count convention is `imgCount`'s — **zero means 256** — because the
index wraps to zero exactly when the page filled.

## What stops rather than printing OK

Two internal errors, both through `CallErrorHandler` so they carry the ` @ line`
suffix and so the harness can see them:

- `INTERNAL ERROR OVERLAY REOPEN` — the `.OVL` would not open for read, having
  been written and closed moments earlier. The object on disk is short of its
  regions and would load and run wrong.
- `INTERNAL ERROR OVERLAY CUT` — the copy did not end on `BXOVLEND`. A read that
  stops early is indistinguishable from end of file here, and the result looks
  like a whole overlay to the loader. This is what `BXOVLEND` is for; the check
  simply asks the question at the writing end too.

The scratch is deliberately *after* the object is closed. Scratch it before, and
anything that fails in between has destroyed the only copy of the regions. After
it, the worst case is a file left behind.

## Verification

The refusal in `source/compiler/source/commands/gpbank.asm:83-87` was lifted
temporarily, both libraries were rebuilt, and four programs were compiled both
ways and compared. The lift was then reverted and
`git diff -- source/compiler/` is empty, including the generated `_library.asm`.

| program | regions | overlay | bank code | overlay start | tail |
|---|---|---|---|---|---|
| BANKY | 2 | 517 bytes | `$3600` | `$4000` | identical |
| BANKZ | 1 | 259 bytes | `$3600` | `$4000` | identical |
| BANKN | 2 | 517 bytes | `$3600` | `$4000` | identical |
| BNK64 | 63 | 16,255 bytes | `$3900` | `$4300` | identical |

Every one is page aligned, every tail is byte-identical to the `.OVL` the shared
build of the same source produced, the same banks walk out of the tail as out of
the `.OVL`, and no `.OVL` was left beside any of the embedded objects. BNK64
copies 64 pages, so the loop, the short last page and the end marker check are
all exercised.

`BNK255` and `BNKOVL` could not be used: they carry `GP.BANKEDSTR`, which
`gpbstr.asm` still refuses, and only `gpbank.asm` was lifted.

`source/unit-tests/banktest3.py` stays at **ALL PASS**, which is what says the
shared path did not move. Every program in it is shared, and shared is exactly
what must not change.

## Acceptance

The check above is the plan's acceptance for this stage, run by hand because the
gate is still closed. When Stage 5 lifts it, add the pairing to `banktest3.py`
as a permanent test: compile a `GP.BANKED` program both ways and assert that the
last `len(.OVL)` bytes of the embedded object equal the shared build's `.OVL`.
The walker `overlays()` already reads the file; the tail needs the same six lines
pointed at a slice.

## Still outstanding

Stage 4. Nothing yet reads the appended overlay: `StartCode` still expects a
`.OVL` on disk, so an embedded program with regions compiles correctly and does
not yet run. The page number the reader needs — `newWorkspacePage -
FrameStackPages + ceil(RTIMG_BANKLEN / 256)` — is known in pass one, which is
where `ObjCheckOverlayFits` already computes it for the fit test, and the
alignment this stage added is what makes it a page number at all.
