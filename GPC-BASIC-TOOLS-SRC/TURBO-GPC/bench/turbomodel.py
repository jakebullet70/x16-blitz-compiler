"""The keys TURBOTEST types into the editor, and what the editor must have done with them.

    groups()         the keys, in the groups TURBOTEST.KEY holds
    write_script()   write TURBOTEST.KEY
    expected()       the documents, the cursor and the two bars after the last key

The header of TURBOTEST-DRIVER.BASL gives the layout of TURBOTEST.KEY. The work document
W.DOC is a copy of the fixture, and the last file of the bench folder, so End picks it in
the file picker. The script types on the empty document, opens W.DOC over it and edits. It
finds a term, finds it again and looks for a term that is nowhere. It finds the first term
twice more, picked from the find history with Up and Down. The history starts with one
term, from the settings store the run starts with. It plants four places of a new term,
finds it, and replaces it three times: answering Y, N, Y and Esc, then A with an empty
replacement, which it undoes, then A with the replacement picked from the replace history.
It picks File, Exit and
answers no to the quit question, saves, starts a new document, saves it as N.DOC, opens
W.DOC again, moves and saves. It goes to document B, types two lines and saves them as
B.DOC. It goes to document C and types a line it does not save. It goes past A to B,
undoes two edits, and through the Edit menu redoes one and undoes it again, then saves
B.DOC. It selects all of B, one line, and finds the selected text. Through the Edit menu
it selects, copies, cuts and pastes in B, and saves B.DOC again. It goes past C to A and
saves A. The driver quits through File, Exit.
"""

import os

import keymodel

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT_FILE = os.path.join(HERE, "TURBOTEST.KEY")
WORK_NAME = "W.DOC"
NEW_NAME = "N.DOC"
B_NAME = "B.DOC"
GROUP_LIMIT = 10
# TEST.SCRIPT.BYTES in TURBOTEST-DRIVER.BASL.
SCRIPT_LIMIT = 1024

FIND, FIND_NEXT, SAVE, OPEN, NEW, ESCAPE, HELP = 6, 134, 137, 15, 14, 27, 133
NEXT_DOCUMENT = 136
REPLACE = 8
UNDO = 26
# The attributes of A, B and C on the title bar at the end: A is on screen, B is saved and
# C has an edit. They are the X16 theme's text, its bar, and yellow on the bar.
DOCUMENT_ATTRIBUTES = (97, 193, 199)
YES, NO = 89, 78
# The hot key of Discard, the second button of the question before changes are lost.
DISCARD = 68
# Esc opens the File menu. X is the hot key of its Exit row. U and R are the hot keys of Undo
# and Redo in the Edit menu, which Right reaches from File, and T, C, P and A those of Cut,
# Copy, Paste and Select All. A key the driver types carries no modifier, so the clipboard
# keys of the key map are out of its reach.
EXIT, MENU_UNDO, MENU_REDO = 88, 85, 82
MENU_CUT, MENU_COPY, MENU_PASTE, MENU_SELECT_ALL = 84, 67, 80, 65
TERM = b"gosub"
# The replace term, which no line of the fixture holds, and its replacement.
PLANTED = b"zq"
REPLACEMENT = b"r"
LINE_LIMIT = 250
# The settings store the run starts with: a key of another program, and a find history of
# one term.
OLD_TERM = b"OLDTERM"
SETTINGS_BEFORE = {b"OTHER.KEY": b"KEEP", b"TG.FIND.1": OLD_TERM}


def typed(text):
    """Return the key codes that type text. A letter is typed unshifted."""
    return [keymodel.key_code(character.lower()) for character in text]


def edit_menu(hot_key):
    """Return the keys that pick a row of the Edit menu by its hot key."""
    return [ESCAPE, keymodel.RIGHT, hot_key]


def find(lines, line, col, term):
    """Return the line and column of the next place term starts after the cursor. The
    search goes to the last line, then once more from the first. None when it is nowhere."""
    for number in range(line, len(lines)):
        at = lines[number].lower().find(term, col + 1 if number == line else 0)
        if at >= 0:
            return number, at
    for number in range(len(lines)):
        at = lines[number].lower().find(term)
        if at >= 0:
            return number, at
    return None


def replace_walk(lines, term, replacement, answers):
    """Return the lines, the cursor and the count of places replaced after a replace run, as
    TURBO.REPLACE.WALK makes them. answers are "y", "n", "a" and "esc", one for each place
    asked about. The cursor is None when no place was asked about."""
    lines = list(lines)
    answers = list(answers)
    cursor = None
    count = 0
    every = False
    number, start = 0, 0
    while True:
        place = None
        for candidate in range(number, len(lines)):
            at = lines[candidate].lower().find(term, start if candidate == number else 0)
            if at >= 0:
                place = (candidate, at)
                break
        if place is None:
            break
        number, at = place
        answer = "a" if every else answers.pop(0)
        if not every:
            cursor = (number, at + len(term))
        if answer == "esc":
            break
        start = at + len(term)
        if answer != "n" and len(lines[number]) - len(term) + len(replacement) <= LINE_LIMIT:
            lines[number] = lines[number][:at] + replacement + lines[number][at + len(term):]
            count += 1
            start = at + len(replacement)
        if answer == "a":
            every = True
    assert not answers
    if cursor is not None:
        cursor = (cursor[0], min(cursor[1], len(lines[cursor[0]])))
    return lines, cursor, count


def plan():
    """Return the key groups and the expectations."""
    groups = []
    lines = keymodel.fixture_lines()
    line = 0
    col = 0

    def edit(keys):
        nonlocal lines, line, col
        lines, line, col = keymodel.run(lines, [(code, 0) for code in keys], line, col)
        for start in range(0, len(keys), GROUP_LIMIT):
            groups.append(keys[start:start + GROUP_LIMIT])

    def jump(place):
        nonlocal line, col
        assert place is not None
        line, col = place

    # ---- the empty document, then W.DOC over it. Discard, the answer to the question before
    # the changes are lost, and the picker's End and RETURN are in the open key's group.
    groups.append(typed("ab") + [keymodel.RETURN] + typed("c"))
    groups.append([OPEN, DISCARD, keymodel.END, keymodel.RETURN])

    edit([keymodel.DOWN] * 3 + typed("xy") + [keymodel.RETURN, keymodel.END, keymodel.BACKSPACE])
    edit([keymodel.TAB] + typed("z") + [keymodel.DOWN, keymodel.HOME, keymodel.DELETE, keymodel.DELETE_LINE])
    edit([keymodel.PAGE_DOWN, keymodel.PAGE_DOWN, keymodel.UP, keymodel.RIGHT, keymodel.RIGHT])

    # ---- find, find next, and a term that is nowhere. A typed letter marks each place.
    groups.append([FIND] + typed(TERM.decode()) + [keymodel.RETURN])
    jump(find(lines, line, col, TERM))
    edit(typed("q"))
    groups.append([FIND_NEXT])
    jump(find(lines, line, col, TERM))
    edit(typed("j"))
    groups.append([FIND] + typed("zqx") + [keymodel.RETURN])
    assert find(lines, line, col, TERM + b"zqx") is None
    edit(typed("k"))

    # ---- the find history: the terms are "gosubzqx", then "gosub". The box starts with the
    # last term. Up passes over the newest entry, the same text, and shows "gosub". Then the
    # history is "gosub", then "gosubzqx": Up shows "gosubzqx" and Down "gosub" again.
    groups.append([FIND, keymodel.UP, keymodel.RETURN])
    jump(find(lines, line, col, TERM))
    edit(typed("h"))
    groups.append([FIND, keymodel.UP, keymodel.DOWN, keymodel.RETURN])
    jump(find(lines, line, col, TERM))
    edit(typed("w"))

    # ---- replace. Three "zq" on the cursor line and one on the next are the places. A find
    # makes "zq" the term: five Backspaces clear "gosub" from its box. A run's keys stay in one
    # group, because the run reads the key buffer.
    edit(typed(PLANTED.decode() * 3) + [keymodel.DOWN] + typed(PLANTED.decode()))
    groups.append([FIND] + [keymodel.BACKSPACE] * 5 + typed(PLANTED.decode()) + [keymodel.RETURN])
    jump(find(lines, line, col, PLANTED))
    planted_lines = [number for number, text in enumerate(lines) if PLANTED in text.lower()]
    assert len(planted_lines) == 2
    # Y, N, Y on the cursor line, and Esc on the next.
    groups.append([REPLACE, keymodel.RETURN] + typed(REPLACEMENT.decode()) + [keymodel.RETURN]
                  + typed("yny") + [ESCAPE])
    lines, cursor, count = replace_walk(lines, PLANTED, REPLACEMENT, ["y", "n", "y", "esc"])
    assert count == 2
    line, col = cursor
    # The replace box starts with "r". Backspace empties it, so the run takes "zq" out, and A
    # answers both places. The undo puts them back, with the cursor at column 0 of the first
    # line the run changed.
    before = list(lines)
    groups.append([REPLACE, keymodel.RETURN, keymodel.BACKSPACE, keymodel.RETURN] + typed("a"))
    lines, cursor, count = replace_walk(lines, PLANTED, b"", ["a"])
    assert count == 2
    groups.append([UNDO])
    lines = before
    line, col = planted_lines[0], 0
    # The replace box starts empty, and Up shows "r", the newest entry of the replace history.
    groups.append([REPLACE, keymodel.RETURN, keymodel.UP, keymodel.RETURN] + typed("a"))
    lines, cursor, count = replace_walk(lines, PLANTED, REPLACEMENT, ["a"])
    assert count == 2
    line, col = cursor

    # ---- File, Exit and no to the quit question, a key with no command behind it, then save
    groups.append([ESCAPE, EXIT, NO])
    edit(typed("m"))
    groups.append([HELP])
    groups.append([SAVE])
    saved = list(lines)

    # ---- a new document saved under a name the prompt asks for
    groups.append([NEW] + typed("new"))
    groups.append([SAVE] + typed(NEW_NAME) + [keymodel.RETURN])

    # ---- W.DOC again
    groups.append([OPEN, keymodel.END, keymodel.RETURN])
    line = 0
    col = 0
    edit([keymodel.PAGE_DOWN, keymodel.DOWN, keymodel.END])
    assert lines == saved
    groups.append([SAVE])

    # ---- documents B and C, then A again with its cursor where it was. In B the two undos
    # take back "two" and then the RETURN. The redo and the undo after it cancel, so B.DOC
    # is one line. The redo and the last undo are the Edit menu's.
    groups.append([NEXT_DOCUMENT] + typed("bee") + [keymodel.RETURN] + typed("two"))
    groups.append([SAVE] + typed(B_NAME) + [keymodel.RETURN])
    groups.append([NEXT_DOCUMENT] + typed("sea"))
    groups.append([NEXT_DOCUMENT, NEXT_DOCUMENT, UNDO, UNDO, ESCAPE, keymodel.RIGHT, MENU_REDO,
                   ESCAPE, keymodel.RIGHT, MENU_UNDO])
    groups.append([SAVE])

    # ---- the find box starts with "bee", the selected text, and RETURN finds it. B's
    # cursor moves and nothing else changes.
    groups.append(edit_menu(MENU_SELECT_ALL) + [FIND, keymodel.RETURN])

    # ---- the clipboard, in B, which holds "bee". Each comment gives the document after the
    # group. A menu's keys stay in one group, because the dropdown reads the key buffer.
    # "bee" selected whole is text: its paste goes in at the cursor. A copy with no selection
    # takes the line, and its paste goes below the cursor line. A typed key replaces the
    # selection. The undo and the redo take the two-line paste out and put it back. The cut
    # with no selection takes the last line, and its paste goes below line 0.
    groups.append([keymodel.HOME] + edit_menu(MENU_SELECT_ALL) + edit_menu(MENU_COPY) + [keymodel.HOME])
    groups.append(edit_menu(MENU_PASTE) + edit_menu(MENU_COPY) + edit_menu(MENU_PASTE))
    # beebee / beebee
    groups.append(edit_menu(MENU_SELECT_ALL) + typed("z") + edit_menu(MENU_PASTE) + typed("x"))
    # z / xbeebee
    groups.append(edit_menu(MENU_SELECT_ALL) + edit_menu(MENU_COPY) + [keymodel.END] + edit_menu(MENU_PASTE))
    # z / xbeebeez / xbeebee
    groups.append([UNDO] + edit_menu(MENU_REDO) + [keymodel.DOWN, keymodel.DOWN])
    groups.append(edit_menu(MENU_CUT) + [keymodel.UP] + edit_menu(MENU_PASTE))
    # z / xbeebee / xbeebeez
    groups.append([SAVE])
    groups.append([NEXT_DOCUMENT, NEXT_DOCUMENT])
    groups.append([SAVE])

    for group in groups:
        assert 0 < len(group) <= GROUP_LIMIT
    return groups, {
        "documents": {WORK_NAME: saved, NEW_NAME: [b"new"], B_NAME: [b"z", b"xbeebee", b"xbeebeez"]},
        "cursor": (line, col),
        "name": WORK_NAME.lower(),
        "message": "Saved",
        "document attributes": DOCUMENT_ATTRIBUTES,
        "settings": settings_after(),
    }


def settings_after():
    """Return the keys of the settings store after the run. A key the store must not hold
    is None. A find term is the bytes of the keys typed."""
    terms = ("bee", PLANTED.decode(), TERM.decode(), TERM.decode() + "zqx")
    history = [bytes(typed(term)) for term in terms]
    history.append(OLD_TERM)
    replacements = [bytes(typed(REPLACEMENT.decode()))]
    settings = {b"OTHER.KEY": SETTINGS_BEFORE[b"OTHER.KEY"]}
    for place in range(1, 7):
        settings[b"TG.FIND.%d" % place] = history[place - 1] if place <= len(history) else None
        settings[b"TG.REPLACE.%d" % place] = replacements[place - 1] if place <= len(replacements) else None
    return settings


def groups():
    return plan()[0]


def expected():
    return plan()[1]


def write_script():
    data = bytearray()
    for group in groups():
        data.append(len(group))
        data += bytes(group)
    data.append(0)
    assert len(data) <= SCRIPT_LIMIT
    # BLOAD takes the file's bytes as they are, with no load address in front.
    with open(SCRIPT_FILE, "wb") as f:
        f.write(data)
    return len(data)


def bar_text(cells):
    """Return the text of one dumped screen row. cells is a character and an attribute for
    each cell. A screen code with no ASCII letter gives ?."""
    out = []
    for code in cells[0::2]:
        if 1 <= code <= 26:
            out.append(chr(code + 96))
        elif code == 30:
            out.append("^")
        elif 32 <= code <= 63 or 65 <= code <= 90:
            out.append(chr(code))
        else:
            out.append("?")
    return "".join(out)
