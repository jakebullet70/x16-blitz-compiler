---
name: library-never-hard-codes-a-bank
description: A GPC-BASIC library module never picks a bank number itself, and banks are shared so no space is wasted
metadata:
  type: feedback
---

A library module never hard-codes a bank number. The program owns the bank map and hands each
module where its data goes. Banks are shared between users, so a module that needs 1 KB does not
take a whole 8 KB bank.

**Why:** 2026-10-03, the user, on putting the GUI into TURBO GPC: "refactor any hard coded banks in
our GUI. Thats just wrong. (share banks too, no wasted space)". `MENU.TEXTBANK` was fixed at 62,
which sits inside TURBO's arena C.

**How to apply:** when a module stores data in a bank, its interface takes the place from the
caller, not a `#DEFINE`d number. A whole-bank grab from `BANKMGR.GET.FREE.BANK` for a small store is
the same waste. Bank 0 for the KERNAL's own tables (`MENUKEY`'s keymap) is the hardware's choice,
not the library's. See [[turbo-gpc-ide-plan]] and [[claim-every-compile-time-bank]].
