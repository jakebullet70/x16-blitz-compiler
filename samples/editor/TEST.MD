# GPC EDIT -- a Markdown editor for the Commander X16

This file is the bullet-list fixture the self-check searches, and it is also
- the second bullet, which find-next has to land on
- a third, so the list reads as a list
- a fourth, for the same reason

You are looking at it in GPC EDIT itself: this is the file the editor opens
when it starts, so the first thing you see is real text in a real document
rather than an empty screen.

## Keys

  Arrows        move the caret; the view scrolls when you reach an edge
  Home / End    start and end of the line
  PgUp / PgDn   a screen at a time
  RETURN        split the line here
  BACKSPACE     delete left, joining lines at column one
  DEL           delete right, joining the next line at end of line
  INS           toggle insert / overwrite (the status line says which)
  ESC           open the menu bar; ESC again closes it
  F2            save
  F3            find again

## Menus

  File          New, Open, Save, Save As, Exit
  Search        Find, Go to line
  Help          About

A menu opens with ESC or by its highlighted letter. Inside one, the arrow keys
move, RETURN chooses and ESC backs out. A file with unsaved changes is marked
with a star in the title bar, and anything that would throw those changes away
asks first.

## What this is for

GPC EDIT is a sample. It is a genuinely useful program, and it is here because
it leans on the one thing an interpreted BASIC is worst at: repainting a whole
screen of text quickly. Every cell you see -- the text, the bars, the menus,
the caret -- is written straight into the VERA text map. No PRINT, no LOCATE.

The row renderer and the field renderer are both inline 65C02 assembly, written
in GP.ASM blocks inside the BASIC source and assembled into the program by the
compiler. That is the whole speed story: the VERA path was always the fast one,
and the loop around it was what cost. Read EDITOR.BASL to see it -- the assembly
sits where the FOR loop used to, a few lines further down the same routine.

## Try it

Type into this paragraph and watch the status line count the column. Press F3
and search for a word. Go to a line with the Search menu. Then open EDITOR.BASL
in the editor and read the renderer while the renderer is drawing it.

Nothing here is precious -- it is a fixture. Save over it, cut it about, or
open one of your own files instead.
