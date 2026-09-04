---
name: gpc-blitz-runtime-slack-and-limits
description: Measured GPC Blitz memory layout numbers, and the object buffer after the runtime moved out of the compiler's RAM
metadata:
  node_type: memory
  type: project
  originSessionId: 4b8bda58-db0d-4799-90e8-505eac54670b
  modified: 2026-08-30T14:06:52.989Z
---

**Figures below predate the shrink work. As of 2026-09-01 the GP block is `$3700`..`ObjectBase
$3b00` = 1,024 bytes (1,010 used, 14 free), the GP-IN image is 13,055 and a GP-OUT program's RT is
12,031 -- `TODO.md` "Shrinking the runtime" holds the current table. The DERIVATIONS below are what
to keep; re-measure any number before quoting it.**

Measured from `source/application/build/code.lbl` and `code.lst`. Useful because these numbers are
the budget for anything added to the runtime, and they are not written down anywhere else in the tree.

- `GPBase $3700` -> `ObjectBase $3F00` = **2,048 bytes** for all ~31 `GP.*` runtime handlers
  (avg 66 each), with roughly 78 bytes of page-alignment padding at the top unused — a small
  handler can land there for zero net cost. See [[gpc-core-page-cushion-below-gpbase]].
- `FreeMemory` is `.align 256` right after the compiler's last byte, and the object buffer is
  `FreeMemory`..`ObjectCeiling $9F00`, so **growing the compiler shrinks the largest program it can
  build, one page for one page**. That is a ceiling, not a running cost — see
  [[compiler-must-not-cap-program-size]].

**The buffer stopped binding on 2026-08-30 (branch `feature/object-buffer`).** `FreeMemory`
`$6D00` -> `$4400`, buffer **12,800 -> 23,296**, because the 14,079-byte runtime image left low RAM
and became `GPC.IMG.nnn.BIN`, streamed into each object at write time. Run-side ceilings, all now
below the buffer: **18,432** embedded GP OUT, 17,664 shared GP OUT, 16,384 embedded GP IN, 15,616
shared GP IN. `README.md`'s "How big a program can it compile?" section was stale in both
directions and has been rewritten with these four.

The measurement that made it possible: across `runtime.library`, `polynomials.library` and
`gp.library` — 10,892 bytes — the compiler makes **zero calls** and had **two** absolute references,
both `gpscan.asm` reading `VectorTable`. Everything it really uses is `common.library` (434 B) and
five entry points in `ifloat32`. **The method is worth keeping**: profile
`build/code.lst` for `jsr`/`jmp` and 4-hex-digit operands originating in the compiler's address
range, and map the targets back to library ranges taken from the `;****** Processing input file`
markers.

Also measured: `.entercmd` is `plx` (1 byte), `.exitcmd` is `jmp NextCommand` (3 bytes).
`CommandGPCall` is 77 bytes, `CommandPushS` ~30, `CommandDATA` (compiler side) 28 — this codebase is
far tighter than intuition suggests, so size estimates anchored elsewhere come out too high.

**Re-measured 2026-08-30, and the note above is now the history, not the state.** `FreeMemory` has
drifted `$4400` -> **`$4700`** as the compiler grew, so the object buffer is **22,528 bytes**, not
23,296. Still comfortably above every run-side ceiling (highest is 18,432), so it is still not what
stops anyone — but **`README.md`'s "build buffer is 23,296 bytes" is stale by 768** and was left
that way deliberately rather than edited by a session working on something else.

**Derive it without a build**: the engine `.PRG` loads at `$0801`, so the compiler's last byte is
`$0801 + filesize - 3`, and `FreeMemory` is the next page boundary. At 16,090 bytes that is `$46D8`
-> `$4700`, leaving **39 bytes of alignment slack**. That is the real budget for the next small
compiler addition: under 39 bytes is free, over it costs a page — 256 bytes off max program size.

**The GP-block side of the budget, measured 2026-08-30 from `source/runtime/build/code.lbl`.**
This is what a new GP keyword actually costs, and the two halves land in different places:

- **The GP block is a fixed 2,048 bytes, all-or-nothing** — `GPBase $3700` to `ObjectBase
  $3F00`, and `RT 12031` (GP OUT) vs `RT 14079` (GP IN) is exactly 2048. The last handler is
  `SelectFindFrame $3EA6` + 12 bytes, so it ends at **`$3EB2` and 78 bytes are free** to the
  top. A handler that fits there costs **nothing** — nothing extra for a GP IN program, and
  invisible to a GP OUT one.
- **A new OPCODE costs 2 bytes in EVERY program, GP OUT included.** `VectorTable $20BD` and
  `ShiftVectorTable $219D` are both below `GPBase`, i.e. core. Every marker gets a slot even
  when it shares a handler body — `.caseend` and `.ifelse` each cost 2 bytes to run
  `CommandXGoto`'s code.
- **A COMPOSITE costs nothing at all.** `gp.asm`, `gp.contains`, `gp.hibyte` do not appear in
  `vectors.asm`: a keyword that expands to opcodes that already exist takes no vector slot and
  no handler. That is the route to reach for first — see [[gpb-goto-out-of-block-design]],
  which gets a whole feature for zero runtime bytes this way.
- Core cushion below `GPBase`: the last core symbol is `FloatTangent $369D`, 99 bytes short of
  `$3700`, of which ~40 are genuinely free — see [[gpc-core-page-cushion-below-gpbase]].
- Frame stack is `FrameStackPages = 16` = **4 KB**; a `GP.SELECT` frame is 7 bytes, a `GP.DO`
  frame 6, `GOSUB` 4, `FOR` 19. Frame markers pack **id in the top 3 bits, size in the low 5**,
  so there are only **8 ids and 4 are spoken for** (7 GOSUB, 6 FOR, 5 GP.DO, 4 GP.SELECT) and
  no frame can exceed 31 bytes.

**THE GP BLOCK IS 1,024 BYTES NOW, NOT 2,048, and every "2,048" above is
history.** `GPBase` **`$3800`** -> `ObjectBase` **`$3c00`**, `RT` **13,311**, code ends `$3B54`, 172 free.
Three groups left the block outright rather than being made smaller, all to `GP.ASM` modules:
`GP.STASH`/`GP.RESTR` (329 B) -> `STASH.INC.BL`; `GP.SORT` (408 B) -> `SORT.INC.BL`; the five
in-place string statements `GP.UPPER`/`GP.LOWER`/`GP.TRIM`/`GP.LTRIM`/`GP.RTRIM` (188 B with their
shared `GPStringAddress`) -> `STRCASE.INC.BL`. A page comes off the object and off the workspace floor
together — they are the SAME page, counted once, not twice: `runtimeEndPage` (`object.asm`) is one
page number deciding how much image is copied out, where the p-code lands AND where the workspace
starts. So that is **768 bytes back for every GP program**, not 1,536, with no keyword lost. In the
currency that matters, max p-code is **17,152 bytes with the block and 18,176 without it**.

**THE RULE THAT CAME OUT OF IT, and it predicts the next one.** A group can leave the block when
(a) its argument reduces to an ADDRESS a BASL routine can be handed, and (b) it is a STATEMENT, not
a function. `GP.ARRPTR` (49 B) and `GP.STRPTR` (24 B) are the hinges that made (a) possible and are
therefore the LAST things to remove, not the first. `GP.INSTR`, `GP.COMP` and `GP.STRPTR` stay
because they are functions and a `GOSUB` cannot be one — `IF GP.COMP(A$,B$) = 0` would become three
lines and an out-variable.

**What the move gives up, once, and it is worth knowing:** `StringVariableCompile` used to reject a
literal at the call site, so `GP.UPPER "abc"` could not compile. A module takes an address and
cannot know where it came from, and `GP.STRPTR("abc")` points INTO THE P-CODE — writing through it
edits the running program. Documented in the module header; the compiler can no longer enforce it.

**Code ends at `$3B54`, which is 84 BYTES past `$3B00`.** `ObjectBase` rounds up to a page, so 84
bytes saved anywhere in the block is worth another 512 to every GP program, while the 172 bytes of
slack above the boundary are worth nothing. Check which side of a page a change lands on BEFORE
costing it: the answer flips. `docs/blitz/GP-BLOCK-LAYOUT.md` §0 lists the candidates.

Related: [[gpasm-inline-assembly-research]], [[gpasm-implementation-status]],
[[compiler-must-not-cap-program-size]], [[gpb-goto-out-of-block-design]].

**THE RUN-SIDE CEILING, MEASURED 2026-09-01, and it supersedes the four figures above.** Embedded
GP-BASIC IN is **17,408 bytes** of p-code (68 pages), not 16,384: `$3b00`..`$9F00` is 25,600 bytes
shared between object, the 4K frame stack and the workspace, and `WriteObjectCode` refuses to leave
under `MIN_WS_PAGES` (4K). Confirmed by a build landing on `OK CODE 17406 FREE 4096` and the next
page failing. **`FREE - 4096` is how much more p-code will fit** — that is the number to quote when
costing anything, not `ObjectCeiling - FreeMemory`, which is only where the compiler BUILDS it.
See [[program-too-big-fires-early]].

**UPDATE 2026-09-02:** the string-heap scavenger ([[string-heap-scavenger]]) took the runtime 13,055 -> 13,311 -- the ~62 bytes crossed the page cushion, so every figure above that quotes a max program size is now 256 bytes smaller. GPBase $3800, ObjectBase $3c00 per genrtimage.
