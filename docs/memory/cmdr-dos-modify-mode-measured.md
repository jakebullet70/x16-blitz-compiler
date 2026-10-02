---
name: cmdr-dos-modify-mode-measured
description: "CMDR-DOS R49, measured in ROM BASIC on hostfs and SD: ,M overwrites in place, P seek takes NUL and 13 bytes, ,A appends, paths work with @: M and A; plus the timings of a fixed-record KV file"
metadata:
  node_type: memory
  type: project
  originSessionId: 5991fdbe-eb9a-440f-bf52-e169789d2edb
  modified: 2026-10-02T08:27:41.452Z
---

Measured 2026-10-02 in ROM BASIC on x16emu R49, on both hostfs and an SD image, while building
`KVBIN.INC.BL` (the fixed-record key and value file) and its editor sample `KV-BIN-STORE`.

**What works, all four on both file systems:**

- `,S,M` reads and writes on one channel, and a write after a seek **overwrites in place**. The
  records either side are untouched. This is measurement 1 of `XBASE/PLAN.md`, answered yes.
- The seek is `PRINT#15, "P" + CHR$(sa) + CHR$(lo) + CHR$(mid) + CHR$(hi) + CHR$(0)`, with no
  semicolon. A `CHR$(0)` passes through to the command channel (XBASE measurement 2, yes), and an
  offset byte of 13 in the middle is not taken as the end of the command.
- `,S,A` appends, which is how the file is grown. The header's count is then rewritten in `,M`.
- A name with a path, `/SUB/NAME`, works with `@:` on a write, and with `,M` and `,A`.

**The trap:** an `,M` channel that has read to the end of the file takes no more reads or writes.
`KVBIN` reads a value one byte short of the record's end, so `GET` and `AT` never reach it.

**Timings on SD, ROM BASIC, jiffies (60 a second), 40 slots of 128 bytes:**

| | |
|---|---|
| create the file | 46 to 143 |
| `GET`, key in slot 3 | 9 |
| `GET`, key in slot 40, or a miss | 39 to 44 |
| `PUT` a new key, which scans every slot | 41 |
| `DEL` | 6 |
| expand by 20 slots | 26 |
| walk 60 slots reading whole records | 300 |

A scan costs about one jiffy a slot: one seek and a 12-byte `BINPUT#`. Reading whole records with
no seek is slower, about 5 jiffies a slot in ROM BASIC with the trimming.

**Under GPC, measured 2026-10-02.** On runtime build 130 `KVBIN.EXP.BL` failed 8 of 13: a
`PRINT#15` seek did not run before the write that followed it, because the runtime never
released the channel. Build 131 has the fix, see [[file-io-error-in-gpdo-key-loop]], and it
passes 13 of 13, EMBEDDED and SHARED, with no change to the module. Timings under GPC are not
measured.

**How to apply:** XBASE can rely on in-place writes from runtime build 131 on. Related:
[[binput-caps-at-255-bytes]], [[demo-project-options]].
