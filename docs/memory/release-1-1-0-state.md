---
name: release-1-1-0-state
description: gpc-release-1.1.0.zip (2026-10-02, runtime build 131) is with a tester and in use as of 2026-10-05; the tree is now 1.2.0
metadata:
  node_type: memory
  type: project
  originSessionId: ec80b68c-9026-4574-88a5-df1e56e99c98
  modified: 2026-10-02T16:53:26.012Z
---

`release/gpc-release-1.1.0.zip` was rebuilt on 2026-10-02 at 19:52 by a full `release.sh` run:
1,545,401 bytes, 356 files, runtime build 131, 15 samples built and 0 failed in 473.7 s. It
replaced a stale zip of the same name from 2026-10-01 that held build 128. The user said on
2026-10-02 that no zip of either version had been sent to anyone, so the name was reused.

The audience is two or three people. The root `README.md` gained a `## Known issues` section for
them, above the release cut, with two entries: `SLEEP 0` returns at once, and a `GP.ASM` label may
not start with `A`.

On 2026-10-05 the user said the 1.1.0 staged files are out to a tester and in use. Keep
`release/gpc-release-1.1.0.zip` as it is: a bug report from the tester refers to that build.

On 2026-10-05 the user asked for V1.2: `buildnum.txt` is 1.2.0, GPC.BIN prints V1.2.0 and the
GPC.PRG banner reads `V1.2 - FALL 2026`. No 1.2.0 zip has been built yet.

**Why:** a later session will ask whether a zip went out and which build it held. Two different
zips under one name would confuse bug reports.

**How to apply:** once the user says the zip was sent, any further release-bound change needs a
new version in `source/application/buildnum.txt` before `release.sh` runs. A full `release.sh` run
bumps the `BUILD nnn` stamp in `GPBMODS.BASL` and `GUI-LITE.BASL`, so those two show as modified
after it; that is the build, not an edit. `MKHELP.PY` run from the repo root changes one line of
`GPC-HELP.md` (the invocation path) and nothing else when the help is current.

Related: [[release-samples-shape]], [[no-ship-language-this-is-dev]],
[[gpasm-label-cannot-start-with-a]], [[blitz-x16-basic-conformance]].
