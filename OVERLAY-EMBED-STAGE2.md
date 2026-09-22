# Stage 2 — the fit check

Status: **done.** The check refuses an oversized embedded program by name, a
small one still compiles, and the regression suite is green. The permanent
acceptance test cannot be added until Stage 5; see *Acceptance* at the bottom.

## What was added

`ObjCheckOverlayFits`, in `source/application/source/compiler/object.asm`,
immediately after `PrepareObjectCode`. It is called from `_POCFits`, between the
existing workspace test and `AsmSetBases`:

    _POCFits:
            jsr     ObjCheckOverlayFits     ; ...and whatever the regions append on top of it
            jsr     AsmSetBases
            jmp     ObjStreamOpen

It needs no test for the build mode. The shared path branches away to
`ObjectPrepareShared` at the top of `PrepareObjectCode`, long before this, and a
shared program's regions travel in a `.OVL` of their own that is never in memory
all at once.

### The low-code length, which was wrong

The embedded branch of `PrepareObjectCode` measured the object code as
`objPtr - ObjectOrigin`. That counts the `GP.BANKED` regions, which sit at the
top of the object buffer, page aligned, and which are not part of the image at
all — they are appended behind it. `ObjectPrepareShared` has always measured to
`gpBankStart` instead when `gpBankActive` is set, for exactly this reason, and
says so in its own comment. The embedded path now does the same:

        lda     objPtr
        ldy     objPtr+1
        ldx     gpBankActive
        beq     _WOCLength
        lda     gpBankStart             ; where the regions begin -- page aligned
        ldy     gpBankStart+1
    _WOCLength:
        sec
        sbc     #ObjectOrigin & $FF
        sta     zTemp1
        tya
        sbc     #ObjectOrigin >> 8
        sta     zTemp1+1

Without this, `BNKBIG` is refused with `PROGRAM TOO BIG` by the workspace test
above — a hundred one-page regions read as a hundred pages of low code, for a
program whose low code is a `GOSUB` and an `END`. The new check never ran. Worse,
once Stage 5 lifts the gate, every embedded banked program of any size would have
been refused by the wrong test with a misleading message. This was found by the
throwaway verification below and is the reason that step was worth doing rather
than deferring to Stage 5.

The change is confined to the embedded branch. The shared path jumps away above
it and is untouched.

## The arithmetic

Everything is counted in pages, because everything involved is page-granular.

    objOvlPages = 1 + sum(layoutPages[0 .. layoutCount-1])

The leading 1 covers every region's two header bytes plus the single `BXOVLEND`
marker. `GPBANK_MAXREGIONS` is 127, so that is at most 2 * 127 + 1 = 255 bytes —
one page covers all of it no matter what the program does. The sum itself is
16-bit: 127 regions of 32 pages is 4,064, which a byte does not hold even though
each individual entry does.

The test is then

    (newWorkspacePage - FrameStackPages)        ; the image ends where the frame stack gap begins
      + ceil(RTIMG_BANKLEN / 256)               ; the bank code, padded up from that page
      + objOvlPages                             ; and the overlay after it
    >= (ObjectCeiling >> 8) - MIN_WS_PAGES + 1  ; -> refuse

which is the same threshold, computed the same way round, as the workspace test
directly above it — deliberately, because that one carries a comment explaining
why it is a threshold comparison rather than a subtraction (the subtraction
underflows into a small positive gap and accepts exactly what it exists to
reject).

Carry is checked after each addition, and `objOvlPages+1` is tested before the
byte arithmetic starts.

## Why this place in the compile

The check runs at the end of pass one, before a byte of object has been written,
which is where the two existing "program too big" tests already live.

`layoutCount` and `layoutPages` are settled by then and include text banks as
well as code regions. `source/compiler/source/main/compiler.asm` calls
`BStrFlush` and then `SaveLayout` at lines 320-321, and only sends
`BLC_ENDPASS1` at line 359 — so by the time this runs, `BStrRegister` has already
added one layout entry per `GP.BANKEDSTR` text bank. That matters: the overlay
carries text banks too (`banktest3.py`'s `OVERLAYS` expects banks 002, 100, 254
and 255 out of BNK255, and 254 is its text bank), so a check that counted only
code regions would undercount.

## The message

    _OCOFNoRoom:
            jsr     CallErrorHandler
            .text   "EMBEDDED REGIONS LEAVE NO ROOM TO LOAD", 0

Compiler space rather than `errors.asm`, for the reason `_WOCSExtNameLong` gives
further down the same file: that table links below `GPBase` and is copied into
every compiled program, and only a compile can ever print this.

The `CallErrorHandler` + inline `.text` form is also what makes the message
visible to the test harness. `banktest3.py` scrapes `errors.asm` and then every
`CallErrorHandler` + `.text` pair under `source/compiler` and
`source/application`; the scan now finds 35 messages, including this one. A
message printed the other way in this file — `PrintMessage` with a `.text "...",
13, 0`, as `PROGRAM TOO BIG` is — would not be found, and would also not print
the `@ <line>` suffix the harness matches on.

## Other changes

`source/unit-tests/banktest3.py` had its interpreter path hard-coded to
`C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe`, which does
not exist on this machine. Every tokenise failed as a result, so the suite could
not run at all. It now uses `sys.executable`.

`work/banktest3/BNKBIG.BASL` is new — a generated program with 100 one-page
regions in banks 2 to 101. Its overlay is 101 pages against roughly 84 available,
so it is comfortably over. It is the program the acceptance test will use. It is
not yet wired into `banktest3.py`; see below.

## Verification so far

- The application builds clean. Runtime image 11,519 bytes, bank code 2,432
  (10 pages, well inside the `MIN_WS_PAGES` allowance the existing `.cerror`
  enforces), GPBase $2F00, ObjectBase $3500.
- The message string is present in the linked `GPC.BIN`.
- `source/unit-tests/banktest3.py` reports **ALL PASS**: six marked/control pairs
  with matching output, fourteen rejections, two overlay walks, four runs. Every
  program in that suite is SHARED, so this is the evidence that SHARED behaviour
  has not moved.
- One earlier run of the suite reported two failures, BANKC and BGD, both
  `TOKFAIL` rather than a compile result. Tokenising runs BASLOAD inside the
  emulator and is timing-sensitive; both files tokenise clean on their own and
  both passed on the re-run. Worth remembering if it recurs.

## Acceptance

`CommandGPBankedCompile`
(`source/compiler/source/commands/gpbank.asm:83-87`) refuses an embedded build at
the *first* `GP.BANKED`, during pass one — before the layout exists and therefore
before this check runs. No entry in `banktest3.py`'s `BAD` list can reach the new
message until Stage 5 lifts that refusal. This was not visible when the plan was
written, so the plan's Stage 2 acceptance — "a deliberately oversized program is
refused by name, add it to `BAD`" — splits in two.

**Done here, as a throwaway.** The `gpbank.asm` refusal was lifted locally,
`bin/compiler.library` and the application rebuilt, and two programs compiled
EMBEDDED:

| program | regions | result |
|---|---|---|
| `BNKBIG` | 100 | `EMBEDDED REGIONS LEAVE NO ROOM TO LOAD @ 302` |
| `BANKA`  | 1   | `OK LOW CODE 256, EMBEDDED GPBASIC` |

Both directions matter. The first is the refusal firing by name. The second is
the control: the check discriminates on size rather than refusing every embedded
program that has a region at all. `BANKA` compiling is not a claim that it
*runs* — Stages 3 and 4 are what make an embedded banked program work — only
that the fit arithmetic lets it through.

The lift was then reverted from source and both libraries rebuilt.
`git diff -- source/compiler/` is empty, generated `_library.asm` included.
Nothing from this step is committed.

**At Stage 5, for keeps.** Add `("BNKBIG", "EMBEDDED REGIONS LEAVE NO ROOM TO
LOAD")` to `BAD`, compiled EMBEDDED, in the same change that lifts the refusal.
The main loop calls `compile_one(n)` with its default of SHARED; `compile_one`
already takes a `mode` argument, so the call site changes, not the function.
`work/banktest3/BNKBIG.BASL` is already in place and tokenises clean.
