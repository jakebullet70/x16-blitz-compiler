"""Write FIX2000.TXT, the fixture every spike bench loads.

    python mkfixture.py

2,000 lines from the edit sample's sources, ASCII, CRLF. A tab becomes two spaces,
a line is cut at 250 characters, and the last line holds the word the find bench
looks for.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLE = os.path.join(HERE, "..", "..", "edit")
SOURCES = ("EDIT.BASL", "ED-SEL.BASL", "ED-UNDO.BASL")
LINES = 2000
NEEDLE = b"REM ZZNEEDLE the last line of the fixture"

lines = []
for name in SOURCES:
    raw = open(os.path.join(SAMPLE, name), "rb").read()
    raw = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    for line in raw.split(b"\n"):
        line = line.replace(b"\t", b"  ")
        lines.append(bytes(c if 32 <= c < 127 else 32 for c in line)[:250])
lines = lines[:LINES]
assert len(lines) == LINES
lines[-1] = NEEDLE
text = b"\r\n".join(lines) + b"\r\n"
with open(os.path.join(HERE, "FIX2000.TXT"), "wb") as f:
    f.write(text)
print("FIX2000.TXT: %d lines, %d bytes" % (len(lines), len(text)))
