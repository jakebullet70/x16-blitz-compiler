---
name: ask-before-writing-asm
description: "Standing order - never write 65C02 / GP.ASM without talking it through first, whatever the performance argument"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bbbf9c42-e6ec-4fbc-be82-c6dad47143ab
  modified: 2026-09-04T00:00:56.636Z
---

**Do not write assembly — `GP.ASM` blobs or 64tass source — unless it has been discussed and
agreed first.** This is a standing order, not a per-task preference. It holds even when the
measurement plainly says assembly is the answer: reach the point of "this needs a blob", stop,
and say so.

**Why:** the user owns that call. A performance number is an argument for assembly, not a licence
to add it — an inline blob is the hardest thing in the tree to read, review and change, and the
decision to spend that cost is theirs.

**How to apply:** when a probe shows a BASIC loop is too slow (the classic: a per-byte copy loop
that costs ~120 cycles a byte), present the number and the options and wait. Look for a design
that avoids the bulk move altogether before proposing one. Given 2026-09-04, on GPC-HELP, where
a 72-byte-per-row bank copy measured 61 jiffies for 57 rows and the obvious fix was a blob.

Related: [[measure-before-changing-code]], [[no-ship-language-this-is-dev]],
[[gpasm-implementation-status]].
