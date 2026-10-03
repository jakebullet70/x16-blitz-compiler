"""The keys KEYBEN.BASL feeds to KEYS.DISPATCH, and a model of what they do.

    script()             the keys, as (code, modifiers) pairs
    write_script()       write them to KEYBEN.KEY
    run(lines, keys)     apply keys to a document: (lines, cursor line, cursor column)
                         The cursor starts at line 0, column 0, or where line and col say.
    play(lines, keys)    as run(), and the selection's anchor as a fourth value: a (line,
                         column) pair, or None when no selection is on

KEYBEN.KEY is the number of keys as two bytes, low byte first, then two bytes a key: its
code and its modifiers. A document here is a list of lines as a saved file holds them.
The model follows TG-VIEW.BASL, TG-KEYS.BASL and TG-CLIP.BASL. It has no undo, so the
script has no undo key. The clipboard starts empty and is never full.
"""

import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "FIX2000.TXT")
SCRIPT_FILE = os.path.join(HERE, "KEYBEN.KEY")

DOWN, UP, RIGHT, LEFT = 17, 145, 29, 157
HOME, END, PAGE_DOWN, PAGE_UP = 19, 4, 2, 130
RETURN, BACKSPACE, DELETE, TAB, DELETE_LINE = 13, 20, 25, 9, 12
SHIFT_HOME, SHIFT_END, INSERT = 147, 132, 148
CUT, COPY, PASTE, SELECT_ALL = 24, 3, 22, 1
SHIFT = 1
CTRL = 4
SPACE = 32
PANE_ROWS = 28
TAB_WIDTH = 4
LINE_LIMIT = 250
RING_DEPTH = 512
EDIT_KEYS = (RETURN, BACKSPACE, DELETE, TAB, DELETE_LINE)
# The actions of KEYS.SETUP's tables in TG-KEYS.BASL. Change them together.
ACT_TYPE, ACT_DOWN, ACT_UP, ACT_RIGHT, ACT_LEFT = 1, 2, 3, 4, 5
ACT_HOME, ACT_END, ACT_PAGE_DOWN, ACT_PAGE_UP = 6, 7, 8, 9
ACT_RETURN, ACT_BACKSPACE, ACT_DELETE, ACT_TAB, ACT_DELETE_LINE = 10, 11, 12, 13, 14
ACT_UNDO, ACT_REDO = 15, 16
ACT_CUT, ACT_COPY, ACT_PASTE, ACT_SELECT_ALL, ACT_INSERT = 17, 18, 19, 20, 21
ACT_FIND, ACT_SAVE, ACT_REPLACE = 65, 67, 80
ACTIONS = {DOWN: ACT_DOWN, UP: ACT_UP, RIGHT: ACT_RIGHT, LEFT: ACT_LEFT, HOME: ACT_HOME,
           END: ACT_END, PAGE_DOWN: ACT_PAGE_DOWN, PAGE_UP: ACT_PAGE_UP, RETURN: ACT_RETURN,
           BACKSPACE: ACT_BACKSPACE, DELETE: ACT_DELETE, TAB: ACT_TAB,
           DELETE_LINE: ACT_DELETE_LINE, 26: ACT_UNDO, SHIFT_HOME: ACT_HOME,
           SHIFT_END: ACT_END, INSERT: ACT_INSERT}
CONTROL_ACTIONS = {HOME: ACT_SAVE, DELETE: ACT_REDO, CUT: ACT_CUT, COPY: ACT_COPY,
                   PASTE: ACT_PASTE, SELECT_ALL: ACT_SELECT_ALL}


def key_code(character):
    """Return the code GET gives for a character of a source file."""
    if "a" <= character <= "z":
        return ord(character) - 0x20
    if "A" <= character <= "Z":
        return ord(character) + 0x80
    return ord(character)


def saved_byte(code):
    """Return the byte a saved file holds for a typed key code."""
    if code == 160:
        return 32
    if 0x41 <= code <= 0x5A:
        return code + 0x20
    if 0xC1 <= code <= 0xDA:
        return code - 0x80
    return code


def is_typed(code):
    return 32 <= code <= 126 or code == 160 or 193 <= code <= 218


def action_of(code, modifiers):
    """Return the action KEYS.DISPATCH gives a key."""
    if code < 32 and modifiers & CTRL and code in CONTROL_ACTIONS:
        return CONTROL_ACTIONS[code]
    if is_typed(code):
        return ACT_TYPE
    return ACTIONS.get(code, 0)


def ordered(anchor, line, col):
    """Return a selection's ends as first line, first column, last line, last column."""
    first, last = sorted([anchor, (line, col)])
    return first + last


def copied(lines, first_line, first_col, last_line, last_col):
    """Return the text between two places as the lines the clipboard holds."""
    if first_line == last_line:
        return [lines[first_line][first_col:last_col]]
    return [lines[first_line][first_col:]] + lines[first_line + 1:last_line] + [lines[last_line][:last_col]]


def taken_out(lines, first_line, first_col, last_line, last_col):
    """Take the text between two places out of lines. Return False, and leave lines as
    they are, when the two ends would join into a line over LINE_LIMIT."""
    tail = lines[last_line][last_col:]
    if first_col + len(tail) > LINE_LIMIT:
        return False
    lines[first_line:last_line + 1] = [lines[first_line][:first_col] + tail]
    return True


def pasted(lines, line, col, clip):
    """Put the clipboard's lines in at a place. Return the cursor's line and column after
    them, or None, with lines as they were, when a line would be over LINE_LIMIT."""
    text = lines[line]
    if len(clip) == 1 and len(text) + len(clip[0]) > LINE_LIMIT:
        return None
    if len(clip) > 1 and (col + len(clip[0]) > LINE_LIMIT
                          or len(clip[-1]) + len(text) - col > LINE_LIMIT):
        return None
    new = list(clip)
    new[0] = text[:col] + new[0]
    new[-1] = new[-1] + text[col:]
    lines[line:line + 1] = new
    end_col = len(clip[-1])
    if len(clip) == 1:
        end_col += col
    return line + len(clip) - 1, end_col


def run(lines, keys, line=0, col=0):
    """Apply keys to a document. Return its lines and the cursor's line and column."""
    return play(lines, keys, line, col)[:3]


def play(lines, keys, line=0, col=0):
    """Apply keys to a document. Return its lines, the cursor's line and column, and the
    selection's anchor, or None when no selection is on."""
    lines = list(lines)
    anchor = None
    clip = []
    clip_whole = False
    for code, modifiers in keys:
        action = action_of(code, modifiers)
        # KEYS.SELECT.MOVE, then KEYS.SELECTION.FIRST.
        if ACT_DOWN <= action <= ACT_PAGE_UP:
            if not modifiers & SHIFT:
                anchor = None
            elif anchor is None:
                anchor = (line, col)
        elif anchor is not None:
            if anchor == (line, col):
                anchor = None
            elif action in (ACT_TYPE, ACT_RETURN, ACT_BACKSPACE, ACT_DELETE):
                ends = ordered(anchor, line, col)
                anchor = None
                if not taken_out(lines, *ends):
                    action = 0
                else:
                    line, col = ends[0], ends[1]
                    if action in (ACT_BACKSPACE, ACT_DELETE):
                        action = 0
            elif not (ACT_CUT <= action <= ACT_INSERT or action in (ACT_FIND, ACT_REPLACE)):
                anchor = None
        if action == ACT_INSERT:
            action = 0
            if modifiers & SHIFT:
                action = ACT_CUT
            elif modifiers & (SHIFT | CTRL) == CTRL:
                action = ACT_COPY
        text = lines[line]
        last = len(lines) - 1
        if action == ACT_DOWN:
            if line < last:
                line += 1
                col = min(col, len(lines[line]))
        elif action == ACT_UP:
            if line > 0:
                line -= 1
                col = min(col, len(lines[line]))
        elif action == ACT_RIGHT:
            if modifiers & CTRL and col < len(text):
                while col < len(text) and text[col] != SPACE:
                    col += 1
                while col < len(text) and text[col] == SPACE:
                    col += 1
            elif col < len(text):
                col += 1
            elif line < last:
                line += 1
                col = 0
        elif action == ACT_LEFT:
            if modifiers & CTRL and col > 0:
                while col > 0 and text[col - 1] == SPACE:
                    col -= 1
                while col > 0 and text[col - 1] != SPACE:
                    col -= 1
            elif col > 0:
                col -= 1
            elif line > 0:
                line -= 1
                col = len(lines[line])
        elif action == ACT_HOME:
            col = 0
        elif action == ACT_END:
            col = len(text)
        elif action == ACT_PAGE_DOWN:
            if modifiers & CTRL:
                line = last
                col = len(lines[line])
            else:
                line = min(line + PANE_ROWS, last)
                col = min(col, len(lines[line]))
        elif action == ACT_PAGE_UP:
            if modifiers & CTRL:
                line = 0
                col = 0
            else:
                line = max(line - PANE_ROWS, 0)
                col = min(col, len(lines[line]))
        elif action == ACT_RETURN:
            front = text[:col]
            indent = len(front) - len(front.lstrip(b" "))
            lines[line:line + 1] = [front, b" " * indent + text[col:]]
            line += 1
            col = indent
        elif action == ACT_BACKSPACE:
            if col > 0:
                lines[line] = text[:col - 1] + text[col:]
                col -= 1
            elif line > 0 and len(lines[line - 1]) + len(text) <= LINE_LIMIT:
                col = len(lines[line - 1])
                lines[line - 1:line + 1] = [lines[line - 1] + text]
                line -= 1
        elif action == ACT_DELETE:
            if col < len(text):
                lines[line] = text[:col] + text[col + 1:]
            elif line < last and len(text) + len(lines[line + 1]) <= LINE_LIMIT:
                lines[line:line + 2] = [text + lines[line + 1]]
        elif action == ACT_TAB:
            spaces = min(TAB_WIDTH - col % TAB_WIDTH, LINE_LIMIT - len(text))
            if spaces > 0:
                lines[line] = text[:col] + b" " * spaces + text[col:]
                col += spaces
        elif action in (ACT_CUT, ACT_COPY):
            if anchor is not None:
                ends = ordered(anchor, line, col)
                clip, clip_whole = copied(lines, *ends), False
                if action == ACT_CUT:
                    anchor = None
                    if taken_out(lines, *ends):
                        line, col = ends[0], ends[1]
            else:
                clip, clip_whole = [text], True
                if action == ACT_CUT:
                    line = delete_line(lines, line)
                    col = 0
        elif action == ACT_PASTE and clip:
            if anchor is not None:
                ends = ordered(anchor, line, col)
                anchor = None
                if not taken_out(lines, *ends):
                    continue
                line, col = ends[0], ends[1]
            if clip_whole:
                lines.insert(line + 1, clip[0])
                line += 1
                col = 0
            else:
                line, col = pasted(lines, line, col, clip) or (line, col)
        elif action == ACT_SELECT_ALL:
            anchor = (0, 0)
            line = last
            col = len(lines[line])
        elif action == ACT_DELETE_LINE:
            line = delete_line(lines, line)
            col = 0
        elif action == ACT_TYPE:
            if len(text) < LINE_LIMIT:
                lines[line] = text[:col] + bytes([saved_byte(code)]) + text[col:]
                col += 1
    return lines, line, col, anchor


def delete_line(lines, line):
    """Take line out of lines, or empty it when it is the only one. Return the cursor's
    line after it."""
    if len(lines) > 1:
        del lines[line]
        return min(line, len(lines) - 1)
    lines[0] = b""
    return 0


def fixture_lines():
    lines = open(FIXTURE, "rb").read().split(b"\r\n")
    if lines and lines[-1] == b"":
        lines.pop()
    return lines


def script():
    """Return the keys of the bench.

    The keys must write fewer undo records than a ring holds. A full ring drops its
    oldest edit, and undoing every edit then does not give the fixture back."""
    keys = []

    def press(code, modifiers=0, times=1):
        keys.extend([(code, modifiers)] * times)

    def text(characters):
        for character in characters:
            press(key_code(character))

    # Type, take out, tab and split inside one line.
    press(DOWN, times=40)
    press(END)
    text("  rem Typed 123")
    press(LEFT, times=4)
    press(BACKSPACE, times=3)
    press(DELETE, times=2)
    press(HOME)
    press(TAB)
    text("x")
    press(TAB)
    press(RETURN)
    text("Indented")
    press(RETURN)
    # Join upward and downward, and cross a line end with the cursor.
    press(HOME)
    press(BACKSPACE)
    press(END)
    press(DELETE)
    press(END)
    press(RIGHT)
    press(LEFT)
    press(160)
    # The last line and the first line.
    press(PAGE_DOWN, times=3)
    press(PAGE_UP)
    press(PAGE_DOWN, CTRL)
    text("end")
    press(RETURN)
    text("last")
    press(DELETE)
    press(DOWN)
    press(RIGHT)
    press(PAGE_DOWN)
    press(PAGE_UP, CTRL)
    press(BACKSPACE)
    press(UP)
    press(LEFT)
    press(PAGE_UP)
    press(DELETE_LINE)
    # Join lines until a join is refused. Fill the line to 250, then try to add to it and
    # to join the line below to it.
    press(DOWN, times=60)
    for _ in range(14):
        press(END)
        press(DELETE)
    lines, line, _ = run(fixture_lines(), keys)
    assert 150 < len(lines[line]) < LINE_LIMIT - 2
    assert len(lines[line]) + len(lines[line + 1]) > LINE_LIMIT
    text("q" * (LINE_LIMIT - 2 - len(lines[line])))
    press(TAB)
    text("z")
    press(TAB)
    press(DOWN)
    press(HOME)
    press(BACKSPACE)
    press(UP)
    press(HOME)
    press(DOWN, times=3)
    # Word moves inside a line and across both line ends.
    press(RIGHT, CTRL, times=6)
    press(LEFT, CTRL, times=3)
    press(END)
    press(LEFT, CTRL)
    press(RIGHT, CTRL, times=2)
    press(HOME)
    press(LEFT, CTRL)
    press(RIGHT, CTRL)
    press(DOWN)
    # Select with Shift held, and take the selection out with each edit key. A selection
    # moved back to its anchor is empty, and Delete then takes out one character.
    press(DOWN, times=5)
    press(HOME)
    press(RIGHT, SHIFT, times=3)
    press(DELETE)
    press(RIGHT, SHIFT, times=2)
    press(LEFT, SHIFT, times=2)
    press(DELETE)
    press(END)
    press(LEFT, SHIFT, times=4)
    press(BACKSPACE)
    press(DOWN, SHIFT, times=2)
    press(RIGHT, SHIFT)
    text("Q")
    press(SHIFT_HOME, SHIFT)
    press(RETURN)
    press(UP, SHIFT)
    press(SHIFT_END, SHIFT)
    press(RIGHT)
    # Copy a selection over two line breaks and paste it twice. Copy and paste a line whole.
    # Cut a selection and a line, with Ctrl+X and Shift+Delete, and paste over a selection.
    press(HOME)
    press(DOWN, SHIFT, times=2)
    press(RIGHT, SHIFT, times=4)
    press(COPY, CTRL)
    press(END)
    press(PASTE, CTRL)
    press(PASTE, CTRL)
    press(COPY, CTRL)
    press(PASTE, CTRL)
    press(UP, times=2)
    press(RIGHT, SHIFT, times=3)
    press(CUT, CTRL)
    press(DOWN)
    press(PASTE, CTRL)
    press(CUT, CTRL)
    press(INSERT, CTRL)
    press(PASTE, CTRL)
    press(RIGHT, SHIFT, times=2)
    press(INSERT, SHIFT)
    press(LEFT, SHIFT, times=2)
    press(PASTE, CTRL)
    # Select all, and a move without Shift ends it.
    press(SELECT_ALL, CTRL)
    press(PAGE_UP, CTRL)
    press(DOWN, times=45)
    # A walk of mixed keys.
    walk = random.Random(2026)
    moves = (DOWN, DOWN, DOWN, UP, UP, RIGHT, RIGHT, RIGHT, LEFT, LEFT, HOME, END, PAGE_DOWN, PAGE_UP)
    for _ in range(260):
        choice = walk.random()
        if choice < 0.52:
            move = walk.choice(moves)
            modifiers = 0
            if move in (RIGHT, LEFT) and walk.random() < 0.4:
                modifiers = CTRL
            press(move, modifiers)
        elif choice < 0.74:
            press(key_code(walk.choice("abcXYZ 09=+\"(")))
        elif choice < 0.82:
            press(BACKSPACE)
        elif choice < 0.88:
            press(DELETE)
        elif choice < 0.94:
            press(RETURN)
        elif choice < 0.97:
            press(TAB)
        else:
            press(DELETE_LINE)
    # End on a long line with the pane scrolled sideways.
    lines, _, _ = run(fixture_lines(), keys)
    long_line = next(number for number, line in enumerate(lines) if len(line) > 150)
    press(PAGE_UP, CTRL)
    press(PAGE_DOWN, times=long_line // PANE_ROWS)
    press(DOWN, times=long_line % PANE_ROWS)
    press(END)
    press(LEFT, times=5)
    # End with a selection on, over three lines, so the pane holds its highlight.
    press(LEFT, SHIFT, times=3)
    press(UP, SHIFT, times=2)

    # A clipboard key here writes at most 4 records.
    records = sum(2 for code, _ in keys if code in EDIT_KEYS) + sum(1 for code, _ in keys if is_typed(code))
    records += sum(4 for code, modifiers in keys if action_of(code, modifiers) in (ACT_CUT, ACT_PASTE, ACT_INSERT))
    assert records < RING_DEPTH, records
    return keys


def write_script():
    keys = script()
    data = bytearray([len(keys) & 255, len(keys) >> 8])
    for code, modifiers in keys:
        data += bytes([code, modifiers])
    with open(SCRIPT_FILE, "wb") as f:
        f.write(data)


if __name__ == "__main__":
    write_script()
    lines, line, col, anchor = play(fixture_lines(), script())
    print("KEYBEN.KEY: %d keys, %d lines, cursor %d,%d, anchor %s" % (len(script()), len(lines), line, col, anchor))
