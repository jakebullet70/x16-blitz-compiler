# EDIT - an MS-DOS-EDIT-style text editor / IDE for the Commander X16

 A full-screen text editor & BASLOAD IDE with a menu bar, dropdown menus and a status line. The document lives in banked RAM, so files are not capped by low memory. It has selection and clipboard, undo / redo, find / replace, optional BASIC
 syntax colouring and line numbers, soft word wrap, colour themes, and can
 hand a file to the ROM BASLOAD tool to tokenize and run it.

 Open the menus with ESC or ALT (the Commodore key); the highlighted red
 letter is each menu's accelerator (e.g. ALT+F = File). Everything on the
 menus also has a shortcut key, listed below.

## MOVEMENT
   Arrows        Move the cursor
   Ctrl+Lt/Rt    Jump a word left / right
   Home / End    Start / end of the line
   PgUp / PgDn   Page up / down
   Ctrl+J        Go to a line number

## SELECTING TEXT
   Shift+arrows  Extend the selection as the cursor moves
   Shift+Home    Select to the start of the line
   Shift+End     Select to the end of the line
   (Any un-shifted cursor move clears the selection.)

## EDITING
   Tab           Insert 4 spaces
   Insert        Toggle insert / overwrite (INS / OVR on the status bar)
   Enter         Split the line (auto-indents to match the line above)
   Backspace     Delete the character to the left / join lines
   Ctrl+K        Delete the current line
   Ctrl+Up/Dn    Move the current line up / down
   Ctrl+Z        Undo            Ctrl+U   Redo

## CLIPBOARD
   Ctrl+C        Copy the selection, or the whole line if nothing is selected
   Ctrl+X        Cut  the selection, or the whole line if nothing is selected
   Shift+Del     Cut  (the same as Ctrl+X)
   Ctrl+V / F4   Paste

## FILES
   Ctrl+N        New document
   Ctrl+O        Open a file (file picker)
   F2            Save   (Save As... on the File menu prompts for a name)
   File > View   Show any file read-only in the viewer, without opening it
                 into the document (handy for files too big to edit)

## SEARCH
   Ctrl+F / F6   Find (wraps around; Cmdr+W toggles whole-word on the bar)
   Ctrl+G / F3   Find next
   Ctrl+R / F8   Replace - interactive: Y replace, N skip, A all, Esc stop

## DEV  (the Dev menu)
   F5            Save the file and run it through the ROM BASLOAD tool
   F8            After BASLOAD, at the BASIC READY prompt, return to EDIT
   Make Backup   Write a .bak copy of the current file (Dev menu)
   Syntax Color  Toggle BASIC syntax colouring (Dev menu)
   Line Numbers  Toggle the line-number gutter (Dev menu)
   Colours       Config... (Help menu) opens the theme picker, EDCFG

## IN THE FILE VIEWER  (File > View, and Help > Keyboard which shows this file)
   PgDn / PgUp   Page down / up        T  Top        B  Bottom
   H             Toggle hex / text (hex needs an 80-column screen)
   F             Find a string
   N / Space     Repeat the search (find next)
   Q / Esc       Quit back to the editor

## EMULATOR vs REAL HARDWARE
   The x16emu emulator window intercepts a few Ctrl chords before they reach
   the program, so those actions also have function-key aliases that work in
   both places:

     Action     Ctrl key      Alias
     Find       Ctrl+F        F6
     Replace    Ctrl+R        F8
     Paste      Ctrl+V        F4

   ALT is the left Alt key in the emulator, the Commodore (C=) key on real
   hardware. Arrows, function keys and the plain keys behave identically.

 EDIT  -  (c) sadLogic 2026  -  written in Prog8 with help from AI
 Press Q or Esc to return to the editor.
