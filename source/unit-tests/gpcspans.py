# -*- coding: utf-8 -*-
#
#   Pass-1 time by source span, from a gpcprobe.py record (docs/blitz/COMPILER-TESTS.PLAN.md,
#   section 5).
#
#       gpcspans.py DRIVE SYM
#
#   DRIVE is a gpcprobe.py drive: CMP.LOG, probe.json and NAME.SRC.PRG. SYM is the program's
#   symbol file. A transcript byte arrived at the first growth of CMP.LOG that passes its offset,
#   so every pass-1 dot has a time, and each dot ends 64 main-loop lines. GP.ASM and GP.BANKEDSTR
#   read their body lines, closer included, without ShowProgress, so a dot counts main-loop
#   lines only.
#
#   The SYM's labels give every BASIC line a file and a source line. The sources are read from
#   samples/GPB-MODS-TESTING/ and its GPC-BASIC/, so only GPBMODS and programs built from its
#   library map. The self-check line counts the label pairs whose walk lands on the next label.
#
#   Prints one row a span, then seconds per file, highest first, and writes DRIVE/spans.json.
#
import os, sys, re, json, bisect
from collections import defaultdict

import dcref

SAMPLE = os.path.join(dcref.ROOT, "samples", "GPB-MODS-TESTING")
drive, sym = sys.argv[1], sys.argv[2]
probe = json.load(open(os.path.join(drive, "probe.json")))
name = probe["name"]
log = open(os.path.join(drive, "CMP.LOG"), "rb").read()
growth = probe["growth"]
sizes = [g[1] for g in growth]


def arrival(offset):
    return growth[bisect.bisect_right(sizes, offset)][0]


#   The PRG: bytes and $CE tokens per BASIC line. main[i] is the BASIC line of main-loop line i+1.
OPENERS = {b"\xce\x5a": b"\xce\x59", b"\xce\x53": b"\xce\x52"}
prg = open(os.path.join(drive, name + ".SRC.PRG"), "rb").read()
p, nbytes, nce, main, inner, closer = 2, {}, {}, [], set(), None
while prg[p] | prg[p + 1]:
    num = prg[p + 2] | prg[p + 3] << 8
    e = prg.index(0, p + 4)
    head = prg[p + 4:e].lstrip(b" ")[:2]
    if closer is not None:
        inner.add(num)
        if head == closer:
            closer = None
    else:
        main.append(num)
        closer = OPENERS.get(head)
    body, quoted, ce = prg[p + 4:e], False, 0
    for c in body:
        if c == 0x22:
            quoted = not quoted
        elif c == 0xCE and not quoted:
            ce += 1
    nbytes[num], nce[num] = len(body), ce
    p = e + 1
total = max(nbytes)

#   The SYM: labels, and a walk that gives every BASIC line a file and source line.
anchors, section, file = [], None, None
for s in open(sym, encoding="latin-1"):
    if s.startswith(("LABELS", "VARIABLES")):
        section = s.strip()
    elif s.startswith("FILE: "):
        file = s[6:].strip()
    elif section == "LABELS":
        m = re.match(r"\s*(\d+)\s+(\S+)\s+=(\d+);", s)
        if m:
            anchors.append((int(m.group(3)), file, int(m.group(1)), m.group(2)))
anchors.sort()
names = {a[3].upper() for a in anchors}
labels_at = defaultdict(int)
for a in anchors:
    labels_at[a[0]] += 1

sources = {}


def source(f):
    if f not in sources:
        path = os.path.join(SAMPLE, f) if f == "GPBMODS.BASL" else os.path.join(SAMPLE, "GPC-BASIC", f)
        text = open(path, encoding="latin-1").read()
        sources[f] = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return sources[f]


def is_code(text):
    t = text.strip()
    if not t or t.startswith("#"):
        return None
    m = re.match(r"([A-Z0-9._]+):(.*)$", t, re.I)
    if m and m.group(1).upper() in names:
        t = m.group(2).strip()
        if not t or t.startswith("#"):
            return None
    return t


where, agree, pairs = {}, 0, 0
for i, (basic, f, line, label) in enumerate(anchors):
    stop = anchors[i + 1][0] if i + 1 < len(anchors) else total + 1
    lines, n, ln = source(f), basic, line
    while ln <= len(lines) and n < stop:
        t = is_code(lines[ln - 1])
        if t is not None:
            where.setdefault(n, (f, ln, t))
            n += 1
        ln += 1
    if i + 1 < len(anchors) and anchors[i + 1][1] == f:
        pairs += 1
        agree += n == stop
unmapped = [n for n in range(1, total + 1) if n not in where]
print("%s: %d BASIC lines, %d labels, self-check %d of %d pairs, %d lines unmapped"
      % (name, total, len(anchors), agree, pairs, len(unmapped)))

#   The dots.
p1, p2, ok = log.find(b"PASS 1 "), log.find(b"PASS 2 "), log.find(b"OK CODE")
t_p1, t_p2, t_ok = arrival(p1), arrival(p2), arrival(ok)
run = re.match(rb"\.*", log[p1 + 7:]).group(0)
dots = [arrival(p1 + 7 + i) for i in range(len(run))]
print("pass 1 %.1f s (%d contiguous dots), pass 2 %.1f s, total %.1f s"
      % (t_p2 - t_p1, len(dots), t_ok - t_p2, t_ok))
print("main-loop lines %d, so %d dots expected; %d lines read inside GP.ASM/GP.BANKEDSTR blocks"
      % (len(main), len(main) // 64, len(inner)))
after = log[p1 + 7 + len(run):p1 + 7 + len(run) + 12]
print("after the dot run: %r at %.1f s" % (after, arrival(p1 + 7 + len(run))))

#   Span k is main-loop lines 64k to 64k+63, from dot k to dot k+1. Span 0 starts at the banner.
edges = [t_p1] + dots + [t_p2]
spans = []
for k in range(len(edges) - 1):
    lo = 1 if k == 0 else main[64 * k - 1]
    hi = main[64 * k + 63] - 1 if k + 1 < len(edges) - 1 else total
    secs = edges[k + 1] - edges[k]
    files = defaultdict(int)
    asm = bstr = 0
    for n in range(lo, hi + 1):
        f, ln, t = where.get(n, ("?", 0, ""))
        files[f] += 1
        asm += "GP.ASM" in t.upper()
        bstr += "GP.BANKEDSTR" in t.upper()
    first = where.get(lo, ("?", 0, ""))
    last = where.get(hi, ("?", 0, ""))
    spans.append(dict(k=k, lo=lo, hi=hi, secs=secs, files=dict(files), first=first[:2], last=last[:2],
                      bytes=sum(nbytes.get(n, 0) for n in range(lo, hi + 1)),
                      ce=sum(nce.get(n, 0) for n in range(lo, hi + 1)),
                      labels=sum(labels_at[n] for n in range(lo, hi + 1)), asm=asm, bstr=bstr,
                      inner=sum(n in inner for n in range(lo, hi + 1))))

per_file = defaultdict(float)
lines_file = defaultdict(int)
for s in spans:
    width = s["hi"] - s["lo"] + 1
    for f, c in s["files"].items():
        per_file[f] += s["secs"] * c / width
        lines_file[f] += c

print("\nspans, in order:")
print("  k   lines        secs  bytes  $CE lab asm bstr inner  from -> to")
for s in spans:
    print("  %-3d %4d-%-4d %6.1f %6d %4d %3d %3d %4d %5d  %s:%d -> %s:%d" % (
        s["k"], s["lo"], s["hi"], s["secs"], s["bytes"], s["ce"], s["labels"], s["asm"], s["bstr"], s["inner"],
        s["first"][0], s["first"][1], s["last"][0], s["last"][1]))

print("\nper file, highest first:")
for f, secs in sorted(per_file.items(), key=lambda x: -x[1]):
    print("  %-26s %6.1f s  %5d lines  %6.1f ms/line" % (f, secs, lines_file[f], 1000 * secs / lines_file[f]))
json.dump(dict(spans=spans, per_file=per_file), open(os.path.join(drive, "spans.json"), "w"), indent=1)
