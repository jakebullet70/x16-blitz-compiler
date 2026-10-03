    ; ---- MSBENCH: the baseline driver of the TURBO GPC spike ----
    ; msedit_bench.py pastes this text into a scratch copy of MSEDIT's edit.p8, inside the main
    ; block, and calls bench_run() ahead of the key loop. It drives the editor through
    ; editor_key(), so each key is MSEDIT's whole path. Times are jiffies.
    ;
    ; The results go to MSBENCH.RES as 18 words, low byte first, in the order bench_note() is
    ; called. msedit_bench.py names them.
    ;
    ; Do not drive save and find through their keys. Those paths end in notify(), which waits
    ; a second.
    uword[18] @nosplit bench_result
    ubyte bench_slot

    sub bench_note(uword value) {
        bench_result[bench_slot] = value
        bench_slot++
    }

    sub bench_keys(ubyte k, uword count) {
        uword started = cbm.RDTIM16()
        repeat count
            editor_key(k)
        bench_note(cbm.RDTIM16() - started)
    }

    sub bench_run() {
        uword started
        g_mod = 0
        bench_slot = 0

        ; load, with the first paint
        started = cbm.RDTIM16()
        void edoc.load_file("fix2000.txt")
        hl_on = @HL@
        hl_mode = HL_BASIC
        ln_on = true
        cur_len = edoc.load(0, &editbuf)
        cur_dirty = false
        full_redraw()
        bench_note(cbm.RDTIM16() - started)
        bench_note(edoc.line_count)

        bench_keys(17, 27)              ; cursor down inside the pane
        bench_keys(17, 300)             ; cursor down, each one scrolls a line
        bench_note(cur_row)
        bench_keys(2, 60)               ; page down
        bench_note(cur_row)
        bench_keys(130, 60)             ; page up
        bench_note(cur_row)

        ed_doc_jump(false)
        repeat 100
            editor_key(17)
        ; type 40 characters at column 0 of each of lines 101 to 105
        uword typing = 0
        ubyte typed_line
        for typed_line in 1 to 5 {
            started = cbm.RDTIM16()
            repeat 40
                editor_key('x')
            typing += cbm.RDTIM16() - started
            if typed_line < 5 {
                editor_key(17)
                editor_key(19)          ; Home
            }
        }
        bench_note(typing)
        bench_note(cur_len)
        editor_key(4)                   ; End
        bench_keys(13, 50)              ; RETURN
        bench_note(edoc.line_count)
        repeat 49
            editor_key(145)
        bench_keys(5, 50)               ; delete line, the 50 lines RETURN made
        bench_note(edoc.line_count)

        started = cbm.RDTIM16()
        commit_editbuf()
        void edoc.save_file("@:msbench.out")
        bench_note(cbm.RDTIM16() - started)

        ed_doc_jump(false)
        void strings.copy("zzneedle", find_term)
        found_row = 65535
        started = cbm.RDTIM16()
        commit_editbuf()
        if find_wrap(cur_row, cur_col + 1) != 0
            goto_found()
        bench_note(cbm.RDTIM16() - started)
        bench_note(found_row)

        if diskio.f_open_w("@:msbench.res") {
            void diskio.f_write(&bench_result, 36)
            diskio.f_close_w()
        }
    }
