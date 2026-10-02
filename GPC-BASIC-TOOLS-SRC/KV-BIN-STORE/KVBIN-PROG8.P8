; ***********************************************************************
;
;   KVBIN-PROG8.P8 -- a KVBIN store read and written from Prog8.
;
;   It works on SETTINGS.KVB, the store that KV-BIN-STORE.PRG and
;   KVBIN-BASIC.PRG work on. The kvbin block is the Prog8 counterpart of
;   KVBIN.INC.BL. Copy it into any program that shares the store.
;
;       L  every key and its value
;       G  a value by key
;       P  write a value by key
;       D  remove a key
;       Q  back to BASIC
;
;   Build:  prog8c -target cx16 KVBIN-PROG8.P8
;
;   WARNING: text is in lower case here. The compiler turns it into the
;   unshifted PETSCII letters that ROM BASIC shows as capitals, and those
;   are the letters the other two programs write.
;
; ***********************************************************************

%import textio
%import diskio
%import strings
%zeropage basicsafe
%option no_sysinit

main {
    const ubyte VALUECOLUMN = 13

    str storename = "settings.kvb"

    ; The screen editor hands back one line, 80 characters at most.
    str typedkey = "?" * 80
    str typedvalue = "?" * 80

    sub start() {
        kvbin.filename = &storename
        txt.print("kvbin store, prog8\n")
        if not kvbin.info() {
            if kvbin.why != kvbin.WHY_NOFILE or not kvbin.create() {
                explain()
                return
            }
            txt.print("new store\n")
        }
        txt.print(storename)
        txt.print(": ")
        txt.print_uw(kvbin.slots)
        txt.print(" slots\n")

        repeat {
            txt.print("\nl list   g get   p put   d delete   q quit\n")
            bool known
            do {
                known = true
                when txt.waitkey() {
                    'l' -> list_keys()
                    'g' -> get_value()
                    'p' -> put_value()
                    'd' -> delete_key()
                    'q' -> return
                    else -> known = false
                }
            } until known
        }
    }

    ; Every slot in order. A free slot comes back with an empty key.
    sub list_keys() {
        uword used = 0
        bool more = kvbin.first()
        while more {
            if kvbin.key[0] != 0 {
                txt.print(kvbin.key)
                txt.column(VALUECOLUMN)
                txt.print("= ")
                txt.print(kvbin.value)
                txt.nl()
                used++
            }
            more = kvbin.next()
        }
        if kvbin.why != kvbin.WHY_NONE {
            explain()
            return
        }
        txt.print_uw(used)
        txt.print(" of ")
        txt.print_uw(kvbin.slots)
        txt.print(" slots used\n")
    }

    sub get_value() {
        if not ask_key()
            return
        if kvbin.get(typedkey) {
            txt.print(kvbin.value)
            txt.nl()
        } else {
            explain()
        }
    }

    sub put_value() {
        if not ask_key()
            return
        txt.print("value: ")
        void txt.input_chars(typedvalue)
        txt.nl()
        if kvbin.put(typedkey, typedvalue) {
            txt.print("saved in slot ")
            txt.print_uw(kvbin.slot)
            txt.nl()
        } else {
            explain()
        }
    }

    sub delete_key() {
        if not ask_key()
            return
        if kvbin.del(typedkey) {
            txt.print("deleted from slot ")
            txt.print_uw(kvbin.slot)
            txt.nl()
        } else {
            explain()
        }
    }

    ; A typed key into typedkey. False for an empty line.
    sub ask_key() -> bool {
        txt.print("key: ")
        ubyte length = txt.input_chars(typedkey)
        txt.nl()
        return length != 0
    }

    ; kvbin.why in words.
    sub explain() {
        when kvbin.why {
            kvbin.WHY_NOFILE -> {
                txt.print("cannot open ")
                txt.print(storename)
                txt.print(": ")
                txt.print(diskio.status())
                txt.nl()
            }
            kvbin.WHY_NOTSTORE -> {
                txt.print(storename)
                txt.print(" is not a kvbin store\n")
            }
            kvbin.WHY_NOKEY -> txt.print("no such key\n")
            kvbin.WHY_FULL -> txt.print("the store is full\n")
        }
    }
}

; ***********************************************************************
;
;   kvbin -- keys and values in one file of fixed records.
;
;       create()            a new store, every slot free
;       info()              how many slots a store has
;       get(key)            a value by key
;       put(key, value)     write a value by key
;       del(key)            remove a key
;       first()             slot 1, then next() for each slot after it
;       stop()              end a first() and next() walk early
;
;   in   filename    the file, with its path if it has one
;
;   out  the result  true done, false not
;        why         why not, a WHY_ number. WHY_NONE when done
;        slot        the slot get, put, del, first and next landed on
;        slots       the store's slot count
;        key         what first and next read. "" is a free slot
;        value       what get, first and next read
;
;   The file is records of 128 bytes. Record 0 is the header:
;       +0..+5   "*KVBIN"
;       +6       the version, 1
;       +7       the key length, 12
;       +8       the record length, 128
;       +9, +10  the slot count, low byte first
;   Record n is slot n:
;       +0..+11  the key, padded with $00. $00 at +0 is a free slot
;       +12..    the value, padded with $00
;   The last byte of a record is always $00.
;
;   A key is cut to 12 characters and a value to 115. Neither holds $00.
;
;   put keeps a key's slot. A new key takes the first free slot. With
;   none free, why is WHY_FULL and nothing is written.
;
;   first and next hand back every slot in order, free ones too, and next
;   is false after the last. The file stays open between the calls. Call
;   nothing else here until next is false or stop has run.
;
;   WARNING: every routine uses the two diskio file channels.
;
; ***********************************************************************
kvbin {
    const ubyte RECLEN = 128
    const ubyte KEYLEN = 12
    const ubyte MAXLEN = 115
    const ubyte VERSION = 1
    const ubyte MAGICLEN = 6
    const uword USUALSLOTS = 40

    const ubyte WHY_NONE = 0
    const ubyte WHY_NOFILE = 1
    const ubyte WHY_NOTSTORE = 2
    const ubyte WHY_NOKEY = 3
    const ubyte WHY_FULL = 4
    const ubyte WHY_BADKEY = 5

    uword filename
    ubyte why
    uword slot
    uword slots
    str key = "?" * KEYLEN
    str value = "?" * MAXLEN

    str magic = "*kvbin"
    ubyte[RECLEN] record
    ubyte[KEYLEN] paddedkey
    uword freeslot

    ; A file of the same name is replaced.
    sub create() -> bool {
        why = WHY_NOFILE
        diskio.delete(filename)
        if not diskio.f_open_w(filename)
            return false
        slots = USUALSLOTS
        sys.memset(&record, RECLEN, 0)
        sys.memcopy(&magic, &record, MAGICLEN)
        record[6] = VERSION
        record[7] = KEYLEN
        record[8] = RECLEN
        record[9] = lsb(slots)
        record[10] = msb(slots)
        bool written = diskio.f_write(&record, RECLEN)
        sys.memset(&record, RECLEN, 0)
        repeat slots {
            if written
                written = diskio.f_write(&record, RECLEN)
        }
        diskio.f_close_w()
        if written
            why = WHY_NONE
        return written
    }

    sub info() -> bool {
        if not open()
            return false
        diskio.f_close()
        return true
    }

    sub get(str wanted) -> bool {
        if not find(wanted)
            return false
        if slot == 0 {
            why = WHY_NOKEY
            return false
        }
        split()
        return true
    }

    sub put(str wanted, str text) -> bool {
        if not find(wanted)
            return false
        if slot == 0
            slot = freeslot
        if slot == 0 {
            why = WHY_FULL
            return false
        }
        ubyte length = strings.length(text)
        if length > MAXLEN
            length = MAXLEN
        sys.memset(&record, RECLEN, 0)
        sys.memcopy(&paddedkey, &record, KEYLEN)
        sys.memcopy(text, &record + KEYLEN, length)
        return write()
    }

    sub del(str wanted) -> bool {
        if not find(wanted)
            return false
        if slot == 0 {
            why = WHY_NOKEY
            return false
        }
        sys.memset(&record, RECLEN, 0)
        return write()
    }

    sub first() -> bool {
        if not open()
            return false
        slot = 0
        return next()
    }

    ; A slot past the end of the file comes back free.
    sub next() -> bool {
        why = WHY_NONE
        if slot >= slots {
            diskio.f_close()
            return false
        }
        slot++
        if diskio.f_read(&record, RECLEN) != RECLEN
            sys.memset(&record, RECLEN, 0)
        split()
        return true
    }

    sub stop() {
        diskio.f_close()
    }

    ; ---- internals ----

    ; The store open for reading, its header checked and the file at slot 1.
    ; False leaves it closed.
    sub open() -> bool {
        why = WHY_NOFILE
        if not diskio.f_open(filename)
            return false
        why = WHY_NOTSTORE
        bool good = diskio.f_read(&record, RECLEN) == RECLEN
        ubyte index
        for index in 0 to MAGICLEN - 1 {
            if record[index] != magic[index]
                good = false
        }
        if record[6] != VERSION or record[7] != KEYLEN or record[8] != RECLEN
            good = false
        if not good {
            diskio.f_close()
            return false
        }
        slots = mkword(record[10], record[9])
        why = WHY_NONE
        return true
    }

    ; The store read for wanted, then closed. slot is the key's slot and
    ; record is that slot's record, or slot is 0. freeslot is the first
    ; free slot, 0 for none. An empty key would match a free slot, so it is
    ; refused before the open.
    sub find(str wanted) -> bool {
        why = WHY_BADKEY
        if wanted[0] == 0
            return false
        if not open()
            return false
        ubyte length = strings.length(wanted)
        if length > KEYLEN
            length = KEYLEN
        sys.memset(&paddedkey, KEYLEN, 0)
        sys.memcopy(wanted, &paddedkey, length)
        slot = 0
        freeslot = 0
        uword each
        for each in 1 to slots {
            if diskio.f_read(&record, RECLEN) != RECLEN
                break
            if record[0] == 0 {
                if freeslot == 0
                    freeslot = each
            } else if key_matches() {
                slot = each
                break
            }
        }
        diskio.f_close()
        return true
    }

    sub key_matches() -> bool {
        ubyte index
        for index in 0 to KEYLEN - 1 {
            if record[index] != paddedkey[index]
                return false
        }
        return true
    }

    ; record over slot slot. The offset is slot times 128, as two words.
    sub write() -> bool {
        why = WHY_NOFILE
        if not diskio.f_open_w_seek(filename)
            return false
        diskio.f_seek_w(mklong2(slot >> 9, slot << 7))
        bool written = diskio.f_write(&record, RECLEN)
        diskio.f_close_w()
        if written
            why = WHY_NONE
        return written
    }

    ; record into key and value. A free slot gives "" for both.
    sub split() {
        record[RECLEN - 1] = 0
        sys.memcopy(&record, &key, KEYLEN)
        key[KEYLEN] = 0
        void strings.copy(&record + KEYLEN, value)
    }
}
