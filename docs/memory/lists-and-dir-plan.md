---
name: lists-and-dir-plan
description: "Agreed 2026-09-19: list verbs read any bank in GP.BSTR image layout at run time; no compiler changes; FILEPICK builds a runtime image"
metadata: 
  node_type: memory
  type: project
  originSessionId: b52e8c4f-ffdf-4b2a-89c7-8a57e0a20a41
  modified: 2026-09-19T17:05:12.014Z
---

Agreed with the user 2026-09-19, not started. **The compiler is off the table.**

- Two list sources: low array `GUI.LIST.ITEM$()` and a BANK holding the GP.BSTR image
  layout ($A000 count16, $A002 count x offset16 to each record's LENGTH byte, records
  [cap][len][cap bytes]). Row N is read with BANK + PEEK in the library, bank a runtime number.
- The engine touches items only at GUI.INC.BL's row draw and the width measure in
  GUI-DIALOGS DLG.LISTBOX*; those become one "fetch row N".
- Rule: a list's text group must be the FIRST group declared in its bank (base 0, so
  GP.BSTR(name,n) == bank row n).
- FILEPICK: FILEDIR raw listing into a scratch bank, the scan POKEs a runtime image
  (name 16 + blocks + type, cap = len, offset table reserved at the front for MAX) into a
  list bank. Two banks or one packed bank is a CALLER OPTION. No low arrays.
- LIST.SORT bank,first,last: BASIC shell sort, swaps the 2-byte offsets only.
- Multi-select cap 255 (MARKS$ string) is fine.
- Speed: BASIC PEEK fetch first; if it is slow, a small GP.ASM blob (user pre-agreed).
- Verbs: LIST.BEGIN title$,rows / LIST.ARRAY count / LIST.BANK bank,first,last /
  N = LISTTO.RUN / GP.FN(LIST.ITEM,N) / LIST.SORT / GP.FN(PICKFILE, ext$).
- Order: LIST.BANK + a LISTS-menu demo on a fixed group, then FILEPICK, then sort.
  Then "update other projects". Follows [[gui-only-through-verbs]], [[test-in-gpbmods-before-spreading]].
