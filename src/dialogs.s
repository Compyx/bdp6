; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - dialog handling
;

; Dialog record structure:
;
;       .byte width             (excluding frame: 1-38)
;       .byte height            (excluding frame: 1-14)
;       .byte default_colors    (bits 0-3: foreground, bits 4-7: background)
;       .byte dialog_type       (see constants)
;       .byte title_colors      (bits 0-3: foreground, bits 4-7: background,
;                                use $00 to disable title)
;       .text title_text, $00   (screen codes, terminated with $00) [optional]
;       .text dialog_text, $00  (screen codes and control codes, terminated
;                                with $00)
;
; Dialog text control codes:    $b0-$bf = background color
;                               $f0-$ff = foreground color
;                               $80     = newline
;                               $00     = end-of-text



        ; Constants for special characters in the font for drawing dialogs

        F_CORNER_TL     = $60   ; corner, top-left
        F_CORNER_TR     = $61   ; corner, top-right
        F_CORNER_BL     = $62   ; corner, bottom-left
        F_CORNER_BR     = $63   ; corner, bottom-right
        F_EDGE_H        = $64   ; horizontal edge
        F_EDGE_V        = $65   ; vertical edge
        F_TITLE_LEFT    = $66   ; title decorator, left
        F_TITLE_RIGHT   = $67   ; title decorator, right
        F_SCROLL_UP     = $68   ; scroll up indicator
        F_SCROLL_DOWN   = $69   ; scroll down indicator

        F_CBM           = $77   ; CBM-key glyph, first char (2 total)
        F_CTRL          = $79   ; CTRL-key glyph, first char (2 total)
        F_SHIFT         = $7b   ; SHIFT-key glyph, first char (2 total)
        F_KEY           = $7d   ; small key glyph, indicates locked items
        F_RETURN        = $5b   ; RETURN-key glyph, first char (3 total)
        F_STOP          = $5e   ; STOP-key glyph, first char (2 total)
        F_DEL           = $6a   ; DEL-key glyph, first char (2 total)
        F_INS           = $6c   ; INS-key glyph, first char (2 total)
        F_HOME          = $6e   ; HOME-key glyph, first char (2 total)

        ; Dialog type constants
        DLG_TYPE_RENDER_ONLY    = 0     ; Render dialog and exit immediately
        DLG_TYPE_INFO           = 1     ; Render dialog, any key exists
        DLG_TYPE_COLOR_CLASH    = 2     ; Render color clash dialog
        DLG_TYPE_COLOR_SELECT   = 3     ;
        DLG_TYPE_BITPAIRS       = 4     ; Bitpair manipulation dialog
        DLG_TYPE_SUBMENU        = 5     ; submenu-style dialog



        F_BIT_ZERO_LEFT = $70   ; inverted 0, left side
        F_BIT_ZERO_RIGHT = $71  ; inverted 0, right side
        F_BIT_ONE_LEFT  = $72   ; inverted 1, left side
        F_BIT_ONE_RIGHT = $73   ; inverted 1, right sode



set_params .proc
        sta data.dlg_param_a
        stx data.dlg_param_x
        sty data.dlg_param_y
        rts
.pend


; Calculate dialog videoram colors
;
; @return A     colors
;
get_dialog_color .proc
        lda data.dlg_fg_color
        asl a
        asl a
        asl a
        asl a
        ora data.dlg_bg_color
        rts
.pend



; @brief        Initialize dialogs module
;
; @param X      LSB of dialog pointers table
; @param Y      MSB of dialog pointers table
;
init .proc
        stx data.dlg_table
        sty data.dlg_table + 1
        lda #$06
        sta data.dlg_bg_color
        lda #$0e
        sta data.dlg_fg_color
        lda #0
        sta data.dlg_xpos
        sta data.dlg_ypos
        sta data.dlg_width
        sta data.dlg_height
        rts
.pend


; @brief        Handle key events
;
; @param A      number of entries in table
; @param X      table LSB
; @param Y      table MSB
;
handle_events



; @brief        Render dialog frame and clear frame contents
;
; @clobbers     all
; @zeropage     ZP2 - ZP+16
;
render_frame .proc

        bitmap = ZP + 2
        bitmap_tmp = ZP + 4
        vidram = ZP + 6
        edge_h = ZP + 8
        edge_v = ZP + 10

        char = ZP + 12
        xpos = ZP + 14
        ypos = ZP + 15
        color = ZP + 16

        ldx data.dlg_xpos
        ldy data.dlg_ypos
        jsr base.get_workspace_bitmap_ptr
        sta bitmap
        stx bitmap + 1
        sta bitmap_tmp
        stx bitmap_tmp + 1

        ldx data.dlg_xpos
        ldy data.dlg_ypos
        jsr base.get_workspace_vidram_ptr
        sta vidram
        stx vidram + 1

        jsr get_dialog_color
        sta color

        ; top-left corner
        lda #F_CORNER_TL
        jsr base.get_font_ptr
        stx char
        sty char + 1
        ldy #7
-       lda (char),y
        sta (bitmap_tmp),y
        dey
        bpl -
        iny
        lda color
        sta (vidram),y

        ; render horizontal edge
        #word_add_val bitmap_tmp, 8
        lda #F_EDGE_H
        jsr base.get_font_ptr
        stx edge_h
        sty edge_h + 1

        lda #0
        sta xpos
-
        ldy #7
-       lda (edge_h),y
        sta (bitmap_tmp),y
        dey
        bpl -
        ldy xpos
        iny
        lda color
        sta (vidram),y

        #word_add_val bitmap_tmp, 8

        inc xpos
        lda xpos
        cmp data.dlg_width
        bne --

        ; render top-right corner
        lda #F_CORNER_TR
        jsr base.get_font_ptr
        stx char
        sty char + 1
        ldy #7
-       lda (char),y
        sta (bitmap_tmp),y
        dey
        bpl -
        ldy xpos
        iny
        lda color
        sta (vidram),y

        ; render vertical edges and clear frame contents
        #word_add_val bitmap, 320
        #word_add_val vidram, 40

        ; get vertical edge char ptr
        lda #F_EDGE_V
        jsr base.get_font_ptr
        stx edge_v
        sty edge_v + 1

        lda #0
        sta ypos
_vert_more
        lda bitmap
        sta bitmap_tmp
        lda bitmap + 1
        sta bitmap_tmp + 1

        lda #0
        sta xpos

        ; left edge
        ldy #7
        lda (edge_v),y
-       sta (bitmap_tmp),y
        dey
        bpl -
        iny
        lda color
        sta (vidram),y

        #word_add_val bitmap_tmp, 8
_clear_more
        ldy #7
        lda #0
-       sta (bitmap_tmp),y
        dey
        bpl -

        #word_add_val bitmap_tmp, 8

        inc xpos
        ldy xpos
        lda color
        sta (vidram),y

        cpy data.dlg_width
        bne _clear_more
        iny
        sta (vidram),y
        ; right edge
        ldy #7
-       lda (edge_v),y
        sta (bitmap_tmp),y
        dey
        bpl -

        #word_add_val bitmap, 320
        #word_add_val vidram, 40

        inc ypos
        lda ypos
        cmp data.dlg_height
        bne _vert_more

        ; bottom right corner
        lda #F_CORNER_BL
        jsr base.get_font_ptr
        stx char
        sty char + 1

        ldx #0
        stx xpos

        ldy #7
-       lda (char),y
        sta (bitmap),y  ; no need to copy `bitmap` to `bitmap_tmp`, last line
        dey
        bpl -
        iny
        lda color
        sta (vidram),y

        #word_add_val bitmap, 8
-
        ; render bottom edge
        ldy #7
-       lda (edge_h),y
        sta (bitmap),y
        dey
        bpl -

        inc xpos
        ldy xpos
        lda color
        sta (vidram),y

        #word_add_val bitmap, 8

        cpy data.dlg_width
        bne --
        iny
        lda color
        sta (vidram),y

        ; render bottom right corner
        lda #F_CORNER_BR
        jsr base.get_font_ptr
        stx char
        sty char + 1
        ldy #7
-       lda (char),y
        sta (bitmap),y
        dey
        bpl -

        rts
.pend


; @brief        Render dialog title
;
; @param A      vidram colors (background in bits 0-3, foreground in bits 4-7)
; @param X      LSB of title text
; @param Y      MSB of title text
;
; @return A     length of title (excluding terminating 0)
;
; @clobbers     all
; @zeropage     ZP+2 - ZP+11
; @note         terminate title with $00
;
render_title .proc

        bitmap = ZP + 2
        vidram = ZP + 4
        char = ZP + 6
        text = ZP + 8
        xpos = ZP + 10
        color = ZP + 11

        sta color
        stx text
        sty text + 1

        ldx data.dlg_xpos
        ldy data.dlg_ypos
        jsr base.get_workspace_bitmap_ptr
        clc
        adc #8
        sta bitmap
        txa
        adc #0
        sta bitmap + 1

        ldx data.dlg_xpos
        ldy data.dlg_ypos
        jsr base.get_workspace_vidram_ptr
        clc
        adc #1
        sta vidram
        bcc +
        inx
+       stx vidram + 1


        lda #F_TITLE_LEFT
        jsr base.get_font_ptr
        stx char
        sty char + 1
        ldy #7
-       lda (char),y
        sta (bitmap),y
        dey
        bpl -
        ; don't set vidram, already done in render_frame()

        #word_add_val bitmap, 8

        ldy #0
        sty xpos
-
        ldy xpos
        lda (text),y
        beq _rt_end     ; done rendering text

        jsr base.get_font_ptr
        stx char
        sty char + 1
        ldy #7
-       lda (char),y
        sta (bitmap),y
        dey
        bpl -

        ldy xpos
        iny
        lda color
        sta (vidram),y

        #word_add_val bitmap, 8
        inc xpos
        bne --
_rt_end
        lda #F_TITLE_RIGHT
        jsr base.get_font_ptr
        stx char
        sty char + 1
        ldy #7
-       lda (char),y
        sta (bitmap),y
        dey
        bpl -
        lda xpos        ; return length of title, minus terminating 0
        rts
.pend


; @brief        Render a character in the active dialog
;
; @param A      screen code
; @param X      column
; @param Y      row
render_char .proc

        bitmap = ZP_TMP
        vidram = ZP_TMP + 2
        font = ZP_TMP + 4
        char = ZP_TMP + 5
        xtmp = ZP_TMP + 6
        ytmp = ZP_TMP + 7

.cerror ytmp >= ZP, format("temp ZP $%02x overlaps ZP at $%02x", ytmp, ZP)

        sta char

        cmp #$f0
        bcc +
        and #$0f
        sta data.dlg_fg_color
        lda char
        rts
+
        cmp #$b0
        bcc +
        and #$0f
        sta data.dlg_bg_color
        lda char
        rts
+

        txa             ; add xpos + 1
        sec
        adc data.dlg_xpos
        tax
        stx xtmp
        tya             ; add ypos + 1
        sec
        adc data.dlg_ypos
        tay
        sty ytmp

        jsr base.get_workspace_bitmap_ptr
        sta bitmap
        stx bitmap + 1

        ldx xtmp
        ldy ytmp
        jsr base.get_workspace_vidram_ptr
        sta vidram
        stx vidram + 1

        ldy #0
        jsr get_dialog_color
        sta (vidram),y

        lda char
        jsr base.get_font_ptr
        stx font
        sty font + 1

        ldy #7
-       lda (font),y
        sta (bitmap),y
        dey
        bpl -

        lda char
        rts
.pend



render_text_set_position .proc
        row = ZP + 4
        column = ZP + 5

        stx column
        sty row
        rts
.pend


; @brief        Render dialog text
;
; Renders dialog text and return the index of the last row in A, and a pointer
; to the data after the terminating 0 in X,Y.
;
; @param X      text LSB
; @param Y      text MSB
;
; @return A     last row of text
; @return X     end-of-text + 1 (LSB)
; @return Y     end-of-text + 1 (MSB)
;
; @clobbers     all
; @zeropage     ZP+2 - ZP+5
render_text .proc

        text = ZP + 2
        row = ZP + 4
        column = ZP + 5

        ;stx $03fe
        ;sty $03ff

        stx text
        sty text + 1
;        lda #0
;        sta row
;        sta column

_more
        ldy #0
        lda (text),y
        bne _check_fg_color

        ;lda text
        ;sta $03fc
        ;lda text + 1
        ;sta $03fd

        lda row
        ldy text + 1
        ldx text
        inx
        bne +
        iny
+       rts

_check_fg_color
        cmp #$f0
        bcc _check_bg_color
        and #$0f
        sta data.dlg_fg_color
        jmp _next
_check_bg_color
        cmp #$b0
        bcc +
        and #$0f
        sta data.dlg_bg_color
        jmp _next
+       cmp #$80
        bcc +
        ; Handle CR etc
        cmp #$80
        bne +
        lda #0
        sta column
        inc row
        jmp _next

+
        ldx column
        ldy row
        jsr render_char
        inc column

_next
        inc text
        bne +
        inc text + 1
+       jmp _more

        rts
.pend


; @brief        Render a down arrow in the right vertical edge
;
; @param A      enabled (0 = render edge, !0 = render arrow)
;
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+4
render_down_arrow .proc

        bitmap = ZP_TMP
        font = ZP_TMP + 2
        enabled = ZP_TMP + 4

        sta enabled

        lda data.dlg_xpos
        sec
        adc data.dlg_width
        tax
        lda data.dlg_ypos
        clc
        adc data.dlg_height
        tay

        jsr base.get_workspace_bitmap_ptr
        sta bitmap
        stx bitmap + 1

        lda enabled
        beq +
        lda #F_SCROLL_DOWN
        bne ++
+       lda #F_EDGE_V
+
        jsr base.get_font_ptr
        stx font
        sty font + 1
        ldy #7
-       lda (font),y
        sta (bitmap),y
        dey
        bpl -
        rts
.pend


; @brief        Render an up arrow in the right vertical edge
;
; @param A      enabled (0 = render edge, !0 = render arrow)
;
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+4
render_up_arrow .proc

        bitmap = ZP_TMP
        font = ZP_TMP + 2
        enabled = ZP_TMP + 4

        sta enabled

        lda data.dlg_xpos
        sec
        adc data.dlg_width
        tax
        ldy data.dlg_ypos
        iny

        jsr base.get_workspace_bitmap_ptr
        sta bitmap
        stx bitmap + 1

        lda enabled
        beq +
        lda #F_SCROLL_UP
        bne ++
+       lda #F_EDGE_V
+
        jsr base.get_font_ptr
        stx font
        sty font + 1
        ldy #7
-       lda (font),y
        sta (bitmap),y
        dey
        bpl -
        rts
.pend

; @brief        Show dialog
;
; @param A      dialog ID
; @param X      dialog X position
; @param Y      dialog Y position
;
show_dialog .proc

        tmp = ZP_TMP
        dlg = ZP

        inc data.dialogs_active ; set dialogs active state

        stx data.dlg_xpos
        sty data.dlg_ypos

        ; get pointer to dialog data
        asl a
        tay
        lda data.dlg_table
        sta tmp
        lda data.dlg_table + 1
        sta tmp + 1
        lda (tmp),y
        sta dlg
        iny
        lda (tmp),y
        sta dlg + 1

        ; get width, height, default colors & type
        ldy #0
        lda (dlg),y
        sta data.dlg_width
        iny
        lda (dlg),y
        sta data.dlg_height
        iny
        lda (dlg),y
        pha
        and #$0f
        sta data.dlg_bg_color
        pla
        lsr a
        lsr a
        lsr a
        lsr a
        sta data.dlg_fg_color
        iny
        lda (dlg),y
        sta data.dlg_type

        ; render frame
        jsr render_frame

        ; title
        ldy #4
        lda (dlg),y
        beq _skip_title
        pha     ; colors

        ; pointer to title text
        ldy dlg + 1
        lda dlg
        clc
        adc #5
        tax
        bcc +
        iny
+       pla
        jsr render_title

        ; add meta data length + length of title to dlg data pointer
        clc
        adc #6
        adc dlg
        sta dlg
        bcc +
        inc dlg + 1
+       jmp _handle_text

_skip_title
        #word_add_val dlg, 5

_handle_text

        ldx #0
        ldy #0
        jsr render_text_set_position

        ldx dlg
        ldy dlg + 1
        jsr render_text

        sta _atmp + 1
        stx _xtmp + 1
        sty _ytmp + 1

        ; temporary: render down arrow
;        lda #1
;        jsr render_down_arrow
;        lda #1
;        jsr render_up_arrow

        lda data.dlg_type
        asl a
        tax
        lda data.dialog_handlers,x
        sta ZP_TMP
        lda data.dialog_handlers + 1,x
        sta ZP_TMP + 1

_atmp   lda #0
_xtmp   ldx #0
_ytmp   ldy #0
        jmp (ZP_TMP)
-
        jsr K_GETIN
        cmp #0
        beq -
        jmp end_dialogs
.pend


end_dialogs .proc
        sta _atmp + 1
        stx _xtmp + 1
        sty _ytmp + 1
        lda #0
        sta data.dialogs_active
        jsr zoom.init_grid
        jsr zoom.zoom_full
_atmp   lda #0
_xtmp   ldx #0
_ytmp   ldy #0
        rts
.pend


;------------------------------------------------------------------------------
; Event handlers for different types of dialogs
;------------------------------------------------------------------------------


; @brief        Handler for DLG_TYPE_RENDER_ONLY
;
; Dummy handler: immediately returns and doesn't clear the `dialogs_active`
; flag. Allows for rendering multiple (non-interactive) dialogs, for example to
; display some help text for another dialog.
;
; @zeropage     none
; @return       none
;
dh_render_only .proc
        rts
.pend


; @brief        Handler for DLG_TYPE_INFO
;
; Waits for any key press.
;
; @return       none
;
dh_info .proc
-       jsr K_GETIN
        cmp #0
        beq -
        jmp end_dialogs
.pend


; @brief        Handler for DLG_TYPE_COLOR_SELECT
;
; Select color with CRSR left/right + Return or STOP to Cancel, Can also select
; color with 'a'-'p'
;
; @return A     color (0-15, or $ff if canceled)
;
; @clobbers     all
; @zeropage     ZP - ZP+3
;
dh_color_select .proc

        row = ZP
        column = ZP + 1
        clmtmp = ZP + 2
        clrtmp = ZP + 3

        clc
        adc #2
        sta row

        ; center colors
        lda data.dlg_width
        sec
        sbc #16
        lsr a
        sta column
        sta clmtmp

        ; render colors
        lda #0
        sta clrtmp
-
        sta data.dlg_fg_color

        lda #$74
        ldy row
        ldx clmtmp
        jsr render_char

        inc clmtmp
        inc clrtmp
        lda clrtmp
        cmp #16
        bne -

        ; cursor/color index
        lda #0
        sta clrtmp

_more
        ; render 'cursor'
        ldy row
        iny
        lda clrtmp
        clc
        adc column
        tax
        lda #$1e
        jsr render_char

-       jsr K_GETIN
        cmp #0
        beq -

        pha
        ldy row
        iny
        lda clrtmp
        clc
        adc column
        tax
        lda #$20
        jsr render_char
        pla

        ; STOP - Cancel
        cmp #3
        bne +
        lda #$ff        ; $ff = cancel code
        jmp _finish
+
        ; keys 'a'-'p': select color and exit
        cmp #$41
        bcc +
        cmp #$51
        bcs +
        sec
        sbc #$40
        jmp _finish
+
        ; cursor left
        cmp #$9d
        bne +
        lda clrtmp
        sec
        sbc #1
        and #$0f
        sta clrtmp
        jmp _more
+
        ; cursor right
        cmp #$1d
        bne +
        lda clrtmp
        clc
        adc #1
        and #$0f
        sta clrtmp
        jmp _more
+
        ; Return - exit
        cmp #$0d
        bne _more
        lda clrtmp

_finish
        jmp end_dialogs
.pend


; {{{ Dialog to handle color clashes

dhcc_render_cursor .proc
        row = ZP
        index = ZP + 1

        sta index

        lda #$20
        ldx #$00
        ldy row
        jsr render_char
        lda #$20
        ldx #$05
        ldy row
        jsr render_char
        lda #$20
        ldx #$0a
        ldy row
        jsr render_char

        ldy index
        ldx dhcc_offsets,y
        ldy row
        lda #$7f        ; arrow right
        jsr render_char
        rts
.pend


dhcc_text
        .enc "screen"
dhcc_01
        .byte $f6, $20, F_BIT_ZERO_LEFT, F_BIT_ONE_RIGHT, $ff, F_KEY, $20
dhcc_02
        .byte $fe, $20, F_BIT_ONE_LEFT, F_BIT_ZERO_RIGHT, $ff, F_KEY, $20
dhcc_03
        .byte $f1, $20, F_BIT_ONE_LEFT, F_BIT_ONE_RIGHT, $ff, F_KEY
        .enc "none"
dhcc_text_end

dhcc_offsets
        .byte 0, 5, 10

; @brief        Color clash handler
;
; @param A      last row using in dialog
; @param X      vidram value
; @param Y      colram+locks value
;
dh_color_clash .proc

        row = ZP
        vidram = ZP + 1
        colram = ZP + 2
        colindex = ZP + 3
        column = ZP + 4
        coltmp = ZP + 5

        clc
        adc #2
        sta row

        ; store colors in text
        lda data.dlg_param_x
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        ora #$f0
        sta dhcc_01
        pla
        ora #$f0
        sta dhcc_02
        lda data.dlg_param_y
        and #$0f
        ora #$f0
        sta dhcc_03


        ldx #0
        stx column
        stx coltmp
        stx colindex
-
        ldx column
        lda dhcc_text,x
        ldx coltmp
        ldy row
        jsr render_char
        bmi +
        inc coltmp
+
        inc column
        ldx column
        cpx #dhcc_text_end - dhcc_text
        bne -

dhcc_event
        lda colindex
        jsr dhcc_render_cursor

-       jsr K_GETIN
        cmp #0
        beq -

        ; handle Amica paint A-P
        cmp #$41
        bcc _check_left
        cmp #$51
        bcs _check_left
        sec
        sbc #$41
        ldx #1
-       cmp edit.current_colors,x       ; TODO: fix this
        bne +
        txa
        bne _done
+
        inx
        cpx #4
        bne -
        jmp dhcc_event

_check_left
        cmp #$9d
        bne _check_right
        ; left
        lda colindex
        sec
        sbc #1
        bcs +
        lda #2
+       sta colindex
        jmp dhcc_event
_check_right
        cmp #$1d
        bne _check_return
        lda colindex
        clc
        adc #1
        cmp #3
        bcc +
        lda #0
+
        sta colindex
        jmp dhcc_event
_check_return
        cmp #$0d
        bne _check_cancel

        lda colindex
        clc
        adc #1
        jmp _done

_check_cancel
        cmp #$03
        bne dhcc_event

        lda #$ff
_done
        jmp end_dialogs
.pend

; }}}


; {{{ Bitpair manipulation/selection dialog

; Text used to display the bitpair manipulation 'controls' and help text
dhbp_text
        .enc "screen"

        .text $f1, F_BIT_ZERO_LEFT, F_BIT_ZERO_RIGHT, F_KEY, "  "
        .text $f7, F_CBM, F_CBM + 1, $ff, "+", $f1, "1", $ff, "-", $f1, "4"
        .text $ff, "  toggle lock"
        .text $80

        .text $f1, F_BIT_ZERO_LEFT, F_BIT_ONE_RIGHT, F_KEY, "  "
        .text $f7, F_SHIFT, F_SHIFT + 1, $ff, "+", $f1, "1", $ff, "-", $f1, "4"
        .text $ff, "  incr. color"
        .text $80

        .text $f1, F_BIT_ONE_LEFT, F_BIT_ZERO_RIGHT, F_KEY, "  "
        .text $f7, F_CTRL, F_CTRL + 1, $ff, "+", $f1, "1", $ff, "-", $f1, "4"
        .text $ff, "  decr. color"
        .text $80

        .text $f1, F_BIT_ONE_LEFT, F_BIT_ONE_RIGHT, F_KEY, "  "
        .text $f7, F_RETURN, F_RETURN + 1, F_RETURN + 2, $ff, "/"
        .text $f7, F_STOP, F_STOP + 1
        .text $ff, "  OK / Cancel"
        .text $80, 0

        .enc "none"

; colors for each bitpair
dhbp_colors     .byte 0, 6, 14, 3

; lock bits (bit 4 = 00 (BG), bit 5 = 01, bit 6 = 10, bit 7 = 11)
dhbp_locks      .byte 0
dhbp_row        .byte 0

dhbp_lock_bits  .byte %00010000, %00100000, %01000000, %10000000

; @brief        Update bitpair handler display
dhbp_update .proc

        vidram = ZP + 16

        lda data.dlg_xpos
        clc
        adc #1
        tax
        lda data.dlg_ypos
        sec
        adc dhbp_row
        tay
        jsr base.get_workspace_vidram_ptr
        sta vidram
        stx vidram + 1

        ldx #0
-
        lda dhbp_colors,x
        asl a
        asl a
        asl a
        asl a
        ora data.dlg_bg_color
        ldy #0
        sta (vidram),y
        iny
        sta (vidram),y
        ; display/hide key
        lda dhbp_locks
        and dhbp_lock_bits,x
        bne +
        lda data.dlg_bg_color
        asl a
        asl a
        asl a
        asl a
        ora data.dlg_bg_color
        jmp _key_color
+
        lda data.dlg_bg_color
        ora #$10
_key_color
        iny
        sta (vidram),y


        #word_add_val vidram, 40
        inx
        cpx #4
        bne -
        rts
.pend


; @brief        Dialog handler for bitpair manipulation
;
; @param A      last row during rendering of dialog text
;
;
; @return A     background color nybble + bit 7 => clear=accept set=cancel
; @return X     vidram nybbles
; @return Y     coloram nybble and locks
;
dh_bitpairs .proc

        ; carefull: render_text uses ZP+2 - ZP+5

        row = ZP

        clc
        adc #2
        sta row
        sta dhbp_row

        tay
        ldx #0
        jsr render_text_set_position

        ldx #<dhbp_text
        ldy #>dhbp_text
        jsr render_text

        ; store 'coder-colors'
        lda #0
        sta dhbp_colors + 0
        lda #6
        sta dhbp_colors + 1
        lda #14
        sta dhbp_colors + 2
        lda #3
        sta dhbp_colors + 3

_more
        jsr dhbp_update
-       jsr K_GETIN
        cmp #0
        beq -

        cmp #$03
        bne _check_shift
        lda #$80                ; Cancel
        jmp end_dialogs

_check_shift
        ; check SHIFT + 1-4
        cmp #$21
        bcc _check_ctrl
        cmp #$25
        bcs _check_ctrl

        sec
        sbc #$21
        tax
        lda #1
_update_colors
        clc
        adc dhbp_colors,x
        and #$0f
        sta dhbp_colors,x
        jmp _more
_check_ctrl
        ; check CTRL + 1-4
        ldx #0          ; color index
        cmp #$90        ; CTRL+1
        bne +
        lda #$ff
        bne _update_colors
+       inx
        cmp #$05
        bne +
        lda #$ff
        bne _update_colors
+       inx
        cmp #$1c
        bne +
        lda #$ff
        bne _update_colors
+       inx
        cmp #$9f
        bne _check_cbm
        lda #$ff
        jmp _update_colors
_check_cbm
        ; check CBM + 1-4
        cmp #$81
        bne +
        lda #$94        ; hack: pretend CBM+1 is $94
_toggle_locks
        sec
        sbc #$94
        tax
        lda dhbp_locks
        eor dhbp_lock_bits,x
        sta dhbp_locks
        jmp _more
+       cmp #$95
        bcc _check_return
        cmp #$98
        bcs _check_return
        bcc _toggle_locks
_check_return
        cmp #$0d
        bne _more

        ; generate return values

        ; X = vidram nybbles
        lda dhbp_colors + 1
        asl a
        asl a
        asl a
        asl a
        ora dhbp_colors + 2
        tax
        ; Y = colorram nybble and locks
        lda dhbp_locks
        ora dhbp_colors + 3
        tay

        ; background + bit 7 clear
        lda dhbp_colors + 0
        and #$0f

        jmp end_dialogs
.pend

; }}}
