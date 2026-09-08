---
name: object-file-must-fit-under-the-runtime
description: "A shared object is LOADED whole at $0801 and must end below RTGPBASE; the p-code fit check never saw the regions, so GPBMODS and GPBFILES both compiled clean into programs that overwrote the resident runtime and read machine code out of their own text bank"
metadata:
  type: project
---

**Found 2026-09-07, fixed in `ObjectPrepareShared`. This is the one that matters.**

`ObjectPrepareShared` measured **resident p-code only** — `FreeMemory..gpBankStart` — because that
is what the workspace stands on. Every `GP.BANKED` and `GP.BANKEDSTR` region sits **above**
`gpBankStart` and was deliberately invisible to it.

But **the file is loaded whole, at `$0801`, regions and all**, and the resident shared runtime is
sitting at `RTGPBASE $6600` (`RTBASE $6E00` for a core-only program). An object that reaches past
it overwrites the runtime; the magic check then fails; the runtime is **reloaded over the object's
own tail**; and the program runs with its regions full of runtime image.

**Nothing reported it.** GPBMODS compiled clean 703 bytes over and read machine code out of its
own text bank — directory intact, records past the overlap replaced. **GPBFILES was over too**, by
far more: "GPBFILES compiles" was recorded here on 09-07 and was WRONG. It produced a file that
could not run. The 341-string verification that passed was `FDUMP`, a smaller separate program.

## The check that was missing

    fileEndPage = PCODE_PAGE + gpBankActive + pages(objPtr - FreeMemory)
    reject unless fileEndPage <= sharedCeilPage

**Count from `PCODE_PAGE + gpBankActive`, not from page 8.** The file loads at `$0801` but its
p-code starts at `$0900`, or `$0A00` for a banked program: 511 bytes of prefix, which is two pages,
which is exactly the margin a first attempt counting from page 8 was wrong by — it accepted a
program 512 bytes over.

## What it means for GP.BANKEDSTR

**Banked text costs FILE even though it costs no low RAM.** The bank image is part of the object,
so `GP.BANKEDSTR` trades workspace for file size, and **the file ceiling is the new binding
constraint** — `RTGPBASE - $0801 = 24,063` bytes of payload for a GP program.

**Measured 2026-09-08:** GPBMODS was **703** bytes over. Dropping the dead `SORT` include (691 B
of p-code) and retightening the panel text (492 B) brought it to **23,553 with 512 to spare**.
GPBFILES is over by far more and needs splitting, not trimming.

## How it was found

Reduction, after the wrong guess. The panel output was garbage that looked like 6502 code:

1. the compiled **bank image was decoded straight out of the object** and was perfect — so it was a
   runtime fault, not a compile one;
2. an isolated 40-group/320-string program read every index correctly — so `GP.BSTR` was fine;
3. `STRINGS.INC.BL` alone was fine — so the library was fine;
4. a `BANK n : PEEK` probe of the live text bank showed **the directory intact and the records
   corrupt**, which is a partial overwrite, not a bad read;
5. object size vs `RTGPBASE` did the rest.

**Two wrong theories died on the way** — an undimensioned `STR.FIELD$`, and `GP.BSTR` above index
255 — both plausible, both disproved by one measurement each. Measure, do not reason, when strings
come back as machine code.

Also learned: **a `GP.BANKEDSTR` block must appear before any `GP.BSTR` that names it.** The group
table is rebuilt as blocks are read, so a forward reference is a plain `SYNTAX ERROR`. Not yet in
`GP-BASIC.md` §3.10.

Related: [[gp-bankedstr-literal-text-in-a-bank]], [[object-writer-regions-vs-low-code]],
[[gpc-blitz-runtime-slack-and-limits]], [[compiler-must-not-cap-program-size]].
