---
name: gpc-basic-for-loop-runs-once
description: "GPC BASIC's FOR tests at NEXT, so FOR I = 1 TO 0 runs the body ONCE - the standard string-walk idiom is wrong on an empty string"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T09:34:15.060Z
---

**`FOR I = 1 TO LEN(S$)` runs the body once when `S$` is empty.** GPC BASIC follows
classic CBM semantics: the limit is tested at `NEXT`, not at `FOR`, so a loop whose
start already exceeds its limit still executes one iteration. `ASC("")` then returns
**0** rather than raising an error, so the usual character-walk

```basic
OUT$ = ""
FOR I = 1 TO LEN(IN$)
  C = ASC(MID$(IN$, I, 1))
  OUT$ = OUT$ + CHR$(C)
NEXT I
```

turns an empty string into `CHR$(0)` — a one-byte string that looks empty in a `PRINT`
and is not. Guard it: `IF LEN(IN$) = 0 THEN RETURN` before the loop.

**Found 2026-08-31, and only because a byte-for-byte comparison ran.** `DOC.TOPETSCII`
in `samples/editor/STORE.BASL` wrote every blank line of a document as a stray `$00`;
the file was 13 bytes long for 13 blank lines and looked completely normal on screen and
in a text editor. Nothing short of comparing the saved file against the original would
have caught it — the self-check did not, because it never saves.

The same shape was latent in `ED.FOLD` in `EDITOR.BASL` (an empty search needle folding
to `CHR$(0)`); both now carry the guard. **Assume any `FOR 1 TO LEN()` in this tree is
wrong until it has the length check.**

Related: [[gpc-editor-is-ascii-inside-petscii-outside]].
