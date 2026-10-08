---
name: release-1-2-0-progress
description: "v1.2.0 release, seven steps, all done 2026-10-08: zip built, docs and release notes committed; 1.1.0 was never public, so the notes run from 1.0.0"
metadata:
  node_type: memory
  type: project
  originSessionId: ec94f0c6-00cf-4484-b8af-f7e45a81977a
  modified: 2026-10-08T16:50:56.646Z
---

The 1.2.0 release ships without the TURBO GPC editor. There are seven steps:

1. Land the compiler and BASLOAD work. Done in 2cb7ca4.
2. Promote the six drifted library modules to root (CHECK, COMBO, GUI, GUI-DIALOGS, FILEDIR,
   FILEPICK). Done in 7d26d3f, with GPBMODS build 033.
3. Rebuild every release sample on V1.2.0, runtime 133. In progress.
4. The user play-tests.
5. Docs: What's new, a migration note, Known issues, the manual, MKHELP, a 78-column check.
6. Run release.sh, the user reviews release/TMP, zip as gpc-release-1.2.0.zip.
7. Commit and a memory note.

User decisions: the int16 library conversion is deferred to 1.3. Known issues must list the
second-DIM bug, a GP.ASM label starting with A ([[gpasm-label-cannot-start-with-a]]), and that
GP.ASM `{VAR}` needs a SYM file from BASLOAD-GPC, because the ROM BASLOAD writes names with no
sigil ([[basload-name-space-widened]]). A bare-name fallback in gpasmcode.asm is an open option
that needs the user's go-ahead for the asm.

**Step 3 state on 2026-10-08, uncommitted, interrupted by a reboot:**
- The five `.132.` runtimes in the tool home (GPC-BASIC-TOOLS-SRC/GPC, gitignored) are deleted.
  The three tracked `.132.` runtimes in GPB-MODS-TESTING are still there; the user has not said
  whether to delete them.
- The user chose to sync the whole root GPC-BASIC into the six sample folders: GPC-HELP,
  GPC-GUI-HELPER, GPC.ERR, GUI-FIELD-EDIT, KV-BIN-STORE, edit. Only files a folder already had
  were overwritten. The GPC tool-home copy got the six modules only. TURBO-GPC and XBASE were
  not touched.
- EDIT.BASL: the FILEIO/FILEDIR/FILEPICK region now sits between ED.GUICODE and ED.DLGCODE,
  because FILEPICK uses GUI's #DEFINE GUI.SPACE.
- Built clean: GPBMODS 27,793 B, COLORTST 17,297 B, BMXVIEW 16,785, GUI-LITE 18,065, MANDEL
  13,969, MANDELASM 15,761, LANDER64 18,833, KVBIN-BASIC 3,442, KVBIN-PROG8 3,855.
- GPC.HELP failed with LABEL NOT FOUND at GUI.INC.BL:767 (`GOSUB SV.START`). STASHVRAM.INC.BL was
  never in GPC-HELP's folder; GUI now saves dialog cells in VRAM through it. Fixed: copied it in
  and #INCLUDEd it in GPC.HELP.BASL (HELP.LIBCODE, after BANKMGR) and GPC.GUI.BASL (GG.UTILCODE,
  after THEME).
- The rerun (samples-step3c.log) failed all six: root MENU.INC.BANKED no longer defaults
  MENU.TEXTBANK (each program now has `#DEFINE MENU.TEXTBANK 62`), and root FILEPICK has no
  PICKBANKS. Root is int16 for THEME, BANKMGR, GUI, MENU, FILEIO, FILEPICK, KVBIN and STASHVRAM,
  so the old bare names (THEME.CLR, GUI.OK) compiled clean as new, unrelated variables. A scratch
  script renamed about 390 uses to the % names in the six programs and KVBIN-BASIC, which had
  built "clean" but broken. API ports: DLGRESET bank, $A000, 8192; LIST.BANK bank, $A000, first,
  last; FORM.ITEMS bank, $A000; PICKBANKS became PICKSPACE plus PICKDIRSPACE (bank, $A000, 8192
  each). Log for the rebuild of the seven: samples-step3d.log.
- samplesbuild.py bumps each master's "BUILD nnn" literal, which is why GUI-LITE.BASL shows as
  modified.
- The step3d rebuild was cut short by a second reboot on 2026-10-08. GPC.HELP (10,088 B) and
  GPC.GUI (9,609 B, OVL 25,103) built clean. EDIT was mid-build. Rerun only the five left:
  `python source/gpc/samplesbuild.py EDIT GPC.ERR GUI-FIELD-EDIT KV-BIN-STORE KVBIN-BASIC`
  in the background. Failed builds delete their PRG.
- The rerun of the five (samples-step3e.log, 268 s) built clean: EDIT 31,121 B (OVL 27,405), GPC.ERR
  10,549 SHARED (OVL 28,433), GUI-FIELD-EDIT 18,321 (OVL 24,589), KV-BIN-STORE 22,417 (OVL 24,077),
  KVBIN-BASIC 3,544. All of step 3 is built.
- Step 3 committed in 134212b, with the three build 132 runtimes in GPB-MODS-TESTING deleted.
  Step 4, the user's play-test, is next.
- Step 4 play-test on 2026-10-08, by the user: GPC.HELP, GPBMODS, GPC.ERR, GUI-FIELD-EDIT,
  BMXVIEW, COLORTST, GUI-LITE, MANDEL, LANDER64 and KVBIN tested good. GPC.HELP repainted the
  whole screen after every dialog; fixed by deleting seven HELP.FULL/HELP.REDRAW sets, since
  GUI.CLOSE restores the covered cells (PRG 10,060 B, OVL 23,053). GPC.GUI and EDIT are not
  release items; release.sh does not stage them. GPC.GUI was rebuilt with runtime 133 in its
  folder anyway, and the user chose to keep it. The build 131 runtimes and the 131/132 images are
  deleted from every sample folder except XBASE; the embedded samples never used them. Step 4
  committed; step 5, the docs, is next.
- Step 5 migration note must list: int16 % names, #DEFINE MENU.TEXTBANK before
  MENU.INC.BANKED, DLGRESET/LIST.BANK/FORM.ITEMS gained an address, PICKBANKS became
  PICKSPACE then PICKDIRSPACE, FILEPICK.COUNT became FILEPICK.COUNT%.

On 2026-10-08 the user said the release goes out the morning of 2026-10-09, after their testing.
The UXCBASIC design draft ([[uxcbasic-plan]]) waits until the release is out.

- Step 5 on 2026-10-08, uncommitted: README.md gained What's new in 1.2.0, Upgrading from 1.1.0
  and two Known issues (second DIM, {VAR} sigil under ROM BASLOAD); GP-BASIC.md section 8 has five
  bugs. Build 131 names and sizes became 133 everywhere shipped: embedded runtime 10,495 CORE /
  12,031 GPBASIC, bank code 2,448, GPBase $3100. Every shipped readme passes 78 columns and ASCII.
  MKHELP, the TESTING render and MKHELPWIN were rerun: 76 topics, index 202 of 210 rows.

- Steps 5 to 7 on 2026-10-08. The user said 1.1.0 was never public, so RELEASE-NOTES.md (root,
  shipped in the zip) covers every change since 1.0.0, with an Upgrading from 1.0.0 section.
  README.md's What's new and Upgrading from 1.1.0 sections became a pointer to it. LICENSE is
  combined: Paul Robson 2023 and Steven De George SR 2026. BASLOAD's BSD licence ships as
  SRC/GPC-BASLOAD/LICENSE. release/gpc-release-1.2.0.zip is built: 359 files, 1,599,637 bytes.
  All seven steps are done.

**Why:** the release work spans many sessions and compacts.

**How to apply:** the release is done; a 1.2.x fix restages with `release.sh stage` then `zip`. Remind the user to /compact after each step
([[compact-early-not-at-the-end]]). Never commit OASIS, and leave the untracked TURBO.DEAD,
TURBO-GPC/bench and SETTINGS files alone. See [[release-1-1-0-state]].
