; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - editing module
;

        ; Print plotting debug info in the lower border sprites
        DEBUG_PLOT = false
        ; Print 'fixed' coordinates debug info the lower border sprites
        DEBUG_COORDS = false

        ; Color clash handling enumerators
        CC_MODE_DENY    = 0     ; refuse to plot pixel (DONE)
        CC_MODE_PIXEL   = 1     ; replace color of pixel under cursor (DONE)
        CC_MODE_LEAST   = 2     ; replace least used color (DONE)
        CC_MODE_DIALOG  = 3     ; pop up dialog (DONE)


        ; no need to implement again
        hex_digits = diskmenu.diskutil.hex_digits


current_colors  .fill 4, 0      ; colors for the current char under cursor
locks           .byte 0         ; bitpair locks for the current char
color_index     .byte 0         ; when plotting, hold the index in the colors
                                ; of the current plotted color (if present in
                                ; the colors), or $ff on color clash
clash_mode      .byte CC_MODE_DIALOG      ; color-clash handling mode

current_bitmap  .fill 8, 0      ; copy of bitmap under cursor for fast access
bitpair_count   .fill 4, 0      ; counts of pixels used per bitpair/color index


tmp_bitmap_ptr  .word 0
tmp_vidram_ptr  .word 0
tmp_colram_ptr  .word 0

coords .block

        ; fixed-up coordinates in pixels

        width_px .byte 0
        height_px .byte 0

        xlo_px  .byte 0
        xhi_px  .byte 0
        ylo_px  .byte 0
        yhi_px  .byte 0


        ; fixed-up coordinates in chars

        width_ch .byte 0
        height_ch .byte 0

        xlo_ch  .byte 0
        xhi_ch  .byte 0
        ylo_ch  .byte 0
        yhi_ch  .byte 0
.bend


; @brief        Generate proper box coordinates from marks
;
;
;
get_coords_box .proc
        ; aliases
        ab = data.markA_buffer
        ax = data.markA_xpos
        ay = data.markA_ypos
        bb = data.markB_buffer
        bx = data.markB_xpos
        by = data.markB_ypos


        ; fixup X coordinates
        lda ax
        ldx bx
        cmp bx
        bcc +

        ldx ax
        lda bx
+
        sta coords.xlo_px
        stx coords.xhi_px
        lsr a
        lsr a
        sta coords.xlo_ch
        txa
        lsr a
        lsr a
        sta coords.xhi_ch

        ; determine width
        lda coords.xhi_px
        sec
        sbc coords.xlo_px
        adc #0  ; add 1
        sta coords.width_px
        lda coords.xhi_ch
        sec
        sbc coords.xlo_ch
        adc #0
        sta coords.width_ch

        ; fixup Y coordinates
        lda ay
        ldx by
        cmp by
        bcc +

        lda by
        ldx ay
+
        sta coords.ylo_px
        stx coords.yhi_px
        lsr a
        lsr a
        lsr a
        sta coords.ylo_ch
        txa
        lsr a
        lsr a
        lsr a
        sta coords.yhi_ch

        ; determine height
        lda coords.yhi_px
        sec
        sbc coords.ylo_px
        adc #0
        sta coords.height_px
        lda coords.yhi_ch
        sec
        sbc coords.ylo_ch
        adc #0
        sta coords.height_ch
        rts
.pend


debug_show_coords
        rts


get_tmp_pointers .proc
        jsr base.get_cursor_bitmap_ptr
        sta tmp_bitmap_ptr
        stx tmp_bitmap_ptr + 1
        jsr base.get_cursor_vidram_ptr
        sta tmp_vidram_ptr
        stx tmp_vidram_ptr + 1
        jsr base.get_cursor_colram_ptr
        sta tmp_colram_ptr
        stx tmp_colram_ptr + 1
        rts
.pend


; @brief        Get colors of the char under the cursor
;
; Colors are stored in the 4-byte `current_colors` table
;
;
; @clobbers     all
; @return       none
get_current_colors .proc
        jsr base.get_current_bgcolor
        sta current_colors + 0
        jsr base.get_cursor_vidram_byte
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        sta current_colors + 1
        pla
        and #$0f
        sta current_colors + 2
        jsr base.get_cursor_colram_byte
        pha
        and #$0f
        sta current_colors + 3
        pla
        lsr a
        lsr a
        lsr a
        lsr a
        sta locks
        rts
.pend


; @brief        Attempt to find value in A among the current colors
;
; @param A      color (0-f)
;
; @return X     index (0-3, or $ff if not found)
;
get_color_index .proc
        ldx #0
-       lda data.cursor_color
        cmp current_colors,x
        beq _ok
        inx
        cpx #4
        bne -
        ldx #$ff        ; color not found
_ok     stx color_index
        rts
.pend


; @brief        Count occurences of each bitpair under cursor
;
; Result is stored in `bitpair_count`
;
; @return       none
;
; @clobbers     all
; @zeropage     ZP - ZP+2
;
;
get_bitpair_count .proc

        bitmap = ZP_TMP
        value = ZP_TMP + 2

        ; read bitmap under cursor into temp data
        jsr base.get_cursor_bitmap_ptr
        sta bitmap
        stx bitmap + 1
        ldy #7
-       lda (bitmap),y
        sta current_bitmap,y
        dey
        bpl -

        ; clear bitpair used table
        ldy #3
        lda #0
-       sta bitpair_count,y
        dey
        bpl -

        ldy #7
-
        lda current_bitmap,y
        sta value

        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        inc bitpair_count,x
        lda value
        lsr a
        lsr a
        lsr a
        lsr a
        and #3
        tax
        inc bitpair_count,x
        lda value
        lsr a
        lsr a
        and #3
        tax
        inc bitpair_count,x
        lda value
        and #3
        tax
        inc bitpair_count,x

        dey
        bpl -
        rts
.pend


; @brief        Get bitpair index of pixel under cursor
;
; @return X     index
;
; @clobbers     all
;
get_current_pixel_color_index .proc
        lda data.cursor_ypos
        and #7
        tay
        lda data.cursor_xpos
        and #3
        tax
        lda current_bitmap,y
        and data.bits_mask,x
-       cpx #3
        beq +
        lsr a
        lsr a
        inx
        bpl -
+
        tax
        rts
.pend


; @brief        Determine the bitpair least used
;
; @return X     bitpair index (1-3)
;
; @clobbers     A,C
;
get_least_used_color_index
        lowest = ZP_TMP
        index = ZP_TMP + 1

        lda #$ff
        sta lowest
        ldx #1  ; skip background color
-       lda bitpair_count,x
        cmp lowest
        bcs +
        stx index
        sta lowest
+       inx
        cpx #4
        bne -
        ; return index found
        ldx index
        rts


; @brief        Plot a pixel, using existing colors
;
; @param A      bitpair index (0-3)
plot_pixel .proc

        bitmap = ZP_TMP
        colorindex = ZP_TMP + 2
        column = ZP_TMP + 3
        row = ZP_TMP + 4

        sta colorindex

        jsr base.get_cursor_bitmap_ptr
        sta bitmap
        stx bitmap + 1

        lda colorindex
        asl a
        asl a
        sta colorindex

        lda data.cursor_xpos
        and #3
        tax
        clc
        adc colorindex
        sta colorindex
        lda data.cursor_ypos
        and #7
        tay

        lda (bitmap),y
        and data.bits_mask_inv,x
        ldx colorindex
        ora data.bits_00,x
        sta (bitmap),y

        ; update zoom and view

        jmp zoom.update_current_char
.pend


; @brief        Replace color
;
; @param A      color
; @param X      bitpair index
;
; @clobbers     A,C,Y
; @safe         X
;
replace_color .proc
        vidram = ZP_TMP
        colram = ZP_TMP + 2
        color = ZP_TMP + 4

        cpx #0
        bne +
        rts
+
        sta color

        txa
        pha
        ldx #3
-       lda tmp_vidram_ptr,x
        sta ZP_TMP,x
        dex
        bpl -
        pla
        tax

        ldy #0

        cpx #1  ; 01
        bne +

        lda color
        asl a
        asl a
        asl a
        asl a
        sta color
        lda (vidram),y
        and #$0f
        ora color
        sta (vidram),y
        rts
+
        cpx #2
        bne +
        lda (vidram),y
        and #$f0
        ora color
        sta (vidram),y
        rts
+
        lda (colram),y
        and #$f0
        ora color
        sta (colram),y
        rts
.pend



; @brief        Attempt to plot a pixel
;
; TODO: cleanup code, pretty messy right now
;
plot .proc

        inc $d020
        ; get pointer for reuse in other functions
        jsr get_tmp_pointers

        jsr get_current_colors
        jsr get_color_index
        jsr get_bitpair_count
.if DEBUG_PLOT
        ; output some debugging information in the lower border sprites
        jsr plot_debug
.endif
        lda color_index
        bmi +
        jmp _ok
+
        ; color clash, what to do?

        ; is there an unused bitpair?
        ldx #1
-       lda bitpair_count,x
        beq _update
        inx
        cpx #4
        bne -
        beq _clash
_update
        stx color_index
        lda data.cursor_color
        jsr replace_color
        lda color_index
        jmp _ok

_clash
        ; determine clash mode
        lda clash_mode
        beq _done       ; CC_MODE_DENY
        cmp #CC_MODE_PIXEL
        bne _check_least

        ; replace color of current pixel under cursor
        jsr get_current_pixel_color_index
        beq _done       ; 00 = background, can't change that

        ; tax
        stx color_index
        lda data.cursor_color
        jsr replace_color
        lda color_index
        jmp _ok

_check_least
        ; replace least used color/bitpair
        cmp #CC_MODE_LEAST
        bne _do_dialog
        jsr get_least_used_color_index
        ; tax
        stx color_index
        lda data.cursor_color
        jsr replace_color
        lda color_index
        jmp _ok

_do_dialog
        ; CC_MODE_DIALOG

        ; vidram in X
        lda current_colors + 1
        asl a
        asl a
        asl a
        asl a
        ora current_colors + 2
        tax
        lda locks
        asl a
        asl a
        asl a
        asl a
        ora current_colors + 3
        tay
        jsr dialogs.set_params

        lda #2
        ldx #4
        ldy #12
        jsr dialogs.show_dialog
        cmp #$ff
        beq _done
        sta color_index
        tax
        lda data.cursor_color
        jsr replace_color
        lda color_index

_ok
        ; OK: plot pixel
        jsr plot_pixel
_done
        dec $d020
        rts
.pend


plot_debug .proc
        lda current_colors + 0
        jsr hex_digits
        stx data.lborder_text + 0
        lda current_colors + 1
        jsr hex_digits
        stx data.lborder_text + 1
        lda current_colors + 2
        jsr hex_digits
        stx data.lborder_text + 2
        lda current_colors + 3
        jsr hex_digits
        stx data.lborder_text + 3
        lda #$20
        sta data.lborder_text + 4

        lda color_index
        bmi +
        lda #$4f        ; OK
        sta data.lborder_text + 5
        lda #$4b
        sta data.lborder_text + 6
        bne ++
+
        lda #$43        ; CL (clash)
        sta data.lborder_text + 5
        lda #$4c
        sta data.lborder_text + 6
+
        lda #$20
        sta data.lborder_text + 7

        ; bitpair count
        lda bitpair_count + 0
        jsr hex_digits
        sta data.lborder_text + 24
        stx data.lborder_text + 25
        lda #$20
        sta data.lborder_text + 26

        lda bitpair_count + 1
        jsr hex_digits
        sta data.lborder_text + 27
        stx data.lborder_text + 28
        lda #$20
        sta data.lborder_text + 29

        lda bitpair_count + 2
        jsr hex_digits
        sta data.lborder_text + 30
        stx data.lborder_text + 31
        lda #$20
        sta data.lborder_text + 32

        lda bitpair_count + 3
        jsr hex_digits
        sta data.lborder_text + 33
        stx data.lborder_text + 34
        lda #$20
        sta data.lborder_text + 35

        jmp status.render_lborder_sprites
.pend


; @brief        Clear current char selected
;
; @zeropage     ZP_TMP - ZP_TMP+1
; @clobbers     all
;
clear_char .proc
        tmp = ZP_TMP

        ; clear bitmap
        jsr base.get_cursor_bitmap_ptr
        sta tmp
        stx tmp + 1
        ldy #7
        lda #0
-       sta (tmp),y
        dey
        bpl -

        ; clear vidram (TODO: check locks)
        jsr base.get_cursor_vidram_ptr
        sta tmp
        stx tmp + 1
        ldy #0
        tya
        sta (tmp),y

        ; clear colram (TODO: check locks)
        jsr base.get_cursor_colram_ptr
        sta tmp
        stx tmp + 1
        ldy #0
        lda (tmp),y
        and #$f0
        sta (tmp),y

        jsr base.get_cursor_pos
        jmp zoom.update_current_char
.pend


; @brief        Clear all bit locks of the current buffer
;
; @returns      none
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+1
;
clear_buffer_locks .proc
        colram = ZP_TMP

        jsr base.get_buffer_bitmap_start
        sta colram
        stx colram + 1

        ldx #2
        ldy #0
-       lda (colram),y
        and #$0f
        sta (colram),y
        iny
        bne -
        inc colram + 1
        dex
        bpl -
-       lda (colram),y
        and #$0f
        sta (colram),y
        iny
        cpy #$e8
        bne -
        rts
.pend


; @brief        Initialize (clear) current buffer
init_buffer .proc
        tmp = ZP
        bgcolor = ZP + 2
        vidram = ZP + 3
        colram = ZP + 4

        sta bgcolor
        stx vidram
        sty colram

        ; clear bitmap
        jsr base.get_current_buffer_bitmap_start
        sta tmp
        stx tmp + 1

        ldx #$1e
        ldy #0
        tya
-       sta (tmp),y
        iny
        bne -
        inc tmp + 1
        dex
        bpl -
-       sta (tmp),y
        iny
        cpy #$40
        bne -

        ; init videoram
        jsr base.get_current_buffer_vidram_start
        pha
        txa     ; MSB to Y
        tay
        pla
        tax     ; MSB to X
        lda vidram      ; value
        jsr base.store_1000_bytes

        ; init colorram
        jsr base.get_current_buffer_colram_start
        pha
        txa     ; MSB to Y
        tay
        pla
        tax     ; MSB to X
        lda colram      ; value
        jsr base.store_1000_bytes

        ; background color
        lda bgcolor
        ldx data.buffer_index
        bne +
        sta BUFFER1_BGCOLOR
        jmp ++
+       sta BUFFER2_BGCOLOR
+
        ; update zoom
        jsr zoom.zoom_full
        jsr zoom.render_view

        rts
.pend


; @brief        Fix marks so that A is alway top-left and B bottom-right
;
; @clobbers     all
;
; @fixme        doesn't always work correctly, need different approach on
;               determening coordinates
;
fix_marks .proc
        ab = data.markA_buffer
        ax = data.markA_xpos
        ay = data.markA_ypos
        bb = data.markB_buffer
        bx = data.markB_xpos
        by = data.markB_ypos

        lda bx
        cmp ax
        bcs +

        lda bx
        ldx ax
        sta ax
        stx bx

+       lda by
        cmp ay
        bcs +

        lda by
        ldy ay
        sta ay
        sty by

+       rts
.pend



; @brief        Clear currently marked area (chars)
;
; @zeropage     ZP - ZP+9
; @clobbers     all
;
; @todo         also clear vidram/colram, depending on bitpair locks
;
clear_area .proc

        xlo = coords.xlo_ch
        xhi = coords.xhi_ch
        ylo = coords.ylo_ch
        yhi = coords.yhi_ch

        bitmap = ZP
        bmptmp = ZP + 2
        vidram = ZP + 4
        colram = ZP + 6
        columns = ZP + 8
        rows = ZP + 9

        jsr get_coords_box

        ldx xlo
        ldy ylo
        jsr base.get_current_buffer_bitmap_ptr
        sta bitmap
        stx bitmap + 1
        #dbg_sta $0400
        #dbg_stx $0401

        ldx coords.width_ch
        ldy coords.height_ch
        stx columns
        sty rows
        #dbg_stx $0402
        #dbg_sty $0403

more_bitmap
        lda bitmap
        sta bmptmp
        lda bitmap + 1
        sta bmptmp + 1

        ldx columns
-
        ldy #7
        lda #0
-       sta (bmptmp),y
        dey
        bpl -

        #word_add_val bmptmp, 8

        dex
        bne --

        #word_add_val bitmap, $140
        dec rows
        bne more_bitmap

        rts
.pend




; @todo:        move source/target calculation/setting into separate function
; @fixme:       complete bullshit, thhe whole src/dst doesn't work for all four
;               copy methods
paste_area .proc
        xlo = coords.xlo_ch
        xhi = coords.xhi_ch
        ylo = coords.ylo_ch
        yhi = coords.yhi_ch

        bmpsrc = ZP
        bmpdst = ZP + 2

        vidsrc = ZP + 4
        viddst = ZP + 6

        colsrc = ZP + 8
        coldst = ZP + 10

        tmpsrc = ZP + 12
        tmpdst = ZP + 14

        columns = ZP + 16
        rows    = ZP + 17

        ; calculate/fix coordinates to form a proper top-left -> bottom-right
        ; box
        jsr get_coords_box
        ; check for 0 width/height
        lda coords.width_ch
        bne +
        rts
+
        lda coords.height_ch
        bne +
        rts
+
        ; get bitmap pointer of area to copy
        lda data.markA_buffer
        ldx xlo
        ldy ylo
        jsr base.get_buffer_bitmap_ptr
        sta bmpsrc
        stx bmpsrc + 1
        #dbg_sta $0400
        #dbg_stx $0401

        ; get videoram pointer to area to copy
        lda data.markA_buffer
        ldx xlo
        ldy ylo
        jsr base.get_buffer_vidram_ptr
        sta vidsrc
        stx vidsrc + 1
        #dbg_sta $0402
        #dbg_stx $0403

        ; get colorram pointer to area to copy
        lda data.markA_buffer
        ldx xlo
        ldy ylo
        jsr base.get_buffer_colram_ptr
        sta colsrc
        stx colsrc + 1
        #dbg_sta $0404
        #dbg_stx $0405

        ; determine size of area to copy
        ldx coords.width_ch
        ldy coords.height_ch
        stx columns
        sty rows
        #dbg_stx $0406
        #dbg_sty $0407

        ; get dest bitmap pointer
        jsr base.get_cursor_bitmap_ptr
        sta bmpdst
        stx bmpdst + 1
        #dbg_sta $0408
        #dbg_stx $0409

        ; get videoram pointer to area to paste to
        jsr base.get_cursor_vidram_ptr
        sta viddst
        stx viddst + 1
        #dbg_sta $040a
        #dbg_stx $040b

        ; get colorram pointer to area to paste to
        jsr base.get_cursor_colram_ptr
        sta coldst
        stx coldst + 1
        #dbg_sta $040c
        #dbg_stx $040d


        ; XXX: four ways to copy properly

        ; determine which code to call, depending on the location of the source
        ; and destination

        jsr base.get_cursor_pos     ; X, Y = cursor position in chars
        cpx xlo
        bcc go_left

        ; we go right here
        cpy ylo
        bcs +
        jmp right_and_up
+       jmp right_and_down

go_left
        cpy ylo
        bcs +
        jmp left_and_up
+       jmp left_and_down


;-----------------
; move LEFT and UP
;-----------------
left_and_up


lu_next_row
        ; copy bitmap
        ldx #0

        lda bmpsrc
        sta tmpsrc
        lda bmpsrc + 1
        sta tmpsrc + 1
        lda bmpdst
        sta tmpdst
        lda bmpdst + 1
        sta tmpdst + 1
lu_next_col
        ldy #7
-       lda (tmpsrc),y
        sta (tmpdst),y
        dey
        bpl -

        txa
        tay
        lda (vidsrc),y
        sta (viddst),y
        lda (colsrc),y
        sta (coldst),y

        #word_add_val tmpsrc, 8
        #word_add_val tmpdst, 8

        inx
        cpx columns
        bne lu_next_col

        #word_add_val bmpsrc, $140
        #word_add_val bmpdst, $140
        #word_add_val vidsrc, 40
        #word_add_val viddst, 40
        #word_add_val colsrc, 40
        #word_add_val coldst, 40

        dec rows
        beq lu_done
        jmp lu_next_row
lu_done
        rts

;----------------------------
; Move/copy area RIGHT and UP
;----------------------------
right_and_up

ru_next_row
        ldx columns
        dex

        lda bmpsrc
        clc
        adc data.bitmap_row_lsb,x
        sta tmpsrc
        lda bmpsrc + 1
        adc data.bitmap_row_msb,x
        sta tmpsrc + 1

        lda bmpdst
        clc
        adc data.bitmap_row_lsb,x
        sta tmpdst
        lda bmpdst + 1
        adc data.bitmap_row_msb,x
        sta tmpdst + 1

ru_next_col
        ;copy bitmap
        ldy #7
-       lda (tmpsrc),y
        sta (tmpdst),y
        dey
        bpl -

        txa
        tay
        lda (vidsrc),y
        sta (viddst),y
        lda (colsrc),y
        sta (coldst),y

        #word_add_val tmpsrc, 8
        #word_add_val tmpdst, 8

        dex
        bpl ru_next_col

        #word_add_val bmpsrc, $140
        #word_add_val bmpdst, $140
        #word_add_val vidsrc, 40
        #word_add_val viddst, 40
        #word_add_val colsrc, 40
        #word_add_val coldst, 40

        dec rows
        beq ru_done
        jmp ru_next_row
ru_done
        rts

;------------------------------
; copy/move area RIGHT and DOWN
;------------------------------
right_and_down

        ; get pointers to the last rows of the target and source
        ldy rows
        dey
        ; bitmap
        lda bmpsrc
        clc
        adc data.bitmap_row_lsb,y
        sta bmpsrc
        lda bmpsrc + 1
        adc data.bitmap_row_msb,y
        sta bmpsrc + 1
        lda bmpdst
        clc
        adc data.bitmap_row_lsb,y
        sta bmpdst
        lda bmpdst + 1
        adc data.bitmap_row_msb,y
        sta bmpdst + 1

        ; vidram source
        lda vidsrc
        clc
        adc data.screen_row_lsb,y
        sta vidsrc
        lda vidsrc + 1
        adc data.screen_row_msb,y
        sta vidsrc +1
        ; vidram destination
        lda viddst
        clc
        adc data.screen_row_lsb,y
        sta viddst
        lda viddst + 1
        adc data.screen_row_msb,y
        sta viddst + 1

        ; colram source
        lda colsrc
        clc
        adc data.screen_row_lsb,y
        sta colsrc
        lda colsrc + 1
        adc data.screen_row_msb,y
        sta colsrc +1
        ; colram destination
        lda coldst
        clc
        adc data.screen_row_lsb,y
        sta coldst
        lda coldst + 1
        adc data.screen_row_msb,y
        sta coldst + 1


        lda bmpsrc
        ldx bmpsrc + 1
        #dbg_sta $0400
        #dbg_stx $0401
        lda bmpdst
        ldx bmpdst + 1
        #dbg_sta $0402
        #dbg_stx $0403



rd_next_row
        ldx columns
        dex

        lda bmpsrc
        clc
        adc data.bitmap_col_lsb,x
        sta tmpsrc
        lda bmpsrc + 1
        adc data.bitmap_col_msb,x
        sta tmpsrc + 1

        lda bmpdst
        clc
        adc data.bitmap_col_lsb,x
        sta tmpdst
        lda bmpdst + 1
        adc data.bitmap_col_msb,x
        sta tmpdst + 1

rd_next_col
        ;copy bitmap
        ldy #7
-       lda (tmpsrc),y
        sta (tmpdst),y
        dey
        bpl -

        txa
        tay
        lda (vidsrc),y
        sta (viddst),y
        lda (colsrc),y
        sta (coldst),y

        #word_sub_val tmpsrc, 8
        #word_sub_val tmpdst, 8

        dex
        bpl rd_next_col

        #word_sub_val bmpsrc, $140
        #word_sub_val bmpdst, $140
        #word_sub_val vidsrc, 40
        #word_sub_val viddst, 40
        #word_sub_val colsrc, 40
        #word_sub_val coldst, 40

        dec rows
        beq rd_done
        jmp rd_next_row
rd_done
        rts


left_and_down

        ldy rows
        dey
        ; bitmap
        lda bmpsrc
        clc
        adc data.bitmap_row_lsb,y
        sta bmpsrc
        lda bmpsrc + 1
        adc data.bitmap_row_msb,y
        sta bmpsrc + 1
        lda bmpdst
        clc
        adc data.bitmap_row_lsb,y
        sta bmpdst
        lda bmpdst + 1
        adc data.bitmap_row_msb,y
        sta bmpdst + 1

        ; vidram source
        lda vidsrc
        clc
        adc data.screen_row_lsb,y
        sta vidsrc
        lda vidsrc + 1
        adc data.screen_row_msb,y
        sta vidsrc +1
        ; vidram dest
        lda viddst
        clc
        adc data.screen_row_lsb,y
        sta viddst
        lda viddst + 1
        adc data.screen_row_msb,y
        sta viddst + 1

        ; colram source
        lda colsrc
        clc
        adc data.screen_row_lsb,y
        sta colsrc
        lda colsrc + 1
        adc data.screen_row_msb,y
        sta colsrc +1
        ; colram dest
        lda coldst
        clc
        adc data.screen_row_lsb,y
        sta coldst
        lda coldst + 1
        adc data.screen_row_msb,y
        sta coldst + 1


ld_next_row
        ldx columns
        dex

        lda bmpsrc
        clc
        adc data.bitmap_row_lsb,x
        sta tmpsrc
        lda bmpsrc + 1
        adc data.bitmap_row_msb,x
        sta tmpsrc + 1

        lda bmpdst
        clc
        adc data.bitmap_row_lsb,x
        sta tmpdst
        lda bmpdst + 1
        adc data.bitmap_row_msb,x
        sta tmpdst + 1

ld_next_col
        ;copy bitmap
        ldy #7
-       lda (tmpsrc),y
        sta (tmpdst),y
        dey
        bpl -

        txa
        tay
        lda (vidsrc),y
        sta (viddst),y
        lda (colsrc),y
        sta (coldst),y

        #word_add_val tmpsrc, 8
        #word_add_val tmpdst, 8

        dex
        bpl ld_next_col

        #word_sub_val bmpsrc, $140
        #word_sub_val bmpdst, $140
        #word_sub_val vidsrc, 40
        #word_sub_val viddst, 40
        #word_sub_val colsrc, 40
        #word_sub_val coldst, 40

        dec rows
        beq ld_done
        jmp ld_next_row
ld_done
        rts

.pend
