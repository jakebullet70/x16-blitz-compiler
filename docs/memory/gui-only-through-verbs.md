---
name: gui-only-through-verbs
description: "Programs reach the GUI only through GP.DEFPROC verbs, the way MENU works; no GOSUB GUI.* outside the library"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b52e8c4f-ffdf-4b2a-89c7-8a57e0a20a41
  modified: 2026-09-19T14:51:31.862Z
---

A program never sets GUI.* inputs and never does GOSUB GUI.OPEN / GUI.FORM.RUN / GUI.CLOSE itself.
Every dialog, form and picker is a verb in GUI-DIALOGS.INC.BL. The GUI.* engine becomes internal,
the way MENU's internals sit behind MENU.BEGIN / MENU.ITEM / MENUTO.*.

**Why:** 2026-09-19, the user: "I only want to call the code through the new verbs, like the menu
code. the menu code is now dead simple. I want the gui to follow that idea."

**How to apply:** a new GUI feature ships as a verb, not a label with inputs. Plug-in controls
(CHECK, COMBO) may still GOSUB engine labels; they are the library. Extends
[[no-backward-compatibility-needed]] and [[gp-defproc-one-line-calls]].
