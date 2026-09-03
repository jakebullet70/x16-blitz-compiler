---
name: tests-share-the-products-memory
description: "A self-check compiled into the program costs it workspace -- the editor's harness was 3,615 bytes of the same 25,600 the runtime lives in"
metadata:
  type: project
---

**P-code and the runtime workspace come out of ONE pot** -- `$3b00`..`$9F00`, 25,600 bytes, split
between object code, the fixed 4K frame stack, and whatever is left for variables, arrays and the
string heap. So a byte of test code is a byte the running program does not get, in 256-byte pages.

**The editor's self-check was 3,615 bytes and `DEBUG.MODE` is a RUN-TIME test, so it shipped in every
build.** The editor was paying for its tests twice: once in code, once in the room it had left to run
in. Putting the harness behind `#IFNDEF ED.RELEASE` took the release build from **16,497 bytes /
4,608 workspace to 12,882 / 8,192**. That is why `OUT OF MEMORY` kept coming back all day -- every
feature (a 298-byte gutter, a 132-byte library call) came off the workspace, with the tests sitting
in the same pot.

**BASLOAD DOES NOT NEST `#IFNDEF`.** A guard inside a guard reports `ERROR: ENDIF WITHOUT IF IN
<file>:<line>` and writes a **6-byte PRG** -- an empty program that then "compiles" to `OK CODE 11
... GP-BASIC OUT`, which looks like a compiler result rather than a tokeniser failure. Read `TOK.LOG`
when a build comes out absurdly small. `samples/editor/EDITOR.BASL` therefore uses three FLAT
symbols, never one inside another: `ED.RELEASE` (preamble, tail and helpers), `ED.NOCORE` and
`ED.NOOPT` (the two halves of the harness). There is no `#IFDEF`, only `#IFNDEF`.

**The harness is split because it no longer fits beside itself**: CORE (geometry, theme, ALT keys,
hardware VSCROLL, the end-to-end walk) at 7,424 free, OPTIONAL (find, bar and dropdown, render and
gutter, key dispatch, the 600-open stress test, GUI dialogs) at 5,120. Both end `M4 OK`. The 40-line
`L0..L39` fixture is `ED.TESTDOC`, outside both guards because both halves need it.

**Splitting a harness exposes what the assertions were leaning on.** Three broke, all test bugs:
`ED.GOFF` was set in a section that moved (so the walk read column 0 and saw the gutter); the bar
had been drawn by a section that moved (so "the bar has not moved" read a letter out of the test
output); and `GUI RESTORE` was summing whatever the KERNAL's `PRINT`s had left on layer 1 -- which is
why its number drifted whenever a test printed one more line, and why it passed on an empty rectangle
once the earlier sections were gone. It lays down a known band now.

Related: [[gpc-string-blocks-never-shrink]], [[program-too-big-fires-early]], [[vera-fx-cache-write-is-aligned]].
