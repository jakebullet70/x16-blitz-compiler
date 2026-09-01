"""deferscan.py -- did anything DEFER?

A statement that fails to compile with a SYNTAX error is not an error: errorhandler.asm rolls it
back and writes a .deferror throw-stub in its place, so the compile prints OK CODE and the program
raises SYNTAX ERROR at run time, at an address, the first time it reaches that statement. A retired
keyword does this to every stale caller at once.

This walks a compiled object's p-code by real instruction size -- a naive byte search would hit the
$EA inside a .word operand or a string -- and reports every .deferror with its source line, read out
of the debug map GPC writes beside the object.

    python deferscan.py <C.NAME.PRG> <codelen> [M.NAME]

codelen is the "OK CODE nnnn" the compiler printed.
"""
import io, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "pcodeconstraw.py")   # the generated token table, beside this script

def token_names():
    txt = io.open(RAW, encoding="utf-8").read()
    m = re.search(r'return "(.*)"', txt, re.S)
    names = {}
    for part in m.group(1).split("|"):
        k, v = part.split(":", 1)
        names[int(k)] = v
    return names

NAMES = token_names()
SHIFT_BASE = 56704                      # .shift's second byte indexes here

# operand bytes that FOLLOW the opcode
FIXED = {
    ".shift": 1, ".byte": 1, ".word": 2, ".float": 5,
    ".goto": 2, ".gosub": 2, ".goto.z": 2, ".goto.nz": 2,
    ".varspace": 2, ".restore": 2, ".fngosub": 2,
    ".deferror": 0, ".exitdo": 2, ".casenext": 2, ".caseend": 2,
    ".ifnext": 2, ".ifelse": 2, ".unwind": 1, ".data": 2,
}

def walk(code):
    """yield (offset, name). Raises on a malformed stream, which is itself the check that the
    walk is aligned -- a bad step lands mid-operand and desynchronises immediately."""
    p = 0
    n = len(code)
    while p < n:
        off = p
        b = code[p]
        if b < 64:                       # small constant, inline
            p += 1; yield off, "const"; continue
        if b < 120:                      # variable reference / store: opcode + slot byte
            p += 2; yield off, "var"; continue
        if b < 128:
            p += 1; yield off, "indirect"; continue
        name = NAMES.get(b, "?%02x" % b)
        if name == ".shift":
            if p + 1 >= n: raise ValueError("shift runs off the end at %04x" % off)
            nm = NAMES.get(SHIFT_BASE + code[p+1], "?shift")
            p += 2; yield off, nm; continue
        if name == ".string":
            if p + 1 >= n: raise ValueError("string runs off the end at %04x" % off)
            p += 2 + code[p+1]; yield off, name; continue
        p += 1 + FIXED.get(name, 0)
        yield off, name
    # A walk that is ALIGNED lands on the last byte or one past it -- the object ends with a
    # terminator this does not model. More than that means the step sizes desynchronised, and a
    # desynchronised walk can invent a .deferror out of an operand byte, so it is fatal.
    if p > n + 1:
        raise ValueError("walk desynchronised: ended at %d, code is %d" % (p, n))

def load_map(path):
    """offset -> line, as GPC writes it: '<hex offset> <line>' per entry."""
    if not path or not os.path.exists(path):
        return []
    txt = io.open(path, encoding="latin-1").read()
    out = []
    for mo in re.finditer(r"([0-9A-Fa-f]{4})\s+(\d+)", txt):
        out.append((int(mo.group(1), 16), int(mo.group(2))))
    out.sort()
    return out

def line_for(mapping, off):
    best = None
    for o, l in mapping:
        if o <= off: best = l
        else: break
    return best

def main():
    obj, codelen = sys.argv[1], int(sys.argv[2])
    mapf = sys.argv[3] if len(sys.argv) > 3 else None
    data = open(obj, "rb").read()
    code = data[len(data) - codelen:]
    mapping = load_map(mapf)

    hits, total = [], 0
    for off, name in walk(code):
        total += 1
        if name == ".deferror":
            hits.append(off)

    print("%s: %d instructions, %d bytes" % (os.path.basename(obj), total, codelen))
    if not hits:
        print("  CLEAN -- no deferred errors")
        return 0
    for off in hits:
        ln = line_for(mapping, off)
        print("  DEFERRED SYNTAX ERROR at $%04X%s" % (off, "  (line %s)" % ln if ln else ""))
    print("  %d statement(s) will throw SYNTAX ERROR at run time." % len(hits))
    return 1

sys.exit(main())
