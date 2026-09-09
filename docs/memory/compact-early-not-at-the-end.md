---
name: compact-early-not-at-the-end
description: "A long session's cost is the context re-read on EVERY turn, not the work done; /compact late spends the whole window at the high rate, and resuming a huge session re-caches it before doing anything"
metadata:
  type: feedback
---

**Measured 2026-09-08.** 75% of a 5-hour window went in **18 minutes** — and the window had been
completely dead for the 90 minutes before that, so nothing was running in the background.

The session had grown to a **558,000-token context**. Fourteen requests:

| what | cache read | cache write |
|---|---:|---:|
| resume — re-cache the whole context before doing anything | 32,771 | **522,458** |
| 9 turns writing memory notes | ~558,000 **each** | ~15,000 |
| `/compact` | 29,850 | 38,688 |
| 3 turns after it | ~70,000 each | 6,280 |

**5.3M cache-read for 31K of output.** The nine notes-writing turns cost 5.6M tokens of input to
produce ~12,000 tokens of actual text.

**Why:** cost tracks CONTEXT SIZE × TURNS, not difficulty. A trivial turn in a 558K context costs
40x the same turn in a 70K one, so a long session's cheapest-looking work is its most expensive.
Compaction cost the same 38K whenever it ran — running it after those nine turns bought nothing that
running it before would not have.

**How to apply:** `/compact` when the context gets large, not when the work is finishing. It cut the
per-turn read 558K -> 70K, an **8x** cut, and the tail of that session would have been nearly free on
the other side of it.

**Every step is the cadence.** Asked for 2026-09-08 as "between phases", and **widened 2026-09-09 to
EVERY step**: whenever a discrete piece of work lands — a phase, a build, a measurement, a file
written — close by reminding the user to `/compact` before the next one is picked up. It is the
natural point, because the context that mattered for the step just finished is exactly what
compaction should drop, and the plan document carries forward what the next step needs anyway.
**Prompt for it every time; do not wait to be asked, and do not skip a step because it felt small.**
A small step in a large context is precisely the expensive case.

Two specific traps:

- **Resuming a huge session is not free.** It re-establishes the entire cache first — 522K here,
  before a single useful token. A session left to grow across days is worth ending, not resuming.
- **Long-running sessions are the whole story.** When usage spikes, the answer is almost never a
  stray process. Suspect the biggest transcript.

**How to check it, and do check rather than speculate** — every billed request is a `usage` record in
`~/.claude/projects/<proj>/*.jsonl`, timestamped UTC. Sum `cache_read_input_tokens` per message and
the shape is unmistakable. Note the transcript records some messages more than once, so dedupe by
timestamp. The 5-hour window's start is the reset time minus five hours, in LOCAL time, against UTC
timestamps.

Related: [[measure-before-changing-code]], [[answer-the-question-asked]].
