---
name: gpc-editor-loader-linput-and-blob
description: "LINPUT# is native and 10x faster than GET# per byte -- plus the ST=66 missing-file trap that comes with it"
metadata:
  type: project
---

**`LINPUT#` is a native keyword** (`source/runtime/source/system-specific/x16/commands/linput.asm`):
CHRIN to the delimiter in assembly, delimiter consumed and not stored, default 13, capped at 255 and
then running on to the delimiter so the next read still starts at a line boundary. `BINPUT# n,A$,len`
reads a fixed count. Both check ST *before* each read, so the byte that sets ST is kept.

**Reading a 2,432-byte file line by line instead of byte by byte: 365 -> 35 jiffies, 10.5x**
(`samples/editor/LOADBEN.BASL` times the old loader against the new one in ONE program, so no
two-build comparison is involved). Most of the rest went with a `GP.ASM` block that copies the
string into the bank window and does the PETSCII->ASCII swap in the SAME pass.

**THE TRAP: `LINPUT#` on a channel whose `OPEN` found nothing returns `CHR$(0)` with `ST = 66`,
for ever.** `GET#` returned an empty string there, so the old loader pushed nothing; the new one
built a document whose single line was a NUL, and an empty document's first cell rendered as
character 0 instead of a space. **Bit 1 of ST is READ ERROR; clean EOF is 64** -- so
`IF (ST AND 2) <> 0` is the guard. There is no `DS` in this compiler.

Also: at EOF a delimiter-only read (`LEN=0`) is a real blank last line and must be kept, while a
stray `CHR$(10)` from a CRLF file is the tail of the line already pushed and must not be -- keep the
RAW length before stripping to tell them apart.
