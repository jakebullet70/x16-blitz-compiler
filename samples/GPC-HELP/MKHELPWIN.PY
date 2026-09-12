#!/usr/bin/env python3
"""Re-render GPC-HELP.md as one Windows-side reference.

GPC-HELP.md is shaped by the X16 viewer it shares a generator with: every topic
carries its title twice, long topics are cut into 120-line pages with a "(2)"
heading on each, and the cross references at the foot of a page are plain text.
None of that helps on a PC, where the file is read in an editor or a browser.

This script reads GPC-HELP.md and writes GPC-HELP.WIN.md with the page breaks
healed, the duplicate headings folded away, one contents list over the whole
document and every cross reference turned into a working link.

It reads GPC-HELP.md and nothing else, so it cannot disagree with the manual.
Run MKHELP.PY first if the masters under GPC-BASIC/ have moved.

    python samples/GPC-HELP/MKHELPWIN.PY
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SRC = os.path.join(HERE, "GPC-HELP.md")
DEFAULT_OUT = os.path.join(HERE, "GPC-HELP.WIN.md")

HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
PAGE_SUFFIX = re.compile(r"\s*\((\d+)\)$")
SEE_ALSO = re.compile(r"^\*See also:\s*(.*?)\.?\*$")
FENCE = re.compile(r"^```(\w*)\s*$")


def normalise(title):
    """Two spellings of one title compare equal.

    A page heading is plain text and the heading under it is the manual's own,
    with backticks and em dashes, so both are flattened before comparing.
    """
    t = title.lower().replace("`", "")
    t = t.replace("—", "-").replace("–", "-")
    t = re.sub(r"[^a-z0-9]+", " ", t)
    return t.strip()


def slug(title, seen):
    """A GitHub-style anchor, unique within the document."""
    s = title.lower().replace("`", "")
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = s.strip().replace(" ", "-")
    n = seen.get(s, 0)
    seen[s] = n + 1
    return s if n == 0 else "%s-%d" % (s, n)


class Topic(object):
    def __init__(self, title):
        self.title = title
        self.body = []
        self.see_also = []
        self.anchor = ""


class Group(object):
    def __init__(self, title):
        self.title = title
        self.topics = []
        self.anchor = ""


def parse(lines):
    """GPC-HELP.md into groups of topics, page breaks healed."""
    groups = []
    topic = None
    i = 0

    # Everything before the first group banner is the generated preamble and its
    # contents list. This script writes its own.
    while i < len(lines) and not (i and lines[i].startswith("# ")):
        i += 1

    while i < len(lines):
        line = lines[i]
        m = HEADING.match(line)

        if m and len(m.group(1)) == 1:
            groups.append(Group(m.group(2)))
            topic = None
            i += 1
            continue

        if m and len(m.group(1)) == 2:
            title = m.group(2)
            page = PAGE_SUFFIX.search(title)
            if page:
                # A continuation page. Its heading is an artefact of the 120-line
                # split, so the text carries straight on into the topic above it.
                base = normalise(PAGE_SUFFIX.sub("", title))
                if topic is not None and normalise(topic.title) == base:
                    i += 1
                    continue
                title = PAGE_SUFFIX.sub("", title)

            # The manual's own heading follows, saying the same thing better.
            # Keep that one and drop this.
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines):
                inner = HEADING.match(lines[j])
                if inner and len(inner.group(1)) >= 4 and normalise(inner.group(2)) == normalise(title):
                    title = inner.group(2)
                    i = j

            topic = Topic(title)
            if not groups:
                groups.append(Group("REFERENCE"))
            groups[-1].topics.append(topic)
            i += 1
            continue

        if line.rstrip() == "---":
            # A page rule. There are no pages here.
            i += 1
            continue

        ref = SEE_ALSO.match(line.strip())
        if ref and topic is not None:
            topic.see_also.append(ref.group(1))
            i += 1
            continue

        if topic is not None:
            topic.body.append(line)
        i += 1

    for g in groups:
        for t in g.topics:
            t.body = reflow(t.body)
    return groups


def reflow(body):
    """Trim the blank lines a healed page break leaves, and tidy entry blocks."""
    out = []
    in_entry = False
    swallow = False
    for line in body:
        f = FENCE.match(line)
        if f:
            if swallow:
                # The block was already closed early, at its Example line.
                swallow = False
                continue
            if in_entry:
                in_entry = False
                out.append("```")
                continue
            if f.group(1) == "entry":
                in_entry = True
                # An entry block is aligned plain text. Tagging it as a language
                # only makes an editor guess at highlighting it.
                out.append("```")
                continue
            out.append(line)
            continue

        if in_entry and line.strip() == "Example":
            # The example is in the fenced block after this one, so close here
            # and let it stand on its own.
            out.append("```")
            out.append("")
            out.append("**Example**")
            in_entry = False
            swallow = True
            continue

        out.append(line)

    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()

    squeezed = []
    blanks = 0
    for line in out:
        if line.strip():
            blanks = 0
        else:
            blanks += 1
            if blanks > 1:
                continue
        squeezed.append(line)
    return squeezed


def shift_headings(body, floor=4):
    """Renumber a topic's own headings so they sit under it, nesting intact."""
    levels = []
    fenced = False
    for line in body:
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        m = HEADING.match(line)
        if m:
            levels.append(len(m.group(1)))
    if not levels:
        return body

    delta = floor - min(levels)
    if delta == 0:
        return body

    out = []
    fenced = False
    for line in body:
        if FENCE.match(line):
            fenced = not fenced
            out.append(line)
            continue
        m = None if fenced else HEADING.match(line)
        if m:
            level = max(1, min(6, len(m.group(1)) + delta))
            out.append("#" * level + " " + m.group(2))
        else:
            out.append(line)
    return out


def link_refs(names, index):
    """Cross references into links.

    The titles have commas in them, so the list cannot simply be split on one.
    Each name is matched against the topics the document actually holds, longest
    first, and anything that matches nothing is left as it was written. A match
    is shown under the heading's own spelling, not the plain one it was cited by.
    """
    out = []
    i = 0
    while i < len(names):
        hit = None
        for j in range(len(names), i, -1):
            candidate = ", ".join(names[i:j]).strip().rstrip(".")
            key = normalise(candidate)
            if key in index:
                hit = (index[key], j)
                break
        if hit:
            (anchor, title), j = hit
            out.append("[%s](#%s)" % (title, anchor))
            i = j
        else:
            out.append(names[i])
            i += 1
    return ", ".join(out)


def merge_refs(lines):
    """One list of names from however many pages the topic was cut into."""
    names = []
    for line in lines:
        for name in line.split(", "):
            name = name.strip().rstrip(".")
            if name and name not in names:
                names.append(name)
    return names


def render(groups, src_name):
    seen = {}
    for g in groups:
        g.anchor = slug(g.title, seen)
        for t in g.topics:
            t.anchor = slug(t.title, seen)

    index = {}
    for g in groups:
        for t in g.topics:
            index.setdefault(normalise(t.title), (t.anchor, t.title))

    topics = sum(len(g.topics) for g in groups)

    out = []
    out.append("# GP.BASIC and BASL -- the reference, for reading on Windows")
    out.append("")
    out.append("The same material `GPB.HELP.PRG` shows on the X16, laid out for an editor or a")
    out.append("browser instead of an 80x30 screen: the 120-line pages are joined back up, each")
    out.append("title appears once, and the cross references are links.")
    out.append("")
    out.append("**Generated. Do not edit.** `MKHELPWIN.PY` builds it from `%s`, which" % src_name)
    out.append("`MKHELP.PY` builds from `GPC-BASIC/`. Correct the manual there, then:")
    out.append("")
    out.append("```")
    out.append("python samples/GPC-HELP/MKHELP.PY")
    out.append("python samples/GPC-HELP/MKHELPWIN.PY")
    out.append("```")
    out.append("")
    out.append("%d topics in %d parts." % (topics, len(groups)))
    out.append("")
    out.append("## Contents")
    out.append("")
    for g in groups:
        out.append("- **[%s](#%s)**" % (g.title, g.anchor))
        for t in g.topics:
            out.append("  - [%s](#%s)" % (t.title, t.anchor))
    out.append("")

    for g in groups:
        out.append("")
        out.append("## %s" % g.title)
        for t in g.topics:
            out.append("")
            out.append("### %s" % t.title)
            out.append("")
            out.extend(shift_headings(t.body))
            if t.see_also:
                out.append("")
                out.append("*See also: %s*" % link_refs(merge_refs(t.see_also), index))
    out.append("")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description="Re-render GPC-HELP.md for reading on Windows.")
    ap.add_argument("--src", default=DEFAULT_SRC, help="the generated GPC-HELP.md")
    ap.add_argument("--out", default=DEFAULT_OUT, help="the file to write")
    args = ap.parse_args()

    if not os.path.exists(args.src):
        sys.exit("not found: %s -- run MKHELP.PY first" % args.src)

    with open(args.src, "r", encoding="utf-8") as f:
        text = f.read()
    nl = "\r\n" if "\r\n" in text else "\n"
    lines = text.replace("\r\n", "\n").split("\n")

    groups = parse(lines)
    body = render(groups, os.path.basename(args.src))

    with open(args.out, "w", encoding="utf-8", newline=nl) as f:
        f.write(body)

    topics = sum(len(g.topics) for g in groups)
    print("%s: %d parts, %d topics, %d lines" % (
        os.path.relpath(args.out), len(groups), topics, body.count("\n") + 1))


if __name__ == "__main__":
    main()
