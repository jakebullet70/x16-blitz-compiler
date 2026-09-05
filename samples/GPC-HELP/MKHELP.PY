#!/usr/bin/env python
# ---------------------------------------------------------------------------
#  MKHELP.PY -- build GPC-HELP's content from the master GPC-BASIC folder.
#
#  Reads, and reads NOTHING ELSE:
#      GPC-BASIC/GP-BASIC.md            the manual        -- sections 1..6
#      GPC-BASIC/GP-BASIC.GLOBALS.md    the name register
#      GPC-BASIC/GP-BASIC.FILES.md      what is in the box, file by file
#      GPC-BASIC/*.INC.BL               the banner header of every module
#
#  Writes, beside this script:
#      HELP-TXT/H001.HLP ... Hnnn.HLP   one file per topic -- see layout()
#      HELP-TXT/GPB.HELP.IDX             the master index
#      GPC-HELP.md             the same content, for reading on a PC
#
#  THE CONTENT IS ALL IN ONE SUBFOLDER, index included, so the program sits in
#  a directory holding the program and one folder. Both are opened through the
#  CMD path syntax "//HELP-TXT/:NAME", which is what CMDR-DOS documents and
#  what a real SD card wants -- the emulator's host filesystem also takes a
#  plain "HELP-TXT/NAME", and that is the one that would not port.
#
#  THE .HLP FORMAT is one screen line per file line, first character a marker:
#
#      @  topic record. Line 1 of the file, and the rest of it is the title
#      =  section header. The viewer draws these as a full width highlight
#         bar -- the one line of highlighting the X16 side has
#      .  ordinary text, already wrapped to WIDTH
#      :  code. Drawn dimmed, and these are the lines "export example" writes
#      >  cross reference, ">ordinal|text" -- the ordinal is a HELP.IDX row
#
#  Wrapped here rather than on the X16 because the wrap is the expensive part
#  and it only has to happen once. The viewer prints what it is given.
#
#  KEYWORD ENTRIES. In sections 3 and 4 a level-3 heading is a topic. A level-4
#  heading under one is a section INSIDE that topic -- unless it is numbered
#  three deep ("#### 3.4.5 `GP.STRPTR` -- address of a string block"), which
#  makes it a topic of its own and puts a cross reference to it in the parent's
#  IN THIS SECTION table. The page points, the entry answers, and neither one
#  scrolls.
#
#  A ```entry fence is the slot block of such an entry -- Syntax, Returns,
#  Kind, Notes, WARNING, Example. Its COLUMNS ARE THE LAYOUT, so it goes out as
#  text with the spacing it was written with, never re-wrapped and never
#  dimmed. Keep its lines within WIDTH. The example code follows in an ordinary
#  fence, where it is dimmed and "X export code" can write it out, and SEE ALSO
#  builds itself from the section references in the body.
#
#  HELP.IDX is "type|topic|section|lines|text" per row. Type H is a category
#  header (not selectable), T a topic, S a section inside one. The topic
#  number names the file. The viewer loads the index at startup and never
#  reads it again; a topic costs one OPEN and nothing else.
#
#  LINE ENDINGS ARE LF and the viewer strips a trailing CR, so a checkout that
#  converts them still reads. .gitattributes marks them -text anyway.
#
#  Usage:  python samples/GPC-HELP/MKHELP.PY  [--src DIR] [--out DIR]
# ---------------------------------------------------------------------------

import argparse
import os
import re
import sys

WIDTH = 76

# The content -- topics and index alike -- lives in a subfolder of the
# program's directory. Both names are spelled again in GPB.HELP.BASL, as
# HELP.DIR$ and the OPEN in HELP.IDXLOAD, so changing one here means
# changing it there.
HELPDIR = "HELP-TXT"
IDXNAME = "GPB.HELP.IDX"

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SRC = os.path.normpath(os.path.join(HERE, "..", "..", "GPC-BASIC"))

# The five categories, in the order they appear on the master index page.
# A category is an ordering and a heading, not a file: every topic has its own
# .HLP, named by its number. See layout().
CATS = [
    ("start",   "GETTING STARTED"),
    ("files",   "WHAT IS IN GPC"),
    ("core",    "GP.* CORE KEYWORDS"),
    ("mods",    "BASL MODULES"),
    ("globals", "GLOBALS AND NAMING"),
    ("traps",   "THE TRAPS"),
    ("memory",  "MEMORY AND LIMITS"),
]

# Modules whose only documentation is their own banner header -- everything in
# GP-BASIC.md section 4 is written up there instead and is taken from there.
BANNER_ONLY = [
    "GUI.INC.BL",
    "GUI2.INC.BL",
    "MENUBAR.INC.BL",
    "STASH.INC.BL",
    "STASHFILE.INC.BL",
]

TIER_NOTE = {
    "ASM": "ASM -- a keyword, run by machine code in the GP runtime block. "
           "A program using ANY GP keyword pays for the whole block.",
    "BASIC": "BASIC -- a .INC.BL module of ordinary BASL, called with GOSUB. "
             "Costs nothing unless you #INCLUDE it.",
    "COMPOSITE": "COMPOSITE -- a keyword with no machine code of its own. The "
                 "compiler expands it into keywords that already exist, so it "
                 "costs the runtime nothing at all.",
}

TRANSLIT = [
    ("\u2014", "--"), ("\u2013", "-"), ("\u2018", "'"), ("\u2019", "'"),
    ("\u201c", '"'), ("\u201d", '"'), ("\u00b7", " - "), ("\u2192", "->"),
    ("\u2190", "<-"), ("\u2248", "~"), ("\u00d7", "x"), ("\u2026", "..."),
    ("\u00b1", "+/-"), ("\u2264", "<="), ("\u2265", ">="), ("\u2022", "-"),
    ("\u00a0", " "), ("\u00bd", "1/2"), ("\u2500", "-"), ("\u2502", "|"),
    ("\u00a7", "SEC "),
    # U+2212 MINUS SIGN, not the ASCII hyphen. The manual writes "-1 if ..."
    # with it, and without this line it became "?1" -- which is not a typo the
    # eye catches in 90 KB of generated text. DROPPED is what found it.
    ("\u2212", "-"),
]

# Every character that reached the ASCII fold without a mapping. Anything in
# here has been replaced by "?" in the output, silently, which is how "-1"
# shipped as "?1". main() prints it, so the next one is noticed on the build
# that introduces it rather than on a screen months later.
DROPPED = {}


# ---------------------------------------------------------------------------
#  Inline markdown -> plain ASCII
# ---------------------------------------------------------------------------

def inline(s):
    """One line of markdown body text as plain ASCII, links flattened."""
    s = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = s.replace("**", "").replace("``", "`")
    s = s.replace("`", "")
    s = re.sub(r"(?<![A-Za-z0-9_*])\*([^*\n]+)\*(?![A-Za-z0-9_*])", r"\1", s)
    s = s.replace("\\|", "|").replace("\\<", "<").replace("\\>", ">")
    s = s.replace("\\$", "$").replace("\\_", "_")
    for a, b in TRANSLIT:
        s = s.replace(a, b)
    s = to_ascii(s)
    return re.sub(r"\s+", " ", s).strip()


def to_ascii(s):
    """The last fold, counting anything it had no mapping for."""
    out = []
    for ch in s:
        if 32 <= ord(ch) < 127:
            out.append(ch)
        else:
            DROPPED[ch] = DROPPED.get(ch, 0) + 1
            out.append("?")
    return "".join(out)


def wrap(text, width, indent="", first=None):
    """Greedy wrap. `first` overrides the indent of the opening line."""
    if not text:
        return [indent]
    lead = indent if first is None else first
    out, cur, fresh = [], lead, True
    for word in text.split():
        if fresh:
            cur += word
            fresh = False
        elif len(cur) + 1 + len(word) <= width:
            cur += " " + word
        else:
            out.append(cur)
            cur = indent + word
    out.append(cur)
    return out


# ---------------------------------------------------------------------------
#  Markdown -> blocks
# ---------------------------------------------------------------------------

def blocks(lines):
    """Tokenise markdown into ('kind', payload) blocks."""
    out, i, n = [], 0, len(lines)
    while i < n:
        raw = lines[i].rstrip("\n")
        s = raw.strip()

        if s.startswith("```"):
            info = s[3:].strip().lower()
            body, i = [], i + 1
            while i < n and not lines[i].strip().startswith("```"):
                body.append(lines[i].rstrip("\n"))
                i += 1
            i += 1
            # ```entry is a keyword entry's slot block. Its columns ARE the
            # layout, so it goes out as text with the spacing it was written
            # with, not as dimmed code and not re-wrapped.
            out.append(("entry" if info == "entry" else "code", body))
            continue

        m = re.match(r"^(#{1,6})\s+(.*)$", s)
        if m:
            out.append(("head", (len(m.group(1)), m.group(2).strip(), raw)))
            i += 1
            continue

        if re.match(r"^(-{3,}|\*{3,}|_{3,})$", s):
            out.append(("hr", None))
            i += 1
            continue

        if s.startswith("|") and i + 1 < n and re.match(r"^\|[\s:\-|]+\|$", lines[i + 1].strip()):
            rows, i = [], i
            while i < n and lines[i].strip().startswith("|"):
                rows.append(lines[i].strip())
                i += 1
            out.append(("table", rows))
            continue

        if re.match(r"^([-*+]|\d+\.)\s+", s):
            items, i = [], i
            while i < n:
                t = lines[i].rstrip("\n")
                if not t.strip():
                    break
                m2 = re.match(r"^\s*([-*+]|\d+\.)\s+(.*)$", t)
                if m2:
                    items.append(m2.group(2))
                elif items and t.startswith((" ", "\t")):
                    items[-1] += " " + t.strip()
                else:
                    break
                i += 1
            out.append(("list", items))
            continue

        if s.startswith(">"):
            body, i = [], i
            while i < n and lines[i].strip().startswith(">"):
                body.append(lines[i].strip().lstrip(">").strip())
                i += 1
            out.append(("quote", body))
            continue

        if not s:
            i += 1
            continue

        para, i = [], i
        while i < n:
            t = lines[i].rstrip("\n")
            if not t.strip() or t.strip().startswith(("#", "|", "```", ">")):
                break
            if re.match(r"^\s*([-*+]|\d+\.)\s+", t) or re.match(r"^(-{3,})$", t.strip()):
                break
            para.append(t.strip())
            i += 1
        out.append(("para", " ".join(para)))
    return out


def table_rows(rows):
    """Header cells and body cells of a pipe table."""
    def cells(r):
        return [c.strip() for c in r.strip().strip("|").split("|")]
    head = cells(rows[0])
    body = [cells(r) for r in rows[2:] if r.strip("| ")]
    return head, body


# ---------------------------------------------------------------------------
#  Blocks -> .HLP lines
# ---------------------------------------------------------------------------

class Emit(object):
    """Collects .HLP lines and remembers where the indexable headers landed."""

    def __init__(self):
        self.lines = []
        self.secs = []      # (title, offset of the '=' line within self.lines)

    def blank(self):
        if self.lines and self.lines[-1] == ".":
            return
        self.lines.append(".")

    def text(self, s, indent="", first=None):
        for ln in wrap(s, WIDTH, indent, first):
            self.lines.append("." + ln)

    def code(self, s):
        self.lines.append(":" + s[:WIDTH])

    def header(self, title, indexed=False):
        self.blank()
        t = title[:WIDTH]
        if indexed:
            self.secs.append((t, len(self.lines)))
        self.lines.append("=" + t)
        self.lines.append(".")


def emit_block(e, kind, payload):
    if kind == "para":
        txt = inline(payload)
        if re.match(r"^Examples?:\s*[A-Z0-9.]+\.EXP\.BL\s*$", txt):
            return
        e.blank()
        e.text(txt)
    elif kind == "code":
        e.blank()
        for ln in payload:
            e.code(inline_code(ln))
    elif kind == "entry":
        e.blank()
        for ln in payload:
            e.lines.append("." + inline_code(ln)[:WIDTH])
    elif kind == "list":
        e.blank()
        for item in payload:
            e.text(inline(item), indent="    ", first="  - ")
    elif kind == "quote":
        e.blank()
        e.text(inline(" ".join(payload)), indent="  | ", first="  | ")
    elif kind == "table":
        emit_table(e, payload)
    elif kind == "hr":
        e.blank()


def inline_code(s):
    """Code keeps its own spacing; only the character set is normalised."""
    for a, b in TRANSLIT:
        s = s.replace(a, b)
    s = s.replace("\t", "    ")
    return to_ascii(s).rstrip()


def emit_table(e, rows):
    """
    Stacked, not columnar. A three column table at 74 characters is unreadable
    however it is aligned, and every table in the manual is at least three -- so
    the first cell becomes the entry and the rest hang under it, labelled with
    their own column heading when the table has one worth repeating.
    """
    head, body = table_rows(rows)
    labels = [inline(h).upper() for h in head]
    for cells in body:
        if not any(c.strip() for c in cells):
            continue
        e.blank()
        e.text(inline(cells[0]), indent="    ", first="  ")
        for j in range(1, len(cells)):
            val = inline(cells[j])
            if not val:
                continue
            lab = labels[j] if j < len(labels) and labels[j] else ""
            if lab:
                e.text(val, indent="        ", first="      " + lab + ": ")
            else:
                e.text(val, indent="        ", first="      ")


# ---------------------------------------------------------------------------
#  Topics
# ---------------------------------------------------------------------------

class Topic(object):
    def __init__(self, cat, key, title):
        self.cat = cat
        self.key = key            # "3.4", "GUI.INC.BL", "G1" ...
        self.title = title        # what a cross reference shows
        self.short = ""           # what the INDEX shows, when shorter
        self.lines = []
        self.secs = []
        self.md = []
        self.refs = []
        self.number = 0           # names its .HLP file, filled by layout()
        self.ordinal = 0


REF_RE = re.compile(r"\u00a7\s*(\d+(?:\.\d+)*)")
EXP_RE = re.compile(r"\b([A-Z0-9]+\.EXP\.BL)\b")
MOD_RE = re.compile(r"\b([A-Z0-9]+\.INC\.BL)\b")


def collect_refs(md_text, self_key):
    """Section numbers and module names this topic points at, in order, once each."""
    keys = []
    for m in REF_RE.finditer(md_text):
        k = m.group(1)
        if k != self_key and k not in keys:
            keys.append(k)
    for m in MOD_RE.finditer(md_text):
        k = m.group(1)
        if k != self_key and k not in keys:
            keys.append(k)
    return keys


def examples_in(md_text):
    out = []
    for m in EXP_RE.finditer(md_text):
        if m.group(1) not in out:
            out.append(m.group(1))
    return out


# ---------------------------------------------------------------------------
#  The manual
# ---------------------------------------------------------------------------

def split_sections(path):
    """The manual as [(level, title, raw_heading, [body lines])] in file order."""
    with open(path, "r", encoding="utf-8") as fh:
        lines = fh.readlines()
    out, cur = [], None
    infence = False
    for ln in lines:
        s = ln.strip()
        if s.startswith("```"):
            infence = not infence
        m = None if infence else re.match(r"^(#{1,6})\s+(.*)$", s)
        if m:
            cur = [len(m.group(1)), m.group(2).strip(), ln.rstrip("\n"), []]
            out.append(cur)
        elif cur is not None:
            cur[3].append(ln.rstrip("\n"))
    return out


def parse_tiers(secs):
    """keyword group -> (tier, [keywords]) from the 'At a glance' table."""
    tiers = []
    for lvl, title, raw, body in secs:
        if not title.lower().startswith("at a glance"):
            continue
        for kind, payload in blocks(body):
            if kind != "table":
                continue
            head, rows = table_rows(payload)
            for cells in rows:
                if len(cells) < 3:
                    continue
                group = inline(cells[0])
                tier = inline(cells[1]).upper()
                if tier not in TIER_NOTE:
                    continue
                kws = re.findall(r"`(GP\.[A-Z]+)`", cells[2])
                tiers.append((group, tier, kws))
    return tiers


def tier_lines(e, title, tiers):
    """The costs card: which tier this topic's keywords are in, and what that buys."""
    t = re.sub(r"^\d+(\.\d+)?\s*", "", title).lower()
    hits = []
    for group, tier, kws in tiers:
        g = group.lower()
        if g and (g in t or t in g):
            hits.append((tier, kws))
    if not hits:
        return
    e.header("WHAT IT COSTS")
    seen = set()
    for tier, kws in hits:
        if kws:
            e.text(tier + ":  " + " ".join(kws), indent="      ", first="  ")
        if tier not in seen:
            seen.add(tier)
            e.text(TIER_NOTE[tier], indent="    ", first="    ")


def build_manual(src, tiers):
    secs = split_sections(os.path.join(src, "GP-BASIC.md"))
    topics = []

    # Which top level section a heading belongs to, and therefore which file.
    top_of = {"1": "start", "2": "start", "3": "core",
              "4": "mods", "5": "globals", "6": "traps", "7": "memory"}

    i = 0
    while i < len(secs):
        lvl, title, raw, body = secs[i]
        m = re.match(r"^(\d+)\.\s+(.*)$", title) if lvl == 2 else None
        if not m:
            i += 1
            continue
        top = m.group(1)
        cat = top_of.get(top)
        if cat is None:
            i += 1
            continue

        # Everything down to the next level-2 heading belongs to this section.
        j = i + 1
        while j < len(secs) and secs[j][0] > 2:
            j += 1
        group = secs[i:j]

        if top in ("3", "4"):
            topics += manual_split(cat, group, tiers, top)
        else:
            topics.append(manual_whole(cat, group))
        i = j
    return topics


def manual_whole(cat, group):
    """A level-2 section and all its children as ONE topic."""
    lvl, title, raw, body = group[0]
    t = Topic(cat, key_of(title), inline(title))
    e = Emit()
    e.header(t.title.upper())
    md = [raw]
    for kind, payload in blocks(body):
        emit_block(e, kind, payload)
    md += body
    for sub in group[1:]:
        e.header(inline(sub[1]), indexed=True)
        for kind, payload in blocks(sub[3]):
            emit_block(e, kind, payload)
        md += [sub[2]] + sub[3]
    t.lines, t.secs, t.md = e.lines, e.secs, md
    t.refs = collect_refs("\n".join(md), t.key)
    return t


def manual_split(cat, group, tiers, top):
    """Section 3 and 4: every level-3 heading is a topic of its own."""
    out = []
    intro = [s for s in group[1:] if s[0] == 3 and
             not re.match(r"^\d+\.\d+\s", s[1])]

    # The section's own preamble, plus any level-3 heading that is not numbered
    # (the 'At a glance' table), as one opening topic.
    lvl, title, raw, body = group[0]
    t = Topic(cat, key_of(title), inline(title))
    e = Emit()
    e.header(t.title.upper())
    md = [raw]
    for kind, payload in blocks(body):
        emit_block(e, kind, payload)
    md += body
    for sub in intro:
        e.header(inline(sub[1]), indexed=True)
        for kind, payload in blocks(sub[3]):
            emit_block(e, kind, payload)
        md += [sub[2]] + sub[3]
    t.lines, t.secs, t.md = e.lines, e.secs, md
    t.refs = collect_refs("\n".join(md), t.key)
    out.append(t)

    # Then one topic per numbered level-3 heading, with its level-4 children.
    k = 1
    while k < len(group):
        lvl, title, raw, body = group[k]
        if lvl != 3 or not re.match(r"^\d+\.\d+\s", title):
            k += 1
            continue
        kids, m = [], k + 1
        while m < len(group) and group[m][0] > 3:
            kids.append(group[m])
            m += 1

        # A NUMBERED level-4 heading is a keyword entry and becomes a topic of
        # its own, so the reader lands on the syntax line instead of scrolling
        # to it. An unnumbered one is prose about the group and stays a section
        # inside this page, as it always was.
        entries, secs_here = [], []
        for s in kids:
            if s[0] == 4 and re.match(r"^\d+\.\d+\.\d+\s", s[1]):
                entries.append(s)
            else:
                secs_here.append(s)
        kids = secs_here

        t = Topic(cat, key_of(title), inline(title))
        e = Emit()
        e.header(t.title.upper())
        md = [raw]

        bl = blocks(body)
        # The syntax card: the opening code fence, if the section leads with one.
        lead = 0
        while lead < len(bl) and bl[lead][0] == "hr":
            lead += 1
        if lead < len(bl) and bl[lead][0] == "code":
            e.header("SYNTAX")
            for ln in bl[lead][1]:
                e.code(inline_code(ln))
            bl = bl[:lead] + bl[lead + 1:]

        tier_lines(e, title, tiers)

        e.header("DESCRIPTION")
        for kind, payload in bl:
            emit_block(e, kind, payload)
        md += body

        # The jump table, high on the page rather than under the prose: on a
        # concept page it is the thing the reader came for. substitute() turns
        # each placeholder into the entry's ordinal and title once every topic
        # has a number.
        if entries:
            e.header("IN THIS SECTION")
            for sub in entries:
                e.lines.append(">@@%s@@|" % key_of(sub[1]))

        for sub in kids:
            e.header(inline(sub[1]), indexed=True)
            for kind, payload in blocks(sub[3]):
                emit_block(e, kind, payload)
            md += [sub[2]] + sub[3]

        t.lines, t.secs, t.md = e.lines, e.secs, md
        t.refs = collect_refs("\n".join(md), t.key)
        t.examples = examples_in("\n".join(md))
        out.append(t)

        # One topic per keyword entry. No costs card and no syntax card: the
        # slot block carries Syntax itself, and what the group costs is on the
        # concept page above.
        for sub in entries:
            et = Topic(cat, key_of(sub[1]), inline(sub[1]))
            ee = Emit()
            # The bar carries the number and the keyword, not the gloss after
            # the dash: uppercased it shouts, and the reader opening the page
            # has just read it on the row they pressed RETURN on.
            et.short = et.title.split(" -- ")[0]
            ee.header(et.short.upper())
            for kind, payload in blocks(sub[3]):
                emit_block(ee, kind, payload)
            emd = [sub[2]] + sub[3]
            et.lines, et.secs, et.md = ee.lines, ee.secs, emd
            et.refs = collect_refs("\n".join(emd), et.key)
            et.examples = examples_in("\n".join(emd))
            out.append(et)

        k = m
    return out


def key_of(title):
    # Three parts as well as two: a keyword entry is 3.4.5, and its key is what
    # the concept page's jump table and every SEC 3.4.5 reference resolve to.
    m = re.match(r"^(\d+(?:\.\d+)*)\.?\s", title)
    return m.group(1) if m else inline(title).upper()


# ---------------------------------------------------------------------------
#  The globals register
# ---------------------------------------------------------------------------

def build_globals(src):
    secs = split_sections(os.path.join(src, "GP-BASIC.GLOBALS.md"))
    topics = []
    i = 0
    while i < len(secs):
        lvl, title, raw, body = secs[i]
        if lvl != 2:
            i += 1
            continue
        j = i + 1
        while j < len(secs) and secs[j][0] > 2:
            j += 1
        t = manual_whole("globals", secs[i:j])
        t.key = "G" + t.key
        topics.append(t)
        i = j
    return topics


# ---------------------------------------------------------------------------
#  What is in the box -- the file manifest
# ---------------------------------------------------------------------------

def build_files(src):
    """GP-BASIC.FILES.md, one topic per '##' section. Same shape as the globals
    register: a second document, read whole, rather than a section of the
    manual -- the manual is about the language and this is about the drive."""
    path = os.path.join(src, "GP-BASIC.FILES.md")
    if not os.path.exists(path):
        return []
    secs = split_sections(path)
    topics = []
    i = 0
    while i < len(secs):
        if secs[i][0] != 2:
            i += 1
            continue
        j = i + 1
        while j < len(secs) and secs[j][0] > 2:
            j += 1
        t = manual_whole("files", secs[i:j])
        t.key = "F" + t.key
        topics.append(t)
        i = j
    return topics


# ---------------------------------------------------------------------------
#  Module banners
# ---------------------------------------------------------------------------

BANNER_RULE = re.compile(r"^#+\s*\*{3,}\s*$")
UPPER_RUN = re.compile(
    r"^([A-Z][A-Z0-9'\-\.#/ ,()$]{14,}?)(?:[.:,](?=\s|$)|\s--\s)\s*(.*)$")


def banner_text(path):
    """The '## **' header block at the top of a module, de-prefixed."""
    out = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for ln in fh:
            s = ln.rstrip("\n")
            if not s.startswith("##"):
                break
            if BANNER_RULE.match(s):
                if out:
                    break
                continue
            body = re.sub(r"^##\s?\*{2}", "", s)
            if body == s:
                body = re.sub(r"^##\s?", "", s)
            out.append(body.rstrip())
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return out


def build_banner_topic(name, path):
    """
    A module's banner header as a topic.

    The banners are already laid out for a 72 column screen, so the two things
    to get right are which lines are PROSE and which are a COLUMN LAYOUT, and
    where the headings are.

    INDENTATION DECIDES THE FIRST. House style writes prose at two spaces under
    the "## **" and everything aligned -- the routine list, the in/out tables,
    the usage block -- at three or more. Prose is joined back into paragraphs
    and re-wrapped, because re-wrapping each source line on its own leaves a
    ragged edge; the aligned lines are passed through untouched, because their
    columns ARE the meaning.

    A RUN OF CAPITALS OPENING A LINE IS A HEADING, which is how this library
    writes one inside a banner. It becomes a section, and the sentence that
    follows it stays as body.
    """
    body = banner_text(path)
    if not body:
        return None
    first = inline(body[0])
    summary = first.split("--", 1)[1].strip() if "--" in first else first
    t = Topic("mods", name, name + " -- " + summary)
    e = Emit()
    e.header(name.upper())
    if summary:
        e.text(summary, indent="  ", first="  ")
    e.header("MODULE HEADER", indexed=True)

    para = []

    def flush():
        if para:
            e.blank()
            e.text(" ".join(para), indent="  ", first="  ")
            del para[:]

    md = ["", "*From the banner header of `%s`.*" % name, "", "```"]
    for raw in body[1:]:
        md.append(raw)
        s = inline(raw)
        if not s:
            flush()
            e.blank()
            continue
        if len(raw) - len(raw.lstrip()) >= 3:
            flush()
            e.code(inline_code(raw))
            continue
        m = UPPER_RUN.match(s)
        if m and len(m.group(1).split()) >= 3:
            flush()
            e.header(m.group(1).strip(), indexed=True)
            if m.group(2).strip():
                para.append(m.group(2).strip())
            continue
        para.append(s)
    flush()
    md.append("```")
    t.lines, t.secs, t.md = e.lines, e.secs, md
    t.refs = collect_refs(chr(10).join(body), name)
    return t


def build_banners(src):
    out = []
    for name in BANNER_ONLY:
        path = os.path.join(src, name)
        if not os.path.exists(path):
            sys.stderr.write("  skipped, not found: %s\n" % name)
            continue
        t = build_banner_topic(name, path)
        if t:
            out.append(t)
    return out


# ---------------------------------------------------------------------------
#  See also, examples, layout, index
# ---------------------------------------------------------------------------

def add_tails(topics):
    """The example pointer and the see-also block, on the end of every topic."""
    have = set(t.key for t in topics)
    # A module topic answers to its file name AND to the section that documents it.
    for t in topics:
        m = MOD_RE.search(t.title)
        if m:
            have.add(m.group(1))
    bykey = resolve_module_keys(topics)
    for t in topics:
        exs = getattr(t, "examples", None) or examples_in("\n".join(t.md))
        if exs:
            e = Emit()
            e.lines = t.lines
            e.secs = t.secs
            e.header("EXAMPLE PROGRAM")
            for x in exs:
                e.text(x + "   -- runnable, in the GPC-BASIC folder",
                       indent="    ", first="  ")
            t.lines, t.secs = e.lines, e.secs

        # A section 4 topic answers to two keys -- "4.8" and "STRCASE.INC.BL"
        # -- so a paragraph naming both listed it twice under SEE ALSO. Dedupe
        # on the topic the key resolves to, not on the key.
        refs, seen_t = [], set()
        for r in t.refs:
            if r not in have or r == t.key:
                continue
            tgt = bykey.get(r)
            mark = id(tgt) if tgt is not None else r
            if mark in seen_t:
                continue
            seen_t.add(mark)
            refs.append(r)
        if not refs:
            continue
        e = Emit()
        e.lines = t.lines
        e.secs = t.secs
        e.header("SEE ALSO")
        t.lines, t.secs = e.lines, e.secs
        for r in refs[:12]:
            t.lines.append(">@@%s@@|" % r)


# THE SCREEN IS THE VIEWER'S PAGE BUFFER. It reads a topic straight from the
# .HLP to the screen and keeps none of it, so the X16 side holds no page array
# at all -- which is its whole memory problem solved, the heap costing about
# 1.67 bytes a character (measured).
#
# Scrolling therefore RE-READS, which is why one file per topic matters twice:
# an open and 27 lines is 4 jiffies. So a topic does NOT have to fit the
# screen, and the bound here is generous on purpose -- SPLITTING COSTS MEMORY,
# because every part is another index row and the index is the one thing that
# is resident.
MAXPAGE = 120


def split_long(topics, limit=MAXPAGE):
    """Break any topic over `limit` lines at a section header, into parts."""
    out = []
    for t in topics:
        if len(t.lines) <= limit:
            out.append(t)
            continue
        start, part = 0, 1
        while start < len(t.lines):
            end = min(start + limit, len(t.lines))
            if end < len(t.lines):
                cut = end
                while cut > start + limit // 3 and not t.lines[cut].startswith("="):
                    cut -= 1
                if cut > start + limit // 3:
                    end = cut
            title = t.title if part == 1 else "%s (%d)" % (t.title, part)
            n = Topic(t.cat, t.key if part == 1 else "%s#%d" % (t.key, part), title)
            n.lines = t.lines[start:end]
            n.secs = [(nm, off - start) for nm, off in t.secs
                      if start <= off < end]
            n.md = t.md if part == 1 else []
            out.append(n)
            start, part = end, part + 1
    return out


def resolve_module_keys(topics):
    """key -> topic, including the module file name a section 4 topic describes."""
    bykey = {}
    for t in topics:
        bykey.setdefault(t.key, t)
        m = MOD_RE.search(t.title)
        if m:
            bykey.setdefault(m.group(1), t)
    return bykey


def layout(topics):
    """
    Group the topics by category, in index order, and give each one the number
    that names its file.

    ONE FILE PER TOPIC, and that is a measured decision, not a tidiness one.
    With the topics packed into five category files a topic was addressed by
    LINE NUMBER, and reaching one meant an OPEN and a run of discarded reads:
    measured on the X16, skipping to line 1000 of a 41 KB MODS.HLP cost 204
    jiffies -- 3.4 seconds to open a page. Reading the 27 lines once there cost
    4. The skip was the whole cost and it grew with depth, so the fix is to
    have nothing to skip.
    """
    files = {}
    for cat, name in CATS:
        files[cat] = []
    for t in topics:
        files[t.cat].append(t)
    n = 0
    for cat, name in CATS:
        for t in files[cat]:
            n += 1
            t.number = n
    return files


def hlp_name(n):
    return "H%03d.HLP" % n


def build_index(files, topics, nosections=False):
    """
    The HELP.IDX rows, in master index order, and the ordinal of each topic.

    A row is "type|topic|section|lines|text". The topic number names the file
    -- H007.HLP -- so no row carries a file NAME, which would be another 60
    strings on a heap that has none to spare. `section` is the line WITHIN the
    topic that a section header sits on, and 0 for a topic row.
    """
    # 72 is what a row can show at 80 columns with the highlight bar's margin,
    # and the index is scanned rather than read: a cut title still identifies.
    def fit(x):
        return x if len(x) <= 72 else x[:69] + "..."

    rows = []
    for ci, (cat, name) in enumerate(CATS):
        rows.append(["H", 0, 0, 0, fit(name)])
        for t in files[cat]:
            n = len(t.lines)
            t.ordinal = len(rows) + 1
            # THE INDEX IS THE ONE THING THE VIEWER KEEPS RESIDENT, at about 1.67
            # bytes a character, so an entry gives it the number and the keyword
            # and leaves the gloss to the cross reference, which is read off the
            # topic file and costs the heap nothing.
            rows.append(["T", t.number, 0, n, fit("  " + (t.short or t.title))])
            if nosections:
                continue
            for sec_title, off in t.secs:
                rows.append(["S", t.number, off + 1, n,
                             fit("     " + sec_title)])
    return rows


def substitute(topics, byord):
    """Fill the see-also placeholders now that every topic has an ordinal."""
    for t in topics:
        for i, ln in enumerate(t.lines):
            m = re.match(r"^>@@(.+?)@@\|$", ln)
            if not m:
                continue
            target = byord.get(m.group(1))
            if target is None or target.ordinal == 0:
                t.lines[i] = ".    (see the manual)"
            else:
                t.lines[i] = ">%d|%s" % (target.ordinal,
                                         target.title[:WIDTH - 6].replace("|", "/"))


# ---------------------------------------------------------------------------
#  Output
# ---------------------------------------------------------------------------

def write_hlp(out, files):
    """One file per topic: line 1 is its @ record, the rest is the body.

    THEY GO IN A SUBFOLDER, HELPDIR, so the program's directory holds the
    program, its index and one folder instead of the program and forty files.
    The viewer opens them through the CMD path syntax -- see the header.
    """
    where = os.path.join(out, HELPDIR)
    if not os.path.isdir(where):
        os.makedirs(where)
    made, biggest, total = 0, 0, 0
    for ci, (cat, name) in enumerate(CATS):
        for t in files[cat]:
            body = ["@" + t.title[:WIDTH]] + t.lines
            path = os.path.join(where, hlp_name(t.number))
            with open(path, "w", encoding="ascii", errors="replace",
                      newline="\n") as fh:
                fh.write("\n".join(body) + "\n")
            made += 1
            total += os.path.getsize(path)
            biggest = max(biggest, len(t.lines))
        print("  %-20s %2d topics" % (name, len(files[cat])))
    # A SHORTER RUN THAN LAST TIME LEAVES ORPHANS, and an orphan .HLP is a file
    # the index cannot reach and nothing will ever delete. Losing a topic is
    # ordinary -- a section is cut and the numbering closes up behind it.
    dropped = 0
    for name in sorted(os.listdir(where)):
        if not re.match("^H[0-9]+[.]HLP$", name):
            continue
        if int(name[1:-4]) > made:
            os.remove(os.path.join(where, name))
            dropped += 1

    print("  %-20s %2d files, %d bytes, longest topic %d lines"
          % ("%s/H001..%s" % (HELPDIR, hlp_name(made)), made, total, biggest))
    if dropped:
        print("  %-20s %2d stale .HLP removed" % ("", dropped))
    return made


def write_idx(out, rows):
    lines = ["# GPB.HELP index, generated by MKHELP.PY -- do not edit",
             "N|%d" % len(rows)]
    for r in rows:
        lines.append("%s|%s|%s|%s|%s" % (r[0], r[1], r[2], r[3], r[4]))
    where = os.path.join(out, HELPDIR)
    if not os.path.isdir(where):
        os.makedirs(where)
    path = os.path.join(where, IDXNAME)
    with open(path, "w", encoding="ascii", errors="replace", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("  %-20s %d rows, %d bytes"
          % ("%s/%s" % (HELPDIR, IDXNAME), len(rows), os.path.getsize(path)))


def anchor(s):
    a = s.lower()
    a = re.sub(r"[^\w\s-]", "", a)
    return re.sub(r"\s+", "-", a).strip("-")


def write_md(out, files, topics):
    L = []
    L.append("# GPC-HELP")
    L.append("")
    L.append("The GP.BASIC and BASL reference that `GPB.HELP.PRG` shows on the X16, "
             "in one file you can read on a PC.")
    L.append("")
    L.append("**Generated. Do not edit.** `MKHELP.PY` builds it and the `.HLP` "
             "files together from `GPC-BASIC/` -- the manual, the name register "
             "and the module banner headers. Fix anything wrong at the source "
             "and rebuild:")
    L.append("")
    L.append("```")
    L.append("python samples/GPC-HELP/MKHELP.PY")
    L.append("```")
    L.append("")
    L.append("## Contents")
    L.append("")
    for cat, name in CATS:
        L.append("- **%s**" % name)
        for t in files[cat]:
            L.append("  - [%s](#%s)" % (t.title, anchor(t.title)))
    L.append("")
    for cat, name in CATS:
        L.append("---")
        L.append("")
        L.append("# %s" % name)
        L.append("")
        for t in files[cat]:
            L.append("## %s" % t.title)
            L.append("")
            for ln in t.md:
                m = re.match(r"^(#{1,6})\s+(.*)$", ln.strip())
                if m:
                    lvl = min(6, len(m.group(1)) + 2)
                    L.append("#" * lvl + " " + m.group(2))
                else:
                    L.append(ln)
            L.append("")
            refs = [ln for ln in t.lines if ln.startswith(">")]
            if refs:
                L.append("*See also: " +
                         ", ".join(ln.split("|", 1)[1] for ln in refs) + "*")
                L.append("")
    path = os.path.join(out, "GPC-HELP.md")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")
    print("  %-12s %5d lines  %6d bytes"
          % ("GPC-HELP.md", len(L), os.path.getsize(path)))


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Build GPC-HELP content from GPC-BASIC.")
    ap.add_argument("--src", default=DEFAULT_SRC, help="the master GPC-BASIC folder")
    ap.add_argument("--out", default=HERE, help="where to write the .HLP files")
    ap.add_argument("--maxpage", type=int, default=MAXPAGE,
                    help="split a topic longer than this many lines. The viewer "
                         "holds one topic in a string array, so this is a memory "
                         "budget, not a style choice")
    ap.add_argument("--nosections", action="store_true",
                    help="index topics only, no section rows")
    args = ap.parse_args()

    src, out = os.path.abspath(args.src), os.path.abspath(args.out)
    if not os.path.isdir(src):
        sys.stderr.write("no such folder: %s\n" % src)
        return 2
    if not os.path.exists(os.path.join(src, "GP-BASIC.md")):
        sys.stderr.write("not a GPC-BASIC folder (no GP-BASIC.md): %s\n" % src)
        return 2
    if not os.path.isdir(out):
        os.makedirs(out)

    print("GPC-HELP content")
    print("  source  %s" % src)
    print("  output  %s" % out)
    print("")

    secs = split_sections(os.path.join(src, "GP-BASIC.md"))
    tiers = parse_tiers(secs)

    topics = build_manual(src, tiers)
    topics += build_banners(src)
    topics += build_globals(src)
    topics += build_files(src)

    add_tails(topics)
    topics = split_long(topics, args.maxpage)
    byord = resolve_module_keys(topics)
    files = layout(topics)
    rows = build_index(files, topics, args.nosections)
    substitute(topics, byord)

    # The see-also substitution changed text, never line counts, so the layout
    # computed above still holds.
    write_hlp(out, files)
    write_idx(out, rows)
    write_md(out, files, topics)
    print("")
    print("  %d topics, %d index rows" % (len(topics), len(rows)))

    # WHAT THE VIEWER HAS TO HOLD, which is the only budget that binds. Blitz's
    # string heap costs about 1.67 bytes a character -- measured, not assumed --
    # and the viewer holds the whole index plus one whole topic at once.
    idx_chars = sum(len(r[4]) for r in rows)
    big = max(len(t.lines) for t in topics)
    print("  index %d chars, longest topic %d lines" % (idx_chars, big))
    print("  string heap needed: about %d bytes -- the index, and nothing else"
          % int(idx_chars * 1.67))

    if DROPPED:
        print("")
        print("  CHARACTERS REPLACED BY '?' -- add them to TRANSLIT:")
        for ch, n in sorted(DROPPED.items(), key=lambda kv: -kv[1]):
            print("    U+%04X  %4d times" % (ord(ch), n))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
