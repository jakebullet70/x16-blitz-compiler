# Prog8 to ProgB Conversion Guide for AI

This document provides systematic instructions for converting Prog8 source code (`.p8` files) to ProgB syntax (`.pb` files). ProgB is a QuickBASIC-style syntax that compiles to the same AST as Prog8.

## Key Principles

1. **Keywords become UPPERCASE** - All Prog8 keywords convert to uppercase ProgB equivalents
2. **Identifiers stay unchanged** - Variable names, function names, and labels keep their original case
3. **Braces become END blocks** - `{ }` becomes `... END X` where X is the block type
4. **Semicolon comments become apostrophe** - `; comment` becomes `' comment`
5. **File extension changes** - `.p8` → `.pb`

---

## 1. Comments

| Prog8 | ProgB |
|-------|-------|
| `; line comment` | `' line comment` |
| `; line comment` | `REM line comment` |
| `/* block comment */` | `/' block comment '/` |

**Example:**
```prog8
; This is a comment
/* Multi-line
   comment */
```
→
```basic
' This is a comment
/' Multi-line
   comment '/
```

---

## 2. Module-Level Directives

Convert `%directive` to uppercase keyword form:

| Prog8 | ProgB |
|-------|-------|
| `%import name` | `IMPORT name` |
| `%zeropage mode` | `ZEROPAGE mode` |
| `%address $xxxx` | `ADDRESS $xxxx` |
| `%memtop $xxxx` | `MEMTOP $xxxx` |
| `%encoding name` | `ENCODING name` |
| `%output type` | `OUTPUT type` |
| `%launcher type` | `LAUNCHER type` |
| `%option name` | `OPTION name` |
| `%zpreserved $xx, $yy` | `ZPRESERVED $xx, $yy` |
| `%zpallowed $xx, $yy` | `ZPALLOWED $xx, $yy` |

**Example:**
```prog8
%import textio
%zeropage basicsafe
%option enable_floats
```
→
```basic
IMPORT textio
ZEROPAGE basicsafe
OPTION enable_floats
```

---

## 3. Block-Level Directives

| Prog8 | ProgB |
|-------|-------|
| `%breakpoint` | `BREAKPOINT` |
| `%asmbinary "file"` | `ASMBINARY "file"` |
| `%asmbinary "file", off` | `ASMBINARY "file", off` |
| `%asmbinary "file", off, len` | `ASMBINARY "file", off, len` |
| `%asminclude "file"` | `ASMINCLUDE "file"` |
| `%align $xx` | `ALIGN $xx` |
| `%jmptable (a, b, c)` | `JMPTABLE a, b, c` |
| `%option merge` | `MERGE` |
| `%option force_output` | `FORCE_OUTPUT` |
| `%option verafxmuls` | `VERAFXMULS` |

**Note:** `%jmptable` removes parentheses around the list.

---

## 4. Program Structure (Blocks/Modules)

Prog8 blocks become ProgB modules:

| Prog8 | ProgB |
|-------|-------|
| `name { ... }` | `MODULE name ... END MODULE` |
| `name $addr { ... }` | `MODULE name AT $addr ... END MODULE` |

**Example:**
```prog8
main {
    sub start() {
        ; code
    }
}
```
→
```basic
MODULE main
    SUB start()
        ' code
    END SUB
END MODULE
```

---

## 5. Variable Declarations

### Basic Variables

| Prog8 | ProgB |
|-------|-------|
| `ubyte x` | `DIM x AS UBYTE` |
| `ubyte x = 5` | `DIM x AS UBYTE = 5` |
| `ubyte x, y, z` | `DIM x, y, z AS UBYTE` |
| `ubyte[10] arr` | `DIM arr[10] AS UBYTE` |
| `ubyte[] arr = [1,2,3]` | `DIM arr[] AS UBYTE = [1,2,3]` |
| `str name = "hello"` | `DIM name AS STRING = "hello"` |

### Data Types

| Prog8 | ProgB |
|-------|-------|
| `ubyte` | `UBYTE` |
| `byte` | `BYTE` |
| `uword` | `UWORD` |
| `word` | `WORD` |
| `long` | `LONG` |
| `float` | `FLOAT` |
| `bool` | `BOOL` |
| `str` | `STRING` |
| `^^type` | `PTR type` or `^^type` |

### Constants

| Prog8 | ProgB |
|-------|-------|
| `const ubyte MAX = 10` | `CONST MAX AS UBYTE = 10` |

### Memory-Mapped Variables

| Prog8 | ProgB |
|-------|-------|
| `&ubyte memvar = $d020` | `DIM memvar AS UBYTE AT $d020` |

### Variable Tags/Attributes

| Prog8 | ProgB |
|-------|-------|
| `@zp ubyte x` | `DIM x AS UBYTE @zp` |
| `@requirezp ubyte x` | `DIM x AS UBYTE @requirezp` |
| `@shared ubyte x` | `DIM x AS UBYTE @shared` |
| `@dirty ubyte x` | `DIM x AS UBYTE @dirty` |
| `@align64 ubyte[64] arr` | `DIM arr[64] AS UBYTE @align64` |
| `@align256 ubyte[256] arr` | `DIM arr[256] AS UBYTE @align256` |
| `@split uword[] arr` | `DIM arr[] AS UWORD @split` |
| `@nosplit uword[] arr` | `DIM arr[] AS UWORD @nosplit` |

**Note:** Tags move from before the type to after the type in ProgB.

**Example:**
```prog8
ubyte counter = 0
@zp uword fastptr
const ubyte MAX_ITEMS = 100
&ubyte BORDER = $d020
ubyte[256] buffer
```
→
```basic
DIM counter AS UBYTE = 0
DIM fastptr AS UWORD @zp
CONST MAX_ITEMS AS UBYTE = 100
DIM BORDER AS UBYTE AT $d020
DIM buffer[256] AS UBYTE
```

---

## 6. Structs

| Prog8 | ProgB |
|-------|-------|
| `struct Name { ... }` | `TYPE Name ... END TYPE` |

**Example:**
```prog8
struct Point {
    ubyte x
    ubyte y
}
```
→
```basic
TYPE Point
    x AS UBYTE
    y AS UBYTE
END TYPE
```

---

## 7. Subroutines and Functions

### Basic Subroutines (no return value)

| Prog8 | ProgB |
|-------|-------|
| `sub name() { ... }` | `SUB name() ... END SUB` |

### Functions (with return values)

| Prog8 | ProgB |
|-------|-------|
| `sub name() -> ubyte { ... }` | `FUNCTION name() AS UBYTE ... END FUNCTION` |
| `sub name() -> ubyte, ubyte { ... }` | `FUNCTION name() AS UBYTE, UBYTE ... END FUNCTION` |
| `inline sub name() -> ubyte { ... }` | `INLINE FUNCTION name() AS UBYTE ... END FUNCTION` |

### Parameters

| Prog8 | ProgB |
|-------|-------|
| `sub foo(ubyte x, uword y)` | `SUB foo(x AS UBYTE, y AS UWORD)` |
| `sub foo(ubyte x @R0)` | `SUB foo(x AS UBYTE @R0)` |

**Example:**
```prog8
sub print_value(ubyte val) {
    txt.print_ub(val)
}

sub calculate(ubyte a, ubyte b) -> ubyte {
    return a + b
}
```
→
```basic
SUB print_value(val AS UBYTE)
    txt.print_ub(val)
END SUB

FUNCTION calculate(a AS UBYTE, b AS UBYTE) AS UBYTE
    RETURN a + b
END FUNCTION
```

---

## 8. Assembly Subroutines

### ASMSUB

| Prog8 | ProgB |
|-------|-------|
| `asmsub name(...) clobbers(...) -> type @reg { %asm {{ }} }` | `ASMSUB name(...) CLOBBERS(...) AS type @reg ... END ASMSUB` |
| `inline asmsub name(...) { }` | `INLINE ASMSUB name(...) ... END ASMSUB` |

**Parameter format changes:**
- Prog8: `ubyte x @A`
- ProgB: `x AS UBYTE @A`

**Example:**
```prog8
asmsub plot(uword x @AX, ubyte y @Y) clobbers(A,X,Y) {
    %asm {{
        ; assembly code
    }}
}

asmsub getchar() -> ubyte @A clobbers(X) {
    %asm {{
        jsr $ffe4
    }}
}
```
→
```basic
ASMSUB plot(x AS UWORD @AX, y AS UBYTE @Y) CLOBBERS(A, X, Y)
    ASM
        ; assembly code
    END ASM
END ASMSUB

ASMSUB getchar() AS UBYTE @A CLOBBERS(X)
    ASM
        jsr $ffe4
    END ASM
END ASMSUB
```

### EXTSUB (External Subroutines)

| Prog8 | ProgB |
|-------|-------|
| `extsub $addr = name(...)` | `EXTSUB $addr = name(...)` |
| `extsub @bank N $addr = name(...)` | `EXTSUB AT BANK N $addr = name(...)` |

**Example:**
```prog8
extsub $ffd2 = chrout(ubyte c @A) clobbers(A)
extsub $ffe4 = getin() -> ubyte @A clobbers(X,Y)
extsub @bank 4 $c000 = banked_sub(ubyte x @A) -> ubyte @A
```
→
```basic
EXTSUB $ffd2 = chrout(c AS UBYTE @A) CLOBBERS(A)
EXTSUB $ffe4 = getin() AS UBYTE @A CLOBBERS(X, Y)
EXTSUB AT BANK 4 $c000 = banked_sub(x AS UBYTE @A) AS UBYTE @A
```

---

## 9. Control Flow

### If Statements

**Block form:**
```prog8
if condition {
    statements
} else if other {
    statements
} else {
    statements
}
```
→
```basic
IF condition THEN
    statements
ELSEIF other THEN
    statements
ELSE
    statements
END IF
```

**Single-line form:**
```prog8
if condition
    statement
```
→
```basic
IF condition THEN statement
```

### For Loops

#### Range-Based For Loops

| Prog8 | ProgB |
|-------|-------|
| `for i in 1 to 10 { }` | `FOR i = 1 TO 10 ... NEXT` |
| `for i in 10 downto 1 { }` | `FOR i = 10 DOWNTO 1 ... NEXT` |
| `for i in 0 to 100 step 5 { }` | `FOR i = 0 TO 100 STEP 5 ... NEXT` |
| `for i in 10 to 1 step -1 { }` | `FOR i = 10 TO 1 STEP -1 ... NEXT` |

**Example:**
```prog8
for i in 0 to 9 {
    txt.print_ub(i)
}
```
→
```basic
FOR i = 0 TO 9
    txt.print_ub(i)
NEXT
```

#### Array Iteration For Loops

Both Prog8 and ProgB support iterating over arrays using `IN`:

| Prog8 | ProgB |
|-------|-------|
| `for i in [1, 2, 3] { }` | `FOR i IN [1, 2, 3] ... NEXT` |
| `for i in arrayvar { }` | `FOR i IN arrayvar ... NEXT` |

**Example with array literal:**
```prog8
for cx16.r0 in [321, 719, 194, 550, 187] {
    txt.print_uw(cx16.r0)
    txt.nl()
}
```
→
```basic
FOR cx16.r0 IN [321, 719, 194, 550, 187]
    txt.print_uw(cx16.r0)
    txt.nl()
NEXT
```

**Example with array variable:**
```prog8
uword[] values = [100, 200, 300, 400, 500]
for cx16.r0 in values {
    txt.print_uw(cx16.r0)
}
```
→
```basic
DIM values[] AS UWORD = [100, 200, 300, 400, 500]
FOR cx16.r0 IN values
    txt.print_uw(cx16.r0)
NEXT
```

**Key points:**
- Use `IN` instead of `=` for array iteration loops
- Works with array literals `[1, 2, 3]` or array variables
- Works with any data type (bytes, words, etc.)
- For literals, the array is stored in heap memory at compile time
- This is useful for iterating over any array expression

### While Loops

```prog8
while condition {
    statements
}
```
→
```basic
WHILE condition
    statements
WEND
```

### Do-Until Loops

```prog8
do {
    statements
} until condition
```
→
```basic
DO
    statements
LOOP UNTIL condition
```

**Note:** For infinite loops (no `until`), omit the `UNTIL` clause:
```basic
DO
    statements
LOOP
```

### Repeat Loops

```prog8
repeat 10 {
    statements
}

repeat {
    ; infinite loop
}
```
→
```basic
REPEAT 10
    statements
END REPEAT

REPEAT
    ' infinite loop
END REPEAT
```

### Unroll Loops

```prog8
unroll 8 {
    statements
}
```
→
```basic
UNROLL 8
    statements
END UNROLL
```

### When/Select Case

```prog8
when x {
    1 -> statement1
    2, 3 -> statement2
    else -> default_statement
}
```
→
```basic
SELECT CASE x
    CASE 1
        statement1
    CASE 2, 3
        statement2
    CASE ELSE
        default_statement
END SELECT
```

### On Goto/Call

| Prog8 | ProgB |
|-------|-------|
| `on x goto label1, label2` | `ON x GOTO label1, label2` |
| `on x call sub1, sub2` | `ON x CALL sub1, sub2` |

---

## 10. Operators

### Logical Operators

| Prog8 | ProgB |
|-------|-------|
| `and` | `AND` |
| `or` | `OR` |
| `xor` | `XOR` |
| `not` | `NOT` |

### Bitwise Operators

| Prog8 | ProgB |
|-------|-------|
| `~` | `BITNOT` or `~` |
| `&` | `BITAND` or `&` |
| `\|` | `BITOR` or `\|` |
| `^` | `BITXOR` or `^` |

### Comparison Operators

| Prog8 | ProgB |
|-------|-------|
| `==` | `=` or `==` |
| `!=` | `<>` |
| `<` `>` `<=` `>=` | `<` `>` `<=` `>=` (unchanged) |

**Note:** ProgB accepts both `=` and `==` for equality comparisons in expressions. Use whichever feels more natural:
```basic
IF a = 5 THEN      ' BASIC style
IF a == 5 THEN     ' C/Prog8 style
```

### Shift Operators

| Prog8 | ProgB |
|-------|-------|
| `<<` | `SHL` or `<<` |
| `>>` | `SHR` or `>>` |

### Modulo

| Prog8 | ProgB |
|-------|-------|
| `%` | `MOD` |

### Containment

| Prog8 | ProgB |
|-------|-------|
| `in` | `IN` |
| `not in` | `NOT IN` |

**Example:**
```prog8
if (a == 5 and b != 0) or (c << 2) != 0 {
    result = x % 10
}
```
→
```basic
IF (a = 5 AND b <> 0) OR (c SHL 2) <> 0 THEN
    result = x MOD 10
END IF
```

---

## 11. Increment/Decrement

| Prog8 | ProgB |
|-------|-------|
| `x++` | `x++` or `INC x` |
| `x--` | `x--` or `DEC x` |

---

## 12. Augmented Assignment

| Prog8 | ProgB |
|-------|-------|
| `x += 5` | `x += 5` |
| `x -= 5` | `x -= 5` |
| `x *= 2` | `x *= 2` |
| `x /= 2` | `x /= 2` |
| `x &= $0f` | `x &= $0f` or `x = x AND $0f` |
| `x \|= $f0` | `x \|= $f0` or `x = x OR $f0` |
| `x ^= $ff` | `x ^= $ff` or `x = x XOR $ff` |
| `x <<= 2` | `x <<= 2` or `x = x SHL 2` |
| `x >>= 2` | `x >>= 2` or `x = x SHR 2` |
| `x %= 5` | `x %= 5` or `x = x MOD 5` |

---

## 13. Chained Assignments

Both Prog8 and ProgB support chaining multiple assignments:

| Prog8 | ProgB |
|-------|-------|
| `a = b = c = 0` | `a = b = c = 0` |
| `x = y = 42` | `x = y = 42` |

This sets all variables to the same value (rightmost value).

### Assignment vs Comparison Disambiguation

In ProgB, `=` is used for both assignment and equality comparison. The parser resolves this based on context:

**Statements (assignment context):**
```basic
a = b = 0         ' Chained assignment: both a and b become 0
a = b = c = 42    ' All three variables become 42
```

**Expressions (comparison context):**
```basic
IF a = 0 THEN     ' Comparison: checks if a equals 0
IF a = b THEN     ' Comparison: checks if a equals b
x = (a = b)       ' Assignment of comparison result (bool) to x
```

**Important:** When you want to assign the result of a comparison to a variable, use parentheses or `==`:
```basic
' These assign the boolean result of comparison to x:
x = (a = 0)       ' x gets TRUE if a equals 0
x = a == 0        ' Same - using == makes intent clearer
```

**Example showing the difference:**
```prog8
; Prog8
a = b = 0         ; chained assignment
x = a == 0        ; assign comparison result
if a == 0 { }     ; comparison in condition
```
→
```basic
' ProgB
a = b = 0         ' chained assignment - both become 0
x = a == 0        ' assign comparison result (TRUE/FALSE) to x
IF a = 0 THEN     ' comparison in condition
END IF
```

---

## 14. Special Expressions

### Typecast

| Prog8 | ProgB |
|-------|-------|
| `value as uword` | `value AS UWORD` |
| `(a + b) as ubyte` | `(a + b) AS UBYTE` |

### Sizeof

| Prog8 | ProgB |
|-------|-------|
| `sizeof(x)` | `SIZEOF(x)` |

### Address-of

| Prog8 | ProgB |
|-------|-------|
| `&variable` | `ADDRESSOF(variable)` or `&variable` |
| `&&variable` | `TYPEDADDR(variable)` or `&&variable` |
| `&<variable` | `&<variable` (unchanged) |
| `&>variable` | `&>variable` (unchanged) |

### Memory Access (PEEK/POKE)

| Prog8 | ProgB |
|-------|-------|
| `@(address)` | `PEEK(address)` or `@(address)` |
| `@(address) = value` | `POKE address, value` or `@(address) = value` |
| `peekw(address)` | `PEEKW(address)` |
| `pokew(address, value)` | `POKEW address, value` |
| `peekl(address)` | `PEEKL(address)` |
| `pokel(address, value)` | `POKEL address, value` |
| `peekbool(address)` | `PEEKBOOL(address)` |
| `pokebool(address, value)` | `POKEBOOL address, value` |
| `peekf(address)` | `PEEKF(address)` |
| `pokef(address, value)` | `POKEF address, value` |

#### Typed PEEK/POKE Variants

ProgB provides typed variants for reading and writing multi-byte values:

| Type | Read (Expression) | Write (Statement) |
|------|-------------------|-------------------|
| Byte (default) | `PEEK(address)` | `POKE address, value` |
| Word (16-bit) | `PEEKW(address)` | `POKEW address, value` |
| Long (32-bit) | `PEEKL(address)` | `POKEL address, value` |
| Bool | `PEEKBOOL(address)` | `POKEBOOL address, value` |
| Float | `PEEKF(address)` | `POKEF address, value` |

**Example:**
```basic
DIM addr AS UWORD = $1000

' Reading typed values
DIM b AS UBYTE = PEEK(addr)           ' read byte
DIM w AS UWORD = PEEKW(addr)          ' read word
DIM l AS LONG = PEEKL(addr)           ' read long
DIM flag AS BOOL = PEEKBOOL(addr)     ' read bool
DIM f AS FLOAT = PEEKF(addr)          ' read float

' Writing typed values
POKE addr, $42                        ' write byte
POKEW addr, $1234                     ' write word
POKEL addr, $12345678                 ' write long
POKEBOOL addr, TRUE                   ' write bool
POKEF addr, 3.14                      ' write float
```

**Note:** These map to the Prog8 builtin functions `peekw()`, `pokew()`, etc.

### Conditional Expression

| Prog8 | ProgB |
|-------|-------|
| `if cond then val1 else val2` | `IF cond THEN val1 ELSE val2` |

---

## 15. Function Calls

| Prog8 | ProgB |
|-------|-------|
| `mysub()` | `mysub()` or `CALL mysub()` |
| `void func()` | `VOID func()` |

**Note:** `CALL` is optional in ProgB. Both forms are valid.

---

## 16. Branch Conditions (CPU Flag Tests)

| Prog8 | ProgB |
|-------|-------|
| `if_cs { }` | `IF_CS ... END IF` |
| `if_cc { }` | `IF_CC ... END IF` |
| `if_eq { }` / `if_z { }` | `IF_EQ ... END IF` |
| `if_ne { }` / `if_nz { }` | `IF_NE ... END IF` |
| `if_pl { }` / `if_pos { }` | `IF_PL ... END IF` |
| `if_mi { }` / `if_neg { }` | `IF_MI ... END IF` |
| `if_vs { }` | `IF_VS ... END IF` |
| `if_vc { }` | `IF_VC ... END IF` |

---

## 17. Inline Assembly

```prog8
%asm {{
    lda #$00
    sta $d020
}}

%ir {{
    load.b r0, 0
}}
```
→
```basic
ASM
    lda #$00
    sta $d020
END ASM

IR
    load.b r0, 0
END IR
```

**Alternative (Prog8-compatible):**
```basic
ASM {{
    lda #$00
    sta $d020
}}
```

---

## 18. Defer

```prog8
defer cleanup()
defer {
    statements
}
```
→
```basic
DEFER cleanup()
DEFER
    statements
END DEFER
```

---

## 19. Alias

| Prog8 | ProgB |
|-------|-------|
| `alias short = long.name` | `ALIAS short = long.name` |

---

## 20. Break and Continue

| Prog8 | ProgB |
|-------|-------|
| `break` | `BREAK` or `EXIT FOR` / `EXIT DO` / `EXIT WHILE` |
| `continue` | `CONTINUE` |

---

## 21. Return Statements

| Prog8 | ProgB |
|-------|-------|
| `return` | `RETURN` |
| `return value` | `RETURN value` |
| `return a, b, c` | `RETURN a, b, c` |

---

## 22. Labels and Goto

| Prog8 | ProgB |
|-------|-------|
| `mylabel:` | `mylabel:` (unchanged) |
| `goto mylabel` | `GOTO mylabel` |

---

## 23. Literals (Mostly Unchanged)

| Type | Prog8 | ProgB |
|------|-------|-------|
| Hex | `$FF` | `$FF` |
| Binary | `%10101010` | `%10101010` |
| Decimal | `123` | `123` |
| Boolean | `true` / `false` | `TRUE` / `FALSE` |
| Float | `3.14` | `3.14` |
| Character | `'A'` | `"A"c` |
| String | `"hello"` | `"hello"` |
| Screencode string | `sc:"text"` | `sc:"text"` |
| Array | `[1,2,3]` | `[1,2,3]` |

**Note on Character Literals:** ProgB uses the syntax `"."c` where `.` is a single character or escape sequence. Examples:
- Space character: `" "c`
- Letter: `"g"c`
- Tab escape: `"\t"c`
- Hex escape: `"\x41"c`

---

## Complete Conversion Example

### Prog8 Original:
```prog8
; Number guessing game
%import textio
%import conv
%import math
%zeropage basicsafe

main {
    sub start() {
        ubyte secret = math.rnd() % 100 + 1
        ubyte guess
        ubyte attempts = 0
        
        txt.print("Guess the number (1-100)!\n")
        
        do {
            txt.print("Your guess: ")
            guess = conv.str2ubyte(txt.input_chars(buffer))
            attempts++
            
            if guess < secret {
                txt.print("Too low!\n")
            } else if guess > secret {
                txt.print("Too high!\n")
            }
        } until guess == secret
        
        txt.print("Correct! Attempts: ")
        txt.print_ub(attempts)
    }
    
    ubyte[10] buffer
}
```

### ProgB Converted:
```basic
' Number guessing game
IMPORT textio
IMPORT conv
IMPORT math
ZEROPAGE basicsafe

MODULE main
    SUB start()
        DIM secret AS UBYTE = math.rnd() MOD 100 + 1
        DIM guess AS UBYTE
        DIM attempts AS UBYTE = 0
        
        txt.print("Guess the number (1-100)!\n")
        
        DO
            txt.print("Your guess: ")
            guess = conv.str2ubyte(txt.input_chars(buffer))
            attempts++
            
            IF guess < secret THEN
                txt.print("Too low!\n")
            ELSEIF guess > secret THEN
                txt.print("Too high!\n")
            END IF
        LOOP UNTIL guess = secret
        
        txt.print("Correct! Attempts: ")
        txt.print_ub(attempts)
    END SUB
    
    DIM buffer[10] AS UBYTE
END MODULE
```

---

## Conversion Checklist

When converting a file, check these in order:

1. [ ] Change file extension from `.p8` to `.pb`
2. [ ] Convert all comments: `;` → `'`
3. [ ] Convert block comments: `/* */` → `/' '/`
4. [ ] Convert `%import` → `IMPORT`
5. [ ] Convert other `%directives` to uppercase keywords
6. [ ] Convert `blockname { }` → `MODULE blockname ... END MODULE`
7. [ ] Convert `sub name() { }` → `SUB name() ... END SUB`
8. [ ] Convert `sub name() -> type { }` → `FUNCTION name() AS TYPE ... END FUNCTION`
9. [ ] Convert variable declarations to DIM syntax
10. [ ] Convert `const type name = val` → `CONST name AS TYPE = val`
11. [ ] Convert control structures (`if`/`for`/`while`/`do`/`repeat`/`when`)
12. [ ] Convert operators (`==`→`=`, `!=`→`<>`, `%`→`MOD`, etc.)
13. [ ] Convert boolean literals to uppercase
14. [ ] Convert assembly blocks: `%asm {{ }}` → `ASM ... END ASM`
15. [ ] Verify all keywords are uppercase
16. [ ] Verify all identifiers retained original case
