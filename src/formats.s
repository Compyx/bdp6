; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - file format data and handlers


        hex_digits = diskmenu.diskutil.hex_digits


        FMT_BDP6        = 0     ; BDP 6.0 file format
        FMT_BDP5        = 1     ; BDP 5.0rc2 file format
        FMT_BDP4        = 2     ; BDP 4.0+ file format
        FMT_KOALA       = 3     ; Koala Painter 2 file format
        FMT_AMICA       = 4     ; Amica Paint format


        AP_PACKBYTE     = $c2   ; Amica Paint packbyte/controlbyte

        BDP6_HEADER_LEN = $08


format_handlers
        .word bdp6_load, bdp6_save      ; bdp6
        .word 0, 0              ; bdp5
        .word 0, 0              ; bdp4
        .word koala_load, 0
        .word amica_load, 0

not_implemented
        .enc "screen"
        .text "handler not implemented yet!", 0
        .enc "none"

unpacking_text
        .enc "screen"
        ;      123456789abcdef0123456789abcdef0123456
        .text "unpacking data: $xxxx-$----", 0
        .enc "none"


packing_text
        .enc "screen"
        ;      123456789abcdef0123456789abcdef0123456
        .text "packing data: $xxxx-$----", 0
        .enc "none"

freq_text
        .enc "screen"
        ;      123456789abcdef0123456789abcdef0123456
        .text "determining run indicator byte: $--", 0
        .enc "none"




bdp6_header
        .enc "screen"
        .text "bdp600"  ; Magic bytes
        .byte 0         ; run indicator byte
        .byte 0         ; unused (for now)
bdp6_header_end



render_unpacking_message
        jsr diskmenu.diskevents.clear_status_area
        ldx #0
-       lda unpacking_text,x
        beq +
        sta $0799,x
        inx
        bne -
+
        lda rle.data.target_start + 1
        jsr hex_digits
        sta $07aa
        stx $07ab
        lda rle.data.target_start + 0
        jsr hex_digits
        sta $07ac
        stx $07ad
        rts

render_unpacking_end_address .proc
        txa
        jsr hex_digits
        sta $07b2
        stx $07b3
        tya
        jsr hex_digits
        sta $07b0
        stx $07b1
        rts
.pend


render_freq_message
        jsr diskmenu.diskevents.clear_status_area
        ldx #0
-       lda freq_text,x
        beq +
        sta $0799,x
        inx
        bne -
+       rts


; mostly for debuggimg
render_freq_message_end
        jsr hex_digits
        sta $07ba
        stx $07bb
        rts


set_buffer_ptr
        ldx #<BUFFER1_BITMAP
        ldy #>BUFFER1_BITMAP

        lda data.buffer_index
        beq +

        ldx #<BUFFER2_BITMAP
        ldy #>BUFFER2_BITMAP
+
        jmp diskmenu.diskio.set_start_address



koala_load
        jsr set_buffer_ptr      ; sets load address to current buffer

        lda data.fname_len
        ldx data.fname_ptr
        ldy data.fname_ptr + 1
        jsr diskmenu.diskio.set_file_name

        jsr diskmenu.diskio.load_file

        rts


; @brief        Copy RAM that gets overwritten during Amica Pain unpacking
;
; @note         Temporarily nlocks IRQ's and sets $01 to $34
;
; @clobbers     A,X
;
amica_backup_ram .proc

        tmp = $0400

        sei
        lda $01
        pha
        lda #$34
        sta $01
        ldx #0
        lda data.buffer_index
        bne +
-       lda BUFFER1_END + 1,x
        sta tmp,x
        inx
        bne -
        beq ++
+
-       lda BUFFER2_END + 1,x
        sta tmp,x
        inx
        bne -
+
        pla
        and #$07
        ora #$30
        sta $01
        cli
        rts
.pend


; @brief        Restore RAM that gets overwritten during Amica Pain unpacking
;
; @note         Temporarily nlocks IRQ's and sets $01 to $34
;
; @clobbers     A,X
;
amica_restore_ram .proc

        tmp = $0400

        sei
        lda #$34
        sta $01
        ldx #0
        lda data.buffer_index
        bne +
-       lda tmp,x
        sta BUFFER1_END + 1,x
        inx
        bne -
        beq ++
+
-       lda tmp,x
        sta BUFFER2_END + 1,x
        inx
        bne -
+
        lda #$36
        sta $01
        cli
        rts
.pend




amica_load
        ldx #<WORKSPACE_START
        ldy #>WORKSPACE_START
        jsr diskmenu.diskio.set_start_address

        lda data.fname_len
        ldx data.fname_ptr
        ldy data.fname_ptr + 1
        jsr diskmenu.diskio.set_file_name

        jsr diskmenu.diskio.load_file

        ; handle buffer index
        lda data.buffer_index
        bne +
        ldx #<BUFFER1_BITMAP
        ldy #>BUFFER1_BITMAP
        jmp ++
+       ldx #<BUFFER2_BITMAP
        ldy #>BUFFER2_BITMAP
+
        jsr rle.set_target_start

        ; render message
        jsr render_unpacking_message

        ; make copy of RAM overwritten wiht AP's color cycle table during
        ; unpacking
        jsr amica_backup_ram

        ; Make sure we can unpack into $d000-$dfff
        sei
        lda #$34
        sta $01

        ; Set packbyte and source data start and depack
        lda #AP_PACKBYTE        ; AP uses a fix 'packbyte'
        ldx #<WORKSPACE_START
        ldy #>WORKSPACE_START
        jsr rle.unpack_generic
;        stx rle.data.target_end
;        sty rle.data_target_end + 1

        jsr render_unpacking_end_address

        ; restore memory overwritten by depacking AP's color cycle table
        jsr amica_restore_ram

        lda #$36
        sta $01
        cli


        rts


bdp6_save
        lda #$36
        sta $01

        jsr base.get_current_buffer_start
        sta rle.data.source_start
        stx rle.data.source_start + 1
        jsr base.get_current_buffer_end
        clc
        adc #1                                  ; make end address exclusive
        sta rle.data.source_end
        bcc +
        inx
+       stx rle.data.source_end + 1

        jsr render_freq_message

        ; determine runbyte
        jsr rle.pack_determine_runbyte
        tya
        pha
        jsr render_freq_message_end
        pla

        sta bdp6_header + 6     ; TODO: use symbolic constant

        ldx #<(WORKSPACE_START + BDP6_HEADER_LEN)
        ldy #>(WORKSPACE_START + BDP6_HEADER_LEN)
        jsr rle.pack_generic
        stx $0334       ; TODO: replace with symbolic constants
        sty $0335

        tya
        jsr hex_digits
        sta $07ba
        stx $07bb
        lda $0334
        jsr hex_digits
        sta $07bc
        stx $07bd

        ; store BDP6 header
        ldx #BDP6_HEADER_LEN - 1
-       lda bdp6_header,x
        sta WORKSPACE_START,x
        dex
        bpl -

        ; save file
        ldx #<WORKSPACE_START
        ldy #>WORKSPACE_START
        jsr diskmenu.diskio.set_start_address

        ldx $0334
        ldy $0335
        jsr diskmenu.diskio.set_end_address

        lda data.fname_len
        ldx data.fname_ptr
        ldy data.fname_ptr + 1
        jsr diskmenu.diskio.set_file_name

        jsr diskmenu.diskio.save_file

        rts


; @brief        Load and decrunch BDP6 format image
;
bdp6_load
        ldx #<WORKSPACE_START
        ldy #>WORKSPACE_START
        jsr diskmenu.diskio.set_start_address

        lda data.fname_len
        ldx data.fname_ptr
        ldy data.fname_ptr + 1
        jsr diskmenu.diskio.set_file_name

        jsr diskmenu.diskio.load_file

        ; handle buffer index
        lda data.buffer_index
        bne +
        ldx #<BUFFER1_BITMAP
        ldy #>BUFFER1_BITMAP
        jmp ++
+       ldx #<BUFFER2_BITMAP
        ldy #>BUFFER2_BITMAP
+
        jsr rle.set_target_start

        ; render message
        jsr render_unpacking_message

        ; Make sure we can unpack into $d000-$dfff (shouldn't happen)
        sei
        lda #$34
        sta $01

        ; Set packbyte and source data start and depack
        lda WORKSPACE_START + 6
        ldx #<(WORKSPACE_START + BDP6_HEADER_LEN)
        ldy #>(WORKSPACE_START + BDP6_HEADER_LEN)
        jsr rle.unpack_generic
;        stx rle.data.target_end
;        sty rle.data_target_end + 1

        jsr render_unpacking_end_address

        lda #$36
        sta $01
        cli
        rts



; @brief        Trigger image load handler
;
; @param A      format index
;
; @note:        don't make into .proc: jumped into from save_file()
;
load_file
        asl a
        asl a
        tax
        lda format_handlers,x
        sta $0334
        lda format_handlers + 1,x
        sta $0335
        ora $0334
        bne exec_handler
not_impl_msg    ; jumped to from save_file()
        jsr diskmenu.diskevents.clear_status_area
        lda #2
        sta $d020
        ldx #0
-       lda not_implemented,x
        beq +
        sta $0799,x
        inx
        bne -
+       rts
exec_handler
        jmp ($0334)


; @brief        Trigger image save handler
;
; @param A      format index
;
save_file
        asl a
        asl a
        tax
        lda format_handlers + 2,x
        sta $0334
        lda format_handlers + 3,x
        sta $0335
        ora $0334
        bne exec_handler
        jmp not_impl_msg


