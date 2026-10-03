"""The keyword table of TURBO GPC, and its colouring rules in Python.

    python tgkeys.py        write TGKEYS.BIN

build.py and bench/spike.py write the table before every build. spike.py uses classify()
and expected_pane() to check what a bench dumps. The words come from the
HELP.KW.STATEMENT and HELP.KW.FUNCTION groups of GPC.HELP.BASL.

TGKEYS.BIN loads at $A000 of the key bank. It starts with 26 addresses, one for each
first letter, low byte first. Each is the address of that letter's records. A record is
a length byte, a kind byte and the word. A length byte of 0 ends the letter. Kind 1 is a
statement and kind 2 is a function. A word under 2 characters or over 8 is left out.
VIEW.CLASS.WORDS does not look up a word of those lengths. The table ends below $BDF0,
where the inks start.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
HELP_SOURCE = os.path.join(ROOT, "GPC-BASIC-TOOLS-SRC", "GPC-HELP", "GPC.HELP.BASL")
TABLE_FILE = os.path.join(HERE, "TGKEYS.BIN")
TABLE_BASE = 0xA000
TABLE_LIMIT = 0xBDF0

# These match VIEW.SETUP in TG-VIEW.BASL. Change both together.
ATTR_TEXT = 97
ATTR_BAND = 225
ATTR_GUTTER = 111
ATTR_CURSOR = 22
SELECT_PAPER = 176
INKS = [1, 7, 13, 3, 8, 15, 1]
PANE_ROWS = 28
PANE_WIDTH = 74


def keywords():
    """Return the statement words and the function words, each a list in the order
    GPC.HELP.BASL holds them."""
    groups = {}
    current = None
    for line in open(HELP_SOURCE, "rb").read().decode("latin-1").splitlines():
        word = line.strip()
        if word.startswith("GP.BANKEDSTR "):
            current = groups.setdefault(word.split()[2], [])
        elif word == "GP.ENDBANKEDSTR":
            current = None
        elif current is not None and word.startswith('"'):
            current.append(word[1:-1])
    return groups["HELP.KW.STATEMENT"], groups["HELP.KW.FUNCTION"]


def table_image():
    statements, functions = keywords()
    buckets = [[] for _ in range(26)]
    for kind, words in ((1, statements), (2, functions)):
        for word in words:
            if not "A" <= word[0] <= "Z":
                raise SystemExit("tgkeys: %s does not start with a letter" % word)
            if 2 <= len(word) <= 8:
                buckets[ord(word[0]) - 65].append((word, kind))
    image = bytearray(52)
    for letter, bucket in enumerate(buckets):
        address = TABLE_BASE + len(image)
        image[letter * 2] = address & 255
        image[letter * 2 + 1] = address >> 8
        for word, kind in bucket:
            image += bytes([len(word), kind]) + word.encode("ascii")
        image.append(0)
    if TABLE_BASE + len(image) > TABLE_LIMIT:
        raise SystemExit("tgkeys: the table runs into the ink table")
    return bytes(image)


def write_table():
    image = table_image()
    with open(TABLE_FILE, "wb") as f:
        f.write(image)
    return len(image)


def is_letter(c):
    return ("A" <= c <= "Z") or ("a" <= c <= "z")


def is_digit(c):
    return "0" <= c <= "9"


def classify(line, statements, functions):
    """Return the class of every column of a line: 0 plain, 1 statement, 2 function,
    3 string, 4 number, 5 comment. A word that is not a keyword is 0 here and 6 in
    VIEW.CLASS.WORDS."""
    n = len(line)
    out = [0] * n
    first = 0
    while first < n and line[first] == " ":
        first += 1
    i = 0
    while i < n:
        c = line[i]
        if c == '"':
            out[i] = 3
            i += 1
            while i < n:
                out[i] = 3
                i += 1
                if line[i - 1] == '"':
                    break
        elif c in "$%" or is_digit(c):
            out[i] = 4
            i += 1
            while i < n and (line[i] == "." or is_digit(line[i]) or is_letter(line[i])):
                out[i] = 4
                i += 1
        elif c == "#":
            if i + 1 < n and line[i + 1] == "#":
                for j in range(i, n):
                    out[j] = 5
                i = n
            elif i == first:
                out[i] = 1
                i += 1
                while i < n and is_letter(line[i]):
                    out[i] = 1
                    i += 1
            else:
                i += 1
        elif is_letter(c):
            start = i
            i += 1
            while i < n and (is_letter(line[i]) or is_digit(line[i]) or line[i] in ".$%"):
                i += 1
            word = line[start:i].upper()
            if word == "REM":
                for j in range(start, n):
                    out[j] = 5
                i = n
                continue
            if "." in word:
                kind = 1 if word.startswith("GP.") else 0
            elif not 2 <= len(word) <= 8:
                kind = 0
            elif word in statements:
                kind = 1
            elif word in functions:
                kind = 2
            else:
                kind = 0
            for j in range(start, i):
                out[j] = kind
        else:
            i += 1
    return out


def stored_byte(code):
    """Return the byte the store holds for a byte of the file."""
    if code < 0x20:
        return 0x20
    if 0x41 <= code <= 0x5A:
        return code | 0x80
    if 0x61 <= code <= 0x7A:
        return code & 0xDF
    return code


def screen_code(code):
    """Return the screen code VIEW.SETUP's table gives a stored byte."""
    if code == 255:
        return 94
    if code < 32:
        return code + 128
    if 64 <= code < 96:
        return code - 64
    if 96 <= code < 128:
        return code - 32
    if 128 <= code < 160:
        return code + 64
    if 160 <= code < 192:
        return code - 64
    if code >= 192:
        return code - 128
    return code


def expected_pane(lines, top, left, cursor_line, cursor_col, colour, selection=None):
    """Return the 28 text rows as VIEW.PAINT leaves them. Each cell is a character byte
    and an attribute byte.

    selection is None, or the selection's first line, first column, last line and last
    column. Its cells take the paper SELECT_PAPER, as VIEW.SELECT.PAINT gives them. A line
    that runs on into the next selected line is marked to the pane's right edge."""
    statements, functions = keywords()
    out = bytearray()
    for row in range(PANE_ROWS):
        number = top + row
        if number >= len(lines):
            out += bytes([32, ATTR_GUTTER]) * 6 + bytes([32, ATTR_TEXT]) * PANE_WIDTH
            continue
        for digit in "%4d  " % (number + 1):
            out += bytes([ord(digit), ATTR_GUTTER])
        line = lines[number]
        row_attr = ATTR_BAND if number == cursor_line else ATTR_TEXT
        classes = classify(line.decode("latin-1"), statements, functions)
        cells = bytearray()
        for cell in range(PANE_WIDTH):
            column = left + cell
            if column >= len(line):
                cells += bytes([32, row_attr])
            elif colour:
                cells += bytes([screen_code(stored_byte(line[column])), INKS[classes[column]] | (row_attr & 0xF0)])
            else:
                cells += bytes([screen_code(stored_byte(line[column])), row_attr])
        if number == cursor_line and 0 <= cursor_col - left < PANE_WIDTH:
            cells[(cursor_col - left) * 2 + 1] = ATTR_CURSOR
        if selection and selection[0] <= number <= selection[2]:
            start = selection[1] if number == selection[0] else 0
            end = selection[3] if number == selection[2] else 255
            for cell in range(max(start - left, 0), min(end - left, PANE_WIDTH)):
                if number != cursor_line or cell != cursor_col - left:
                    cells[cell * 2 + 1] = cells[cell * 2 + 1] & 0x0F | SELECT_PAPER
        out += cells
    return bytes(out)


if __name__ == "__main__":
    print("TGKEYS.BIN %d bytes" % write_table())
