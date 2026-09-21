#!/usr/bin/env python3
#
#   int16scan.py -- which untyped numeric variables can take a % suffix, and what that frees.
#
#       int16scan.py [PROGRAM ...]              one table a program, every program by default
#       int16scan.py --names TIER PROGRAM       free | review | blocked | array, with reasons
#       int16scan.py --check [PROGRAM ...]      a name used both plain and with %; exit 1 if new
#       int16scan.py --spread PROGRAM           where each module's candidate names appear
#
#   The variable list is BASLOAD's: testing/<PROGRAM>.SRC.SYM from the last build. The SYM
#   drops % and $, so each name is typed from the sources the SYM names. A table is as
#   current as that build.
#
#   A float scalar takes six bytes of variable space and an int16 two. The p-code does not
#   change: a scalar access is two bytes whatever its type (variables/readwrite.asm).
#
#   BASLOAD looks a name up without its suffix and copies the % through (line.inc), so X and
#   X% are two variables. A rename that misses one site compiles clean. --check finds it.
#
#   TIERS
#       free     no reason found not to convert
#       review   * 256, / outside INT(), ^, a fraction, VAL, READ/INPUT, a GP.DEFPROC formal
#                or RETURNS, assigned from a name blocked for its range, or an X% already
#                exists and would merge
#       blocked  FOR index (a compile error), GP.ASM {NAME} read, TI FRE GP.STRPTR GP.ARRPTR,
#                RND PI SIN COS TAN ATN LOG EXP SQR outside INT(), a value over 32,767,
#                * 512 or more
#       array    DIM'd without a suffix: every element and the head slot shrink
#
#   Left out altogether: GP.BANKEDSTR group names and GP.DEFPROC verbs. BASLOAD lists them
#   as variables, but neither is one, and a % on either is a syntax error (gpbstr.asm,
#   gpdefproc.asm).
#
#   An argument to PEEK or VPEEK is an address and the result is a byte, so nothing inside
#   one counts. "from NAME" looks one assignment deep, and a FOR index taints only when a
#   bound of its FOR is out of range itself.
#
#   An int16 store has no range check (memory/write_int.asm). 40,960 stores as -24,576 and
#   no error is raised. A fraction truncates toward zero.
#
import os, re, sys, collections

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

PROGRAMS = [
    dict(name="GPBMODS",  sym="testing/GPBMODS.SRC.SYM",  prg="testing/GPBMODS.PRG",
         src=["samples/GPB-MODS-TESTING", "samples/GPB-MODS-TESTING/GPC-BASIC"]),
    dict(name="XBASE",    sym="testing/XBASE.SRC.SYM",    prg="testing/XBASE.PRG",
         src=["samples/XBASE", "samples/XBASE/GPC-BASIC"]),
    dict(name="GPB.HELP", sym="testing/GPB.HELP.SRC.SYM", prg="testing/GPB.HELP.PRG",
         src=["samples/GPC-HELP", "samples/GPC-HELP/GPC-BASIC"]),
]

#   Plain and % on one name before any conversion. FILEDIR's blob writes FILE.DIR.SLOW% and
#   BASIC keeps a float copy of it.
KNOWN_PAIRS = {"FILE.DIR.SLOW"}

#   --spread reads these. Generated files are left out: they follow their masters.
EDIT_ROOTS = ["GPC-BASIC", "samples/GPB-MODS-TESTING", "samples/GPC-HELP", "samples/XBASE",
              "samples/edit", "samples/color-test", "samples/cruncher", "docs"]
SKIP_DIRS = {"HELP-TXT", "memory", "attic", "spike"}
SKIP_FILES = {"GPC-HELP.md", "GPC-HELP.WIN.md", "GPC-HELP-TESTING.md"}

SIZE = {("", False): 6, ("%", False): 2, ("$", False): 2,
        ("", True): 6, ("%", True): 2, ("$", True): 2}

SYMROW = re.compile(r"^\s*(\d{6})\s+([A-Za-z][A-Za-z0-9._]*)\s+=\w+;")
DEFINE = re.compile(r"^\s*#DEFINE\s+([A-Za-z][A-Za-z0-9._]*)\s+(.*?)\s*(?:##.*)?$", re.I)
STRING = re.compile(r'"[^"\n]*(?:"|$)')
ASSIGN = re.compile(r"^(?:LET\s+)?([A-Z][A-Z0-9._]*)(?![A-Z0-9._%$(])\s*=\s*(.*)$")
FOR_IX = re.compile(r"(?<![A-Z0-9._])FOR\s+([A-Z][A-Z0-9._]*)(?![A-Z0-9._%$])\s*=([^:\n]*)")
READIN = re.compile(r"(?<![A-Z0-9._])(?:READ|INPUT|LINPUT)(?![A-Z0-9._$])#?([^:\n]*)")
DEFPROC = re.compile(r"(?<![A-Z0-9._])GP\.DEFPROC\s+[A-Z][A-Z0-9._]*([^:\n]*)")
VERB = re.compile(r"(?<![A-Z0-9._])GP\.DEFPROC\s+([A-Z][A-Z0-9._]*)")
GROUP = re.compile(r"(?<![A-Z0-9._])GP\.BANKEDSTR\s+(?:.*\s)?([A-Z][A-Z0-9._]*)\s*$")
ASMREF = re.compile(r"\{([A-Z][A-Z0-9._]*)([%$]?)\}")
IDENT = re.compile(r"(?<![A-Z0-9._])([A-Z][A-Z0-9._]*)(?![A-Z0-9._])([%$]?)(\s*\()?")

RANGE_KW = re.compile(r"(?<![A-Z0-9._])(TI|FRE|GP\.STRPTR|GP\.ARRPTR)(?![A-Z0-9._$%])")
FRAC_KW = re.compile(r"(?<![A-Z0-9._])(RND|SIN|COS|TAN|ATN|LOG|EXP|SQR|PI)(?![A-Z0-9._$%])")
HEX = re.compile(r"(?<![A-Z0-9._])\$([0-9A-F]+)")
DEC = re.compile(r"(?<![A-Z0-9._$])(\d{5,})(?![\d.])")
MULT = re.compile(r"\*\s*(\d+)|(\d+)\s*\*")
FRACTION = re.compile(r"(?<![A-Z0-9._$])\d*\.\d+")
VALUSR = re.compile(r"(?<![A-Z0-9._])(VAL|USR)\s*\(")


def rel(p):
    return os.path.join(ROOT, *p.split("/"))


def read_sym(path):
    files, labels, variables = [], set(), []
    section = None
    cur = None
    for line in open(path, encoding="utf-8", errors="replace"):
        head = line.strip()
        if head in ("LABELS", "VARIABLES"):
            section = head
            continue
        m = re.match(r"FILE:\s*(\S+)", head)
        if m:
            cur = m.group(1)
            if cur not in files:
                files.append(cur)
            continue
        m = SYMROW.match(line)
        if not m:
            continue
        if section == "LABELS":
            labels.add(m.group(2).upper())
        elif section == "VARIABLES":
            variables.append((cur, int(m.group(1)), m.group(2).upper()))
    return files, labels, variables


def load(path):
    s = open(path, encoding="utf-8", errors="replace").read()
    return s.replace("\r\n", "\n").replace("\r", "\n").split("\n")


def code_of(line):
    if line.strip().startswith("#"):
        return ""
    s = STRING.sub('""', line)
    s = re.sub(r"##.*", "", s)
    s = re.sub(r"\bREM\b.*", "", s, flags=re.I)
    return s.upper()


def without_int(s, fn="INT"):
    while True:
        m = re.search(r"(?<![A-Z0-9._])" + fn + r"\s*\(", s)
        if not m:
            return s
        depth = 0
        j = m.end() - 1
        while j < len(s):
            if s[j] == "(":
                depth += 1
            elif s[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        s = s[:m.start()] + "0" + s[j + 1:]


def unpeeked(expr):
    return without_int(without_int(expr, "PEEK"), "VPEEK")


def range_reasons(expr):
    """(blocked, review) reasons an expression gives for keeping its target a float."""
    hard, soft = [], []
    e = unpeeked(expr)
    bare = without_int(e)
    for k in RANGE_KW.findall(e):
        hard.append("reads " + k)
    for k in FRAC_KW.findall(bare):
        hard.append("reads " + k)
    for h in HEX.findall(e):
        if int(h, 16) > 0x7FFF:
            hard.append("$" + h)
    for d in DEC.findall(e):
        if int(d) > 32767:
            hard.append(d)
    for a, b in MULT.findall(e):
        v = int(a or b)
        if v >= 512:
            hard.append("* %d" % v)
        elif v == 256:
            soft.append("* 256")
    if "/" in bare:
        soft.append("/ outside INT()")
    if "^" in e:
        soft.append("^")
    if FRACTION.search(e):
        soft.append("fraction")
    for k in VALUSR.findall(e):
        soft.append(k)
    return hard, soft


def statements(code):
    for part in re.split(r":|\bTHEN\b|\bELSE\b", code):
        yield part.strip()


def boundary_alternation(names):
    alt = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))
    return re.compile(r"(?<![A-Z0-9._])(" + alt + r")(?![A-Z0-9._])([%$]?)(\s*\()?")


def varspace_token():
    p = rel("source/runtime/source/generated/vectors.asm")
    if os.path.isfile(p):
        for line in open(p, encoding="utf-8", errors="replace"):
            m = re.search(r";\s*\$([0-9a-fA-F]{2})\s+\.varspace\b", line)
            if m:
                return int(m.group(1), 16)
    return 0xE7


def measure_prg(path):
    """(variable space, workspace) out of a built object, or None."""
    p = rel(path)
    if not os.path.isfile(p):
        return None
    b = open(p, "rb").read()
    if len(b) < 64:
        return None
    load_at = b[0] | b[1] << 8
    tok = varspace_token()
    for i in range(2, min(len(b) - 9, 1200)):
        if b[i] == 0xA9 and b[i + 2] == 0xAE and b[i + 5] == 0xAC and b[i + 8] == 0x4C:
            a1 = (b[i + 3] | b[i + 4] << 8) - load_at + 2
            a2 = (b[i + 6] | b[i + 7] << 8) - load_at + 2
            ws = (b[a2] - b[a1]) * 256 if 0 <= a1 < len(b) and 0 <= a2 < len(b) else None
            for j in range(i + 9, len(b) - 2):
                if b[j] == tok:
                    return b[j + 1] | b[j + 2] << 8, ws
            return None, ws
    return None


class Program(object):
    def __init__(self, spec):
        self.spec = spec
        self.name = spec["name"]
        symp = rel(spec["sym"])
        if not os.path.isfile(symp):
            raise SystemExit("%s: no %s -- build it first" % (self.name, spec["sym"]))
        self.files, self.labels, variables = read_sym(symp)
        self.paths = {}
        for f in self.files:
            for d in spec["src"]:
                p = os.path.join(rel(d), f)
                if os.path.isfile(p):
                    self.paths[f] = p
                    break
        self.missing = [f for f in self.files if f not in self.paths]

        self.owner = {}
        self.names = []
        for f, ln, n in variables:
            if n not in self.owner:
                self.owner[n] = (f, ln)
                self.names.append(n)

        self.defines = {}
        self.code = []
        asm = []
        for f, p in self.paths.items():
            for i, line in enumerate(load(p), 1):
                m = DEFINE.match(line)
                if m:
                    self.defines[m.group(1).upper()] = m.group(2).upper()
                if line.strip().startswith("##"):
                    continue
                asm.append(line.upper())
                c = code_of(line)
                if c.strip():
                    self.code.append((f, i, c))
        self.asm_text = "\n".join(asm)
        self.code_text = "\n".join(c for _, _, c in self.code)
        self.define_re = boundary_alternation(self.defines) if self.defines else None

    def expand(self, s):
        if not self.define_re:
            return s
        for _ in range(4):
            t = self.define_re.sub(lambda m: self.defines[m.group(1)] + m.group(2), s)
            if t == s:
                break
            s = t
        return s

    def analyse(self):
        #   BASLOAD lists these as variables. Neither is one: no variable space, and a % on
        #   either is a syntax error.
        self.groups, self.verbs = set(), set()
        for _, _, c in self.code:
            m = GROUP.search(c)
            if m:
                self.groups.add(m.group(1))
            self.verbs.update(VERB.findall(c))
        self.names = [n for n in self.names if n not in self.groups and n not in self.verbs]

        names_re = boundary_alternation(self.names)
        form = collections.defaultdict(set)
        for m in names_re.finditer(self.code_text):
            form[m.group(1)].add((m.group(2), bool(m.group(3))))
        for m in ASMREF.finditer(self.asm_text):
            if m.group(1) in self.owner:
                form[m.group(1)].add((m.group(2), False))
        self.form = form

        rhs = collections.defaultdict(list)
        for f, i, c in self.code:
            for st in statements(c):
                m = ASSIGN.match(st)
                if m and m.group(1) in self.owner:
                    rhs[m.group(1)].append((self.expand(m.group(2)), (f, i)))

        found = {"blocked": collections.defaultdict(list), "review": collections.defaultdict(list)}
        site_of = {}

        def mark(tier, n, reason, site):
            found[tier][n].append(reason)
            site_of.setdefault((tier, n), site)

        for f, i, c in self.code:
            for m in FOR_IX.finditer(c):
                mark("blocked", m.group(1), "FOR index", (f, i))
                for r in range_reasons(self.expand(m.group(2)))[0]:
                    mark("blocked", m.group(1), "FOR bound " + r, (f, i))
            for m in READIN.finditer(c):
                for k in names_re.finditer(m.group(1)):
                    if not k.group(2) and not k.group(3):
                        mark("review", k.group(1), "READ/INPUT", (f, i))
            for m in DEFPROC.finditer(c):
                for k in names_re.finditer(m.group(1)):
                    if not k.group(2) and not k.group(3):
                        mark("review", k.group(1), "GP.DEFPROC formal", (f, i))

        asm_plain = {m.group(1) for m in ASMREF.finditer(self.asm_text) if not m.group(2)}
        candidates = [n for n in self.names if ("", False) in form.get(n, ())]
        for n in candidates:
            if n in asm_plain:
                mark("blocked", n, "GP.ASM {%s}" % n, self.owner[n])
            for r, site in rhs.get(n, ()):
                hard, soft = range_reasons(r)
                for x in hard:
                    mark("blocked", n, x, site)
                for x in soft:
                    mark("review", n, x, site)
            if ("%", False) in form[n]:
                mark("review", n, "merges with %s%%" % n, self.owner[n])

        block, review = found["blocked"], found["review"]
        ranged = {n for n, rs in block.items() if any(r != "FOR index" for r in rs)}
        if ranged:
            ranged_re = boundary_alternation(ranged)
            for n in candidates:
                if n in block:
                    continue
                for r, site in rhs.get(n, ()):
                    for m in ranged_re.finditer(unpeeked(r)):
                        if not m.group(2) and not m.group(3) and m.group(1) != n:
                            mark("review", n, "from " + m.group(1), site)

        self.tier, self.why, self.where = {}, {}, {}
        for n in candidates:
            tier = "blocked" if block.get(n) else "review" if review.get(n) else "free"
            self.tier[n] = tier
            self.why[n] = sorted(set(found[tier][n])) if tier != "free" else []
            self.where[n] = site_of.get((tier, n), self.owner[n])
        self.arrays = [n for n in self.names if ("", True) in form.get(n, ())]
        self.counted = sum(SIZE[k] for n in self.names for k in form.get(n, ()))
        return self


def table(prog):
    rows = collections.OrderedDict()
    for f in prog.files:
        rows[f] = collections.Counter()
    for n in prog.names:
        f = prog.owner[n][0]
        forms = prog.form.get(n, ())
        c = rows.setdefault(f, collections.Counter())
        if ("%", False) in forms:
            c["int"] += 1
        if ("$", False) in forms:
            c["str"] += 1
        if ("", False) in forms:
            c["float"] += 1
            c[prog.tier[n]] += 1
        if ("", True) in forms:
            c["array"] += 1

    symtime = os.path.getmtime(rel(prog.spec["sym"]))
    import time
    stamp = time.strftime("%Y-%m-%d %H:%M", time.localtime(symtime))
    got = measure_prg(prog.spec["prg"])
    print("%s  (SYM %s)" % (prog.name, stamp))
    if prog.missing:
        print("  sources not found: " + " ".join(prog.missing))
    if prog.groups or prog.verbs:
        print("  left out, not variables: %d GP.BANKEDSTR group names, %d GP.DEFPROC verbs" % (
            len(prog.groups), len(prog.verbs)))
    print("  %-26s %5s %5s %6s %5s %6s %6s %5s %8s %9s" % (
        "file", "int%", "str$", "float", "free", "review", "blockd", "array", "free B", "+review B"))
    tot = collections.Counter()
    for f, c in sorted(rows.items(), key=lambda kv: -(kv[1]["free"] + kv[1]["review"])):
        if not any(c.values()):
            continue
        tot.update(c)
        print("  %-26s %5d %5d %6d %5d %6d %6d %5d %8d %9d" % (
            f, c["int"], c["str"], c["float"], c["free"], c["review"], c["blocked"], c["array"],
            c["free"] * 4, (c["free"] + c["review"]) * 4))
    print("  %-26s %5d %5d %6d %5d %6d %6d %5d %8d %9d" % (
        "TOTAL", tot["int"], tot["str"], tot["float"], tot["free"], tot["review"], tot["blocked"],
        tot["array"], tot["free"] * 4, (tot["free"] + tot["review"]) * 4))
    lib = collections.Counter()
    for f, c in rows.items():
        if not f.upper().endswith(".BASL"):
            lib.update(c)
    print("  library share: %d free, %d review = %d B of %d B" % (
        lib["free"], lib["review"], (lib["free"] + lib["review"]) * 4,
        (tot["free"] + tot["review"]) * 4))
    if got and got[0]:
        vs, ws = got
        line = "  variable space: %d B measured, %d B counted from SYM names" % (vs, prog.counted)
        if ws:
            line += ", workspace %d B" % ws
        print(line)
        print("  after free: %d B   after free + review: %d B" % (
            vs - tot["free"] * 4, vs - (tot["free"] + tot["review"]) * 4))
    else:
        print("  variable space: %d B counted from SYM names (no object to measure)" % prog.counted)
    print()


def names(prog, tier):
    if tier == "array":
        for n in prog.arrays:
            f, ln = prog.owner[n]
            print("%-32s %s:%d" % (n, f, ln))
        return
    for n in prog.names:
        if prog.tier.get(n) == tier:
            f, ln = prog.where[n]
            print("%-32s %-40s %s:%d" % (n, ", ".join(prog.why[n]), f, ln))


def check(prog):
    form = collections.defaultdict(set)
    for _, _, c in prog.code:
        for m in IDENT.finditer(c):
            form[m.group(1)].add((m.group(2), bool(m.group(3))))
    pairs = sorted(n for n, k in form.items()
                   if ("%", False) in k and ("", False) in k
                   and n not in prog.defines and n not in prog.labels)
    new = [n for n in pairs if n not in KNOWN_PAIRS]
    print("%s: %d name(s) used both plain and with %%" % (prog.name, len(pairs)))
    for n in pairs:
        sites = [(f, i) for f, i, c in prog.code
                 if re.search(r"(?<![A-Z0-9._])" + re.escape(n) + r"(?![A-Z0-9._%$(])", c)]
        print("  %-30s %s   plain at %s" % (n, "known" if n in KNOWN_PAIRS else "NEW",
                                         ", ".join("%s:%d" % s for s in sites[:4])))
    return not new


def spread(prog):
    cand = [n for n in prog.names if prog.tier.get(n) in ("free", "review")
            and not prog.owner[n][0].upper().endswith(".BASL")]
    if not cand:
        return
    rx = boundary_alternation(cand)
    hits = collections.defaultdict(collections.Counter)
    for r in EDIT_ROOTS:
        for dp, dn, fn in os.walk(rel(r)):
            dn[:] = [d for d in dn if d not in SKIP_DIRS]
            for f in fn:
                if f in SKIP_FILES or not f.upper().endswith((".BASL", ".BL", ".MD")):
                    continue
                p = os.path.join(dp, f)
                s = open(p, encoding="utf-8", errors="replace").read().upper()
                for m in rx.finditer(s):
                    if not m.group(2):
                        hits[m.group(1)][os.path.relpath(p, ROOT).replace("\\", "/")] += 1

    module = lambda f: re.sub(r"(\.BANK)?\.INC\.BL$", "", f.upper())
    by_mod = collections.OrderedDict()
    for n in cand:
        by_mod.setdefault(module(prog.owner[n][0]), []).append(n)
    print("%s: where each module's free and review names appear" % prog.name)
    print("  %-16s %5s %7s %7s  %s" % ("module", "names", "in own", "outside", "outside, by file"))
    for mod, ns in sorted(by_mod.items(), key=lambda kv: -len(kv[1])):
        own = collections.Counter()
        out = collections.Counter()
        for n in ns:
            for p, k in hits[n].items():
                base = module(os.path.basename(p))
                (own if base == mod else out)[p] += k
        top = ", ".join("%s %d" % (p, k) for p, k in out.most_common(4))
        print("  %-16s %5d %7d %7d  %s" % (mod, len(ns), sum(own.values()), sum(out.values()), top))
    print()


def main(argv):
    wanted = [a for a in argv if not a.startswith("--")]
    specs = {p["name"]: p for p in PROGRAMS}
    for w in wanted:
        if w not in specs and w not in ("free", "review", "blocked", "array"):
            raise SystemExit("unknown program %s -- one of %s" % (w, ", ".join(specs)))

    if "--names" in argv:
        tier = argv[argv.index("--names") + 1]
        prog = [w for w in wanted if w in specs]
        if tier not in ("free", "review", "blocked", "array") or len(prog) != 1:
            raise SystemExit("--names free|review|blocked|array PROGRAM")
        names(Program(specs[prog[0]]).analyse(), tier)
        return 0

    progs = [specs[w] for w in wanted if w in specs] or PROGRAMS

    if "--check" in argv:
        ok = True
        for p in progs:
            ok = check(Program(p)) and ok
        return 0 if ok else 1

    if "--spread" in argv:
        for p in progs:
            spread(Program(p).analyse())
        return 0

    for p in progs:
        table(Program(p).analyse())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
