#	Which BASL routines does a program include and never call, and what do they cost?
#
#		deadcode.py <TOP.BASL> [dir ...]                     reachability only
#		deadcode.py <TOP.BASL> --price MAP SYM [BANKSTART]   priced in real p-code bytes
#
#	BANKSTART is gpBankStart, read off the map's own discontinuity. Give it and the totals
#	split resident from banked, which is the split the SHARED cap actually constrains.
#
#	Reachability is transitive from the program's entry, not a reference count. Refcounting
#	answers a different question and gets this one wrong: FILE.DIR.OPEN calls BANKHOLD, WHERE,
#	ASKFOR and SUCK, so if nothing calls OPEN, refcounting still sees four live references and
#	keeps all five routines. Dead code holds dead code up.
#
#	A BLOCK is a label and everything up to the next label -- the granularity BASL routines are
#	written at. Block 0 is the program's entry and is the only root.
#
#	EDGES ARE ANY WHOLE-TOKEN OCCURRENCE OF A LABEL NAME, not a parse of GOTO / GOSUB /
#	THEN / ON..GOSUB. That is exact here rather than sloppy: BASLOAD puts labels and variables
#	in one name space, so a name is one or the other and never both -- see
#	docs/memory/basload-label-and-variable-collide.md. String literals are blanked first so
#	menu text naming a routine is not read as a call to it.
#
#	FALL-THROUGH keeps the next block alive unless this one ends in RETURN / END / STOP / GOTO.
#	When it cannot tell, it keeps.
#
#	PRICING NEEDS THE BLOB POOL. GP.ASM blocks emit no line marker (gpasm.asm skips
#	STRMarkLine deliberately), so assembled machine code is invisible to the map and the
#	label-gap method charges the whole pool to whichever label precedes it. --price reports the
#	pool separately rather than pretending the map covers it.

import re, os, sys

LABEL_DEF = re.compile(r'^([A-Za-z][A-Za-z0-9._]*):')
INCLUDE   = re.compile(r'^#INCLUDE\s+"([^"]+)"', re.I)


def expand(top, search):
	"""The whole program, includes spliced in at the directive, as (file, lineno, text)."""
	def find(name):
		for d in search:
			p = os.path.join(d, name)
			if os.path.exists(p):
				return p
		sys.exit("missing include: " + name)

	out, seen = [], set()

	def load(path):
		txt = open(path, encoding="latin-1").read().replace("\r\n", "\n").replace("\r", "\n")
		base = os.path.basename(path)
		for n, ln in enumerate(txt.split("\n"), 1):
			m = INCLUDE.match(ln.strip())
			if not m:
				out.append((base, n, ln))
				continue
			inc = find(m.group(1))
			if inc not in seen:
				seen.add(inc)
				load(inc)

	p = find(top)
	seen.add(p)
	load(p)
	return out


def analyse(top, search):
	rows = []
	for f, n, t in expand(top, search):
		s = t.strip()
		rows.append((f, n, t, bool(s) and not s.startswith("#")))

	blocks, cur = [], {"name": "<entry>", "rows": []}
	for r in rows:
		if r[3] and LABEL_DEF.match(r[2]):
			blocks.append(cur)
			cur = {"name": LABEL_DEF.match(r[2]).group(1), "rows": []}
		cur["rows"].append(r)
	blocks.append(cur)

	labels = {b["name"]: i for i, b in enumerate(blocks) if b["name"] != "<entry>"}
	#	longest first, so FILE.DIR.BANKHOLD is matched before FILE.DIR.BANK
	names = sorted(labels, key=len, reverse=True)
	ident = re.compile(r'(?<![A-Za-z0-9._])(' + "|".join(map(re.escape, names)) + r')(?![A-Za-z0-9._%$])')

	for i, b in enumerate(blocks):
		b["refs"], b["lines"], b["bytes"], b["data"] = set(), 0, 0, False
		b["file"] = b["rows"][0][0] if b["rows"] else "?"
		last = None
		for j, (f, n, t, code) in enumerate(b["rows"]):
			if not code:
				continue
			b["lines"] += 1
			b["bytes"] += len(t.strip())
			body = re.sub(r'"[^"]*"?', '""', t)
			if j == 0 and b["name"] != "<entry>":
				body = LABEL_DEF.sub("", body, count=1)
			if re.search(r'\bDATA\b|\bDIM\b', body):
				b["data"] = True
			for m in ident.finditer(body):
				b["refs"].add(labels[m.group(1)])
			last = body.strip().upper()
		b["falls"] = not (last and re.match(r'^(RETURN|END|STOP|GOTO\s|RUN\b)', last.split(":")[-1].strip()))
		b["refs"].discard(i)

	live, work = set(), [0]
	while work:
		i = work.pop()
		if i in live:
			continue
		live.add(i)
		work += [j for j in blocks[i]["refs"] if j not in live]
		if blocks[i]["falls"] and i + 1 < len(blocks) and i + 1 not in live:
			work.append(i + 1)

	return blocks, live


def price(blocks, live, mapf, symf, bankat):
	"""Charge each label the distance to the next label in OBJECT order, per measure-pcode-per-module."""
	line2off, maxoff = {}, 0
	for ln in open(mapf, encoding="latin-1"):
		p = ln.split()
		if len(p) != 2:
			continue
		try:
			off, num = int(p[0], 16), int(p[1])
		except ValueError:
			continue
		if num < 60000:
			line2off[num] = off
			maxoff = max(maxoff, off)

	cur, prev, labels = None, -1, []
	for ln in open(symf, encoding="latin-1"):
		if ln.strip() == "VARIABLES":
			break
		m = re.match(r"\s*FILE:\s*(\S+)", ln)
		if m:
			cur, prev = m.group(1), -1
			continue
		m = re.match(r"\s*(\d+)\s+(\S+)\s+=(\d+);", ln)
		if m and cur:
			src = int(m.group(1))
			#	BASLOAD writes no new FILE: heading when an #INCLUDE ends, so a source line
			#	going backwards is the main file resuming
			if src < prev:
				cur = "(main program)"
			prev = src
			d = int(m.group(3))
			if d in line2off:
				labels.append((line2off[d], cur, m.group(2)))
	labels.sort()

	dead = {b["name"] for i, b in enumerate(blocks) if i not in live}
	total, dead_b, rows = [0, 0], [0, 0], []
	for i, (off, f, name) in enumerate(labels):
		sz = max(0, (labels[i + 1][0] if i + 1 < len(labels) else maxoff) - off)
		w = 1 if off >= bankat else 0
		total[w] += sz
		if name in dead:
			dead_b[w] += sz
			rows.append((sz, name, f, w))

	#	the blob pool: the one span with no line markers in it at all
	offs = sorted(line2off.values())
	pool = max(((offs[i + 1] - offs[i], offs[i]) for i in range(len(offs) - 1)), default=(0, 0))

	print()
	print("  %-24s %8s %8s" % ("", "RESIDENT", "banked"))
	print("  %-24s %8d %8d" % ("p-code total", total[0], total[1]))
	print("  %-24s %8d %8d   excluding blobs" % ("dead", dead_b[0], dead_b[1]))
	print("  %-24s %8d %8s   at $%04X, charged to the label before it" % ("GP.ASM blob pool", pool[0], "", pool[1]))
	print()
	print("  dead is %.1f%% of resident p-code, before the blob pool is split out." %
		(100.0 * dead_b[0] / max(total[0], 1)))
	print()
	for sz, name, f, w in sorted(rows, reverse=True):
		print("    %-28s %-22s %5d %s" % (name, f, sz, "banked" if w else ""))


def main():
	top = sys.argv[1]
	if "--price" in sys.argv:
		k = sys.argv.index("--price")
		dirs, mapf, symf = sys.argv[2:k], sys.argv[k + 1], sys.argv[k + 2]
		bankat = int(sys.argv[k + 3]) if len(sys.argv) > k + 3 else 1 << 30
	else:
		dirs, mapf, symf, bankat = sys.argv[2:], None, None, 0
	search = [os.path.abspath(d) for d in dirs] or [os.getcwd()]

	blocks, live = analyse(top, search)
	dead = [b for i, b in enumerate(blocks) if i not in live]

	print("=== %s ===" % top)
	print("  blocks %d, live %d, dead %d" % (len(blocks), len(live), len(dead)))
	print("  source code lines %d, dead %d (%.1f%%)" % (
		sum(b["lines"] for b in blocks), sum(b["lines"] for b in dead),
		100.0 * sum(b["lines"] for b in dead) / max(sum(b["lines"] for b in blocks), 1)))

	per = {}
	for b in dead:
		per.setdefault(b["file"], [0, 0])
		per[b["file"]][0] += 1
		per[b["file"]][1] += b["lines"]
	print()
	for f in sorted(per, key=lambda x: -per[x][1]):
		print("    %-24s %2d blocks %4d lines" % (f, per[f][0], per[f][1]))

	#	READ walks every DATA in the program in order and DIM sizes an array the rest of the
	#	program may index, so a block holding either is never safe to strip
	unsafe = [b["name"] for b in dead if b["data"]]
	print()
	print("  dead blocks holding DATA or DIM -- NEVER strip these: %s" % (", ".join(unsafe) or "none"))

	if mapf:
		price(blocks, live, mapf, symf, bankat)


main()
