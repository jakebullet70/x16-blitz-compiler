---
name: gpc-editor-is-ascii-inside-petscii-outside
description: samples/editor is PETSCII on disk and ASCII everywhere above it; why the font is re-ordered in VRAM and why PETSCII order was the wrong choice
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T09:34:41.908Z
---

**Built 2026-08-31.** `samples/editor/` was moved off ISO onto the **PETSCII charset 3
(PET upper/lower)**, keeping both cases. The rule that makes it hang together:

> **PETSCII on disk. ASCII everywhere above the disk.**

**Why ASCII inside, which is the part that is easy to get backwards.** BASLOAD writes
string literals through as *the bytes that were in the source file*, so every literal in
`EDITOR.BASL` — menu names, prompts, messages — is ASCII, and there is no directive to
change that (`#REM`, `#INCLUDE`, `#AUTONUM`, `#CONTROLCODES`, `#SYMFILE`, `#SAVEAS`,
`#MAXCOLUMN`, `#DEFINE` is the whole list). Make the document PETSCII and it no longer
matches the program's own literals: **find stops finding its own needles and all chrome
renders case-swapped.** That was measured, not reasoned — the self-check reported
`FIND1 ... MSG=Not found: bullet` with `62 75 6C 6C 65 74` in the PRG against
`42 55 4C 4C 45 54` in the file.

**The renderers cost zero, and that is why the font moves instead of the text.** Both
`GP.ASM` blocks write document bytes straight into VERA, where a tile index is a *screen*
code. `ED.PETFONT` re-orders the 2 KB charset at **VRAM `$1:F000`** so glyph N is the
glyph for code N — so a byte is its own tile index again, exactly as ISO gave for free.
Translating in the renderer instead costs `TAX` + `LDA table,X` = **6 cycles on a
31-cycle cell, ~19%**, on every character of every repaint. The runtime's arithmetic
`pet2scr` (`GPDrawPet2Scr`) is ~29 cycles and was never a candidate.

**In ASCII order the permutation is tiny and has no cycle.** Charset 3 already holds
`$20-$3F` and the capitals `$41-$5A` where ASCII wants them, so only **38 glyphs** move:
`$40←$00`, `$5B-$5F←$1B-$1F`, `$60←$40`, `$61-$7A←$01-$1A`, `$7B-$7F←$5B-$5F`. Order
`$60` before `$40` and `$7B-$7F` before `$5B-$5F`; screen `$01-$1A` and `$1B-$1F` are
only ever sources, so **no staging buffer is needed**. (A *PETSCII*-ordered permutation
does need one — its block map contains the cycle `6←2, 2←0, 0←4, 4←6`.)

**Where the conversions live** — all at the boundary, never per cell:
`DOC.LOADFILE` PETSCII→ASCII per character; `DOC.TOPETSCII` ASCII→PETSCII per line at
save; `ED.KEY.RANGE` PETSCII→ASCII per keystroke, because **`GET` returns `$41-$5A` for
lower case and `$C1-$DA` for upper** — the old `32..126` printable test dropped every
capital. `ED.FOLD` stays ASCII (`$61-$7A`, −32).

**Two things the KERNAL forces.** Anything `PRINT`ed after the re-order renders wrong,
because CHROUT converts to a screen code first — `ED.QUIT` puts the machine back through
`APPHELP.RESTORE`, which replays the whole `$0372` byte (charset number *and* the ISO bit;
`screen_set_charset` does not clear bit 6 on its own) before saying `BYE.`. The hardcoded
`POKE 780, 3 : SYS 65378` this note used to recommend is **gone and was wrong** — it
assumed a charset the machine had not necessarily booted with. And the charset really is
at `$1:F000`, not `$1:F800` — `$F800` is the unused 448-byte hole, and reading it is what
produced an earlier false "PETSCII upper/lower is not in ROM" conclusion.

**The re-order also eats the box-drawing glyphs**, which is not obvious until a frame is
wanted: charset 3 keeps them at `$40`-`$7D`, almost exactly the range that gets ASCII
letters written over it. See [[gp-draw-under-a-reordered-font]] for what survives, where
the originals are, and why only `GP.BOX` style 0 works.

**And the keyboard changes underneath it too.** The ISO flag makes ALT+letter return
ISO-8859-15 — or nothing at all — so PETSCII Commodore accelerators stop arriving; see
[[gpc-editor-alt-keys-need-the-keymap]].

Verified: all 256 glyphs re-indexed with zero mismatches; a load→save round trip is
byte-for-byte identical to the original apart from `PRINT#` writing CR where the fixture
had LF. `TEST.MD` is now PETSCII; `git show HEAD:samples/editor/TEST.MD` is the ASCII
original, and the swap is its own inverse.

Related: [[gpc-basic-for-loop-runs-once]], [[gpasm-implementation-status]],
[[gpc-blitz-runtime-slack-and-limits]].
