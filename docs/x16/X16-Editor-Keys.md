# Commander X16 — Built-in Screen Editor Key Reference

Valid keys / control codes recognised by the X16's built-in screen editor.
Distilled from `Docs/x16/X16 Reference - 03 - Editor.md`. Codes are the PETSCII
values produced by the keypress (`CHR$(code)` prints the same effect). Entries
**new vs the C64** are marked ★.

---

## Editing & Navigation

| Key | Code | Action |
|-----|------|--------|
| RETURN | $0D | Enter line |
| SHIFT+RETURN | $8D | Return without executing (output: shifted return) |
| CURSOR DOWN | $11 | Move down |
| CURSOR UP | $91 | Move up (★ editor now scrolls up too) |
| CURSOR RIGHT | $1D | Move right |
| CURSOR LEFT | $9D | Move left |
| HOME | $13 | Cursor to top-left |
| CLR (SHIFT+HOME) | $93 | Clear screen |
| DEL / BACKSPACE | $14 | Delete char left |
| INSERT (SHIFT+DEL) | $94 | Insert space |
| FWD DEL (PS/2 Del) ★ | $19 | Delete char right |
| TAB ★ | $09 | Tab forward |
| SHIFT+TAB ★ | $18 | Tab backward |
| ESC | $1B | Escape |
| RUN/STOP | $03 | Stop (input) / RUN (output) |
| END ★ | $04 | Cursor to end |
| SHIFT+END (HELP) ★ | $84 | Help |
| PAGE DOWN ★ | $02 | Page down |
| PAGE UP ★ | $82 | Page up |

## Reverse & Color

| Key | Code | Action |
|-----|------|--------|
| SWAP COLORS ★ | $01 | Swap fg/bg color |
| REVERSE ON | $12 | Reverse video on |
| REVERSE OFF | $92 | Reverse video off |

Color codes (entered as CTRL+1‑8 for the first eight, C=+1‑8 for the next eight,
or printed via `CHR$()`):

| Color | Code | | Color | Code |
|-------|------|-|-------|------|
| BLACK | $90 | | ORANGE | $81 |
| WHITE | $05 | | BROWN | $95 |
| RED | $1C | | LIGHT RED | $96 |
| CYAN | $9F | | DARK GRAY | $97 |
| PURPLE | $9C | | MIDDLE GRAY | $98 |
| GREEN | $1E | | LIGHT GREEN | $99 |
| BLUE | $1F | | LIGHT BLUE | $9A |
| YELLOW | $9E | | LIGHT GRAY | $9B |

## Charset & Mode

| Key / Code | Code | Action |
|------------|------|--------|
| CHARSET LOWER/UPPER | $0E | Switch to upper/lowercase font |
| CHARSET UPPER/PETSCII | $8E | Switch to uppercase/graphics font |
| CTRL+O — ISO ON ★ | $0F | Enable ISO‑8859‑15 (ASCII) charset |
| ISO OFF ★ | $8F | Back to PETSCII (default) |
| VERBATIM MODE ★ | $80 | Print the next char literally (incl. CR/DEL) |
| BELL ★ | $07 | Beep |
| MENU ★ | $06 | Open the X16 Control Panel |
| LAYOUT SWAP (CTRL+K) ★ | $0B | Toggle current ↔ previous keyboard layout |

> **ISO mode note:** in ISO mode BASIC keywords must be typed in **upper case**
> (Shift held) and keyword abbreviation is disabled.

## Function Keys

Editor macros (only active at the editor prompt; while a program runs, the key
just yields its PETSCII code).

| Key | Code | Editor macro |
|-----|------|--------------|
| F1 | $85 | `LIST:` |
| F2 | $89 | `SAVE"@:` |
| F3 | $86 | `LOAD "` |
| F4 | $8A | Toggle 40/80 columns |
| F5 | $87 | `RUN:` |
| F6 | $8B | `MONITOR` |
| F7 | $88 | `DOS"$` + CR (directory) |
| F8 | $8C | `DOS"` |
| F9 ★ | $10 | (undefined) |
| F10 ★ | $15 | (undefined) |
| F11 ★ | $16 | (undefined) |
| F12 ★ | $17 | Emulator debug |

## Charset-switch lock

| Key | Code | Action |
|-----|------|--------|
| DISALLOW CHARSET SWITCH (SHIFT+ALT) | $08 | Lock current case |
| ALLOW CHARSET SWITCH | $09 | (shares $09 with TAB) Unlock |

---

## ISO-mode Alt / dead keys (default `ABC/X16` layout)

Only reachable in **ISO mode**; produce ISO‑8859‑15 characters.

**Direct Alt combos:** Alt+1 ¡ · Alt+3 £ · Alt+4 ¢ · Alt+5 § · Alt+7 ¶ ·
Alt+9 ª · Alt+0 º · Alt+q œ · Alt+r ® · Alt+t Þ · Alt+y ¥ · Alt+o ø ·
Alt+\ « · Alt+s ß · Alt+d ð · Alt+g © · Alt+l ¬ · Alt+' æ · Alt+m µ · Alt+/ ÷ ·
Shift+Alt+2 € · Shift+Alt+8 ° · Shift+Alt+9 · · Shift+Alt+- X16‑logo ·
Shift+Alt+= ± · Shift+Alt+q Œ · Shift+Alt+t þ · Shift+Alt+\ » · Shift+Alt+/ ¿
(and shifted letter variants Á É Í … per the source table).

**Dead keys** (press, then a letter):

| Dead key | Adds |
|----------|------|
| Alt+` (grave) | à è ì ò ù (+ caps) |
| Alt+6 (circumflex) | â ê î ô û (+ caps) |
| Alt+e (acute) | á é í ó ú ý (+ caps) |
| Alt+u (diaeresis) | ä ë ï ö ü ÿ (+ caps) |
| Alt+n (tilde) | ã ñ õ (+ caps) |
| Alt+k (ring) | å Å |
| Alt+c (cedilla) | ç Ç |
| Alt+v (caron) | š ž Š Ž |

> Full Alt/dead-key tables and the per-layout details are in
> `X16 Reference - 03 - Editor.md` (§ Keyboard Layouts). 27 ROM keyboard
> layouts are selectable via `KEYMAP"<id>"` (e.g. `KEYMAP"DE-DE"`) or the
> `MENU` control panel.
