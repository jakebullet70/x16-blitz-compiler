---
name: shared-test-warm-step-is-stale
description: "shared_test.py fails its WARM step with ?RTC<nnn> on any build with bank 1 code: the driver loads only GPC.RT, and the bootstrap also wants the magic at $A000 in bank 1. Not a runtime fault."
metadata:
  type: project
---

Found 2026-10-02 on runtime build 131. `python source/unit-tests/shared-runtime/shared_test.py`
passes layout, COLD and ROOT, then fails: `WARM: program marker b'WARMOK' never printed`. The
emulator log shows `?RTC131`.

The WARM driver makes the runtime resident with `LOAD"GPC.RT.nnn.BIN",8,1` only. The bootstrap
(`source/application/source/compiler/bootstrap.asm`, `_BBCheck`) takes the warm path only when
the four magic bytes are at `RTBASE` and also at `$A000` in bank 1. The driver never loads
`GP1.RT.nnn.BIN`, so the bootstrap goes cold and asks for the file the test has just scratched.
The test was not run on build 130. The check there is the same code, last changed at build 128.

**The warm path itself works.** Measured with a driver that runs the program once cold, scratches
`GPC.RT.131.BIN`, then loads and runs it again: `WARMOK` printed twice, no `?RT`.

`LOAD"GP1.RT.nnn.BIN",8,1` after `BANK 1` is not the repair. It leaves ROM BASIC at
`?OUT OF MEMORY ERROR`, and the next pasted lines fail.

**How to apply:** do not read a WARM failure as a runtime regression. The repair is the two-run
driver above, with the pass test changed to two markers. The test file is not changed yet.

Related: [[file-io-error-in-gpdo-key-loop]], [[headless-basl-build-recipe]],
[[paste-cannot-drive-a-running-program]].
