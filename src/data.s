; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - data section - both variable and constant
;

; {{{ Variable data

; Initialization that needs to be done once has happened
init_done       .byte 0
; Welcome screen shown
welcome_shown   .byte 0

; Dialogs active: disable grid
dialogs_active  .byte 0

; Current buffer (either 0 or 1)
buffer_index    .byte 0

view_offset     .byte 0         ; offset in bitmap of view area
view_index      .byte 0         ; index of the zoom area in the view
                                ; (determines placement of sprites)
markA_xpos      .byte 0
markA_ypos      .byte 0
markA_buffer    .byte 0
markB_xpos      .byte 159
markB_ypos      .byte 199
markB_buffer    .byte 1



; Zoom mode (either 0 or 1)
zoom_mode       .byte 0

zoom_xpos       .byte 0
zoom_ypos       .byte 0

cursor_xpos     .byte 0
cursor_ypos     .byte 0

cursor_color    .byte 0         ; Paint color: 00-0f (selected with a-p)
color_clash_mode
                .byte 0         ; 0 = pop up dialog
                                ; 1 = select least used bitpair
                                ; 2 = select bitpair under cursor

zoom_temp_bmp   .fill 8, 0
zoom_temp_col   .fill 4, 0

grid_color      .byte 6
grid_color_index
                .byte 1

key_code        .byte 0
key_flags       .byte 0


; Status line text
status_text
        .enc "screen"
        .text "000,000 00,00 "          ; 0-13
        .byte $70, $71, $7d, $20        ; 14-17
        .byte $70, $73, $7d, $20        ; 18-21
        .byte $72, $71, $7d, $20        ; 22-25
        .byte $72, $73, $7d, $20        ; 26-29
        .text "buf:0 "                  ; 30-35
        .text "c:", $75, $76

; Status line vidram
status_color
        .fill 40, $16

; Lower border text
lborder_text
        ;      0123456789abcdef01234567
        .text "markA 000,000 00,00 buf1"
        .text "markB 000,000 00,00 buf1"
; }}}

; Fixed data

bitmap_row_lsb
        .byte <(range(0, $1f40, $140))
bitmap_row_msb
        .byte >(range(0, $1f40, $140))

bitmap_col_lsb
        .byte <(range(0, $140, 8))
bitmap_col_msb
        .byte >(range(0, $140, 8))

screen_row_lsb
        .byte <(range(0, $03e8, 40))
screen_row_msb
        .byte >(range(0, $03e8, 40))

bits_mask
        .byte %11000000, %00110000, %00001100, %00000011

bits_mask_inv
        .byte %00111111, %11001111, %11110011, %11111100

bits_00
        .byte %00000000, %00000000, %00000000, %00000000
bits_01
        .byte %01000000, %00010000, %00000100, %00000001
bits_10
        .byte %10000000, %00100000, %00001000, %00000010
bits_11
        .byte %11000000, %00110000, %00001100, %00000011



cursor_color_table
        .fill 4, 1
        .byte $0d, $03, $0e, $04, $06
        .fill 4, 0
        .byte $06, $04, $0e, $03, $8d

grid_colors
        .byte 0, 6, 9, 11


sprite_xpos_lsb
        .byte $00, $01, $02, $40, $41, $42, $80, $81, $82, $c0, $c1, $c2
        .byte $00, $01, $02, $40, $41, $42, $80, $81, $82, $c0, $c1, $c2
sprite_xpos_msb
        .fill 12, 0
        .fill 12, 1


;------------------------------------------------------------------------------
; Data section for dialogs
;------------------------------------------------------------------------------

dlg_xpos        .byte 0         ; dialog xpos
dlg_ypos        .byte 0         ; dialog ypos
dlg_width       .byte 0         ; dialog width, excluding frame
dlg_height      .byte 0         ; dialog height, excluding frame
dlg_bg_color    .byte $06       ; current dialog background color
dlg_fg_color    .byte $0f       ; current dialog foreground color

dlg_type        .byte 0         ; dialog type
dlg_table       .word 0         ; pointers to the various dialogs

dlg_param_a     .byte 0
dlg_param_x     .byte 0
dlg_param_y     .byte 0


; Event handler for different types of dialogs
dialog_handlers
        .word dialogs.dh_render_only
        .word dialogs.dh_info
        .word dialogs.dh_color_clash
        .word dialogs.dh_color_select
        .word dialogs.dh_bitpairs


;------------------------------------------------------------------------------
; Data section for the disk menu
;------------------------------------------------------------------------------

; file formats table
dm_formats
        .enc "screen"
        .text "bdp 6.0.0  "
        .text "bdp 5.0-rc2"
        .text "bdp 4.0+   "
        .text "koala paint"
        .text "amica paint"
        .enc "none"
dm_formats_end


; callbacks for the disk menu
dm_callbacks
        .word events.dm_load_callback
        .word events.dm_save_callback
        .word events.dm_exit_callback

fname_len       .byte 0 ; lenght of file name
fname_ptr       .word 0 ; pointer to file name

