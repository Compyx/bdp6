; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - dialog data


; @brief        Table of available dialogs
;
; @note         This is *not* the same as the DLG_TYPE_* dialog enum, this is
;               a table of all dialogs, each of which can have one of the
;               DLG_TYPE_* types controlling its behaviour
;
dialogs_table
        .word start_dialog
        .word help_dialog
        .word color_clash_dialog
        .word init_buffer_dialog
        .word operations_dialog


; @brief        Short dialog shown when booting BDP6
;
start_dialog
        .byte 30, 8, $e6, dialogs.DLG_TYPE_INFO
        ; title
        .byte $16
        .enc "screen"
        .text "BDP 6.0.0", 0
        ; text
        .text $80
        .text $ff, "Welcome to ", $f1, "Boogie Down Paint 6", $80, $80
        .text $ff, "Press ", $f7, "F1", $ff, " during editing for", $80
        .text $ff, "help.", $80, $80
        .text "Press any key to continue."
        .byte 0
        .enc "none"


; @brief        Built-in help dialog
;
; @todo         Allow for text scrolling in dialog boxes so I can display more
;               text
help_dialog
        ; dimensions, color and dialog type
        .byte 38, 20, $e6, dialogs.DLG_TYPE_INFO
        ; title
        .byte $16
        .enc "screen"
        .text "BDP 6 help", 0
        ; text
        .text $ff, "Important keys:", $80, $80

        .text $f7, "STOP", $ff, "  cancel/exit dialog/exit screen", $80, $80
        .text $f7, "F1", $ff, "  display help (this screen)", $80
        .text $f7, "F3", $ff, "  switch zoom mode (full/preview)", $80
        .text $f7, "F5", $ff, "  switch image buffer", $80
        .text $f7, "F7", $ff, "  enter disk menu", $80, $80
        .text $f7, "Return", $ff, "  show current buffer", $80
        .text $f7, "Space ", $ff, "  plot pixel", $80
        .text $f7, "Cursor", $ff, "  move pixel cursor", $80
        .text $f7, "a", $ff, "-", $f7, "p", $ff, "     select color", $80
        .text $f7, dialogs.F_SHIFT, dialogs.F_SHIFT + 1, $ff, "+", $f7, "g"
        .text $ff, "    change grid color", $80
        .text $f7, "A", $ff, "/", $f7, "B", $ff, "  "
        .text "set mark ", $f1, "A", $ff, "/", $f1, "B", $80
        .text $f7, "C", $ff, "         clear marked area (chars)", $80
        .text $f7, "V", $ff, "         copy marked area (chars)"
        .byte 0
        .enc "none"

color_clash_dialog
        .byte 24, 6, $a2, dialogs.DLG_TYPE_COLOR_CLASH
        .enc "screen"
        .text $12, "Color clash", 0
        .text $ff, "Select color to replace", $80
        .text "or press ", $f1, "STOP", $ff, " to cancel.", 0
        .enc "none"



init_buffer_dialog
        .byte 24, 10, $f6, dialogs.DLG_TYPE_BITPAIRS
        .enc "screen"
        .text $16, "Initialize buffer", 0
        .text $ff, "Select colors and/or", $80
        .text "bitpair locks"
        .text 0
        .enc "none"

operations_dialog
        .byte 30, 12, $f6, dialogs.DLG_TYPE_INFO
        .enc "screen"
        .text $16, "Choose an operation:", 0

        .text $f7, "I    ", $ff, "initialize image", $80

        .text 0



