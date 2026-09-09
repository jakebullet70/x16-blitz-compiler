---
name: byte-data-type-feasibility
description: A byte type is feasible for ARRAYS ONLY; the opcode space refuses byte scalars, and the $60 type code plus $7B/$7F array opcodes are the free slots
metadata:
  type: project
---

Design study only, 2026-09-09. **Nothing built, nothing changed.** The idea was to cut RAM by
storing values in one byte instead of a 6-byte float.

**The type field.** Type is two bits in the top of the variable name's FIRST byte
(`source/ifloat32/source/data.inc`): `$00` float, `$20` int16 (`%`), `$40` string (`$`), bit 7 =
array. That byte is fully packed -- 5 bits of the first character plus the three flags. `$60`
(both type bits set) is the ONE unused combination and is the only sane code for a byte type.
Bits 6-7 of the name's SECOND byte are also free (it is 6-bit ASCII), if a spare bit is ever
needed elsewhere.

**Arrays are the prize, scalars are not.** Sizes are 6 (float) / 2 (int16) per scalar AND per
array element -- see [[array-element-sizes-measured]]. A byte scalar saves 1 byte over `A%`, and
there are at most 1,365 variable slots, so scalars buy nothing. A byte array halves `%`.

**The opcode space decides the shape of the feature.** Scalar access packs as
`$40 | type*16 | write*8 | top-3-bits-of-halved-address` (`variables/readwrite.asm`), giving
`$40-$4F` float, `$50-$5F` int16, `$60-$6F` string. A fourth type wants `$70-$7F`, which
collides with the array-indirection block at `$78-$7F`. **There is no room for byte scalars.**
Array indirection packs as `$78 | type | write*4`, so `$78/$79/$7A` read and `$7C/$7D/$7E`
write -- **`$7B` and `$7F` are free**, exactly the both-bits-set slot. Byte arrays drop in at
zero opcode cost. The accident lines up with where the saving is: build it arrays-only and
reject byte scalars with a clear error.

**The real work is the mask audit.** About 50 sites do `and #NSSTypeMask` (=`$40`) then
`cmp #NSSIFloat` to mean "is this numeric" -- LET, PRINT, INPUT, IF, SELECT, READ, GET, WAIT,
LINPUT, DEFPROC. At `$60` every one of them reads a byte variable as a STRING and rejects it.
The mask has to widen to `$60` and each site become three-way. Not sed-able: some sites want
"float exactly" (FOR already spells that `and #NSSTypeMask|NSSIInt16`), others want "any
number", and a missed one fails silently. All compiler-side, so it costs a program zero bytes
([[two-pass-compiler]]).

**Three size sites**, all two-way branches on "is it float": `AllocateBytesForType`
(`storage/create.asm`), runtime `commands/dim.asm` (`ldx #2` / `ldx #6`), and `ArrayConvert`'s
index scaling (`memory/array.asm`). Byte needs NO shift at all, so a byte array would be the
FASTEST array type as well as the smallest.

**Why it is tractable at all: byte is a storage type, not a stack type.** The number stack is
4-byte mantissa + exponent + status. A byte read zeroes mantissa 1-3 and can never be negative,
so `ReadByte` is smaller and faster than `ReadInteger` (no sign branch). Arithmetic, comparison
and PRINT need no changes.

**Two semantics to decide, not discover.** Wrap mod 256 on store is free and is what byte code
wants, but `A!(I) = A!(I)+1` at 255 silently becoming 0 is a debugging trap. Unsigned only --
signed costs a sign branch per read and buys little, but it means **a byte variable cannot hold
a library boolean**, because TRUE is -1 ([[gpc-basl-true-is-minus-one]]). Byte is for data, not
flags. FOR needs no work: the index is already required to be a plain float.

**Check BASLOAD FIRST.** A `!` or `&` suffix has to survive BASLOAD's long-name to short-name
mapping, and `$` already does NOT separate `FOO` from `FOO$`
([[basload-label-and-variable-collide]]). If the sigil will not pass, nothing downstream matters.

**Byte is the THIRD lever, not the first.** Ahead of it: using `%` where it is not used yet
(6 to 2 is a 3x win, exists today, free -- and FILEDIR's header had the element sizes wrong, so
some of that win may be unclaimed), then [[gp-banked-region-relocation]], which saves 100% of
low RAM rather than 50%. Byte earns its place only for arrays that CANNOT be banked and are
already `%` -- the XBase 255-byte record buffer is exactly that shape ([[xbase-engine-planned]]).

Cost if built: about 40 bytes added to the resident runtime in every program
([[blitz-x16-runtime-footprint]]); everything else is compiler-side and free.
