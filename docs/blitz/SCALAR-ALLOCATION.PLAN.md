# Scalar allocation: size a variable by its real type

Status: **done**, 2026-09-20, commit 5cb815a. GPBMODS measured 4,322 -> 3,482 bytes; it compiles
and runs. The compiler test suite keeps every verdict; only the stored reference objects differ,
which a layout change is expected to do, and they have not been refreshed.

This is a compiler fix in 64tass, five call sites, no runtime change. It is written for an
agent picking it up cold.

---

## 1. The defect

`AllocateBytesForType` (`source/compiler/source/storage/create.asm:142`) decides between two
bytes and six from the type bits **in A**:

```
AllocateBytesForType:
		pha
		phx
		ldx 	#2 						; bytes to allocate
		and 	#NSSTypeMask+NSSIInt16
		cmp 	#NSSIFloat
		bne 	_CVNotFloat
		ldx 	#6
_CVNotFloat:
		txa 							; add 6 or 2 to the free memory pointer.
		clc
		adc 	freeVariableMemory
		...
```

Every one of its five callers reaches it immediately after `FindVariable` returned carry
clear, and that path — `_IVNotFound` in `source/compiler/source/storage/findvar.asm` — exits
with **A = 0**. Zero is not a type. It is the end-of-list marker the scan loop just read:

```
_IVCheckLoop:
		lda 	(zTemp0) 					; finished ?
		beq  	_IVNotFound 				; if so, return with CC.
```

`NSSIFloat = $00`, so `cmp #NSSIFloat` always matches and the answer is always six.

**Every scalar is allocated six bytes: `%`, `$` and array head slots alike.**

The real type is in X at that moment. `ExtractVariableName` packs the first character ANDed
with 31 plus the type bits into X, and `_IVNotFound` restores it before returning. Four of
the five sites have already pushed it on the stack.

### Measured

GPBMODS, clean, 2026-09-20: variable space **4,322 bytes** = 720 slots x 6 + 2, against about
700 named variables. Converting 168 float names to `%` across GUI.INC.BL and MENU.INC.BL —
1,292 edit sites — moved that figure by **exactly zero**. That is the proof.

### Why it is urgent

`GetSetVariable` addresses a scalar with eleven bits of a halved offset, so scalars reach
4,096 bytes and no further; see [[scalar-variable-space-caps-at-4096]] and the comment block
at the head of `AllocateBytesForType`. The compiler now refuses anything past that with
`TOO MANY VARIABLES`, which is correct but leaves GPBMODS unbuildable at 4,322.

Sizing correctly is the whole fix. It needs **no source change to any BASIC program**.

---

## 2. What the correct sizes are

Confirmed against the runtime, not inferred:

| type | bits after `and #NSSTypeMask+NSSIInt16` | slot | evidence |
|---|---|---|---|
| float | `$00` `NSSIFloat` | 6 bytes | mantissa, exponent, status |
| int16 `%` | `$20` `NSSIInt16` | 2 bytes | `source/runtime/source/memory/write_int.asm` writes `(zTemp0)` and `(zTemp0),y` with `y = 1`, nothing more |
| string `$` | `$40` `NSSString` | 2 bytes | `source/runtime/source/memory/write_string.asm` reads the slot as a pointer to the heap block |
| array head slot | — | 2 bytes | the slot is written and read as an int16: `dim.asm:58` and `refterm.asm:70` both do `lda #NSSIFloat+NSSIInt16` before `jsr GetSetVariable` |

So the allocator's own `and` / `cmp` are already right. Only what arrives in A is wrong.

Constants are in `source/ifloat32/source/data.inc`: `NSSString = $40`, `NSSIFloat = $00`,
`NSSIInt16 = $20`, `NSSTypeMask = $40`, `NSSArray = $80`.

---

## 3. The five call sites

`AllocateBytesForType` is the only thing in the compiler that advances `freeVariableMemory`
(the others only read it), so these five are the complete set.

Two different corrections are needed. A **scalar** site must pass the variable's real type. An
**array head slot** site must pass int16 unconditionally — the slot holds a pointer to the
array structure whatever the element type is, and the six bytes a float array gets today are
simply dead.

### 3.1 `variables/refterm.asm:30` — scalar, the main creation path

The type was pushed at line 26 and is consumed by the `pla` at line 32, so fetch it back
without unbalancing the stack.

```
		phx 								; save type on stack
		jsr 	FindVariable 				; find it
		bcs 	_GRTNoCreate 				; create if required.
		jsr 	CreateVariableRecord 		; create a variable.
		pla 								; the real type back: the allocator sizes from A, and
		pha 								; A arrives from FindVariable as the zero end marker
		jsr 	AllocateBytesForType 		; allocate memory for it
_GRTNoCreate:
		pla 								; get type back, strip out type information.
```

### 3.2 `variables/refterm.asm:113` — array head slot, `RegisterImplicitArray`

This one already passes a type, `lda implicitDimType`, so it is the only site that is not
handing over a zero. It is still wrong: a float array's pointer slot gets six bytes. The slot
is read back as an int16 at line 70.

```
		lda 	#NSSIFloat+NSSIInt16 		; the slot holds a pointer, and line 70 reads it as
		jsr 	AllocateBytesForType 		; an int16 -- two bytes whatever the element type is
```

`implicitDimType` is still wanted afterwards and line 122 reloads it, so dropping the load
here costs nothing.

### 3.3 `commands/dim.asm:43` — array head slot, `_CDCreate`

Same as 3.2. The slot is written as an int16 at line 58.

```
_CDCreate:
		jsr 	CreateVariableRecord 		; create the basic variable
		lda 	#NSSIFloat+NSSIInt16 		; the head slot is a pointer, read as an int16 below
		jsr 	AllocateBytesForType 		; allocate memory for it
```

The type bits pushed at line 24 are consumed by the `pla` at line 45. `lda` does not touch the
stack, so that stays balanced.

### 3.4 `commands/dim.asm:73` — scalar, `_CDScalar`

The type went on the stack at line 24 and is discarded by the `pla` at line 75.

```
_CDScalar:
		jsr 	FindVariable 				; does it already exist ?
		bcs 	_CDScalarDone 				; yes -- nothing to do.
		jsr 	CreateVariableRecord 		; no -- create it
		pla 								; size it by its real type, not the zero FindVariable
		pha 								; leaves behind
		jsr 	AllocateBytesForType 		; and give it storage.
```

### 3.5 `commands/select.asm:133` — scalar

The type was pushed at line 127 and is consumed by the `pla` at line 134. SELECT has already
rejected strings, but the variable may still be float or int16, so the type is still needed.

```
		jsr 	CreateVariableRecord
		pla 								; float or int16 -- SELECT rejected strings above, but
		pha 								; the allocator still has to tell those two apart
		jsr 	AllocateBytesForType
```

---

## 4. Constraints to respect

- **`AllocateBytesForType` preserves A and X** (`pha` / `phx` on entry, `plx` / `pla` on both
  exits) and never touches Y. Every caller depends on YX still holding the slot address that
  `CreateVariableRecord` returned. `pla` / `pha` touches only A and the stack, so it is safe.
- **Keep the stack balanced.** Each site has exactly one pushed type byte with exactly one
  matching `pla` later. Do not convert a `pla` / `pha` pair into a `plx` / `phx` / `txa`
  without checking what X holds at that point.
- **Do not change the allocator's `and` / `cmp`.** They are correct.
- **Do not touch the runtime.** Nothing there assumes six bytes; see the table in §2.
- `create.asm` is **CRLF**. `sed -i` in Git Bash flattens it to LF — see
  [[git-bash-sed-strips-crlf]]. Patch with Python and rewrite the line endings, or edit in
  place with an editor that preserves them. Check with `python -c "print(open(p,'rb').read().count(b'\r\n'))"`
  before and after; it should be 196 for create.asm today.

---

## 5. Verify

Rebuild the compiler and install it:

```
make libs
```

`make libs` does not install the runtime; if the runtime is touched as well, the other half is
`make -C source/runtime gpc-rt`. This fix does not touch it.

Then compile GPBMODS and read the variable space straight off the object. The compiler writes
the figure into a `.varspace` operand, opcode `$E7`, at PRG offset 513:

```
python source/gpc/samplesbuild.py GPBMODS
python -c "b=open('testing/GPBMODS.PRG','rb').read(); print(b[513], b[514] | b[515]<<8)"
```

The first number must be `231` (`$E7`, confirming the operand is where it is expected). The
second is the scalar total.

- **Before the fix:** 4,322, and the compile fails with `TOO MANY VARIABLES @ 3888`.
- **After:** comfortably under 4,096. A rough estimate is 2,500 to 2,900 depending on how many
  of the 720 slots are non-float, but take the measured number, not the estimate.
- The compile must reach `compiled GPBMODS.SRC.PRG -> GPBMODS.PRG (… SHARED)` with an overlay
  size printed after it.

Then build the rest. **This changes the memory layout of every program**, so everything needs
rebuilding, and the samples need running, not just compiling:

```
python source/gpc/samplesbuild.py
```

At minimum run GPBMODS and the compiler's own tests. A variable-offset bug shows up as one
variable's value appearing in another, which a clean compile will not reveal.

---

## 6. Out of scope

- **Do not widen the p-code operand.** The 4,096-byte wall stays. It was considered and
  rejected: the opcode's spare bits are the write flag.
- **Do not convert BASIC sources to `%`.** That conversion is worth roughly 672 bytes once this
  fix lands, but it is a separate step with its own testing, and the reverted edit set plus the
  script that applies it are kept aside for it. See [[int16-conversion-planned]].
- **Do not fix the integer `FOR` variable defect here.** An integer loop variable compiles to a
  two-byte stub that raises `SYNTAX ERROR` at run time. It is real, it is parked, and it is a
  different piece of work.

---

## 7. What to update when it is done

- `source/gpc/int16scan.py` and `samples/GPB-MODS-TESTING/INT16-HANDOFF.md` model `%` as two
  bytes. That becomes true for the first time, so their byte columns start meaning something.
- The memory note `every-scalar-allocated-six-bytes.md` — mark it fixed with the measured
  before and after figures.
