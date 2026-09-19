---
name: test-in-gpbmods-before-spreading
description: "A library change is built and tested in GPBMODS before it is copied into ANY other sample's GPC-BASIC folder, not just root"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b52e8c4f-ffdf-4b2a-89c7-8a57e0a20a41
  modified: 2026-09-19T14:45:12.096Z
---

A library change made in samples/GPB-MODS-TESTING/GPC-BASIC/ stays there until GPBMODS has been
built and tested with it. Only then does it go anywhere else: root GPC-BASIC/ **and** the private
GPC-BASIC/ copies inside other samples (editor, GPC-HELP, GPC-GUI-HELPER, XBASE).

**Why:** 2026-09-19, the dialog-verb rework (GUI-DIALOGS) was ported into three samples' own
library copies before GPBMODS had been built once. The user: "i wanted testing 1st before we
copied". A sample's private copy is still a copy.

**How to apply:** when a plan has a "convert the other samples" step, put "build and test GPBMODS"
ahead of it and stop there for the user. Extends [[library-working-copy-then-root]].
