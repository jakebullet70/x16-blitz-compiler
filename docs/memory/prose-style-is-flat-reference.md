---
name: prose-style-is-flat-reference
description: The user rejected the essayistic comment/doc voice; the settled rules live in the doc-style agent
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a6175322-7b3e-463a-bb18-626df55663ed
  modified: 2026-09-05T01:48:55.700Z
---

On 2026-09-05 the user said the way comments and docs were being written was "wrong for a
programmer" for their taste. The essayistic voice in `GPB.HELP.BASL` and `HELP-TXT/*.HLP` was the
specific offender: em-dash asides, points restated for effect, ALL CAPS for stress.

Five decisions were settled and written into `.claude/agents/doc-style.md`:

1. Comments: contracts, traps, checklists and `## ---- section ----` signposts. No trivial, no
   TODO, no commented-out code, and **no history** -- "it was X until Y" is deleted on sight.
2. Voice: flat reference. One fact a sentence, present tense, no asides, no restating.
3. Help layout: a concept page that points, one fixed-slot entry per keyword
   (Syntax / Returns / Kind / Notes / WARNING / Example). A `>` row is display only -- the viewer
   has no cursor on a topic page and RETURN does not follow a link; **L** opens the dialog that
   lists the jump table and the see-alsos together.
4. Emphasis: caps only in a labelled `WARNING`, a handful per file.
5. **No Why slot and no justifying.** One person reads this code and it is the person who wrote
   it, so nothing is argued for and nothing records what was tried. State the limit, not the
   reason the author could not lift it. Design rationale that must be kept goes in
   `docs/blitz/GP-BASIC.TIERS.md`.

**Why:** the reader is a programmer at a keyboard with a question, not someone reading for
pleasure. Explanation where reference was wanted is the failure. On 2026-09-05 the user cut a
history sentence out of GP-BASIC.FILES.md and said to stop writing "why crap" -- there is no
audience to justify anything to.

**The three candidate layouts**, rendered as real 80x30 screens, are at
https://claude.ai/code/artifact/4a2ddf5c-a8ab-45d5-a043-b2bbf3ebbef0 .

**How to apply:** invoke `doc-style` for any prose work, or follow that file. It applies to
`.BASL` / `.INC.BL` comments, 64tass sources, and `GPC-BASIC/GP-BASIC.md` — never to
`HELP-TXT/*.HLP`, which `MKHELP.PY` generates. See [[compile-shared-not-embedded]] and
[[comments-light-code-should-flow]], which this supersedes on voice.
