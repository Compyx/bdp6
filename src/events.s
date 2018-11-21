; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - event handling


; Event flags. OR the key code with any of these flags to trigger the behaviour
; described for each of them.

; @brief        Update status bar
EV_UPDATE_STATUS = 1 << 8

; @brief        Do a full zoom update
EV_UPDATE_FULL_ZOOM = 1 << 9

; @brief        Do a full view update
EV_UPDATE_FULL_VIEW = 1 << 10

; @brief        Update marks data in the lower border sprites
EV_UPDATE_MARKS = 1 << 11



; Table of keys, flags and event handlers for the main event loop
;
; Each entry contains a word with bits 0-7 containing the PETSCII key code and
; bits 8-15 for "after-event" flags, and a word containing the event handler
; for the key.
;
keys
        ; UP
        .word $91 | EV_UPDATE_STATUS, cursor_up
        ; DOWN
        .word $11 | EV_UPDATE_STATUS, cursor_down
        ; LEFT
        .word $9d | EV_UPDATE_STATUS, cursor_left
        ; RIGHT
        .word $1d | EV_UPDATE_STATUS, cursor_right

        ; RETURN - show buffer
        .word $0d, zoom.show_buffer     ; doesn't return, but jumps back to
                                        ; main.main_init() on exit

        ; full char movement of zoom area:

        ; '@' / '[' - move cursor eight pixels up
        .word $40 | EV_UPDATE_STATUS, cursor_up_char
        ; ':' / ';' - move cursor four pixels left
        .word $3a | EV_UPDATE_STATUS, cursor_left_char
        ; '/' / '/' - move cursor eight pixels down
        .word $2f | EV_UPDATE_STATUS, cursor_down_char
        ; ';' / ''' - move cursor four pixels right
        .word $3b | EV_UPDATE_STATUS, cursor_right_char

        ; F3 - switch zoom mode
        .word $86, zoom.switch_mode

        ; F5 - switch buffer
        .word $87 | EV_UPDATE_STATUS, events.switch_buffer

        ; F7 - enter disk menu
        .word $88, events.run_diskmenu

        ; G - change grid color
        .word $c7 | EV_UPDATE_STATUS, events.change_grid_color

        ; F1 - show help dialog
        .word $85, show_help

        ; F2 - test dialog
;        .word $89, test_color_clash
;        .word $89, test_buffer_init
        .word $89, show_operations

        ; Delete - clear current char (no confirmation)
        .word $14 | EV_UPDATE_STATUS, edit.clear_char

        ; A - set mark A
        .word $c1 | EV_UPDATE_MARKS, set_markA
        ; B - set mark B
        .word $c2 | EV_UPDATE_MARKS, set_markB

        ; C - clear marked area
        .word $c3 | EV_UPDATE_FULL_ZOOM | EV_UPDATE_FULL_VIEW, edit.clear_area

        ; V - paste marked area into current position
        .word $d6 | EV_UPDATE_FULL_ZOOM | EV_UPDATE_FULL_VIEW, edit.paste_area


keys_end


;------------------------------------------------------------------------------
; Cursor movement routines
;------------------------------------------------------------------------------

; {{{ void      cursor_up()
; Move the cursor in the zoom area one pixel up
;
; @clobbers     all
;
cursor_up
        lda data.cursor_ypos
        beq +
        dec data.cursor_ypos
        rts

+       lda data.zoom_ypos
        beq +
        jsr zoom.move_up
        lda #7
        sta data.cursor_ypos

crsr_up_view_update
        lda data.zoom_mode
        beq +
        jsr zoom.move_view_up
+       rts
; }}}

; {{{ void      cursor_up_char()
; Move the cursor in the zoom area eight pixels up
;
; @clobbers     all
;
cursor_up_char
        lda data.cursor_ypos
        sec
        sbc #8
        sta data.cursor_ypos
        bcc +
-       rts
+       lda #0
        sta data.cursor_ypos
        lda data.zoom_ypos
        beq -
        jsr zoom.move_up
        jmp crsr_up_view_update
; }}}

; {{{ void      cursor_down()
; Move the cursor in the zoom area one pixel down
;
; @clobbers     all
cursor_down .proc
        lda data.zoom_mode
        beq _mode_full
        ; view+zoom
        lda data.cursor_ypos
        cmp #31
        beq +
        inc data.cursor_ypos
        rts
+       lda data.zoom_ypos
        cmp #21
        bcs +
        jsr zoom.move_down
        lda #24
        sta data.cursor_ypos
        jsr zoom.move_view_down
+       rts

_mode_full
        lda data.cursor_ypos
        cmp #47
        beq +
        inc data.cursor_ypos
        rts
+       lda data.zoom_ypos
        cmp #19
        bcs +
        jsr zoom.move_down
        lda #40
        sta data.cursor_ypos
+       rts
.pend
; }}}

; {{{ void      cursor_down_char()
; Move the cursor in the zoom area eight pixels down
;
; @clobbers     all
;
cursor_down_char .proc

        lda data.zoom_mode
        beq _mode_full

        ; view+zoom mode
        lda data.cursor_ypos
        clc
        adc #8
        sta data.cursor_ypos
        cmp #32         ; overflow
        bcs +
        sta data.cursor_ypos
        rts
+
        lda #31
        sta data.cursor_ypos

        lda data.zoom_ypos
        cmp #21
        bcs +
        jsr zoom.move_down
        jsr zoom.move_view_down
+       rts

_mode_full
        lda data.cursor_ypos
        clc
        adc #8
        sta data.cursor_ypos
        cmp #48
        bcs +
        sta data.cursor_ypos
        rts
+
        lda #47
        sta data.cursor_ypos
        lda data.zoom_ypos
        cmp #19
        bcs +
        jsr zoom.move_down
+       rts
.pend
; }}}

; {{{ void      cursor_left()
; Move the cursor in the zoom area one pixel left
;
; @clobbers     all
;
cursor_left .proc
        lda data.cursor_xpos
        beq +
        dec data.cursor_xpos
        rts
+       lda data.zoom_xpos
        beq +
        jsr zoom.move_left
        lda #3
        sta data.cursor_xpos
+       rts
.pend
; }}}

; {{{ void      cursor_left_char()
; Move the cursor in the zoom area four pixels left
;
; @clobbers     all
;
cursor_left_char .proc
        lda data.cursor_xpos
        sec
        sbc #4
        sta data.cursor_xpos
        bcc +
-       rts
+       lda #0
        sta data.cursor_xpos
        lda data.zoom_xpos
        beq -
        jmp zoom.move_left
.pend
; }}}

; {{{ void      cursor_right()
; move the cursor in the zoom area one pixel right
;
; @clobbers     all
cursor_right .proc
        lda data.cursor_xpos
        cmp #39
        bcs +
        inc data.cursor_xpos
        rts
+       lda data.zoom_xpos
        cmp #30
        bcs +
        jsr zoom.move_right
        lda #36
        sta data.cursor_xpos
+       rts
.pend
; }}}

; {{{ void      cursor_right_char()
; move the cursor in the zoom area four pixels right
;
; @clobbers     all
;
cursor_right_char .proc
        lda data.cursor_xpos
        clc
        adc #4
        sta data.cursor_xpos
        cmp #40
        bcs +
-       rts
+       lda #39
        sta data.cursor_xpos
        lda data.zoom_xpos
        cmp #30
        bcs -
        jmp zoom.move_right
.pend
; }}}




; {{{ void      switch_buffer()
; Switch working buffer
;
; @clobbers     all
;
switch_buffer .proc
        lda data.buffer_index
        ; and #1
        eor #1
        sta data.buffer_index

        lda data.zoom_mode
        beq +
        ; view+zoom mode
        jsr zoom.render_view
+       jmp zoom.zoom_full
.pend
; }}}


; {{{ void      change_grid_color()
; Change the zoom grid color (of a selection of four colors: 0, 6, 9, 11)
;
; @clobbers     A,C,X
;
change_grid_color .proc
        lda data.grid_color_index
        clc
        adc #1
        and #3
        sta data.grid_color_index
        tax
        lda data.grid_colors,x
        sta data.grid_color
        ldx #39
-       lda data.status_color,x
        and #$f0
        ora data.grid_color
        sta data.status_color,x
        dex
        bpl -
        rts
.pend
; }}}


; {{{ void      main_loop()
;
; Main event loop for BDP6: runs during editing
;
;
main_loop .proc
        jsr K_GETIN
        cmp #0
        beq main_loop

        ; make the cursor move a bit faster
        ldx #2
        stx $028b

        cmp #$20        ; Space: plot
        bne +
        jsr edit.plot
        jmp events.main_loop
+
        ; store key code for later use
        sta data.key_code

        ; check 'a'-'p': colors
        cmp #$41
        bcc _check_keys
        cmp #$51
        bcs _check_keys
        sec
        sbc #$41
        sta data.cursor_color
        ; update color in status line (much faster than updating the entire
        ; status line)
        asl a
        asl a
        asl a
        asl a
        ora data.grid_color
        ldx data.zoom_mode
        bne +
        sta WORKSPACE_VIDRAM + 38
        sta WORKSPACE_VIDRAM + 39
        jmp main_loop
+       sta WORKSPACE_VIDRAM + (8 * 40) + 38
        sta WORKSPACE_VIDRAM + (8 * 40) + 39
        jmp main_loop

        ; check key code against table
_check_keys
        ldx #0
-       cmp keys,x
        beq +
        inx
        inx
        inx
        inx
        cpx #keys_end - keys
        bne -
        beq main_loop
+
        ldy keys + 1,x
        sty data.key_flags

        ldy keys + 2,x
        sty _exec + 1
        ldy keys + 3,x
        sty _exec + 2

_exec   jsr $fce2
        ; TODO: handle after-event flags

        lda data.key_flags
        and #(EV_UPDATE_STATUS >> 8)
        beq +
        jsr status.render_status
+
        lda data.key_flags
        and #(EV_UPDATE_MARKS >> 8)
        beq +
        jsr status.update_marks
+
        lda data.key_flags
        and #(EV_UPDATE_FULL_ZOOM >> 8)
        beq +
        jsr zoom.zoom_full
+
        lda data.key_flags
        and #(EV_UPDATE_FULL_VIEW >> 8)
        beq +
        lda data.zoom_mode
        beq +
        jsr zoom.render_view
+

        jmp main_loop

.pend
; }}}


test_color_clash .proc
        lda #2
        ldx #4
        ldy #12
        jsr dialogs.show_dialog
        rts
.pend



; @brief        Show dialog to initialize current buffer
;
;
test_buffer_init .proc
        lda #3
        ldx #4
        ldy #12
        jsr dialogs.show_dialog

        cmp #$80
        bcc +
        rts
+
        jsr edit.init_buffer

        rts
.pend



; @brief        Show help screen
;
; Temporarily sets zoom mode to full to allow for a full screen dialog
;
show_help
        lda data.zoom_mode
        sta _old_mode + 1
        lda #ZOOM_MODE_FULL
        sta data.zoom_mode
        lda #1
        ldx #0
        ldy #0
        jsr dialogs.show_dialog
_old_mode
        lda #0
        sta data.zoom_mode
        beq +
        jsr zoom.render_view
+       jsr status.render_status
        rts


dm_load_callback .proc
        sta data.fname_len
        stx data.fname_ptr
        sty data.fname_ptr + 1
        lda #$f
        sta $d020
        jsr diskmenu.get_file_type
        jsr formats.load_file
        lda #5
        sta $d020
        rts
.pend

dm_save_callback .proc
        sta data.fname_len
        stx data.fname_ptr
        sty data.fname_ptr + 1
        lda #$04
        sta $d020
        jsr diskmenu.get_file_type
        jsr formats.save_file
        lda #5
        sta $d020
        rts
.pend

dm_exit_callback .proc
        jmp main_init
.pend


save_file_callback .proc
        jmp $fce2
.pend


run_diskmenu .proc
        ldx #<data.dm_formats
        ldy #>data.dm_formats
        lda #((data.dm_formats_end - data.dm_formats) / 11)
        jsr diskmenu.set_file_types
        ldx #<data.dm_callbacks
        ldy #>data.dm_callbacks
        jsr diskmenu.set_callbacks
        jmp diskmenu.exec
.pend


show_operations .proc
        lda #4
        ldx #4
        ldy #10
        jsr dialogs.show_dialog
        rts
.pend


; @brief        Set mark A
;
; @clobbers     all
;
set_markA .proc
        jsr base.get_cursor_pos_pixels
        stx data.markA_xpos
        sty data.markA_ypos
        lda data.buffer_index
        sta data.markA_buffer
        rts
.pend


; @brief        Set mark B
;
; @clobbers     all
;
set_markB .proc
        jsr base.get_cursor_pos_pixels
        stx data.markB_xpos
        sty data.markB_ypos
        lda data.buffer_index
        sta data.markB_buffer
        rts
.pend

