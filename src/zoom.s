; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - zoom functions


; Initialize bitmap and videoram for zoom grid
;
; @return       none
;
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+1
init_grid .proc
        bmp = ZP_TMP

        lda data.zoom_mode
        bne +

        ldx #<WORKSPACE_BITMAP
        ldy #>WORKSPACE_BITMAP
        bne _ig_go
+
        ldx #<(WORKSPACE_BITMAP + 9 * $140)
        ldy #>(WORKSPACE_BITMAP + 9 * $140)
_ig_go
        stx bmp
        sty bmp + 1

_ig_more
        lda #$ff
        ldy #7
-       sta (bmp),y
        dey
        cpy #3
        bne -
        lda #0
-       sta (bmp),y
        dey
        bpl -

        #word_add_val bmp, 8

        lda bmp + 1
        cmp #>WORKSPACE_BITMAP_END
        bne _ig_more
        lda bmp
        cmp #<WORKSPACE_BITMAP_END
        bne _ig_more
        rts
.pend


; Show current buffer
;
; Shows the full buffer, allows switching buffers with Space.
;
; @note Resets PC/IRQ etc so it can't return to the main event loop, instead it
;       jumps to main_init() when the user pressed Return or Stop.
;
show_buffer .proc

        bmp_src = ZP_TMP
        bmp_dst = ZP_TMP + 2
        vid_src = ZP_TMP + 4
        vid_dst = ZP_TMP + 6
        col_src = ZP_TMP + 8
        col_dst = ZP_TMP + 10

.cerror col_dst + 1 >= ZP, format("ZP_TMP $%02x overlaps with ZP $%02x", col_dst + 1, ZP)

        sei
        lda #$31
        ldx #$ea
        sta $0314
        stx $0315
        ldx #$ff
        txs
        cld
        jsr K_RESTOR
        jsr K_IOINIT
        jsr K_SCINIT
        lda #$36
        sta $01
        lda #$02
        sta $dd00
        lda #$3b
        sta $d011
        lda #$18
        sta $d016
        lda #$78
        sta $d018
        cli

        ; copy current buffer to workspace
copy_buffer
        ldx #<WORKSPACE_BITMAP
        ldy #>WORKSPACE_BITMAP
        stx bmp_dst
        sty bmp_dst + 1
        ldx #<WORKSPACE_VIDRAM
        ldy #>WORKSPACE_VIDRAM
        stx vid_dst
        sty vid_dst + 1
        ldx #0
        ldy #$d8
        stx col_dst
        sty col_dst + 1

        ; get buffer pointers
        jsr base.get_current_buffer_bitmap_start
        sta bmp_src
        stx bmp_src + 1
        jsr base.get_current_buffer_vidram_start
        sta vid_src
        stx vid_src + 1
        jsr base.get_current_buffer_colram_start
        sta col_src
        stx col_src + 1

        ; copy bitmap
        ldx #$1e
        ldy #0
-       lda (bmp_src),y
        sta (bmp_dst),y
        iny
        bne -
        inc bmp_src + 1
        inc bmp_dst + 1
        dex
        bpl -
        ldy #$3f
-       lda (bmp_src),y
        sta (bmp_dst),y
        dey
        bpl -

        ; copy videoram and colorram
        ldx #2
        ldy #0
-       lda (vid_src),y
        sta (vid_dst),y
        lda (col_src),y
        sta (col_dst),y
        iny
        bne -
        inc vid_src + 1
        inc vid_dst + 1
        inc col_src + 1
        inc col_dst + 1
        dex
        bpl -
-       lda (vid_src),y
        sta (vid_dst),y
        lda (col_src),y
        sta (col_dst),y
        iny
        cpy #$e8
        bne -

        lda BUFFER1_BGCOLOR
        ldx data.buffer_index
        beq +
        lda BUFFER2_BGCOLOR
+       sta $d020
        sta $d021



_sb_event_loop
-       jsr K_GETIN
        cmp #0
        beq -

        ; SPACE - switch buffer
        cmp #$20
        bne +
        lda data.buffer_index
        eor #1
        sta data.buffer_index
        jmp copy_buffer
+
        ; STOP/RETURN - exit
        cmp #$03
        beq _sb_event_loop_exit
        cmp #$0d
        beq _sb_event_loop_exit
        bne _sb_event_loop
_sb_event_loop_exit
        jmp main_init
.pend


; Zoom a single char of the current buffer
;
; @param A      X/Y coordinates in the zoom area
; @param X      column in the current buffer
; @param Y      row in the current buffer
;
; zero page:    ZP_TMP/ZP_TMP+1, ZP - ZP+5
zoom_char .proc

        bitmap = data.zoom_temp_bmp
        colors = data.zoom_temp_col

        temp = ZP_TMP   ; used for copying bitmap

        xtmp = ZP + 0   ; temp storage for X
        ytmp = ZP + 1   ; temp storage for Y
        bmp_row = ZP + 2 ; bitmap char row index
        ws_row = ZP + 3    ; workspace vidram index
        ws_vidram = ZP + 4      ; workspace vidram pointer

        ;
        ; Setup: get copy of bitmap, get colors, setup pointer to zoom vidram
        ;

        stx xtmp
        sty ytmp

        ; determine char in zoom area
        pha
        and #%00001111
        asl a
        asl a
        adc #1  ; skip first row
        tay
        pla
        lsr a
        lsr a
        and #%00111100
        tax
        jsr base.get_workspace_vidram_ptr
        sta ws_vidram
        stx ws_vidram + 1

        ; determine char in current buffer
        ldx xtmp
        ldy ytmp
        jsr base.get_current_buffer_bitmap_ptr

        ; copy bitmap to temp area for easier access
        sta temp
        stx temp + 1
        ldy #7
-       lda (temp),y
        sta bitmap,y
        dey
        bpl -

        ; get vidram colors
        ldx xtmp
        ldy ytmp
        jsr base.get_current_buffer_vidram_byte
        pha
        and #$0f
        sta colors + 2
        pla
        lsr a
        lsr a
        lsr a
        lsr a
        sta colors + 1

        ; get colram color+flags
        ldx xtmp
        ldy ytmp
        jsr base.get_current_buffer_colram_byte
        sta colors + 3

        ; get background color
        lda BUFFER1_BGCOLOR
        ldx data.buffer_index
        beq +
        lda BUFFER2_BGCOLOR
+       sta colors + 0

        ;
        ; Zoom the char
        ;

        lda #0
        sta bmp_row
        sta ws_row
-
        ldy bmp_row

        lda bitmap + 0,y
;        rol a
;        ror a
;        rol a
;        and #%00000011
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda colors,x
        sta temp
        lda bitmap + 1,y
;        rol a
;        rol a
;        rol a
;        and #%00000011
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda colors,x
        asl a
        asl a
        asl a
        asl a
        ora temp
        ldy ws_row
        sta (ws_vidram),y

        ldy bmp_row
        lda bitmap + 0,y
        lsr a
        lsr a
        lsr a
        lsr a
        and #%00000011
        tax
        lda colors,x
        sta temp
        lda bitmap + 1,y
        lsr a
        lsr a
        lsr a
        lsr a
        and #%00000011
        tax
        lda colors,x
        asl a
        asl a
        asl a
        asl a
        ora temp
        ldy ws_row
        iny
        sta (ws_vidram),y

        ldy bmp_row
        lda bitmap + 0,y
        lsr a
        lsr a
        and #%00000011
        tax
        lda colors,x
        sta temp
        lda bitmap + 1,y
        lsr a
        lsr a
        and #%00000011
        tax
        lda colors,x
        asl a
        asl a
        asl a
        asl a
        ora temp
        ldy ws_row
        iny
        iny
        sta (ws_vidram),y

        ldy bmp_row
        lda bitmap + 0,y
        and #%00000011
        tax
        lda colors,x
        sta temp
        lda bitmap + 1,y
        and #%00000011
        tax
        lda colors,x
        asl a
        asl a
        asl a
        asl a
        ora temp
        ldy ws_row
        iny
        iny
        iny
        sta (ws_vidram),y

        lda bmp_row
        clc
        adc #2
        sta bmp_row
        lda ws_row
        clc
        adc #40
        sta ws_row

        lda bmp_row
        cmp #8
        beq +
        jmp -
+

        rts
.pend


; @brief        Render a full zoom (either 16 rows or 24 rows)
;
; @zero page    ZP+8 - ZP+11
; @clobbers     all
;
zoom_full .proc

        zm_col = ZP + 8         ; zoom area 'column', each column is 4 chars
        zm_row = ZP + 9         ; zoom area 'row' ,each row is 4 screen lines

        buf_col = ZP + 10
        buf_row = ZP + 11


        lda #0
        sta zm_col
        ldx data.zoom_mode      ; zoom mode 0: full screen
                                ;           1: view + zoom
        beq +
        lda #2
+       sta zm_row

        lda data.zoom_xpos
        sta buf_col
        lda data.zoom_ypos
        sta buf_row

_zmf_more
        lda zm_col
        asl a
        asl a
        asl a
        asl a
        ora zm_row
        ldx buf_col
        ldy buf_row
        jsr zoom_char

        inc zm_col
        inc buf_col

        lda zm_col
        cmp #10
        bne _zmf_more

        lda #0
        sta zm_col
        lda data.zoom_xpos
        sta buf_col

        inc zm_row
        inc buf_row

        lda zm_row
        cmp #6
        bne _zmf_more
        rts
.pend


; Move zoom 'window' down over the buffer
move_down .proc

        src = ZP + 8
        dst = ZP + 10

        ws_pos = ZP + 12
        buf_col = ZP + 13

        ldx data.zoom_mode
        lda data.zoom_ypos
        cpx #0
        bne +
        cmp #19
        bcc ++
        rts
+
        cmp #21
        bcc +
        rts
+       inc data.zoom_ypos


        lda data.zoom_mode
        bne +

        lda #<(WORKSPACE_VIDRAM + 5 * 40)
        ldx #>(WORKSPACE_VIDRAM + 5 * 40)
        sta src
        stx src + 1
        lda #<(WORKSPACE_VIDRAM + 1 * 40)
        ldx #>(WORKSPACE_VIDRAM + 1 * 40)
        sta dst
        stx dst + 1

        ldx #4
        bne _zm_down_more
+
        lda #<(WORKSPACE_VIDRAM + 13 * 40)
        ldx #>(WORKSPACE_VIDRAM + 13 * 40)
        sta src
        stx src + 1
        lda #<(WORKSPACE_VIDRAM + 9 * 40)
        ldx #>(WORKSPACE_VIDRAM + 9 * 40)
        sta dst
        stx dst + 1

        ldx #2

_zm_down_more
        ldy #0
-       lda (src),y
        sta (dst),y
        iny
        cpy #160
        bne -

        #word_add_val src, 160
        #word_add_val dst, 160

        dex
        bpl _zm_down_more

        ; now zoom only the last row

        ; adjust for view+zoom or full zoom
        lda #5  ; add five rows to render the sixth row
        ldx data.zoom_mode
        beq +
        lda #3  ; add three rows to render the fourth row
+       sta _yadd + 1

        lda #$05                ; zoom blocks: col = 0, row = 5
        sta ws_pos

        lda data.zoom_xpos
        sta buf_col
-
        ldx buf_col
        lda data.zoom_ypos
        clc
_yadd   adc #5
        tay
        lda ws_pos
        jsr zoom_char

        inc buf_col

        lda ws_pos
        clc
        adc #$10
        sta ws_pos
        cmp #$a5
        bne -

        rts
.pend


; Move zoom 'window' up
move_up .proc

        src = ZP + 8
        dst = ZP + 10
        ws_pos = ZP + 12
        buf_col = ZP + 13
        cols = ZP + 14

        lda data.zoom_ypos
        bne +
        rts
+       dec data.zoom_ypos

        lda #<(WORKSPACE_VIDRAM + 17 * 40)
        ldx #>(WORKSPACE_VIDRAM + 17 * 40)
        sta src
        stx src + 1
        lda #<(WORKSPACE_VIDRAM + 21 * 40)
        ldx #>(WORKSPACE_VIDRAM + 21 * 40)
        sta dst
        stx dst + 1

        ldx #4
        lda data.zoom_mode
        beq +
        ldx #2
+
_zm_up_more
        ldy #0
-       lda (src),y
        sta (dst),y
        iny
        cpy #160
        bne -

        #word_sub_val src, 160
        #word_sub_val dst, 160

        dex
        bpl _zm_up_more

        ; now zoom only the first row

        lda #0
        sta cols

        ; lda #$00                ; zoom blocks: col = 0, row = 5
        ldx data.zoom_mode
        beq +
        lda #$02
+
        sta ws_pos

        lda data.zoom_xpos
        sta buf_col
-
        ldx buf_col
        ldy data.zoom_ypos
        lda ws_pos
        jsr zoom_char

        inc buf_col

        lda ws_pos
        clc
        adc #$10
        sta ws_pos
        inc cols
        lda cols
        cmp #10
        bne -
        rts
.pend


; Move zoom 'window' left
;
; zero page:    ZP+8 - ZP+14
move_right .proc

        src = ZP + 8
        dst = ZP + 10
        ws_pos = ZP + 12
        buf_col = ZP + 13
        buf_row = ZP + 14

        lda data.zoom_xpos
        cmp #30
        bcc +
        rts
+       inc data.zoom_xpos

        lda data.zoom_mode
        bne +

        lda #<(WORKSPACE_VIDRAM + (40 * 1) + 4)
        ldx #>(WORKSPACE_VIDRAM + (40 * 1) + 4)
        sta src
        stx src + 1

        lda #<(WORKSPACE_VIDRAM + (40 * 1) + 0)
        ldx #>(WORKSPACE_VIDRAM + (40 * 1) + 0)
        sta dst
        stx dst + 1

        ldx #23
        bne _zm_right_more
+
        lda #<(WORKSPACE_VIDRAM + (40 * 9) + 4)
        ldx #>(WORKSPACE_VIDRAM + (40 * 9) + 4)
        sta src
        stx src + 1

        lda #<(WORKSPACE_VIDRAM + (40 * 9) + 0)
        ldx #>(WORKSPACE_VIDRAM + (40 * 9) + 0)
        sta dst
        stx dst + 1

        ldx #15
_zm_right_more
        ldy #0
-       lda (src),y
        sta (dst),y
        iny
        cpy #36
        bne -

        #word_add_val src, 40
        #word_add_val dst, 40

        dex
        bpl _zm_right_more

        ; render full 'colum' of new zoomed data on the right

        lda data.zoom_xpos
        clc
        adc #9
        sta buf_col
        lda data.zoom_ypos
        sta buf_row

        lda #$90
        ldx data.zoom_mode
        beq +
        lda #$92
+
        sta ws_pos

-
        lda ws_pos
        ldx buf_col
        ldy buf_row
        jsr zoom_char

        inc buf_row
        inc ws_pos
        lda ws_pos
        cmp #$96
        bne -

        rts
.pend

;
; zero page:    ZP+8 - ZP+14
move_left .proc

        src = ZP + 8
        dst = ZP + 10
        ws_pos = ZP + 12
        buf_col = ZP + 13
        buf_row = ZP + 14

        ; move zoom area
        lda data.zoom_xpos
        bne +
        rts
+       dec data.zoom_xpos

        ; determine what to display and where
        lda data.zoom_mode
        bne +

        lda #<(WORKSPACE_VIDRAM + (40 * 1) + 0)
        ldx #>(WORKSPACE_VIDRAM + (40 * 1) + 0)
        sta src
        stx src + 1

        lda #<(WORKSPACE_VIDRAM + (40 * 1) + 4)
        ldx #>(WORKSPACE_VIDRAM + (40 * 1) + 4)
        sta dst
        stx dst + 1

        ldx #23
        bne _zm_left_more
+
        lda #<(WORKSPACE_VIDRAM + (40 * 9) + 0)
        ldx #>(WORKSPACE_VIDRAM + (40 * 9) + 0)
        sta src
        stx src + 1

        lda #<(WORKSPACE_VIDRAM + (40 * 9) + 4)
        ldx #>(WORKSPACE_VIDRAM + (40 * 9) + 4)
        sta dst
        stx dst + 1

        ldx #15
_zm_left_more
        ldy #35
-       lda (src),y
        sta (dst),y
        dey
        bpl -

        #word_add_val src, 40
        #word_add_val dst, 40

        dex
        bpl _zm_left_more

        ; render full 'colum' of new zoomed data on the right

        lda data.zoom_ypos
        sta buf_row

        lda #$00
        ldx data.zoom_mode
        beq +
        lda #$02
+
        sta ws_pos

-
        lda ws_pos
        ldx data.zoom_xpos
        ldy buf_row
        jsr zoom_char

        inc buf_row
        inc ws_pos
        lda ws_pos
        cmp #$06
        bne -

        rts
.pend


; Render a partial view of the buffer being worked on
render_view .proc

        bmp_src = ZP_TMP
        bmp_dst = ZP_TMP + 2
        vid_src = ZP_TMP + 4
        vid_dst = ZP_TMP + 6
        col_src = ZP_TMP + 8
        col_dst = ZP_TMP + 10

.cerror col_dst + 1 >= ZP, format("ZP_TMP $%02x overlaps with ZP $%02x", col_dst + 1, ZP)

        ; destination pointers
        ldx #0
        ldy #>WORKSPACE_BITMAP
        stx bmp_dst
        sty bmp_dst + 1
        ldy #>WORKSPACE_VIDRAM
        stx vid_dst
        sty vid_dst + 1
        ldy #$d8
        stx col_dst
        sty col_dst + 1

        lda data.view_offset
        jsr base.get_bitmap_row_offset
        sta bmp_src
        txa
        clc
        ldy data.buffer_index
        bne +
        adc #>BUFFER1_BITMAP
        bne ++
+       adc #>BUFFER2_BITMAP
+       sta bmp_src + 1

        lda data.view_offset
        jsr base.get_screen_row_offset
        clc
        adc #<BUFFER1_VIDRAM    ; this works since both buffers are aligned
        sta vid_src             ; on 256-byte boundaries
        txa
        ldy data.buffer_index
        bne +
        adc #>BUFFER1_VIDRAM
        bne ++
+       adc #>BUFFER2_VIDRAM
+       sta vid_src + 1

        lda data.view_offset
        jsr base.get_screen_row_offset
        clc
        adc #<BUFFER1_COLRAM
        sta col_src
        txa
        ldy data.buffer_index
        bne +
        adc #>BUFFER1_COLRAM
        bne ++
+       adc #>BUFFER2_COLRAM
+       sta col_src + 1

        ldx #9          ; $0a00 = 8 rows of bitmap data
        ldy #0
-       lda (bmp_src),y
        sta (bmp_dst),y
        iny
        bne -
        inc bmp_src + 1
        inc bmp_dst + 1
        dex
        bpl -

        ldy #0
-       lda (vid_src),y
        sta (vid_dst),y
        lda (col_src),y
        sta (col_dst),y
        iny
        bne -
        inc vid_src + 1
        inc vid_dst + 1
        inc col_src + 1
        inc col_dst + 1
        ldy #$3f
-       lda (vid_src),y
        sta (vid_dst),y
        lda (col_src),y
        sta (col_dst),y
        dey
        bpl -

        rts
.pend


update_zoom_char .proc

        column = ZP_TMP
        row = ZP_TMP + 1

        stx column
        sty row

        lda #0
        ldx data.zoom_mode
        beq +
        lda #2
+       sta _extra + 1

        lda data.cursor_xpos
        lsr a
        lsr a
        asl a
        asl a
        asl a
        asl a
        sta _tmp + 1
        lda data.cursor_ypos
        lsr a
        lsr a
        lsr a
        clc
_extra  adc #2
_tmp    ora #0
        ldx column
        ldy row
        jmp zoom.zoom_char
.pend


; @brief        Update a single char in the view
;
; @param X      column in the current buffer
; @param Y      row in the current buffer
;
; @return       none
;
; @clobbers     all
; @zeropage     ZP_TMP - ZP_TMP+11
;
update_view_char .proc

        column = ZP_TMP
        row = ZP_TMP + 1

        src_bmp = ZP_TMP + 2
        src_vid = ZP_TMP + 4
        src_col = ZP_TMP + 5

        dst_bmp = ZP_TMP + 6
        dst_vid = ZP_TMP + 8
        dst_col = ZP_TMP + 10

        stx column
        sty row

        ;stx $0500
        ;sty $0501

        ; pointer to source bitmap
        jsr base.get_current_buffer_bitmap_ptr
        sta src_bmp
        stx src_bmp + 1

        ;sta $0400
        ;stx $0401

        ; source vidram value
        ldx column
        ldy row
        jsr base.get_current_buffer_vidram_byte
        sta src_vid
        ; source colram value
        ldx column
        ldy row
        jsr base.get_current_buffer_colram_byte
        sta src_col

        ; determine destination in the view

        lda row
        sec
        sbc data.view_offset
        sta row
        tay
        ldx column
        jsr base.get_workspace_bitmap_ptr
        sta dst_bmp
        stx dst_bmp + 1

        ;sta $0402
        ;stx $0403

        ldx column
        ldy row
        jsr base.get_workspace_vidram_ptr
        sta dst_vid
        stx dst_vid + 1

        ;sta $0404
        ;stx $0405

        ldx column
        ldy row
        jsr base.get_workspace_colram_ptr
        sta dst_col
        stx dst_col + 1

        ;sta $0406
        ;stx $0407

        ldy #7
-       lda (src_bmp),y
        sta (dst_bmp),y
        dey
        bpl -
        iny
        lda src_vid
        sta (dst_vid),y
        lda src_col
        sta (dst_col),y
        rts
.pend


update_current_char .proc
        jsr base.get_cursor_pos ; row in Y, column in X
        stx _xtmp + 1
        sty _ytmp + 1
        jsr update_zoom_char
        lda data.zoom_mode
        bne +
        rts
+
_xtmp   ldx #0
_ytmp   ldy #0
        jmp update_view_char
.pend


; Switch zoom mode between FULL (40x24 zoom area) and VIEW+ZOOM (8 lines preview
; of the bitmap and 40x16 zoom area)
switch_mode .proc

        bitmap = ZP_TMP

        jsr status.clear_lborder_sprites

        lda data.zoom_mode
        and #1
        eor #1
        sta data.zoom_mode

        ; jsr status.clear_status
        lda data.zoom_mode
        beq ++

        ; adjust cursor ypos
        lda data.cursor_ypos
        cmp #32
        bcc +
        lda #31
        sta data.cursor_ypos
+

        ; render 8 rows of the view
        jsr render_view
        jmp _sm_finish

+       ; restore 8 row of the zoom area bitmap
        lda data.zoom_ypos
        cmp #19
        bcc +
        lda #19
        sta data.zoom_ypos
+
        ldx #<WORKSPACE_BITMAP
        ldy #>WORKSPACE_BITMAP
        stx bitmap
        sty bitmap + 1
-
        ldy #7
        lda #$ff
-       sta (bitmap),y
        dey
        cpy #3
        bne -
        lda #0
-       sta (bitmap),y
        dey
        bpl -

        #word_add_val bitmap, 8

        lda bitmap + 1
        cmp #>(WORKSPACE_BITMAP + $b40)
        bne ---
        lda bitmap
        cmp #<(WORKSPACE_BITMAP + $b40)
        bne ---

_sm_finish
        jsr status.render_status
        jsr zoom.zoom_full
;        jsr status.clear_lborder_sprites
        jmp status.render_lborder_sprites
.pend


; Move the view and/or its zoom area indicators up one row
;
; The zoom area indicators stay vertically centered when possible and move up
; only when the zoom has to display the first two lines of a buffer
;
move_view_up .proc
        lda data.view_offset
        beq _mvu_end
        lda data.view_index
        cmp #3
        bcc +
        dec data.view_index
        rts
+       dec data.view_offset
        jmp zoom.render_view

_mvu_end
        lda data.view_index
        beq +
        dec data.view_index
+       rts


.pend


; Move the view and/or its zoom area indicators dow one row
;
; The zoom area indicators stay vertically centered when possible and move down
; only when the zoom has to display last two lines of a buffer
;
move_view_down .proc
        lda data.view_offset
        cmp #17
        bcs _mvd_end

        lda data.view_index
        cmp #2
        bcs +
        inc data.view_index
        rts
+
        inc data.view_offset
        jmp zoom.render_view

_mvd_end
        lda data.view_index
        cmp #4
        bcs +
        inc data.view_index
+       rts
.pend







