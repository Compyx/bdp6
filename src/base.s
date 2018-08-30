; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - base functions


; {{{ (A,X)     get_bitmap_row_offset(A)
;
; Get bitmap row offset
;
; @param A      bitmap row index (0-24)
;
; @return       LSB in A, MSB in X
;
get_bitmap_row_offset .proc
        tax
        lda data.bitmap_row_lsb,x
        pha
        lda data.bitmap_row_msb,x
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_screen_row_offset(A)
;
; Get screen (vidram/colram) row offset
;
; @param A      screen row index (0-24)
;
; @return       LSB in A, MSB in X
;
get_screen_row_offset
        tax
        lda data.screen_row_lsb,x
        pha
        lda data.screen_row_msb,x
        tax
        pla
        rts
; }}}


; {{{ (A,X)     get_bitmap_offset(X,Y)
;
; Get offset to a 'char' in a bitmap
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_bitmap_offset .proc
        stx _col + 1
        tya
        jsr get_bitmap_row_offset

_col    ldy #0
        clc
        adc data.bitmap_col_lsb,y
        pha
        txa
        adc data.bitmap_col_msb,y
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_buffer_bitmap_ptr(A,X,Y)
;
; Get pointer to a char's bitmap in a buffer
;
; @param A      buffer index
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
get_buffer_bitmap_ptr .proc
        sta _buf + 1
        jsr get_bitmap_offset

        sta $0502
        stx $0503

        pha
        txa
_buf    ldy #0
        bne +
        clc
        adc #>BUFFER1_BITMAP
        tax
        pla
        rts

+       clc
        adc #>BUFFER2_BITMAP
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_current_buffer_bitmap_ptr(X,Y)
;
; Get pointer to a char's bitmap in the current buffer
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X

get_current_buffer_bitmap_ptr .proc
        lda data.buffer_index
        jmp get_buffer_bitmap_ptr       ; XXX: can be BPL
.pend
; }}}


; {{{ (A,X)     get_workspace_bitmap_ptr(X,Y)
;
; Get pointer to a char in the workspace bitmap
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
get_workspace_bitmap_ptr .proc
        jsr get_bitmap_offset
        pha
        txa
        clc
        adc #>WORKSPACE_BITMAP
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_screen_offset(X,Y)
;
; Get offset to a 'char' in a screen
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_screen_offset .proc
        txa
        clc
        adc data.screen_row_lsb,y
        pha
        lda data.screen_row_msb,y
        adc #0
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_buffer_vidram_ptr(A,X,Y)
;
; Get a pointer to a char in a buffer's vidram
;
; @param A      buffer index
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_buffer_vidram_ptr .proc
        sta _buf + 1
        jsr get_screen_offset
        clc
_buf    ldy #0
        bne +
        adc #<BUFFER1_VIDRAM
        pha
        txa
        adc #>BUFFER1_VIDRAM
        tax
        pla
        rts
+       adc #<BUFFER2_VIDRAM
        pha
        txa
        adc #>BUFFER2_VIDRAM
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_buffer_colram_ptr(A,X,Y)
;
; Get a pointer to a char in a buffer's colram
;
; @param A      buffer index
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_buffer_colram_ptr .proc
        sta _buf + 1
        jsr get_screen_offset
        clc
_buf    ldy #0
        bne +
        adc #<BUFFER1_COLRAM
        pha
        txa
        adc #>BUFFER1_COLRAM
        tax
        pla
        rts
+       adc #<BUFFER2_COLRAM
        pha
        txa
        adc #>BUFFER2_COLRAM
        tax
        pla
        rts
.pend
; }}}


; {{{ (A,X)     get_current_buffer_vidram_ptr(X,Y)
;
; Get a pointer to a char in the current buffer's vidram
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_current_buffer_vidram_ptr .proc
        lda data.buffer_index
        jmp get_buffer_vidram_ptr
.pend
; }}}


; {{{ (A)       get_current_buffer_vidram_byte(X,Y)
;
; @brief        Get vidram value from current buffer
;
; @param X      column
; @param Y      row
;
; @return A     vidram value
;
get_current_buffer_vidram_byte .proc
        jsr get_current_buffer_vidram_ptr
        sta _tmp + 1
        stx _tmp + 2
_tmp    lda $fce2
        rts
.pend
; }}}

; Get a pointer to a char in the current buffer's colram
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_current_buffer_colram_ptr .proc
        lda data.buffer_index
        jmp get_buffer_colram_ptr
.pend

; Get a the colram/bitmaks of a char in the current buffer's colram
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_current_buffer_colram_byte .proc
        jsr get_current_buffer_colram_ptr
        sta _tmp + 1
        stx _tmp + 2
;        sta $0402
;        stx $0403
_tmp    lda $fce2
        rts
.pend


; @brief        Calculate final cursor position in buffer in chars
;
; Uses cursor position in zoom and offset of the zoom to determine the cursor's
; actual position in chars in a buffer.
;
; @return X     column
; @return Y     row
;
; @clobbers     A,C
; @zeropage     none
;
get_cursor_pos .proc
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
        rts
.pend


get_cursor_pos_pixels
        lda data.zoom_xpos
        asl a
        asl a
        clc             ; XXX: not strictly required
        adc data.cursor_xpos
        tax
        lda data.zoom_ypos
        asl a
        asl a
        asl a
        clc             ; XXX: not strictly required
        adc data.cursor_ypos
        tay
        rts


get_cursor_vidram_ptr .proc
        jsr get_cursor_pos
        jmp get_current_buffer_vidram_ptr
.pend

get_cursor_vidram_byte .proc
        jsr get_cursor_pos
        jmp get_current_buffer_vidram_byte
.pend

get_cursor_colram_ptr .proc
        jsr get_cursor_pos
        jmp get_current_buffer_colram_ptr
.pend

get_cursor_colram_byte .proc
        jsr get_cursor_pos
        jmp get_current_buffer_colram_byte
.pend




; Get a pointer to a char in the workspace vidram
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_workspace_vidram_ptr .proc
        jsr get_screen_offset
        pha
        clc
        txa
        adc #>WORKSPACE_VIDRAM
        tax
        pla
        rts
.pend


; Get a pointer to a char in the workspace colram
;
; @param X      column
; @param Y      row
;
; @return       LSB in A, MSB in X
;
get_workspace_colram_ptr .proc
        jsr get_screen_offset
        pha
        txa
        clc
        adc #$d8
        tax
        pla
        rts
.pend


; @brief        Multiply a byte in A bye 8 to a word in X,Y
;
; @param A      value to multiply by 8
; @return       LSB in X, MSB in Y
;
; @zeropage     none
; @safe         A
; @stack        2
;
byte_mul8 .proc
        pha
        asl a
        rol a
        rol a
        pha
        and #$f8
        tax
        pla
        rol a
        and #$07
        tay
        pla
        rts
.pend


; @brief        Get pointer to char in the font
;
; @param A      char
; @return       LSB in X, MSB in Y
;
get_font_ptr .proc
        jsr byte_mul8
        tya
        clc
        adc #>EDITOR_FONT
        tay
        rts
.pend


; @brief        Convert byte to three decimal digits (YXA)
;
; @param A      value
;
; @return A     10^0
; @return X     10^1
; @return Y     10^2
;
; @clobbers     C
; @zeropage     none
;
byte_to_decimal .proc
        ; 0xx, 1xx or 2xx
        ldy #$30
        cmp #200
        bcc +
        sbc #100
        iny
+       cmp #100
        bcc +
        iny
        sbc #100
+
        ; x00-x99
        ldx #$2f
-       inx
        sec
        sbc #10
        bcs -
        adc #$30 + 10
        rts
.pend

; @brief        Get background of current buffer
;
; @return A     color
;
get_current_bgcolor .proc
        lda data.buffer_index
        bne +
        lda BUFFER1_BGCOLOR
        and #$0f
        rts
+       lda BUFFER2_BGCOLOR
        and #$0f
        rts
.pend


get_cursor_bitmap_ptr .proc
        jsr get_cursor_pos
        jmp get_current_buffer_bitmap_ptr
.pend



get_buffer_bitmap_start .proc
        cmp #0
        bne +
        lda #<BUFFER1_BITMAP
        ldx #>BUFFER1_BITMAP
        rts
+       lda #<BUFFER2_BITMAP
        ldx #>BUFFER2_BITMAP
        rts
.pend


get_current_buffer_start = get_current_buffer_bitmap_start

get_current_buffer_bitmap_start .proc
        lda data.buffer_index
        jmp get_buffer_bitmap_start
.pend


get_current_buffer_vidram_start .proc
        lda data.buffer_index
        bne +
        lda #<BUFFER1_VIDRAM
        ldx #>BUFFER1_VIDRAM
        rts
+       lda #<BUFFER2_VIDRAM
        ldx #>BUFFER2_VIDRAM
        rts
.pend


get_current_buffer_colram_start .proc
        lda data.buffer_index
        bne +
        lda #<BUFFER1_COLRAM
        ldx #>BUFFER1_COLRAM
        rts
+       lda #<BUFFER2_COLRAM
        ldx #>BUFFER2_COLRAM
        rts
.pend


get_current_buffer_end .proc
        lda data.buffer_index
        bne +
        lda #<BUFFER1_END
        ldx #>BUFFER1_END
        rts
+       lda #<BUFFER2_END
        ldx #>BUFFER2_END
        rts
.pend

store_1000_bytes .proc
        dst = ZP_TMP

        stx dst
        sty dst + 1

        ldx #2
        ldy #0
-       sta (dst),y
        iny
        bne -
        inc dst + 1
        dex
        bpl -
-       sta (dst),y
        iny
        cpy #$e8
        bne -
        rts
.pend



