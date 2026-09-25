# Stage 1 findings — where the three halves are

Read on 22nd Sep 2026. Nothing was written. Line numbers are in the real
sources under `source/application/source/`, not in the concatenated
`_library.asm` builds — edit the real sources.

## 1. The writer: where the append goes

`_CACloseOut`, `source/application/source/compiler/api.asm:138-141`, is the
`BLC_CLOSEOUT` handler and it is the whole of the end-of-compile sequence:

    _CACloseOut:
            jsr     ObjEmitBankCode         ; embedded: the bank code, after the p-code
            stz     objStreamLive
            jmp     IOObjectClose

`ObjEmitBankCode` (`source/application/source/compiler/object.asm:1260`) pads
the object with zeroes up to the next page boundary — counting from `objPtr`'s
low byte, with a `.cerror` holding `ObjectOrigin` page-aligned — then streams
`RTIMG_BANKLEN` bytes out of `OBJ_BANKCODE_BANK`, reselecting the window before
every single write because the KERNAL's buffers live in bank 0. SHARED returns
at the first instruction (`ModeText` = `'S'`).

**The insertion point is between `ObjEmitBankCode` and `IOObjectClose`.** The
overlay is finished and closed well before this: `ObjStreamClose`
(`object.asm:1033`) runs at end of pass two, writes the `BXOVLEND` marker and
closes the overlay file, and `BLC_CLOSEOUT` is only sent afterwards, from
`source/compiler/source/main/compiler.asm:441`, once the two passes have been
compared. So at the insertion point `NAME.OVL` is a complete, closed file on
disk, ready to be read back and streamed on. `ovlStreamLive` is already zero.

The overlay must be appended **after** the bank code, because the bank code's
length is a fixed constant the reader relies on and the padding is measured
from the p-code end.

## 2. The copy point in startup

`StartCode`, `source/application/source/main/00rtimage.header:56`. This is the
`SYS 2069` entry of a compiled program, and it already does exactly the job we
need, for the bank code:

    RunBankPage:
            lda     #0          ; page of the bank code, zero once copied (operand +1)
            beq     _SCInBank
            ...copies (RTImgBankEnd - RTImgBankHeader + $FF) >> 8 pages to HANDLER_BANK...
            stz     RunBankPage+1
    _SCInBank:
    RunCodePage:
            lda     #0          ; page of the object code to run          (operand +1)
    RunWorkspacePage:
            ldx     #0          ; first page of workspace                 (operand +1)
            ldy     #$9F        ; byte after the last page ($9F00 is I/O)
            jmp     StartRuntime

Two things this settles:

- **The workspace is zeroed inside `StartRuntime`, after this point.** That is
  the instruction the plan's constraint 1 was looking for. Everything appended
  to the file must be consumed here, before the `jmp`.
- **The RUN-after-END guard is `stz RunBankPage+1`.** A second RUN finds a zero
  page operand and skips the copy, because the workspace no longer holds the
  source bytes. Any overlay walk needs the same guard, in the same shape.

The three immediates are patched into the byte stream as the image is written,
not in RAM. `source/application/scripts/genrtimage.py:175-177` finds
`RunCodePage`, `RunWorkspacePage` and `RunBankPage` in the label file, adds 1
for the operand, and emits `RTIMG_CODEPOFS` / `RTIMG_WSPAGEOFS` /
`RTIMG_BANKPOFS` (lines 214-221) as offsets from `$0801`. It also emits
`RTIMG_BANKLEN` with a `.cerror` against `MIN_WS_PAGES << 8`. **A fourth
operand is a four-line change here plus one more substitution in the
streamer**, and the existing `.cerror` is the template for the fit check.

## 3. The reusable half of the reader

`source/application/source/compiler/bootstrap2.asm`, 328 lines, one pinned
256-byte page. Split at `BXBankOK`:

| lines | does | embedded |
|---|---|---|
| 125-133 | `SETNAM` / `SETLFS` / `OPEN` / `CHKIN` | drop |
| 278-281 | `BXNameLen` + `BXName`, `.fill BXNAMEMAX, 0` (48 bytes) | drop |
| 147-192 | region loop: bank byte, `BXOVLEND` test, `?RAM` bank check against `BXTop`, page count, page copy, repeat | **keep, unchanged in shape** |
| 224-227 | `CLRCHN` / `CLOSE` | drop |
| 199-222 | `BXAllDone` / `BXRun`: set `BXHigh` guard, select `BXStartBank`, `jmp RT_ENTRY` with `BXBase` / `BXWS` / `BXWSEnd` | already `StartCode`'s job |

Every byte of the region loop arrives through one call, `jsr X16_ACPTR`,
appearing five times. **The embedded variant is that call replaced by a
"fetch next byte from a RAM pointer" — the loop structure around it does not
change.** The two end-of-file tests (`X16_READST` after the bank byte and once
per page) have no embedded equivalent and become nothing, because a walk in
RAM cannot run short; the `BXOVLEND` marker test stays and remains the only
terminator.

Note the destination trick worth keeping: `BXStore+2` is self-modified a page
at a time from `$A0`, rather than using a zero page pointer, "because the
runtime has not started yet" — which is equally true inside `StartCode`.

`BXStartBank` (the last `GP.BANKED` region's bank, patched in by the compiler,
so a fall-through `GOTO` into a region runs in the right bank) is a fourth
patched value that the embedded path needs as well. `BXHigh` is the
second-RUN guard and maps onto `stz RunOvlPage+1`.

## What this changes about the plan

**Stage 4 should extend `StartCode` rather than fork `bootstrap2.asm`.** The
plan assumed an embedded copy of the extension page. But `StartCode` already
has the loop shape, the bank-window handling, the RUN-after-END guard and the
handover, and it is not on a pinned 256-byte page, so it has no size ceiling
to bump into and no `.cerror` at `$09F0` to respect. Reusing `bootstrap2.asm`
would mean carrying a page mechanism the embedded image does not otherwise
have. For a `GP.BANKED`-only first landing (which Stage 5 already recommends)
nothing in the extension page is needed at all — `GPBSTRBANKS` at `$09F0`
serves `GP.BANKEDSTR`, which stays refused.

Concretely, Stage 4 becomes: a `RunOvlPage` operand next to `RunBankPage`, a
walk between it and `_SCInBank`, `stz RunOvlPage+1` at the end, plus
`RTIMG_OVLPOFS` in `genrtimage.py` and one more substitution in the object
streamer.

**Stage 3 gains a detail:** the overlay's page is derivable rather than
stored. The p-code is padded to a page, then `RTIMG_BANKLEN` bytes of bank
code follow, so the overlay starts at the next page after that. The writer
should still pad to a page boundary before appending the overlay, so
`RunOvlPage` is a whole page number like the other three.
