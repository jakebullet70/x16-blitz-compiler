---
name: claim-every-compile-time-bank
description: "Standing rule: every GP.BANKED and GP.BANKEDSTR bank number must be BANKMGR.CLAIMed at startup, before the first ALLOC -- the compiler picks it, so the manager has to be told rather than asked"
metadata:
  type: feedback
---

**Adding a `GP.BANKED` region or a `GP.BANKEDSTR` group to a program is not finished until
`BANKMGR` has been told that bank is taken.**

```basic
GOSUB BANKMGR.INIT
BANKMGR.WANT = SHIM.GUIBANK : GOSUB BANKMGR.CLAIM
BANKMGR.WANT = GM.TEXTBANK  : GOSUB BANKMGR.CLAIM
GOSUB BANKMGR.ALLOC                                ' only now
```

**Why:** the bank number in a `GP.BANKED` / `GP.BANKEDSTR` header is a decimal constant the
compiler reads while it writes the object. Nothing about it survives into the runtime, and
`BANKMGR` has no way to discover it -- it tracks a bitmap of promises between the program's own
modules. An unclaimed region bank stays marked free, so a later `BANKMGR.ALLOC` hands it to a
scratch user, which then writes its data over the program's own code or literal text. The failure
is silent and arrives far from the cause.

**How to apply:** claim before you allocate. Both claims sit above the first `ALLOC` in the
startup block, and each is checked -- `IF BANKMGR.OK = 0 THEN` a message, because a claim can only
fail if two owners named the same number, which is a bug worth naming rather than surviving.

**Status 2026-09-08:** the two programs in `samples/GPB-MODS-TESTING/` already do this -- GPBMODS
and GPBFILES both claim `SHIM.GUIBANK` and `GM.TEXTBANK`. The rule is written up in the
`GP.BANKEDSTR` section of `GPC-BASIC/GP-BASIC.md`. **It is the OTHER programs that still have to
be checked**, as each is converted to the new runtime: anything that gains a banked region or
banked text also gains a claim, and anything that already uses `BANKMGR.ALLOC` without one is a
live corruption waiting to happen.

Related: [[gp-bankedstr-literal-text-in-a-bank]], [[gp-banked-region-relocation]],
[[gp-banked-call-out-loses-the-bank]], [[gpc-bank-statement-not-poke-zero]].
