; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; Diskmenu - I/O routines
;

;------------------------------------------------------------------------------
; Symbol declarations
;------------------------------------------------------------------------------
; {{{
; Buffer used for storing PETSCII output of drive status command
IEC_TEXT_BUFFER = $0340
; Maximum size of the drive status buffer
IEC_TEXT_BUFFER_LEN = $c0
; }}}

;------------------------------------------------------------------------------
; Data section - TODO: probably move to diskmenu.data
;------------------------------------------------------------------------------

; {{{ various constant text blobs
; 'Name' of the directory: "$"
dirname .byte $24


; Text to display while reading the directory
rd_text_reading
        .enc "screen"
        .text "reading directory entry"
        .enc "none"
rd_text_reading_end


; Text to display for the number of block free
rd_text_blocks_free
        .enc "screen"
        .text "blocks free."
        .enc "none"
rd_text_blocks_free_end


; Text to display while loading (only for load_file_verbose())
lf_text
        .enc "screen"
        .text "loading ", $22
        .enc "none"
lf_text_end


; Text to display while saving (only for save_file_verbose())
sf_text
        .enc "screen"
        .text "saving ", $22
        .enc "none"
sf_text_end
; }}}

;------------------------------------------------------------------------------
; Code section
;------------------------------------------------------------------------------

; {{{ (C,X)     iec_status(void)
; Get status of IEC device
;
; Returns:      X: Message length
;               C: clear on success, set on failure
iec_status .proc
        ldx #0
        txa
-       sta IEC_TEXT_BUFFER,x
        inx
        cpx #IEC_TEXT_BUFFER_LEN
        bne -

        lda #0
        sta $90 ; clear status byte

        lda diskdata.device_number
        jsr K_LISTEN
        lda #$6f        ; secondary address (command channel)
        jsr K_LSTNSA
        jsr K_UNLSTN

        ; check device present
        lda $90
        bne _iec_dev_np

        lda diskdata.device_number
        jsr K_TALK
        lda #$6f
        jsr K_TALKSA
        ldx #0
_iec_more
        lda $90
        bne _iec_eof
        jsr K_IECIN
        sta IEC_TEXT_BUFFER,x
        inx
        jmp _iec_more
_iec_eof
        jsr K_UNTALK
        clc
        dex
        rts
_iec_dev_np
        sec
        rts
.pend   ;}}}

; {{{ (A,C,X,Y) read_dir(void)
; Read directory of current device
;
; Directory entries are stored in *(data.dir_buffer), with each entry containing:
;
; $00-$01:      blocks (LSB/MSB)
; $02-$11:      filename, padded with spaces
; $12-$16:      '*prg<' part
; $17    :      filename length
;
; Returns:      A: number of directory entries
;               X/Y: pointer to final bytes of directory: blocks free (LSB/MSB)
;               C clear on success, C set on failure
read_dir .proc

        buf = DISKMENU_ZP
        cnt = DISKMENU_ZP + 4
        cnt2 = DISKMENU_ZP + 5
        tmp = DISKMENU_ZP + 2

        lda #0
        ldx diskdata.dir_buffer
        sta buf
        stx buf + 1

        jsr diskevents.clear_status_area
        ldx #rd_text_reading_end - rd_text_reading - 1
-       lda rd_text_reading,x
        sta $0799,x
        dex
        bpl -

        lda #0
        sta cnt

        lda #1
        ldx #<dirname
        ldy #>dirname
        jsr K_SETNAM

        lda #$02
        ldx diskdata.device_number
        ldy #0
        jsr K_SETLFS

        jsr K_OPEN
        bcc +
        jmp _rd_error
+
        ldx #$02
        jsr K_CHKIN

        ; Get disk name and ID

        ; skip BASIC load address, pointer to next BASIC line, line number,
        ; PETSCII REVERSE and opening double quote
        ldy #8
-
        jsr K_READST
        beq +
        jmp _rd_error
+
        jsr K_GETIN
        dey
        bne -

        ; get disk name and store on screen
        ldy #0
-
        jsr K_READST
        beq +
        jmp _rd_error
+
        jsr K_GETIN
        jsr diskutil.petscii_to_screen
        sta $042d,y
        lda #7
        sta $d82d,y
        iny
        cpy #16
        bne -

        ; skip closing quote and space
        ldy #2
-
        jsr K_READST
        beq +
        jmp _rd_error
+       jsr K_GETIN
        dey
        bne -

        ; read disk ID
        ldy #0
-       jsr K_READST
        beq +
        jmp _rd_error
+
        jsr K_GETIN
        jsr diskutil.petscii_to_screen
        sta $043e,y
        lda #7
        sta $d83e,y
        iny
        cpy #5
        bne -

        ; Read and discard EOL
        jsr K_GETIN

        ;
        ; Read and parse each directory entry
        ;

_rd_more
        ; update status line
        ldx cnt
        inx
        ldy #0
        jsr diskutil.decimal_digits
        jsr diskutil.decimal_digits_left_align
        ldx #0
-       lda diskutil.decimal_result,x
        sta $0799 + 24,x
        inx
        cpx #5
        bne -

        ; read pointer to next BASIC line
        jsr K_READST
        bne _rd_error
        jsr K_GETIN
        sta _rd_tmp + 1
        jsr K_GETIN
_rd_tmp ora #0
        beq _rd_end     ; pointer to next BASIC line is 0000, EOD

        ; get blocks
        jsr K_GETIN
        ldy #0
        sta (buf),y     ; blocks LSB
        iny
        jsr K_GETIN
        sta (buf),y
        iny

        ; find opening quote
-       jsr K_GETIN
        cmp #$42
        beq _rd_end     ; BLOCKS FREE
        cmp #$22
        bne -
-
        jsr K_GETIN
        sta (buf),y
        iny
        cpy #18
        bne -

        jsr K_GETIN     ; skip closing quote or space

        ; get '*prg<'
-
        jsr K_GETIN
        sta (buf),y
        iny
        cpy #23
        bne -

        ; find EOL
-       jsr K_GETIN
        bne -

        lda buf
        clc
        adc #$18
        sta buf
        bcc +
        inc buf + 1
+
        inc cnt

        jmp _rd_more

_rd_error
        ; unclean exit
        lda #2
        sta $d020
        jsr K_CLOSE
        jsr K_CLRCHN
        lda cnt
        ldx buf
        ldy buf + 1
        sec
        rts

        ; clean exit
_rd_end
_rd_close
        lda #2
        jsr K_CLOSE
        jsr K_CLRCHN


        jsr diskevents.clear_status_area

        ; disable KERNAL, if buffer is at $e000+
        lda diskdata.dir_buffer
        cmp #$e0
        bcc +
        sei
        lda $01
        pha
        lda #$35
        sta $01
+
        ldy #0
        lda (buf),y
        tax
        iny
        lda (buf),y
        tay
        jsr diskutil.decimal_digits
        jsr diskutil.decimal_digits_left_align

        ; now fix the filename lengths
        lda #0
        ldx diskdata.dir_buffer
        sta tmp
        stx tmp + 1

        lda #0
        sta cnt2
-
        ldx #0
        ldy #2
-       lda (tmp),y
        cmp #$22
        beq +
        iny
        inx
        cpx #16
        bne -
+
        cpx #16
        beq +
        lda #$20
        sta (tmp),y
+       txa
        ldy #23
        sta (tmp),y

        lda tmp
        clc
        adc #$18
        sta tmp
        bcc +
        inc tmp + 1
+       inc cnt2
        lda cnt2
        cmp cnt
        bcc --

        lda diskdata.dir_buffer
        cmp #$e0
        bcc +
        pla
        and #$07
        ora #$30
        sta $01
        cli
+

        ldx #0
-       lda diskutil.decimal_result,x
        cmp #$20
        beq +
        sta $0799,x
        inx
        cpx #5
        bne -
+
        inx
        ldy #0
-       lda rd_text_blocks_free,y
        sta $0799,x
        inx
        iny
        cpy #rd_text_blocks_free_end - rd_text_blocks_free
        bne -

        lda cnt
        ldx buf
.if DISKMENU_DEBUG
        stx $0400
        sty $0401
.endif
        ldy buf + 1
        clc
        rts
.pend   ; }}}

; {{{ void      set_start_address(X,Y)
; Set start address for loading/saving
;
; Input:        X/Y: LSB/MSB
;
set_start_address .proc
        stx diskdata.start_address
        sty diskdata.start_address + 1
        rts
.pend   ; }}}

; {{{ void      set_end_address(X,Y)
; Set end address for saving
;
; Input:        X/Y: LSB/MSB
;
set_end_address .proc
        stx diskdata.end_address
        sty diskdata.end_address + 1
        rts
.pend   ; }}}

; {{{ void      set_file_name(A,X,Y)
; Set file name and length of file name
;
; Input:        A: length of file name
;               X: LSB of file name
;               Y: MSB of file name
set_file_name .proc
        sta diskdata.file_name_len
        stx diskdata.file_name_ptr
        sty diskdata.file_name_ptr + 1
        rts
.pend   ; }}}

; {{{ void      get_file_name(A,X,Y)
; Get file name and length of file name
;
; Output:       A: length of file name
;               X: LSB of file name
;               Y: MSB of file name
get_file_name .proc
        lda diskdata.file_name_len
        ldx #<diskdata.file_name_buf
        ldy #>diskdata.file_name_buf
        rts
.pend   ; }}}

; {{{ (C,X,Y)   load_file(void)
; Load a file into memory
;
; Uses params set through `set_file_name` and 'set_start_address`.
;
; Returns:      C: 0 = success, 1 = failure
;               X: end address LSB
;               Y; end address MSB
;
load_file .proc
        lda diskdata.file_name_len
        ldx diskdata.file_name_ptr
        ldy diskdata.file_name_ptr + 1
        jsr K_SETNAM
        lda #1
        ldx diskdata.device_number
        ldy #0
        jsr K_SETLFS

        lda #0
        ldx diskdata.start_address
        ldy diskdata.start_address + 1
        jsr K_LOAD
        bcs _lf_error
        ldx $ae         ; $ae/$af contains end address + 1, adjust
        ldy $af
        dex
        cpx #$ff
        bne +
        dey
+
        stx diskdata.end_address
        sty diskdata.end_address + 1
        clc
        rts
_lf_error
        lda #2
        sta $d020
        sec
        rts
.pend   ; }}}

; {{{ (C,X,Y)   load_file_verbose(void)
; Load a file into memory, while printing "loading" and start/end address
;
; Uses params set through `set_file_name` and 'set_start_address`.
;
; Returns:      C: 0 = success, 1 = failure
;               X: end address LSB (only on C 0)
;               Y; end address MSB (only on C 0)
;
load_file_verbose .proc

        tmp = DISKMENU_ZP

        jsr diskevents.clear_status_area
        ldx #0
-       lda lf_text,x
        sta $0799,x
        inx
        cpx #lf_text_end - lf_text
        bne -

        lda diskdata.file_name_ptr
        sta tmp
        lda diskdata.file_name_ptr + 1
        sta tmp + 1
        ldy #0
-       lda (tmp),y
        jsr diskutil.petscii_to_screen
        sta $0799,x
        inx
        iny
        cpy diskdata.file_name_len
        bne -
        lda #$22
        sta $0799,x
        inx
        inx
        lda #$24
        sta $0799,x
        txa
        tay
        iny

        lda diskdata.start_address + 1
        jsr diskutil.hex_digits
        sta $0799,y
        txa
        iny
        sta $0799,y
        lda diskdata.start_address
        jsr diskutil.hex_digits
        iny
        sta $0799,y
        txa
        iny
        sta $0799,y
        iny
        lda #$2d
        sta $0799,y

        sty _ytmp + 1
        jsr load_file
        bcc +
        lda #2
        sta $d020
        rts
+
        stx tmp
        sty tmp + 1

_ytmp   ldy #0
        iny
        lda #$24
        sta $0799,y

        lda tmp +1
        jsr diskutil.hex_digits
        iny
        sta $0799,y
        iny
        txa
        sta $0799,y
        iny
        lda tmp
        jsr diskutil.hex_digits
        sta $0799,y
        iny
        txa
        sta $0799,y
        clc
        ldx tmp
        ldy tmp + 1
        rts
.pend   ; }}}

; {{{ (C)       save_file(void)
; Save file to disk
;
; Input:        none*
; Ouput:        C clear on success, C set on failure
;
; * = this function requires calls to `set_start_address`, `set_end_address`
;     and `set_file_name` for proper operation
;
save_file .proc
        lda diskdata.file_name_len
        ldx diskdata.file_name_ptr
        ldy diskdata.file_name_ptr + 1
        jsr K_SETNAM
        lda #0
        ldx diskdata.device_number
        ldy #0
        jsr K_SETLFS

        lda diskdata.start_address
        ldx diskdata.start_address + 1
        sta $fb
        stx $fc

        lda #$fb
        ldx diskdata.end_address
        ldy diskdata.end_address + 1
        jsr K_SAVE
        bcs _error
        rts
_error
        lda #2
        sta $d020
        rts
.pend   ; }}}

; {{{ (C)       save_file_verbose(void)
; Save file to disk, notifying the user of progress and success/failure
;
; Input:        none*
; Ouput:        C clear on success, C set on failure
;
; * = this function requires calls to `set_start_address`, `set_end_address`
;     and `set_file_name` for proper operation
;
save_file_verbose .proc

        jsr diskevents.clear_status_area
        ldy #0
-       lda sf_text,y
        sta $0799,y
        iny
        cpy #sf_text_end - sf_text
        bne -

        lda diskdata.file_name_ptr
        sta _fname + 1
        lda diskdata.file_name_ptr + 1
        sta _fname + 2

        ldx #0
-
_fname  lda $fce2,x
        jsr diskutil.petscii_to_screen
        sta $0799,y
        inx
        iny
        cpx diskdata.file_name_len
        bne -

        lda #$22
        sta $0799,y
        iny
        iny
        lda #$24
        sta $0799,y
        iny
        lda diskdata.start_address + 1
        jsr diskutil.hex_digits
        sta $0799,y
        txa
        iny
        sta $0799,y
        iny
        lda diskdata.start_address
        jsr diskutil.hex_digits
        sta $0799,y
        iny
        txa
        sta $0799,y
        iny
        lda #$2d
        sta $0799,y
        iny
        lda #$24
        sta $0799,y
        iny
        lda diskdata.end_address + 1
        jsr diskutil.hex_digits
        sta $0799,y
        txa
        iny
        sta $0799,y
        iny
        lda diskdata.end_address
        jsr diskutil.hex_digits
        sta $0799,y
        iny
        txa
        sta $0799,y

        jsr save_file
        jsr diskevents.get_dev_status
        rts
.pend   ; }}}

