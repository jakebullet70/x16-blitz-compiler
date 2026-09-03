---
name: no-backward-compatibility-needed
description: "This user is the only user of GPC Blitz; do not weigh backward compatibility, token renumbering or forced recompiles as costs"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T10:01:30.155Z
---

**Stated 2026-09-01:** *"remember, we are the only user testing, there is 0 impact
to any other users."*

So **backward compatibility is not a cost in this repo.** Renumbering p-codes,
freeing and reusing keyword tokens, bumping `RT_ABI`, or forcing every SHARED-mode
program to be recompiled are all free. Do not raise them as objections, and do not
design around them.

What this changes in practice: removing a GP keyword from the runtime block —
`gpsort.asm`, `gpstash.asm` — was costed partly on "every p-code after it
renumbers". That objection is void. The only real costs are the work of the port
and whether the replacement is as good.

Note the tree's own docs say some tokens are "never renumbered" and that
`GP.MENU` (52840) / `GP.SEL` (52839) are "NOT to be reused". Treat that as house
style worth keeping for readability of old PRGs, not as a compatibility
requirement — ask before breaking it rather than assuming either way.

Related: [[compiler-must-not-cap-program-size]], [[no-ship-language-this-is-dev]].
