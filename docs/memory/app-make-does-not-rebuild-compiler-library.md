---
name: app-make-does-not-rebuild-compiler-library
description: "make in source/application links a STALE bin/compiler.library, so a change under source/compiler/source/** silently does not reach GPC.BIN -- and the freshly-dated binary hides it. Use make libs."
metadata:
  type: project
---

**`make` in `source/application` does not rebuild `bin/compiler.library`.** It rebuilds
`common.library`, bumps the build number, regenerates the runtime image and links `GPC.BIN` — with
whatever `compiler.library` was already sitting in `bin/`.

So a change to anything under **`source/compiler/source/**`** — every command handler, `gpbank.asm`,
`gpbstrflush.asm`, `compiler.asm`, `goto.asm` — assembles clean, produces a `GPC.BIN` with today's
timestamp, and **does not contain the change**.

**Use `make libs` from the repo root.** It runs `make -C source`, which rebuilds every library
including `compiler.library`, then the application, and copies `GPC.BIN` to `testing/` as well.

## What it looks like when it bites

Found 2026-09-08 building the `GP.BANKED REGION OVER 8K` message. Two full emulator cycles went into
compiling the same test twice and getting the **old** error text both times, with a `GPC.BIN` dated
minutes earlier each time. The tell was one `ls`:

    bin/common.library      Sep 8 09:18     rebuilt
    bin/compiler.library    Sep 7 22:21     eleven hours stale
    source/application/GPC.BIN  Sep 8 09:18 freshly dated, silently wrong

There is no warning and no error. The link succeeds because the stale library is a valid library.

**`ls -la bin/*.library` before believing a compiler change did not work.** A change that appears to
have had no effect at all — same output, byte for byte, from a binary you just built — is a build
question first and a code question second.

**Which tree a file is in decides this**, and the two are easy to confuse: `object.asm` lives in
`source/application/source/compiler/` and goes into `GPC.BIN` through `_library.asm`, so the
application make *does* pick it up. `gpbank.asm` lives in `source/compiler/source/commands/` and does
not. A change touching both partly lands, which is worse than not landing at all.

Related: [[baseline-compiler-is-the-application-copy]] (the neighbouring trap — `testing/GPC.BIN`
lagging `source/application/GPC.BIN`), [[build-toolchain-location]], [[headless-basl-build-recipe]],
[[measure-before-changing-code]].
