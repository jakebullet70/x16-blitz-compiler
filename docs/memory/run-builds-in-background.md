---
name: run-builds-in-background
description: Fire builds with run_in_background so a typed message cannot cancel them
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 39165f33-c388-4120-897a-33de633496bc
  modified: 2026-09-11T10:59:13.631Z
---

Start every build with the Bash tool's `run_in_background` flag, then report the numbers
when the completion notification arrives.

**Why:** a message typed while a tool is in flight cancels that tool. On 2026-09-11 three
XBase builds in a row were killed that way: the user saw no output, assumed nothing had
started, typed again, and killed the next one. The builds themselves were never the
problem — the run is ~75 seconds, settled in [build-report-dont-investigate](build-report-dont-investigate.md).

The delay he was reacting to is the pause before the first tool call, not the build. His
`~/.claude/settings.json` carries `"effortLevel": "xhigh"`, which buys minutes of thinking
ahead of every turn. He was offered `"medium"` and has not yet said yes, so leave the file
alone until he does.

**How to apply:** background the build, say in one line that it is running, and stay quiet
until it finishes. Do not poll — the notification arrives on its own. If he asks what is
taking so long, answer with what is actually running rather than re-explaining the build
cost.
