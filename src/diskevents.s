; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; Diskmenu - event handlers

;------------------------------------------------------------------------------
; Symbol declarations
;------------------------------------------------------------------------------
; {{{
;
; Flags controlling what to do (if anything) after an event has been triggered
; (none of these are used so far)
;
EV_STATUS       = $100  ; show device status after event
; }}}


;------------------------------------------------------------------------------
; Data section (TODO: move to diskmenu.data ?)
;------------------------------------------------------------------------------

; {{{ non-constant data

; number of directory entries in buffer
dir_entry_count         .byte 0
; offset in directory buffer for display
dir_entry_offset        .byte 0
; index in the directory contents on-screen
dir_entry_row           .byte 0
dir_row_max             .byte 0
; }}}

; {{{ constant data
; Text shown when an empty disk is present
empty_disk_text
        .enc "screen"
        .text "<< empty disk >>"
        .enc "none"

save_file_text
        .enc "screen"
        .text "enter filename: "
        .enc "none"
save_file_text_end

operation_aborted_text
        .enc "screen"
        .text "current operation aborted by user"
        .enc "none"
operation_aborted_text_end

file_loading_text
        .enc "screen"
        .text "loading file "
        .enc "none"
file_loading_text_end

exit_text
        .enc "screen"
        .text "exit disk menu?", 0
        .enc "none"

prompt_yesno_text
        .enc "screen"
        .text "(y/n)"
        .enc "none"

; Table of keys and their associated event handlers
event_handlers
        .word $44, diskevents.inc_dev_number            ; D - increment dev#
        .word $4c, diskevents.load_file_browser         ; L - Load file
        .word $53, diskevents.save_file_handler         ; S - Save file
        .word $54, diskevents.get_dev_status            ; T - get device sTatus
        .word $03, diskevents.exit_menu                 ; STOP - exit menu
        .word $46, diskevents.select_file_type          ; F - select file type
event_handlers_end


; }}}


;------------------------------------------------------------------------------
; Code section
;------------------------------------------------------------------------------

; {{{ void      inc_dev_number(void)
; Increment device number (8-11)
inc_dev_number .proc
        lda diskdata.device_number
        clc
        adc #1
        and #3
        ora #8
        sta diskdata.device_number
        jsr render_device_number
        rts
.pend   ; }}}

; {{{ void      get_dev_status(void)
; Get IEC device status and print in the status area
get_dev_status .proc
        jsr clear_status_area
        jsr diskio.iec_status
        bcs +

        ; got message
        dex     ; X contains message length
-
        lda diskio.IEC_TEXT_BUFFER,x
        and #$3f
        sta $0799,x
        dex
        bpl -
        rts

        ; device not present error
+
        ldx #0
-       lda diskdata.device_not_ready,x
        sta $0799,x
        inx
        cpx #diskdata.device_not_ready_end - diskdata.device_not_ready
        bne -

        rts
.pend   ; }}}

; {{{ void      clear_status_area(void)
; Clear the 'status' area, the 38 char line on the bottom of the screen
clear_status_area .proc
        ldx #38
-       lda #$20
        sta $0798,x
        lda #1
        sta $db98,x
        dex
        bne -
        rts
.pend   ; }}}

; {{{ void      render_aborted_message(void)
; Output "operation aborted" message
render_aborted_message .proc
        jsr clear_status_area
        ldx #0
-       lda operation_aborted_text,x
        sta $0799,x
        inx
        cpx #operation_aborted_text_end - operation_aborted_text
        bne -
        rts
.pend   ; }}}

; {{{ (C)       prompt_yesno(X,Y)
; Show a YES/NO prompt
;
; The message should be in screen codes, ending with a 0 byte.
;
; Input:        X/Y: LSB/MSB of message
; Output:       C clear on 'Y', C set on any other key
;
prompt_yesno .proc
        msg = DISKMENU_ZP

        stx msg
        sty msg + 1

        jsr clear_status_area

        ldy #0
-       lda (msg),y
        beq +
        sta $0799,y
        lda #$0f
        sta $db99,y
        iny
        cpy #32
        bne -
+       iny
        ldx #0
-       lda prompt_yesno_text,x
        sta $0799,y
        lda #1
        sta $db99,y
        iny
        inx
        cpx #5
        bne -

-       jsr K_GETIN
        cmp #0
        beq -
        pha
        jsr clear_status_area
        pla
        cmp #$59
        bne +
        clc
        rts
+
        sec
        rts
.pend   ; }}}

; {{{ void      render_file_type_selection(void)
; Mark current selection during file type selection 'dialog'
render_file_type_selection .proc
        vidram = DISKMENU_ZP

        lda diskdata.file_type_selector_index
        jsr diskutil.mul_byte_40
        clc
        adc #$bc
        sta vidram
        txa
        adc #$04
        sta vidram + 1
        ldy #10
-       lda (vidram),y
        ora #$80
        sta (vidram),y
        dey
        bpl -
        rts
.pend   ; }}}

; {{{ void      render_file_type_dialog(void)
; Render the file type list during file type selection 'dialog'
render_file_type_list .proc
        ftlist = DISKMENU_ZP
        vidram = DISKMENU_ZP + 2
        colram = DISKMENU_ZP + 4

        lda #$bc
        ldx #$04
        ldy #$d8
        sta vidram
        stx vidram + 1
        sta colram
        sty colram + 1

        lda diskdata.file_type_list
        ldx diskdata.file_type_list + 1
        sta ftlist
        stx ftlist + 1

        ldx #0
-
        ldy #10
-       lda (ftlist),y
        sta (vidram),y
        lda #$0f
        sta (colram),y
        dey
        bpl -

        lda ftlist
        clc
        adc #11
        sta ftlist
        bcc +
        inc ftlist + 1
+       lda colram
        clc
        adc #40
        sta colram
        sta vidram
        bcc +
        inc colram + 1
        inc vidram + 1
+
        inx
        cpx diskdata.file_type_count
        bne --
        rts
.pend   ; }}}

; {{{ void      select_file_type(void)
; Display file type list
;
; XXX: doesn't handle > 18 entries yet!
select_file_type .proc

        lda diskdata.file_type_index
        sta diskdata.file_type_selector_index

        jsr render_file_type_list
        jsr render_file_type_selection

_sft_event_loop
        jsr K_GETIN
        cmp #0
        beq _sft_event_loop

        cmp #$91
        bne +
        ; UP
        lda diskdata.file_type_selector_index
        beq _sft_event_loop
        dec diskdata.file_type_selector_index
        jmp _sft_update_selection
+
        cmp #$11
        bne +
        lda diskdata.file_type_selector_index
        clc
        adc #1
        cmp diskdata.file_type_count
        bcs _sft_event_loop
        sta diskdata.file_type_selector_index
        jmp _sft_update_selection
+
        cmp #$0d
        bne +
        lda diskdata.file_type_selector_index
        sta diskdata.file_type_index
        jmp _sft_exit
+
        cmp #$03
        bne _sft_event_loop

_sft_exit
        jsr render_menu_text
        jsr render_device_number
        jsr render_file_type
        rts
_sft_update_selection
        jsr render_file_type_list
        jsr render_file_type_selection
        jmp _sft_event_loop
.pend   ; }}}

; {{{ void      clear_dir_area(void)
; Clear the directory contents area
clear_dir_area .proc
        vidram = DISKMENU_ZP + 10
        colram = DISKMENU_ZP + 12

        lda #$78
        ldx #$04
        ldy #$d8
        sta vidram
        stx vidram + 1
        sta colram
        sty colram + 1

        ldx #18
_cda_more
        ldy #1
-       lda #$20
        sta (vidram),y
        lda #$0f
        sta (colram),y
        iny
        cpy #4
        bne -

        iny
-       lda #$20
        sta (vidram),y
        lda #$0f
        sta (colram),y
        iny
        cpy #21
        bne -

        iny
-       lda #$20
        sta (vidram),y
        lda #$0f
        sta (colram),y
        iny
        cpy #27
        bne -

        lda vidram
        clc
        adc #40
        sta vidram
        sta colram
        bcc +
        inc vidram + 1
        inc colram + 1
+
        dex
        bpl _cda_more
        rts
.pend   ; }}}

; {{{ void      render_dir_contents(void)
; Render the directory contents on screen
render_dir_contents .proc

        buffer = DISKMENU_ZP
        vidram = DISKMENU_ZP + 2
        lines = DISKMENU_ZP + 4

        ; get pointer to first entry
        lda dir_entry_offset
        jsr diskutil.mul_byte_24
        sta buffer
        txa
        clc
        adc diskdata.dir_buffer
        sta buffer + 1

        ; determine number of lines to render
        lda dir_entry_count
.if DISKMENU_DEBUG
        sta $0400
.endif
        bne +
        rts
+
        sec
        sbc dir_entry_offset
        cmp #19
        bcc +
        lda #19
+       sta lines

        ; setup pointer to first line (-1 for the |)
        lda #$78
        ldx #$04
        sta vidram
        stx vidram + 1

        ; determine if the buffer is 'under' the KERNAL area ($e000+)
        lda diskdata.dir_buffer
        cmp #$e0
        bcc +
        sei
        lda $01
        pha
        lda #$35
        sta $01
+

_rdc_more
        ; blocks
        ldy #0
        lda (buffer),y
        tax
        iny
        lda (buffer),y
        tay
        jsr diskutil.decimal_digits
        jsr diskutil.decimal_digits_left_align
        ldy #1
        ldx #0
-       lda diskutil.decimal_result,x
        sta (vidram),y
        iny
        inx
        cpx #3
        bne -

        ; filename
        lda buffer
        clc
        adc #2
        sta _name + 1
        lda buffer + 1
        adc #0
        sta _name + 2

        ldy #5
        ldx #0
-
_name   lda $fce2,x
        jsr diskutil.petscii_to_screen
        sta (vidram),y
        inx
        iny
        cpx #16
        bne -

        ; file type and locked/closed indicators
        lda buffer
        clc
        adc #18
        sta _ftype + 1
        lda buffer + 1
        adc #0
        sta _ftype + 2
        ldx #0
-
        iny
_ftype  lda $fce2,x
        jsr diskutil.petscii_to_screen
        sta (vidram),y
        inx
        cpx #5
        bne -

        lda buffer
        clc
        adc #$18
        sta buffer
        bcc +
        inc buffer + 1
+
        lda vidram
        clc
        adc #40
        sta vidram
        bcc +
        inc vidram + 1
+
        dec lines
        bne _rdc_more

        lda diskdata.dir_buffer
        cmp #$e0
        bcc +
        pla
        and #$07
        ora #$30
        sta $01
        cli
+
        rts
.pend   ; }}}

; {{{ void      render_dir_selection(void)
; Display currently selection directory entry by inverting its case
;
render_dir_selection .proc
        vidram = DISKMENU_ZP

        lda dir_entry_row
        jsr diskutil.mul_byte_40
        clc
        adc #$7d
        sta vidram
        txa
        adc #$04
        sta vidram + 1

        ldy #$0f
-       lda (vidram),y
        ora #$80
        sta (vidram),y
        dey
        bpl -
        rts
.pend   ; }}}

; {{{ (C)       load_file_browser(void)
;
; Load a file through a directory browser dialog
;
; Returns:      C: clear if file selected, set if aborted
;
load_file_browser .proc

        ; zp+0 - zp+5 are used by render_dir_contents()
        bufend = DISKMENU_ZP + 6
        tmp = DISKMENU_ZP + 8

        jsr diskio.read_dir
        bcc +
        rts
+
        sta dir_entry_count
        stx bufend
        sty bufend + 1

;        jsr clear_status_area
        jsr clear_dir_area
        lda dir_entry_count
        bne +
        ldx #0
-       lda empty_disk_text,x
        sta $047d,x
        inx
        cpx #16
        bne -
        rts
+
        lda #0
        sta dir_entry_offset
        jsr render_dir_contents

        lda #0
        sta dir_entry_row

        ; determine number of valid rows inside the frame
        lda dir_entry_count
        cmp #18
        bcs +
        sec
        sbc #1
        jmp ++
+       lda #18
+       sta dir_row_max


        jsr render_dir_selection

        ; event handler
        ; TODO: add file type selection with 'F' once that is implemented
_lfb_event_loop
        jsr K_GETIN
        cmp #0
        beq _lfb_event_loop

        cmp #$03        ; STOP
        bne _lfb_check_up

        jsr render_aborted_message
        sec     ; cancel
        rts
_lfb_check_up
        cmp #$91        ; CRSR UP
        bne _lfb_check_down

        lda dir_entry_row
        beq +
        dec dir_entry_row
        jmp ++
+
        lda dir_entry_offset
        beq _lfb_event_loop
        dec dir_entry_offset
+
        jsr render_dir_contents
        jsr render_dir_selection


        jmp _lfb_event_loop

_lfb_check_down
        cmp #$11        ; CRSR DOWN
        bne _lfb_check_return


        lda dir_entry_row
        cmp dir_row_max
        bcc _lfb_cd_down_one_row

        lda dir_row_max
        cmp #18
        bcs +
        jmp _lfb_event_loop
+
        lda dir_entry_count
        sec
        sbc dir_entry_offset
        cmp #20
        bcc +

        inc dir_entry_offset
+
        jmp +

_lfb_cd_down_one_row
        inc dir_entry_row

+
        jsr render_dir_contents
        jsr render_dir_selection

        jmp _lfb_event_loop

_lfb_check_return
        cmp #$0d        ; RETURN
        bne _lfb_event_loop

        ; Grab file name and file name length
        lda dir_entry_offset
        clc
        adc dir_entry_row
        jsr diskutil.mul_byte_24
        sta tmp
        txa
        clc
        adc diskdata.dir_buffer
        sta tmp + 1

        lda diskdata.dir_buffer
        cmp #$e0
        bcc +
        sei
        lda $01
        pha
        lda #$35
        sta $01
+

        ldy #2
        ldx #0
-       lda (tmp),y
        sta diskdata.file_name_buf,x
        iny
        inx
        cpx #16
        bne -
        ldy #23
        lda (tmp),y
        sta diskdata.file_name_len

        lda diskdata.dir_buffer
        cmp #$e0
        bcc +
        pla
        and #$07
        ora #$30
        sta $01
        cli
+

        jsr clear_status_area
        ldx #0
-       lda file_loading_text,x
        sta $0799,x
        inx
        cpx #file_loading_text_end - file_loading_text
        bne -
        lda #$22
        sta $0799,x
        inx
        ldy #0
-       lda diskdata.file_name_buf,y
        jsr diskutil.petscii_to_screen
        sta $0799,x
        inx
        iny
        cpy diskdata.file_name_len
        bne -
        lda #$22
        sta $0799,x

        lda diskdata.callback_load
        sta _cb_exec + 1
        lda diskdata.callback_load + 1
        sta _cb_exec + 2

        lda diskdata.file_name_len
        ldx #<diskdata.file_name_buf
        ldy #>diskdata.file_name_buf + 1

.if DISKMENU_DEBUG
        stx $0500
        sty $0501
        sta $0502
.endif
        clc     ; OK
_cb_exec jsr $fce2
        rts
.pend   ; }}}

; {{{ void      save_file_handler(A,X,Y)
; Request a filename for saving and trigger the callback on "Return"
;
; If an empty filename is given, or STOP is pressed, the operation is aborted
; and the main event loop is entered again.
;
; Output:       A: filename length
;               X; filename LSB
;               Y: filename MSB
save_file_handler .proc

        index = DISKMENU_ZP

        jsr clear_status_area
        ldx #0
-       lda save_file_text,x
        sta $0799,x
        lda #$0f
        sta $db99,x
        inx
        cpx #save_file_text_end - save_file_text
        bne -
        lda #0
        sta index

        lda #$a0
        sta $0799 + 16

_sfh_getin
        jsr K_GETIN
        cmp #$03
        bne +
_sfh_abort
        ; STOP pressed
        jsr render_aborted_message
        sec
        rts
+
        cmp #$0d
        bne +
        ; RETURN pressed
        lda index
        beq _sfh_abort
        ldx #0
-       lda $0799 + 16,x
        jsr diskutil.screen_to_petscii
        sta diskdata.file_name_buf,x
        inx
        cpx index
        bne -

        lda diskdata.callback_save
        sta _sfh_exec + 1
        lda diskdata.callback_save + 1
        sta _sfh_exec + 2

        lda index
        ldx #<diskdata.file_name_buf
        ldy #>diskdata.file_name_buf
        ; trigger callback
_sfh_exec
        jsr $fce2
        rts
+
        cmp #$14
        bne +
        ; DELETE pressed
        ldx index
        beq _sfh_getin
        lda #$20
        sta $0799 + 16,x
        lda #$a0
        sta $0799 + 15,x
        dec index
        jmp _sfh_getin
+
        cmp #$20
        bcc _sfh_getin
        cmp #$80
        bcs _sfh_getin

        ldx index
        inx
        cpx #16
        beq _sfh_getin
        jsr diskutil.petscii_to_screen
        sta $0799 + 15,x
        lda #$a0
        sta $0799 + 16,x
        inc index
        jmp _sfh_getin
.pend   ; }}}

; {{{ void      exit_menu(void)
;
; Handler for exit menu (STOP)
;
; Jumps to the callback, so not a clean exit
;
exit_menu .proc
        ldx #<exit_text
        ldy #>exit_text
        jsr prompt_yesno
        bcc +
        rts
+       lda diskdata.callback_exit
        sta $0334
        lda diskdata.callback_exit + 1
        sta $0335
        jmp ($0334)
.pend   ; }}}


;------------------------------------------------------------------------------
; Main event handling loop
;------------------------------------------------------------------------------

; {{{ void      event_loop(void)
event_loop .proc
        jsr K_GETIN
        cmp #0
        beq event_loop
        ldx #0
_more
        cmp event_handlers,x
        beq _do_event
        inx
        inx
        inx
        inx
        cpx #event_handlers_end - event_handlers
        bne _more
        jmp event_loop
_do_event
        lda event_handlers + 2,x
        sta _exec + 1
        lda event_handlers + 3,x
        sta _exec + 2
_exec   jsr $fec2

        ; todo: handle any extra events specified in the flags of the event
        jmp event_loop
.pend   ; }}}

