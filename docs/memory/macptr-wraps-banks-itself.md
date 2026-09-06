---
name: macptr-wraps-banks-itself
description: "MACPTR ($FF44) crosses RAM bank boundaries by itself and leaves the new bank selected -- so a transfer larger than one 8KB window needs no banking code, which is what STASH wants"
metadata:
  node_type: memory
  type: reference
---

From the X16 KERNAL reference, `MACPTR` ($FF44), confirmed while building `FILEDIR.INC.BL`:

> For reading into Hi RAM, you must set the desired bank prior to calling `MACPTR`. During the read,
> `MACPTR` will **automatically wrap to the next bank** as required, leaving the new bank active
> when finished.

So a block read into banked RAM crossing `$BFFF` needs **no banking code at all** — set the bank,
point at `$A000`, and the KERNAL walks the windows. `MCIOUT` ($FEB1) says the same for writing.

**The caller wanting this is STASH, not the directory reader.** An 80x60 text stash is
80 * 60 * 2 + 4 = **9,604 bytes** and genuinely does not fit one 8KB window, so a stash of a large
screen either spans two banks or cannot be taken. `FILEDIR` deliberately does *not* use the wrap: it
stops at the end of the one bank it was given, because wrapping would spill the listing into a bank
it never claimed. The trick is recorded here for the case that actually needs it.

**The details that bite either way:**

- Ask for **at most 255 bytes** a call and the returned count fits one byte, which keeps the
  pointer arithmetic eight bit. `A = 0` means "up to 512, KERNAL's choice".
- It can return **fewer bytes than asked for** and that is not an error. Count is in X (lo) / Y (hi).
- **Carry set on return means the device has no `MACPTR`** and the caller must fall back to `ACPTR`
  / `CHRIN` per byte. Nothing on this machine refuses it, so that path cannot be tested here.
- It **leaves the new bank selected**, so whatever restores the caller's bank has to run after it —
  the same trap as [[stash-leaves-its-bank-selected]].
- The destination pointer still has to be reset to `$A000` between calls; it is the *bank register*
  the KERNAL advances, not the caller's copy of the address.

Related: [[gp-banked-region-relocation]], [[kernal-preserves-ram-bank]], [[pcode-runs-from-a-bank-proven]].
