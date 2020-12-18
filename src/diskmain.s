; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; Diskmenu - main


;------------------------------------------------------------------------------
; The entire diskmenu and its data and constants live in the 'diskmenu' scope
;------------------------------------------------------------------------------

        ; Enable/disable some debugging code
        DISKMENU_DEBUG = false

        ; Zero page used by the diskmenu
        DISKMENU_ZP = $10

        ; The MSB of the directory buffer
        DEFAULT_DIR_BUFFER = $e0

;------------------------------------------------------------------------------
; KERNAL calls - not all of these are used, but let's declare 'em all anyway
;------------------------------------------------------------------------------
        K_SCINIT = $ff81
        K_IOINIT = $ff84
        K_RAMTAS = $ff87
        K_RESTOR = $ff8a
        K_VECTOR = $ff8d
        K_SETMSG = $ff90
        K_LSTNSA = $ff93
        K_TALKSA = $ff96
        K_MEMBOT = $ff99
        K_MEMTOP = $ff9c
        K_SCNKEY = $ff9f
        K_SETTMO = $ffa2
        K_IECIN  = $ffa5
        K_IECOUT = $ffa8
        K_UNTALK = $ffab
        K_UNLSTN = $ffae
        K_LISTEN = $ffb1
        K_TALK   = $ffb4
        K_READST = $ffb7
        K_SETLFS = $ffba
        K_SETNAM = $ffbd
        K_OPEN   = $ffc0
        K_CLOSE  = $ffc3
        K_CHKIN  = $ffc6
        K_CHKOUT = $ffc9
        K_CLRCHN = $ffcc
        K_CHRIN  = $ffcf
        K_CHROUT = $ffd2
        K_LOAD   = $ffd5
        K_SAVE   = $ffd8
        K_SETTIM = $ffdb
        K_RDTIM  = $ffde
        K_STOP   = $ffe1
        K_GETIN  = $ffe4
        K_CLALL  = $ffe7
        K_UDTIM  = $ffea
        K_SCREEN = $ffed
        K_PLOT   = $fff0
        K_IOBASE = $fff3


;------------------------------------------------------------------------------
; Jumps into the diskmenu for easier access when using the diskmenu as a
; preassembled binary blob.
;------------------------------------------------------------------------------

        ; Aliases to allow using `diskmenu.$some_function`
        set_start_address       = diskio.set_start_address
        set_end_address         = diskio.set_end_address
        set_file_name           = diskio.set_file_name
        get_file_name           = diskio.get_file_name
        load_file               = diskio.load_file
        load_file_verbose       = diskio.load_file_verbose
        save_file               = diskio.save_file
        save_file_verbose       = diskio.save_file_verbose


        jmp exec
        jmp set_callbacks
        jmp set_file_types
        jmp set_start_address
        jmp set_end_address
        jmp set_file_name
        jmp get_file_name
        jmp get_file_type
        jmp load_file
        jmp load_file_verbose
        jmp save_file
        jmp save_file_verbose


;------------------------------------------------------------------------------
; Data section used by the disk menu - contains both variable and static data
;------------------------------------------------------------------------------
diskdata .block

; Callback functions

callbacks_table

callback_load   .word 0
callback_save   .word 0
callback_exit   .word 0

callbacks_table_end


; MSB of the memory to use for the directory buffer
;
; Using a 1541/1571 drive, there will 144 + 1 (blocks free line) entries max.
; Each entry is 24 bytes, so a buffer must be able to contain $0d98 bytes.
;
; Using a 1581, there will be 296 + 1 (blocks free line) entries max. So the
; buffer must be able to hold $1bd8 bytes. The 1581 is a TODO at the moment,
; since the entries count is a byte, so after 256 entries, the counter wraps
; around to 0.
dir_buffer      .byte diskmenu.DEFAULT_DIR_BUFFER

file_type_list  .word 0

file_type_count .byte 0

file_type_index .byte 0
file_type_selector_index
                .byte 0

start_address   .word 0         ; start address for loading/saving
end_address     .word 0         ; end address for saving

file_name_ptr   .word 0         ; pointer to PETSCII file name
file_name_len   .byte 0         ; length of PETSCII file name

file_name_buf   .fill 16, 0


; Device number: 8-11
device_number   .byte 8

; Version string of the disk menu
version_string
        .enc "screen"
        .text "dmenu 1.0.0"
        .enc "none"

; Device numbers in screencodes for fast and easy rendering
dev_numbers
        .enc "screen"
        .text "8 9 1011"
        .enc "none"


; Top of the menu frame
menu_frame_top
        .enc "screen"
        .byte $70
        .fill 3, $40
        .byte $72
        .fill 16, $40
        .byte $72
        .fill 5, $40
        .byte $72
        .fill 11, $40
        .byte $6e
        .enc "none"

; Top frame split of the menu
menu_frame_split_top
        .enc "screen"
        .byte $6b
        .fill 3, $40
        .byte $5b
        .fill 16, $40
        .byte $5b
        .fill 5, $40
        .byte $5b
        .fill 11, $40
        .byte $73
        .enc "none"

; Bottom frame split of the menu
menu_frame_split_bottom
        .enc "screen"
        .byte $6b
        .fill 3, $40
        .byte $71
        .fill 16, $40
        .byte $71
        .fill 5, $40
        .byte $71
        .fill 11, $40
        .byte $73

; The menu text must be 11 characters per line, $f0-$ff sets the color and is
; not counted against the 11 chars per line
menu_text
        .enc "screen"
        .text $f1, "f", $ff, "ile type: "
        .text $f7, "-----------"
        .fill 11, " "
        .text $f1, "l", $ff, "oad file  "
        .text $f1, "s", $ff, "ave file  "
        .fill 11, " "
        .text $f1, "d", $ff, "evice#: ", $f7, "--"
        .text $ff, "dev. s", $f1, "t", $ff, "atus"
        .enc "none"
menu_text_end

; Message for 'device not ready'
device_not_ready
        .enc "screen"
        .text "device not present error"
        .enc "none"
device_not_ready_end


; end 'diskmenu.data' block
.bend


;------------------------------------------------------------------------------
; I/O routines sub module
;------------------------------------------------------------------------------
diskio .binclude "diskio.s"

;------------------------------------------------------------------------------
; Main event loop and event handlers
;------------------------------------------------------------------------------
diskevents .binclude "diskevents.s"

;------------------------------------------------------------------------------
; Utility functions: calculations and conversions
;------------------------------------------------------------------------------
diskutil .binclude "diskutil.s"




; Clear the screen
clear_screen .proc
        ldx #0
-       lda #$0e
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        lda #$20
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $06e8,x
        inx
        bne -
        rts
.pend


; Render the default menu text
render_menu_text .proc

        vidram = DISKMENU_ZP
        colram = DISKMENU_ZP + 2
        color = DISKMENU_ZP + 4

        lda #$94
        ldx #$04
        ldy #$d8
        sta vidram
        sta colram
        stx vidram + 1
        sty colram + 1

        ldy #0

        ldx #0
-
        lda diskdata.menu_text,x
        cmp #$f0
        bcc +
        and #$0f
        sta color
        inx
        lda diskdata.menu_text,x
+       sta (vidram),y
        lda color
        sta (colram),y
        iny
        cpy #11
        bne ++
        lda vidram
        clc
        adc #40
        sta vidram
        sta colram
        bcc +
        inc vidram + 1
        inc colram + 1
+
        ldy #0
+

        inx
        cpx #diskdata.menu_text_end - diskdata.menu_text
        bcc -
        rts
.pend


; Render the device number in the menu
render_device_number .proc
        lda diskdata.device_number
        and #3
        asl a
        tax
        lda diskdata.dev_numbers,x
        sta $058d
        lda diskdata.dev_numbers + 1,x
        sta $058e
        rts
.pend


render_file_type .proc

        ftlist = DISKMENU_ZP + 10

        ; check for 0 entries
        lda diskdata.file_type_count
        bne +
        rts
+       ; check for `NULL` pointer
        lda diskdata.file_type_list
        ora diskdata.file_type_list
        bne +
        rts
+
        lda diskdata.file_type_index
        jsr diskutil.mul_byte_11
.if DISKMENU_DEBUG
        sta $0410
        stx $0411
.endif
        clc
        adc diskdata.file_type_list
        sta ftlist
        txa
        adc diskdata.file_type_list + 1
        sta ftlist + 1

        ldy #10
-       lda (ftlist),y
        sta $04bc,y
        dey
        bpl -
        rts
.pend


; Set up the menu screen frame
setup_screen .proc

        vidram = DISKMENU_ZP

        jsr clear_screen
        ldx #39
-       lda diskdata.menu_frame_top,x
        sta $0400,x
        dex
        bpl -

        ; generate vertical frame lines
        lda #$28
        ldx #$04
        sta vidram
        stx vidram + 1

        ldx #20
-
        lda #$5d
        ldy #0
        sta (vidram),y
        ldy #4
        sta (vidram),y
        ldy #21
        sta (vidram),y
        ldy #27
        sta (vidram),y
        ldy #39
        sta (vidram),y

        lda vidram
        clc
        adc #40
        sta vidram
        bcc +
        inc vidram + 1
+       dex
        bpl -

        ; add top and bottom frame splits
        ldx #39
-       lda diskdata.menu_frame_split_top,x
        sta $0450,x
        lda diskdata.menu_frame_split_bottom,x
        sta $0770,x
        dex
        bpl -

        lda #$5d
        sta $0798
        sta $07bf
        lda #$6d
        sta $07c0
        lda #$7d
        sta $07e7
        ldx #38
        lda #$40
-       sta $07c0,x
        dex
        bne -

        ldx #10
-       lda diskdata.version_string,x
        sta $0444,x
        lda #1
        sta $d844,x
        dex
        bpl -

        rts
.pend


; Setup callbacks
;
; @param X      callback table LSB
; @param Y      callback table MSB
;
set_callbacks .proc
        cbt = DISKMENU_ZP

        stx cbt
        sty cbt + 1
        ldy #0
-       lda (cbt),y
        sta diskdata.callbacks_table,y
        iny
        cpy #diskdata.callbacks_table_end - diskdata.callbacks_table
        bne -
        rts
.pend


; @brief        Set file types/formats
;
; @param A      number of file types/formats
; @param X      LSB of file format table
; @param Y      MSB of file format table
;
; @note         The table is expected to be a list of file format names in
;               screen codes, 11 bytes per entry (fixed)
set_file_types .proc
        sta diskdata.file_type_count
        stx diskdata.file_type_list
        sty diskdata.file_type_list + 1
        rts
.pend

get_file_type .proc
        lda diskdata.file_type_index
        rts
.pend


; Disk menu entry point
exec .proc
        sei
        ldx #$ff
        txs
        lda #$36
        sta $01
        cld
        jsr kernal.k_restor_fixed
        jsr K_IOINIT
        jsr K_SCINIT
        lda #0
        sta $d020
        lda #6
        sta $d021
        jsr setup_screen
        jsr render_menu_text
        jsr render_device_number
        jsr render_file_type
        cli
        jmp diskevents.event_loop
.pend

