; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - status display functions


; @brief        Clear status display line
;
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+5
clear_status .proc

        bitmap_new = ZP_TMP
        bitmap_old = ZP_TMP + 2
        vidram_new = ZP_TMP + 4

        ; status line is either the first or the nineth line
        lda data.zoom_mode
        bne +

        ; status line
        ldx #<WORKSPACE_BITMAP
        ldy #>WORKSPACE_BITMAP
        stx bitmap_new
        sty bitmap_new + 1
        ; previous zoom line
        ldx #<(WORKSPACE_BITMAP + 8 * $140)
        ldy #>(WORKSPACE_BITMAP + 8 * $140)
        stx bitmap_old
        sty bitmap_old + 1

        ; vidram (new only)
        ldx #<(WORKSPACE_VIDRAM)
        ldy #>(WORKSPACE_VIDRAM)
        stx vidram_new
        sty vidram_new + 1

        jmp _cs_go
+
        ; previous zoom line
        ldx #<WORKSPACE_BITMAP
        ldy #>WORKSPACE_BITMAP
        stx bitmap_old
        sty bitmap_old + 1
        ; previous zoom line
        ldx #<(WORKSPACE_BITMAP + 8 * $140)
        ldy #>(WORKSPACE_BITMAP + 8 * $140)
        stx bitmap_new
        sty bitmap_new + 1
        ; vidram (new only)
        ldx #<(WORKSPACE_VIDRAM + 8 * 40)
        ldy #>(WORKSPACE_VIDRAM + 8 * 40)
        stx vidram_new
        sty vidram_new + 1

_cs_go
        ldx #39
_cs_more
        ldy #7
        lda #$00
-       sta (bitmap_new),y
        dey
        bpl -

        ldy #7
        lda #$ff
-       sta (bitmap_old),y
        dey
        cpy #3
        bne -
        lda #0
-       sta (bitmap_old),y
        dey
        bpl -

        txa
        tay

        lda #$16
        sta (vidram_new),y

        #word_add_byte bitmap_old, 8
        #word_add_byte bitmap_new, 8
        dex
        bpl _cs_more
        rts
.pend


; @brief        Render status line
;
; Calls `update_status` to first update any changes in the status
;
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+7
;
; @return       none
;
render_status .proc

        bitmap = ZP_TMP
        vidram = ZP_TMP + 2
        font = ZP_TMP + 4
        column = ZP_TMP + 6

        jsr update_status

        lda data.zoom_mode
        bne +

        ldx #<WORKSPACE_BITMAP
        ldy #>WORKSPACE_BITMAP
        stx bitmap
        sty bitmap + 1
        ldx #<WORKSPACE_VIDRAM
        ldy #>WORKSPACE_VIDRAM
        stx vidram
        sty vidram + 1
        bne _rs_go      ; always non-zero
+
        ldx #<(WORKSPACE_BITMAP + 8 * $140)
        ldy #>(WORKSPACE_BITMAP + 8 * $140)
        stx bitmap
        sty bitmap + 1
        ldx #<(WORKSPACE_VIDRAM + 8 * 40)
        ldy #>(WORKSPACE_VIDRAM + 8 * 40)
        stx vidram
        sty vidram + 1
_rs_go
        ldy #0
        sty column
-
        lda data.status_color,y
        sta (vidram),y

        lda data.status_text,y
        jsr base.get_font_ptr
        stx font
        sty font + 1
        ldy #7
-       lda (font),y
        sta (bitmap),y
        dey
        bpl -

        #word_add_val bitmap, 8

        inc column
        ldy column
        cpy #40
        bne --
        rts
.pend



; @brief        Update all fields/colors in the status line
;
; @clobbers     all
; @return       none
; @zeropage     none
;
update_status .proc

        lda data.zoom_xpos
        clc
        asl a
        asl a
        adc data.cursor_xpos
        jsr base.byte_to_decimal
        sty data.status_text + 0
        stx data.status_text + 1
        sta data.status_text + 2

        lda data.zoom_ypos
        clc
        asl a
        asl a
        asl a
        adc data.cursor_ypos
        jsr base.byte_to_decimal
        sty data.status_text + 4
        stx data.status_text + 5
        sta data.status_text + 6

        lda data.cursor_xpos
        lsr a
        lsr a
        clc
        adc data.zoom_xpos
        jsr base.byte_to_decimal
        stx data.status_text + 8
        sta data.status_text + 9

        lda data.cursor_ypos
        lsr a
        lsr a
        lsr a
        clc
        adc data.zoom_ypos
        jsr base.byte_to_decimal
        stx data.status_text + 11
        sta data.status_text + 12

        ; show colors under cursor
        jsr base.get_current_bgcolor
        asl a
        asl a
        asl a
        asl a
        ora data.grid_color
        sta data.status_color + 14
        sta data.status_color + 15

        lda data.cursor_xpos
        lsr a
        lsr a
        clc
        adc data.zoom_xpos
        tax
        lda data.cursor_ypos
        lsr a
        lsr a
        lsr a
        clc
        adc data.zoom_ypos
        tay
        stx _xtmp + 1
        sty _ytmp + 1
        jsr base.get_current_buffer_vidram_byte

        pha
        and #$f0
        ora data.grid_color
        sta data.status_color + 18
        sta data.status_color + 19
        pla
        asl a
        asl a
        asl a
        asl a
        ora data.grid_color
        sta data.status_color + 22
        sta data.status_color + 23

_xtmp   ldx #0
_ytmp   ldy #0
        jsr base.get_current_buffer_colram_byte
        asl a
        asl a
        asl a
        asl a
        ora data.grid_color
        sta data.status_color + 26
        sta data.status_color + 27

        ; buffer index
        lda data.buffer_index
        clc
        adc #$31
        sta data.status_text + 34

        ; cursor color
        lda data.cursor_color
        asl a
        asl a
        asl a
        asl a
        ora data.grid_color
        sta data.status_color + 38
        sta data.status_color + 39
        rts
.pend


; @brief        Render a single char in the lower border sprites
;
; @param A      character
; @param X      column
; @param Y      row (pixels)
;
render_lborder_char .proc

        atmp = ZP_TMP
        xtmp = ZP_TMP + 1
        ytmp = ZP_TMP + 2
        tmp = ZP_TMP + 3
        ; XXX:  'char' shadows a function in recent 64tass
        ;       may have to come up with a slightly better label
        char_ = TEMP_SPACE

        sta atmp
        stx xtmp
        sty ytmp

        ; copy char data for easier access
        jsr base.get_font_ptr
        stx tmp
        sty tmp + 1
        ldy #7
-       lda (tmp),y
        sta char_,y
        dey
        bpl -

        ; determine destination in sprites
        ldx xtmp
        lda data.sprite_xpos_lsb,x
        sta tmp
        lda data.sprite_xpos_msb,x
        clc
        adc #>LBORDER_SPRITES
        sta tmp + 1

        ldy ytmp
        ldx #1          ; chars are only 6 pixels high
-       lda char_,x
        sta (tmp),y
        iny
        iny
        iny
        inx
        cpx #7
        bne -
        rts
.pend


clear_lborder_sprites .proc
        ldx #0
        txa
-       sta LBORDER_SPRITES,x
        sta LBORDER_SPRITES + $0100,x
        inx
        bne -
        rts
.pend


render_lborder_sprites .proc
        column = ZP
        row1 = ZP + 1
        row2 = ZP + 2

        ldx #(7 * 3)
        ldy #((7 + 7) * 3)
        lda data.zoom_mode
        bne +
        inx
        inx
        inx
        iny
        iny
        iny
+
        stx row1
        sty row2

        ; first sprite is lower in the border due to the zoom sprite
        ldx #0
        stx column
-
        lda data.lborder_text,x
        ldy #0
        jsr render_lborder_char
        inc column
        ldx column
        cpx #3
        bne -
-
        ldy row1
        lda data.lborder_text,x
        jsr render_lborder_char
        inc column
        ldx column
        cpx #24
        bne -

        ldx #0
        stx column
-
        lda data.lborder_text + 24,x
        ldy #(7 * 3)
        jsr render_lborder_char
        inc column
        ldx column
        cpx #3
        bne -
-
        ldy row2
        lda data.lborder_text + 24,x
        jsr render_lborder_char
        inc column
        ldx column
        cpx #24
        bne -

        rts
.pend


update_marks
        ; mark A, x-pixels
        lda data.markA_xpos
        jsr base.byte_to_decimal
        sty data.lborder_text + 6
        stx data.lborder_text + 7
        sta data.lborder_text + 8
        ; mark A, y-pixels
        lda data.markA_ypos
        jsr base.byte_to_decimal
        sty data.lborder_text + 10
        stx data.lborder_text + 11
        sta data.lborder_text + 12

        ; mark A, x-chars
        lda data.markA_xpos
        lsr a
        lsr a
        jsr base.byte_to_decimal
        stx data.lborder_text + 14
        sta data.lborder_text + 15

        ; mark A, y-chars
        lda data.markA_ypos
        lsr a
        lsr a
        lsr a
        jsr base.byte_to_decimal
        stx data.lborder_text + 17
        sta data.lborder_text + 18

        ; mark A, buffer index
        lda data.markA_buffer
        clc
        adc #$31
        sta data.lborder_text + 23



        ; mark B, x-pixels
        lda data.markB_xpos
        jsr base.byte_to_decimal
        sty data.lborder_text + 6 + 24
        stx data.lborder_text + 7 + 24
        sta data.lborder_text + 8 + 24
        ; mark B, y-pixels
        lda data.markB_ypos
        jsr base.byte_to_decimal
        sty data.lborder_text + 10 + 24
        stx data.lborder_text + 11 + 24
        sta data.lborder_text + 12 + 24

        ; mark B, x-chars
        lda data.markB_xpos
        lsr a
        lsr a
        jsr base.byte_to_decimal
        stx data.lborder_text + 14 + 24
        sta data.lborder_text + 15 + 24

        ; markB, y-chars
        lda data.markB_ypos
        lsr a
        lsr a
        lsr a
        jsr base.byte_to_decimal
        stx data.lborder_text + 17 + 24
        sta data.lborder_text + 18 + 24

        ; mark B, buffer index
        lda data.markB_buffer
        clc
        adc #$31
        sta data.lborder_text + 23 + 24

        jsr render_lborder_sprites
        rts



