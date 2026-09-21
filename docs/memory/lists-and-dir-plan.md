---
name: lists-and-dir-plan
description: "Agreed 2026-09-19: list verbs read GP.BSTR-layout banks at run time, no compiler work. All three slices done and tested on the machine by 2026-09-21; next is update other projects"
metadata: 
  node_type: memory
  type: project
  originSessionId: b52e8c4f-ffdf-4b2a-89c7-8a57e0a20a41
  modified: 2026-09-20T15:45:48.582Z
---

Agreed with the user 2026-09-19. **The compiler is off the table.**

**Where it stands 2026-09-21:** ALL THREE SLICES are done and RUN on the machine — LIST.BANK
with its demo, and FILEPICK in both bank modes (the FILES menu's TWO BANKS and ONE BANK rows
both pass; about 2 s of that is FILEDIR pulling the listing in, not the picker -- and that
2 s is OUR read loop, not the host: see [[hostfs-is-not-the-dir-slowness]]). Slice 3,
LIST.SORT, passed on build 008: the FILES row PICKFILE SORTED LIST reads the drive, sorts
and puts up ONE sorted box. Two things came out of testing it and are in the code now:
PICKSCAN, a drive read with no box, so the only list the user sees is the sorted one; and
the two waits naming themselves on a banner in the MIDDLE of the screen (GM.BUSYY%), because
nobody reads the result row at the bottom while a wait is happening.

- Two list sources: low array `GUI.LIST.ITEM$()` and a BANK holding the GP.BSTR image
  layout ($A000 count16, $A002 count x offset16 to each record's LENGTH byte, records
  [cap][len][cap bytes]). Row N is read with BANK + PEEK in the library, bank a runtime number.
- The engine touches items only at GUI.INC.BL's row draw and the width measure in
  GUI-DIALOGS DLG.LISTBOX*; those became one "fetch row N", `GUI.LIST.FETCH`.
- Rule: a list's text group must be the FIRST group declared in its bank (base 0, so
  GP.BSTR(name,n) == bank row n).
- FILEPICK: FILEDIR raw listing into a scratch bank, the scan POKEs a runtime image
  (name 16 + blocks + type, cap = len, offset table reserved at the front for MAX) into a
  list bank. Two banks or one packed bank is a CALLER OPTION. No low arrays.
- **LIST.SORT bank,first,last** is in GUI-DIALOGS.INC.BL beside the other LIST verbs: a shell
  sort that moves the 2-byte OFFSET ENTRIES only, so records never travel and a caller's
  pointer into one stays good -- but a string NUMBER does not. It reaches the bank through
  STASH.SELECT, which is how the module keeps its "executes no BANK statement" promise for a
  GP.BANKED region. GPBMODS tests it on the FILES row PICKFILE SORTED LIST (GMX.F.PICKSORT):
  pick, then sort the list left behind in the bank and show it again with LIST.BANK, without
  going near the drive.
- Multi-select cap 255 (MARKS$ string) is fine.
- Speed: BASIC PEEK fetch first; if it is slow, a small GP.ASM blob (user pre-agreed).
- Verbs: LIST.BEGIN title$,rows / LIST.ARRAY count / LIST.BANK bank,first,last /
  N = LISTTO.RUN / GP.FN(LIST.ITEM,N) / LIST.SORT bank,first,last / GP.FN(PICKFILE, title$,ext$).
- **"update other projects" is DONE 2026-09-21**, committed and pushed. Root GPC-BASIC took the
  tested modules and the editor, GPC-HELP, GPC-GUI-HELPER and color-test took them from root.
  GUI2.INC.BL is deleted everywhere (it was GUI.LISTBOX alone), GUI.EXP.BL is on the EX verbs, and
  GPC-GUI-HELPER is off the old FILEPICK.RUN and onto PICKBANKS/PICKFILE with a second bank.
  GPC.GUI is in samplesbuild.py now. All six samples COMPILE; none but GPBMODS has been RUN.
  Follows [[gui-only-through-verbs]], [[test-in-gpbmods-before-spreading]],
  [[library-working-copy-then-root]].
- STILL OWED: run the five non-GPBMODS samples on the machine, and regenerate the GPB.HELP topics
  from the rewritten GP-BASIC.md §4.11/§4.12 -- see [[hlp-files-carry-hand-edits]] before running
  MKHELP.PY. GG.PICK.RUN in GPC-GUI-HELPER still GOSUBs GUI.OPEN and GUI.FORM.* directly, against
  [[gui-only-through-verbs]].
