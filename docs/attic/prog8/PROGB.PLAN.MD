# ProgB: A BASIC-Flavored Syntax for Prog8

## Overview

ProgB is an alternative syntax frontend for the Prog8 compiler that provides a QuickBASIC-style syntax while compiling to the same AST and backend. This allows developers who prefer BASIC syntax to write programs for 6502-based systems while leveraging Prog8's powerful compiler infrastructure.

## Key Design Principles

1. **Same AST, Different Syntax** - ProgB produces identical AST nodes as Prog8, meaning all optimizers and code generators work unchanged.
2. **Minimal Parser Complexity** - When in doubt, follow Prog8's syntax patterns. ProgB should be a thin syntactic layer, not a language that requires complex transformations. If a BASIC-style construct would need significant parsing logic to convert, prefer the Prog8-style equivalent.
3. **Mixed-Language Projects** - `.pb` (ProgB) and `.p8` (Prog8) files can coexist and import each other.
4. **Case-Insensitive Keywords** - `OPTION`, `Option`, and `option` all work (identifiers remain case-sensitive).
5. **Full Feature Parity** - Every Prog8 feature has a ProgB equivalent.

## File Extension

| Extension | Language |
|-----------|----------|
| `.p8` | Prog8 (original syntax) |
| `.pb` | ProgB (BASIC syntax) |

---

## Syntax Mapping Reference

### Directives (Module-Level)

| Prog8 | ProgB |
|-------|-------|
| `%import textio` | `IMPORT textio` |
| `%zeropage basicsafe` | `ZEROPAGE basicsafe` |
| `%zeropage floatsafe` | `ZEROPAGE floatsafe` |
| `%zeropage kernalsafe` | `ZEROPAGE kernalsafe` |
| `%zeropage dontuse` | `ZEROPAGE dontuse` |
| `%zeropage full` | `ZEROPAGE full` |
| `%address $0810` | `ADDRESS $0810` |
| `%memtop $9fff` | `MEMTOP $9FFF` |
| `%encoding iso` | `ENCODING iso` |
| `%output raw` | `OUTPUT raw` |
| `%output prg` | `OUTPUT prg` |
| `%launcher basic` | `LAUNCHER basic` |
| `%launcher none` | `LAUNCHER none` |
| `%option enable_floats` | `OPTION ENABLE_FLOATS` |
| `%option no_sysinit` | `OPTION NO_SYSINIT` |
| `%option romable` | `OPTION ROMABLE` |
| `%option ignore_unused` | `OPTION IGNORE_UNUSED` |
| `%option no_symbol_prefixing` | `OPTION NO_SYMBOL_PREFIXING` |
| `%zpreserved $80, $ff` | `ZPRESERVED $80, $FF` |
| `%zpallowed $80, $ff` | `ZPALLOWED $80, $FF` |

### Directives (Block/Code-Level)

| Prog8 | ProgB |
|-------|-------|
| `%breakpoint` | `BREAKPOINT` |
| `%asmbinary "file"` | `ASMBINARY "file"` |
| `%asmbinary "file", offset` | `ASMBINARY "file", offset` |
| `%asmbinary "file", offset, len` | `ASMBINARY "file", offset, len` |
| `%asminclude "file"` | `ASMINCLUDE "file"` |
| `%align $100` | `ALIGN $100` |
| `%jmptable (sub1, sub2)` | `JMPTABLE sub1, sub2` |
| `%option merge` | `MERGE` |
| `%option force_output` | `FORCE_OUTPUT` |
| `%option verafxmuls` | `VERAFXMULS` |

### Generic Directive Syntax (Prog8-Compatible)

For compatibility with Prog8 and future directives, ProgB also accepts the Prog8-style `%directive` syntax:

```basic
' ProgB - BASIC-style (preferred)
IMPORT textio
ZEROPAGE basicsafe
JMPTABLE sub1, sub2, sub3

' ProgB - Prog8-compatible style (also valid)
%import textio
%zeropage basicsafe
%jmptable (sub1, sub2, sub3)

' Any Prog8 directive works, even future ones
%newdirective arg1, arg2
%anydirective (name1, name2)
```

This allows:
- Pasting Prog8 code directly into ProgB files
- Using new directives without grammar updates
- Validation at compile-time (same as Prog8)

### Program Structure

| Prog8 | ProgB |
|-------|-------|
| `blockname { ... }` | `MODULE blockname ... END MODULE` |
| `blockname $1000 { ... }` | `MODULE blockname AT $1000 ... END MODULE` |
| `sub name() { ... }` | `SUB name() ... END SUB` |
| `sub name() -> ubyte { ... }` | `FUNCTION name() AS UBYTE ... END FUNCTION` |
| `sub name() -> ubyte, ubyte { ... }` | `FUNCTION name() AS UBYTE, UBYTE ... END FUNCTION` |
| `asmsub name() { ... }` | `ASMSUB name() ... END ASMSUB` |
| `inline asmsub name() { ... }` | `INLINE ASMSUB name() ... END ASMSUB` |
| `extsub $ffd2 = name()` | `EXTSUB $FFD2 = name()` |
| `extsub @bank 4 $c000 = name()` | `EXTSUB AT BANK 4 $C000 = name()` |

### Variable Declarations

| Prog8 | ProgB |
|-------|-------|
| `ubyte x` | `DIM x AS UBYTE` |
| `ubyte x = 5` | `DIM x AS UBYTE = 5` |
| `ubyte x, y, z` | `DIM x, y, z AS UBYTE` |
| `ubyte[10] arr` | `DIM arr[10] AS UBYTE` |
| `ubyte[] arr = [1,2,3]` | `DIM arr[] AS UBYTE = [1,2,3]` |
| `str name = "hello"` | `DIM name AS STRING = "hello"` |
| `const ubyte MAX = 10` | `CONST MAX AS UBYTE = 10` |
| `&ubyte memvar = $d020` | `DIM memvar AS UBYTE AT $D020` |
| `@zp ubyte fastvar` | `DIM fastvar AS UBYTE @ZP` |
| `@requirezp ubyte mustbezp` | `DIM mustbezp AS UBYTE @REQUIREZP` |
| `@shared ubyte sharedvar` | `DIM sharedvar AS UBYTE @SHARED` |
| `@dirty ubyte dirtyvar` | `DIM dirtyvar AS UBYTE @DIRTY` |
| `@align64 ubyte[64] aligned` | `DIM aligned[64] AS UBYTE @ALIGN64` |
| `@align256 ubyte[256] page` | `DIM page[256] AS UBYTE @ALIGN256` |
| `@split uword[] arr` | `DIM arr[] AS UWORD @SPLIT` |
| `@nosplit uword[] arr` | `DIM arr[] AS UWORD @NOSPLIT` |

### Data Types

| Prog8 | ProgB | Notes |
|-------|-------|-------|
| `ubyte` | `UBYTE` | Unsigned 8-bit |
| `byte` | `BYTE` | Signed 8-bit |
| `uword` | `UWORD` | Unsigned 16-bit |
| `word` | `WORD` | Signed 16-bit |
| `long` | `LONG` | 32-bit signed integer |
| `float` | `FLOAT` | Floating point |
| `bool` | `BOOL` | Boolean |
| `str` | `STRING` | String |
| `^^ubyte` | `PTR UBYTE` or `^^UBYTE` | Pointer to ubyte |
| `^^MyStruct` | `PTR MyStruct` or `^^MyStruct` | Pointer to struct |

### Structs

```basic
' ProgB
TYPE MyStruct
    x AS UBYTE
    y AS UBYTE
    name AS STRING
END TYPE

DIM ptr AS PTR MyStruct
```

```prog8
; Prog8 equivalent
struct MyStruct {
    ubyte x
    ubyte y
    str name
}

^^MyStruct ptr
```

### Alias

| Prog8 | ProgB |
|-------|-------|
| `alias shortname = some.long.name` | `ALIAS shortname = some.long.name` |

### Control Flow

#### If/Else

```basic
' ProgB
IF condition THEN
    statements
ELSEIF other_condition THEN
    statements
ELSE
    statements
END IF

' Single-line form
IF condition THEN statement
```

```prog8
; Prog8 equivalent
if condition {
    statements
} else if other_condition {
    statements
} else {
    statements
}
```

#### For Loop

```basic
' ProgB - Range-based loops
FOR i = 1 TO 10
    statements
NEXT

FOR i = 10 TO 1 STEP -1
    statements
NEXT

FOR i = 10 DOWNTO 1
    statements
NEXT

' ProgB - Array literal loops
FOR cx16.r0 IN [321, 719, 194, 550, 187]
    statements
NEXT

FOR value IN [10, 20, 30, 40, 50]
    txt.print_ub(value)
NEXT
```

```prog8
; Prog8 equivalent - range-based
for i in 1 to 10 {
    statements
}

for i in 10 to 1 step -1 {
    statements
}

for i in 10 downto 1 {
    statements
}

; Prog8 equivalent - array literal
for cx16.r0 in [321, 719, 194, 550, 187] {
    statements
}

for value in [10, 20, 30, 40, 50] {
    txt.print_ub(value)
}
```

#### While Loop

```basic
' ProgB
WHILE condition
    statements
WEND
```

```prog8
; Prog8 equivalent
while condition {
    statements
}
```

#### Do Loop

```basic
' ProgB
DO
    statements
LOOP UNTIL condition
```

```prog8
; Prog8 equivalent
do {
    statements
} until condition
```

#### Repeat Loop

```basic
' ProgB
REPEAT 10
    statements
END REPEAT

REPEAT  ' infinite loop
    statements
END REPEAT
```

```prog8
; Prog8 equivalent
repeat 10 {
    statements
}

repeat {
    statements
}
```

#### Unroll Loop

```basic
' ProgB
UNROLL 8
    ' statements unrolled 8 times at compile time
END UNROLL
```

```prog8
; Prog8 equivalent
unroll 8 {
    ; statements
}
```

#### Defer

```basic
' ProgB - cleanup code that runs when subroutine exits
SUB example()
    DEFER cleanup()
    DEFER
        txt.print("exiting")
    END DEFER
    ' ... code ...
END SUB
```

```prog8
; Prog8 equivalent
sub example() {
    defer cleanup()
    defer {
        txt.print("exiting")
    }
    ; ... code ...
}
```

#### Select Case (When)

```basic
' ProgB
SELECT CASE x
    CASE 1
        statements
    CASE 2, 3, 4
        statements
    CASE ELSE
        statements
END SELECT
```

```prog8
; Prog8 equivalent
when x {
    1 -> statements
    2, 3, 4 -> statements
    else -> statements
}
```

#### On Goto/Gosub

```basic
' ProgB
ON x GOTO label1, label2, label3
ON x GOSUB sub1, sub2, sub3
ON x CALL sub1, sub2, sub3      ' CALL also supported

' With ELSE fallback (when x is out of range)
ON x GOTO label1, label2 ELSE default_label
```

```prog8
; Prog8 equivalent
on x goto label1, label2, label3
on x call sub1, sub2, sub3
```

### Operators

| Prog8 | ProgB | Notes |
|-------|-------|-------|
| `and` | `AND` | Logical/bitwise and |
| `or` | `OR` | Logical/bitwise or |
| `xor` | `XOR` | Logical/bitwise xor |
| `not` | `NOT` | Logical not |
| `~` | `BITNOT` or `~` | Bitwise invert |
| `%` | `MOD` | Modulo |
| `==` | `=` | Equality (context-sensitive) |
| `!=` | `<>` | Not equal |
| `<<` | `SHL` or `<<` | Shift left |
| `>>` | `SHR` or `>>` | Shift right |
| `in` | `IN` | Containment check |
| `not in` | `NOT IN` | Negative containment |
| `+` `-` `*` `/` | `+` `-` `*` `/` | Arithmetic (same) |
| `<` `>` `<=` `>=` | `<` `>` `<=` `>=` | Comparison (same) |
| `&` | `BITAND` or `&` | Bitwise and |
| `\|` | `BITOR` or `\|` | Bitwise or |
| `^` | `BITXOR` or `^` | Bitwise xor |

### Increment/Decrement

| Prog8 | ProgB |
|-------|-------|
| `x++` | `x++` or `INC x` or `x = x + 1` |
| `x--` | `x--` or `DEC x` or `x = x - 1` |

### Augmented Assignment

| Prog8 | ProgB |
|-------|-------|
| `x += 5` | `x += 5` or `x = x + 5` |
| `x -= 5` | `x -= 5` |
| `x *= 2` | `x *= 2` |
| `x /= 2` | `x /= 2` |
| `x &= $0f` | `x = x AND $0F` or `x &= $0F` |
| `x \|= $f0` | `x = x OR $F0` or `x \|= $F0` |
| `x ^= $ff` | `x = x XOR $FF` or `x ^= $FF` |
| `x <<= 2` | `x = x SHL 2` or `x <<= 2` |
| `x >>= 2` | `x = x SHR 2` or `x >>= 2` |
| `x %= 5` | `x %= 5` or `x = x MOD 5` |

### Chained Assignment

Multiple variables can be assigned in a single statement:

```basic
' ProgB
x = y = z = 0       ' All three set to 0
a = b = getValue()  ' Both get the return value
```

### Literals

| Prog8 | ProgB | Notes |
|-------|-------|-------|
| `$FF` | `$FF` | Hexadecimal (same!) |
| `%10101010` | `%10101010` | Binary (same!) |
| `123` | `123` | Decimal (same) |
| `1_000_000` | `1_000_000` | Underscores allowed (same) |
| `true` / `false` | `TRUE` / `FALSE` | Boolean |
| `3.14159` | `3.14159` | Float (same) |
| `1.5e-10` | `1.5e-10` | Scientific notation (same) |
| `'A'` | `'A'` | Character literal (same) |
| `"hello"` | `"hello"` | String literal (same) |
| `sc:"hello"` | `sc:"hello"` | Screencodes string (same) |
| `petscii:"text"` | `petscii:"text"` | Explicit encoding (same) |
| `[1,2,3]` | `[1,2,3]` | Array literal (same!) |
| `[1,2,3,]` | `[1,2,3,]` | Trailing comma allowed |
| `[]` | `[]` | Empty array literal |
| `[1,2,3] * 10` | `[1,2,3] * 10` | Repeated array (same!) |

### Address-of Operators

| Prog8 | ProgB | Notes |
|-------|-------|-------|
| `&variable` | `ADDRESSOF(variable)` or `&variable` | Address of variable |
| `&&variable` | `TYPEDADDR(variable)` or `&&variable` | Typed address (pointer) |
| `&<variable` | `&<variable` | LSB of address (same!) |
| `&>variable` | `&>variable` | MSB of address (same!) |
| `sizeof(x)` | `SIZEOF(x)` | Size of type/variable |

### Comments

| Prog8 | ProgB |
|-------|-------|
| `; comment` | `' comment` |
| `; comment` | `REM comment` |
| `/* block */` | `/' block '/` |

### Inline Assembly

```basic
' ProgB - block style (preferred)
ASM
    lda #$00
    sta $d020
END ASM

' IR assembly
IR
    load.b r0, 0
END IR

' Alternate brace style (Prog8-compatible)
ASM {{
    lda #$00
    sta $d020
}}
```

```prog8
; Prog8 equivalent
%asm {{
    lda #$00
    sta $d020
}}

%ir {{
    load.b r0, 0
}}
```

### Branch Conditions (Low-Level CPU Flag Tests)

| Prog8 | ProgB | Notes |
|-------|-------|-------|
| `if_cs { }` | `IF_CS ... END IF` | If carry set |
| `if_cc { }` | `IF_CC ... END IF` | If carry clear |
| `if_eq { }` / `if_z { }` | `IF_EQ ... END IF` | If zero/equal |
| `if_ne { }` / `if_nz { }` | `IF_NE ... END IF` | If not zero |
| `if_pl { }` / `if_pos { }` | `IF_PL ... END IF` | If positive |
| `if_mi { }` / `if_neg { }` | `IF_MI ... END IF` | If negative |
| `if_vs { }` | `IF_VS ... END IF` | If overflow set |
| `if_vc { }` | `IF_VC ... END IF` | If overflow clear |

### Conditional Expressions (Ternary)

```basic
' ProgB
result = IF condition THEN value1 ELSE value2

' Branch condition expression
result = IF_CC THEN value1 ELSE value2
```

```prog8
; Prog8 equivalent
result = if condition then value1 else value2

result = if_cc then value1 else value2
```

### Subroutine Calls

```basic
' ProgB - CALL is optional
CALL txt.print("hello")     ' explicit CALL (traditional BASIC style)
txt.print("hello")          ' CALL omitted (cleaner, modern style)
mysub()

' Discarding return values
VOID txt.input_chars(buf)   ' explicitly discard return value

' Function calls in expressions (never use CALL)
x = txt.input_chars(buffer)
result = math.sqrt(value)
```

```prog8
; Prog8 equivalent
txt.print("hello")
mysub()

void txt.input_chars(buf)

x = txt.input_chars(buffer)
result = math.sqrt(value)
```

### Multi-Value Return and Assignment

```basic
' ProgB - multiple return values
FUNCTION getcoords() AS UBYTE, UBYTE
    RETURN 10, 20
END FUNCTION

' Multi-assign
DIM x, y AS UBYTE
x, y = getcoords()
```

```prog8
; Prog8 equivalent
sub getcoords() -> ubyte, ubyte {
    return 10, 20
}

ubyte x, y
x, y = getcoords()
```

### Return Statements

```basic
' ProgB
RETURN              ' return from sub
RETURN value        ' return value from function
RETURN a, b, c      ' multiple return values
```

### Break and Continue

| Prog8 | ProgB |
|-------|-------|
| `break` | `BREAK` or `EXIT DO` / `EXIT FOR` / `EXIT WHILE` |
| `continue` | `CONTINUE` |

```basic
' ProgB
FOR i = 1 TO 100
    IF i = 50 THEN EXIT FOR
    IF i MOD 2 = 0 THEN CONTINUE
    txt.print_ub(i)
NEXT

DO
    IF done THEN EXIT DO
LOOP
```

### Labels and Goto

```basic
' ProgB
mylabel:
GOTO mylabel
```

### Typecast

```basic
' ProgB - same as Prog8
value = x AS UWORD
result = (a + b) AS UBYTE
```

### Ranges

```basic
' ProgB - used in FOR loops and containment checks
FOR i = 1 TO 10                ' 1 to 10 inclusive
FOR i = 10 TO 1 STEP -1        ' countdown (or use DOWNTO)
FOR i = 10 DOWNTO 1            ' same as above
FOR i = 0 TO 100 STEP 5        ' with step

IF x IN 1 TO 10 THEN           ' range containment
IF x NOT IN 1 TO 10 THEN       ' negative containment
```

### Static Struct Initializer

```basic
' ProgB - initialize struct pointer
DIM ptr AS PTR MyStruct = MyStruct:[10, 20, "hello"]
```

```prog8
; Prog8 equivalent
^^MyStruct ptr = MyStruct:[10, 20, "hello"]
```

### Memory Access

```basic
' ProgB - BASIC-style PEEK/POKE
value = PEEK(address)       ' read byte from address
POKE address, value         ' write byte to address

' ProgB - also supports Prog8 style
value = @(address)          ' read byte from address
@(address) = value          ' write byte to address
```

```prog8
; Prog8 equivalent
value = @(address)
@(address) = value
```

### Pointers

```basic
' ProgB - pointer syntax same as Prog8
DIM ptr AS PTR UBYTE            ' pointer to ubyte (or ^^UBYTE)
DIM ptr AS ^^UBYTE              ' alternate syntax
value = myptr^^                 ' dereference
myptr^^.field                   ' dereference and access field
```

```prog8
; Prog8 equivalent
^^ubyte ptr
value = myptr^^
myptr^^.field
```

### Assembly Subroutines (with registers)

```basic
' ProgB - asmsub with register parameters
ASMSUB plot(x AS UWORD @AX, y AS UBYTE @Y) CLOBBERS(A, X, Y)
    ASM
        ; assembly code here
    END ASM
END ASMSUB

' With return value
ASMSUB getchar() AS UBYTE @A CLOBBERS(X)
    ASM
        jsr $ffe4
    END ASM
END ASMSUB

' External ROM routine
EXTSUB $FFD2 = chrout(c AS UBYTE @A) CLOBBERS(A)
EXTSUB $FFE4 = getin() AS UBYTE @A CLOBBERS(X, Y)

' Banked external routine
EXTSUB AT BANK 4 $C000 = mybankedsub(x AS UBYTE @A) AS UBYTE @A
```

```prog8
; Prog8 equivalent
asmsub plot(uword x @AX, ubyte y @Y) clobbers(A,X,Y) {
    %asm {{
        ; assembly code here
    }}
}

asmsub getchar() -> ubyte @A clobbers(X) {
    %asm {{
        jsr $ffe4
    }}
}

extsub $ffd2 = chrout(ubyte c @A) clobbers(A)
extsub $ffe4 = getin() -> ubyte @A clobbers(X,Y)

extsub @bank 4 $c000 = mybankedsub(ubyte x @A) -> ubyte @A
```

### Subroutine Parameters with Virtual Registers (R0-R15)

```basic
' ProgB - normal sub can use virtual registers R0-R15
SUB myfast(value AS UWORD @R0, count AS UBYTE @R1)
    ' R0 and R1 will hold the parameters
END SUB
```

```prog8
; Prog8 equivalent
sub myfast(uword value @R0, ubyte count @R1) {
    ; R0 and R1 will hold the parameters
}
```

### Line Continuation

Expressions can span multiple lines. Line breaks are allowed after binary operators and within parentheses:

```basic
' ProgB - long expressions can be split across lines
result = very_long_variable_name +
         another_long_name *
         some_factor

total = (first_value +
         second_value +
         third_value)

IF x > 10 AND
   y < 20 THEN
    ' ...
END IF
```

### Contextual Keywords

The following keywords can also be used as variable names, subroutine names, or struct field names when the context is unambiguous:

`on`, `call`, `inline`, `step`, `import`, `zeropage`, `address`, `memtop`, `encoding`, `output`, `launcher`, `option`, `zpreserved`, `zpallowed`, `breakpoint`, `asmbinary`, `asminclude`, `align`, `jmptable`, `merge`, `force_output`, `verafxmuls`

```basic
' These are valid variable names
DIM step AS UBYTE = 5
DIM option AS BOOL = TRUE
DIM import AS UWORD

' "step" is a keyword in FOR context, but variable elsewhere
FOR i = 0 TO 10 STEP step
    txt.print_ub(i)
NEXT
```

---

## Implementation Plan

### Phase 1: Grammar Foundation
- [ ] Create `Prog8QB.g4` grammar file based on `Prog8ANTLR.g4`
- [ ] Implement case-insensitive lexing using `CaseChangingCharStream`
- [ ] Define all keyword tokens (OPTION, MODULE, SUB, DIM, etc.)
- [ ] Define statement rules matching Prog8's AST structure

### Phase 2: AST Visitor
- [ ] Create `Antlr2KotlinVisitorQB.kt` based on existing visitor
- [ ] Map ProgB constructs to existing AST classes:
  - `MODULE` → `Block`
  - `SUB`/`FUNCTION` → `Subroutine`
  - `DIM` → `VarDecl`
  - `IF`/`END IF` → `IfElse`
  - `FOR`/`NEXT` → `ForLoop`
  - `WHILE`/`WEND` → `WhileLoop`
  - `SELECT CASE` → `When`
  - etc.

### Phase 3: Parser Integration
- [ ] Create `ProgBParser.kt` (minimal, wraps ANTLR)
- [ ] Modify `ModuleImporter.kt` to select parser based on file extension
- [ ] Handle `IMPORT` directive to resolve `.pb` or `.p8` files

### Phase 4: Testing
- [ ] Convert example programs to ProgB syntax
- [ ] Test mixed-language imports (`.pb` importing `.p8` and vice versa)
- [ ] Verify generated code is identical regardless of syntax used
- [ ] Test error messages point to correct ProgB source locations

### Phase 5: Documentation & Tooling
- [ ] Write ProgB language reference
- [ ] Create syntax highlighting for VS Code (`.pb` files)
- [ ] Update compiler CLI to recognize `.pb` extension
- [ ] Add examples to `examples/` folder

---

## Example Program: Number Guessing Game

```basic
IMPORT textio
IMPORT conv
IMPORT math
ZEROPAGE basicsafe

' The classic number guessing game

MODULE main

    SUB start()
        DIM name AS STRING = "????????????????????????"
        DIM input AS STRING = "??????????"
        DIM secretnumber AS UBYTE = math.rnd() MOD 99 + 1
        DIM attempts_left AS UBYTE
        DIM guess AS UBYTE

        txt.lowercase()
        txt.print("Please introduce yourself: ")
        VOID txt.input_chars(name)
        txt.print("Hello, ")
        txt.print(name)
        txt.print("! Let's play a number guessing game.")
        txt.nl()

        FOR attempts_left = 10 DOWNTO 1
            txt.print("You have ")
            txt.print_ub(attempts_left)
            txt.print(" guesses left. Your guess? ")
            VOID txt.input_chars(input)
            guess = conv.str2ubyte(input)

            IF guess = secretnumber THEN
                txt.print("You guessed it!")
                RETURN
            ELSEIF guess < secretnumber THEN
                txt.print("Too low!")
            ELSE
                txt.print("Too high!")
            END IF
            txt.nl()
        NEXT

        txt.print("Too bad! My number was: ")
        txt.print_ub(secretnumber)
        txt.nl()
    END SUB

END MODULE
```

## Example: Primes with Sieve

```basic
IMPORT textio
ZEROPAGE basicsafe

' Calculate prime numbers up to 255

MODULE main
    DIM sieve[256] AS BOOL
    DIM candidate_prime AS UBYTE = 2

    SUB start()
        sys.memset(ADDRESSOF(sieve), 256, 0)
        
        txt.print("Prime numbers up to 255:")
        txt.nl()
        txt.nl()
        
        DIM amount AS UBYTE = 0
        
        DO
            DIM prime AS UBYTE = find_next_prime()
            IF prime = 0 THEN EXIT DO
            txt.print_ub(prime)
            txt.print(", ")
            amount++
        LOOP
        
        txt.nl()
        txt.print("Number of primes (expected 54): ")
        txt.print_ub(amount)
        txt.nl()
    END SUB

    FUNCTION find_next_prime() AS UBYTE
        WHILE sieve[candidate_prime]
            candidate_prime++
            IF candidate_prime = 0 THEN RETURN 0
        WEND

        sieve[candidate_prime] = TRUE
        DIM multiple AS UWORD = candidate_prime AS UWORD

        WHILE multiple < len(sieve)
            sieve[lsb(multiple)] = TRUE
            multiple += candidate_prime
        WEND

        RETURN candidate_prime
    END FUNCTION

END MODULE
```

## Example: Inline Assembly

```basic
ZEROPAGE basicsafe

MODULE main

    SUB start()
        DIM color AS UBYTE = 0
        
        DO
            POKE $D020, color   ' or: @($D020) = color
            color++
            
            ' Low-level wait using assembly
            ASM
                lda #$10
            .wait:
                cmp $d012
                bne .wait
            END ASM
        LOOP
    END SUB

END MODULE
```

---

## Development & Testing

### Building the Compiler

To build the compiler after making changes to the grammar or source code:

```cmd
REM Regenerate ANTLR parser from grammar (after modifying .g4 files)
.\gradlew.bat :parser:generateGrammarSource

REM Build the full compiler
.\gradlew.bat installdist

REM The compiler launch script will be at:
REM .\compiler\build\install\prog8c\bin\prog8c.bat
```

### Testing ProgB Files

```cmd
REM Compile a ProgB file for C64
.\compiler\build\install\prog8c\bin\prog8c.bat -target c64 examples\progb\hello.pb

REM Compile a ProgB file for Commander X16
.\compiler\build\install\prog8c\bin\prog8c.bat -target cx16 examples\progb\hello.pb

REM Compile a ProgB file for Virtual target
.\compiler\build\install\prog8c\bin\prog8c.bat -target virtual examples\progb\hello.pb

REM Run all tests
.\gradlew.bat test
```

### Quick Test Cycle

For rapid iteration when debugging grammar or visitor issues:

```cmd
REM 1. Regenerate grammar
.\gradlew.bat :parser:generateGrammarSource

REM 2. Build compiler
.\gradlew.bat installdist

REM 3. Test your file
.\compiler\build\install\prog8c\bin\prog8c.bat -target virtual your_test_file.pb
```

---

## Files to Create/Modify

### New Files
- `parser/src/main/antlr/Prog8QB.g4` - ANTLR grammar
- `compilerAst/src/prog8/ast/antlr/Antlr2KotlinVisitorQB.kt` - AST visitor
- `compilerAst/src/prog8/parser/ProgBParser.kt` - Parser wrapper

### Modified Files
- `compiler/src/prog8/compiler/ModuleImporter.kt` - Add `.pb` extension handling
- `compiler/src/prog8/Compiler.kt` - Recognize `.pb` files as valid input

---

## Success Criteria

1. Any valid Prog8 program can be expressed in ProgB syntax
2. Mixed `.p8` and `.pb` projects compile correctly
3. Generated machine code is identical regardless of source syntax
4. Error messages reference correct ProgB source locations
5. Existing Prog8 standard library works unchanged from ProgB programs
