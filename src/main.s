; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - main
;
; TODO: clean up IRQ code
;


        ; Global debug flag
        DEBUG = true



; KERNAL calls
.include "kernal.inc"

; Generic macros
.include "macros.inc"


        ZOOM_MODE_FULL          = 0     ; full zoom mode: 40x24 chars zoom
        ZOOM_MODE_VIEW          = 1     ; view+zoom mode: 40x16 chars zoom +
                                        ; 40x8 view

        ; zero page addresses that are only guaranteed to be available inside
        ; a function/procedure
        ZP_TMP                  = $10

        ; more generic zero page addresses, careful when using these in nested
        ; function calls
        ZP                      = $20

        ; 204 bytes of temporary storage
        TEMP_SPACE              = $0334


        ; Total workspace constants
        WORKSPACE_START         = $5000
        WORKSPACE_END           = $7fff

        ; vidram used for the zoom/view and fullscreen buffer views
        WORKSPACE_VIDRAM        = $5c00
        ; bitmap used for the zoom/view and fullscreen buffer views
        WORKSPACE_BITMAP        = $6000
        WORKSPACE_BITMAP_END    = $7f40

        ; Buffer 1: $8000-$a7ff
        BUFFER1_BITMAP          = $8000
        BUFFER1_VIDRAM          = BUFFER1_BITMAP + $1f40
        BUFFER1_COLRAM          = BUFFER1_VIDRAM + $03e8
        BUFFER1_BGCOLOR         = BUFFER1_COLRAM + $03e8
        BUFFER1_START           = BUFFER1_BITMAP
        BUFFER1_END             = BUFFER1_BGCOLOR

        ; Buffer 2: $a800-$cfff
        BUFFER2_BITMAP          = $a800
        BUFFER2_VIDRAM          = BUFFER2_BITMAP + $1f40
        BUFFER2_COLRAM          = BUFFER2_VIDRAM + $03e8
        BUFFER2_BGCOLOR         = BUFFER2_COLRAM + $03e8
        BUFFER2_START           = BUFFER2_BITMAP
        BUFFER2_END             = BUFFER2_BGCOLOR

        ; Font
        EDITOR_FONT             = $4c00         ; $400 bytes
        ; Sprites for the zoom (pixel, char and corners for the view)
        EDITOR_SPRITES          = $4700         ; $180 bytes
        ; Sprites to display to grid over the zoom area
        GRID_SPRITES            = $4880         ; $380 bytes

        ; Sprite pointer for the pixel sprite
        EDITOR_SPRITE_PIXEL     = ((EDITOR_SPRITES & $3fff) / 64) + 0
        ; Sprite pointer for the char sprite
        EDITOR_SPRITE_CHAR      = ((EDITOR_SPRITES & $3fff) / 64) + 1
        ; Sprite pinter to the first 'corner' sprite used to display in the
        ; view what area of the view is being shown in the zoom area
        EDITOR_SPRITE_TOPLEFT   = ((EDITOR_SPRITES & $3fff) / 64) + 2

        ; Lower border sprites (8), for extra status text/help
        LBORDER_SPRITES         = $e000

        ; Top raster line, this where the first IRQ should trigger
        RASTER_TOP              = $1f


        ; LOAD ADDRESS
        * = $0801

        ; BASIC SYS line: "2017 sys${main_init}"
        .word (+)
        .word 2017
        .null $9e, format("%d", main_init)
+       .word 0

        jmp main_init

;------------------------------------------------------------------------------
; IRQ handlers for view + zoom - grid of 7*7 sprites
;------------------------------------------------------------------------------

; Set grid sprite Y positions
;
; Sets Y-pos for sprites 1-7
;
; @param A      new Y position
gspr_set_ypos .proc
        sta $d003
        sta $d005
        sta $d007
        sta $d009
        sta $d00b
        sta $d00d
        sta $d00f
        rts
.pend




; Set grid sprite pointers
;
; @param X      pointer for sprites 1, 3, 5 & 7
; @param Y      pointer for sprites 2, 4 & 6
;
gspr_set_ptrs .proc
        stx WORKSPACE_VIDRAM + $03f9
        sty WORKSPACE_VIDRAM + $03fa
        stx WORKSPACE_VIDRAM + $03fb
        sty WORKSPACE_VIDRAM + $03fc
        stx WORKSPACE_VIDRAM + $03fd
        sty WORKSPACE_VIDRAM + $03fe
        stx WORKSPACE_VIDRAM + $03ff
        rts
.pend

;------------------------------------------------------------------------------
; IRQ handlers used during view+zoom mode
;------------------------------------------------------------------------------

; Set the border and background color of the view
irq_view_pre
        ; determine delay required depending on what Y-pos the view sprites are
        .page
        ldx #13
        lda data.view_index
        cmp #2
        bcs +
        ldx #10
+
-       dex
        bpl -
        .endp
irqview_bgcolor
        lda #3
        sta $d020
        sta $d021

        ;lda $d010
        ;and #%0000001
        ;sta $d010
        ; goto first view-IRQ setting grid sprites
        #do_irq_macro $70, irq_view

irq_view
        ;
       .page
        ldx #$0f
-       dex
        bpl -
        .endp
        lda #$08
        sta $d016
;        lda data.grid_color
;        sta $d020
        lda #0
        sta $d020
        sta $d021

        lda data.dialogs_active
        beq +
        #do_irq_macro $f9, irq_dialogs_lborder
+
        ; TODO: do d015,d01d and d028-d02e setup somewhere else
        lda #$ff
        sta $d015
        lda #$fe
        sta $d01d

        lda data.grid_color
        sta $d028
        sta $d029
        sta $d02a
        sta $d02b
        sta $d02c
        sta $d02d
        sta $d02e

        #set_grid_sprites_ypos $7a
        #set_grid_sprites_ptrs 0
        jsr set_grid_sprites_xpos


        #do_irq_macro $7a + 19, irq_view_row1

irq_view_row1
        #set_grid_sprites_ypos $7a + 21
        #set_grid_sprites_ptrs 2
        #do_irq_macro $7a + (2 *21) - 2, irq_view_row2

irq_view_row2
        #set_grid_sprites_ypos $7a + (2 * 21)
        .page
        ldx #9
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 0
        #do_irq_macro $7a + (3 * 21) -3, irq_view_row3

irq_view_row3
        #set_grid_sprites_ypos $7a + (3 * 21)
        .page
        ldx #9
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 4
        #do_irq_macro $7a + (4 * 21) - 2, irq_view_row4

irq_view_row4
        #set_grid_sprites_ypos $7a + (4 * 21)
        nop
        nop
        #set_grid_sprites_ptrs 6
        #do_irq_macro $7a + (5 * 21) -2, irq_view_row5

        .align 16
irq_view_row5
        #set_grid_sprites_ypos $7a + (5 * 21)
        .page
        ldx #9
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 0
        #do_irq_macro $7a + (6 * 21) - 2, irq_view_row6

        ; avoid page boundary cross in timing loop
        .align 16
irq_view_row6
        #set_grid_sprites_ypos $7a + (6 * 21)
        .page
        ldx #10
-       dex
        bpl -
        .endp
        ; last 2 pixels of grid
        #set_grid_sprites_ptrs 8

        lda #$53
        sta $d011
        dec $d020
        lda #6
        sta $d021
        lda #0
        sta $f9ff

        ldx #(LBORDER_SPRITES & $3fff) / 64
        stx $fbf8
        inx
        stx $fbf9
        inx
        stx $fbfa
        inx
        stx $fbfb
        inx
        stx $fbfc
        inx
        stx $fbfd
        inx
        stx $fbfe
        inx
        stx $fbff

        lda #$ff
        sta $d001

        lda #1
        sta $d027
        sta $d028
        sta $d029
        sta $d02a
        sta $d02b
        sta $d02c
        sta $d02d
        sta $d02e

        lda #$00
        sta $d01d
        ; lda #$00
        sta $dd00
        lda #$e0
        sta $d018

        lda #$58
        sta $d000
        lda #$70
        sta $d002
        lda #$88
        sta $d004
        lda #$a0
        sta $d006
        lda #$b8
        sta $d008
        lda #$d0
        sta $d00a
        lda #$e8
        sta $d00c
        lda #0
        sta $d00e
        lda #$80
        sta $d010
        lda #$ff
        sta $d015

        dec $d020
        jsr flash_cursor
        ldx #$30
-       dex
        bpl -
        inc $d020
        lda #$5b
        sta $d011
        inc $d020

        lda #RASTER_TOP
        ldx #<irq1
        ldy #>irq1
        sta $d012
        stx $0314
        sty $0315
        inc $d019
        jmp $ea31


;------------------------------------------------------------------------------
; IRQ handlers for full screen zoom - grid of 7*10 sprites
;------------------------------------------------------------------------------

irq_full_row1
        #set_grid_sprites_ypos $3a + (21 * 1)
        #set_grid_sprites_ptrs 2

        lda data.grid_color
        sta $d028
        sta $d029
        sta $d02a
        sta $d02b
        sta $d02c
        sta $d02d
        sta $d02e

        #do_irq_macro $3a + (2 * 21) - 3, irq_full_row2

        .align 16
irq_full_row2
        #set_grid_sprites_ypos $3a + (2 * 21)
        .page
        ldx #9
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 0
        #do_irq_macro $3a + (3 * 21) - 2, irq_full_row3

irq_full_row3
        #set_grid_sprites_ypos $3a + (3 * 21)
        nop
        #set_grid_sprites_ptrs 4
        #do_irq_macro $3a + (4 * 21) - 2, irq_full_row4

irq_full_row4
        #set_grid_sprites_ypos $3a + (4 * 21)
        .page
        ldx #1
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 6
        #do_irq_macro $3a + (5 * 21) - 2, irq_full_row5

irq_full_row5
        #set_grid_sprites_ypos $3a + (5 * 21)
        .page
        ldx #7
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 0
        #do_irq_macro $3a + (6 * 21) - 2, irq_full_row6

irq_full_row6
        #set_grid_sprites_ypos $3a + (6 * 21)
        .page
        ldx #3
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 10
        #do_irq_macro $3a + (7 * 21) - 2, irq_full_row7

irq_full_row7
        #set_grid_sprites_ypos $3a + (7 * 21)
        .page
        ldx #1
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 6
        #do_irq_macro $3a + (8 * 21) - 2, irq_full_row8

irq_full_row8
        #set_grid_sprites_ypos $3a + (8 * 21)
        .page
        ldx #7
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 0
        #do_irq_macro $3a + (9 * 21) - 2, irq_full_row9

irq_full_row9
        #set_grid_sprites_ypos $3a + (9 * 21)
        .page
        ldx #18
-       dex
        bpl -
        .endp
        #set_grid_sprites_ptrs 12
        ldx #$03
-       dex
        bpl -
        lda #$33
        sta $d011
        dec $d020
        ldx #(LBORDER_SPRITES & $3fff) / 64
        stx $fbf8
        inx
        stx $fbf9
        inx
        stx $fbfa
        inx
        stx $fbfb
        inx
        stx $fbfc
        inx
        stx $fbfd
        inx
        stx $fbfe
        inx
        stx $fbff

        lda #$ff
        sta $d001

        lda #1
        sta $d027
        sta $d028
        sta $d029
        sta $d02a
        sta $d02b
        sta $d02c
        sta $d02d
        sta $d02e

        lda #$00
        sta $d01d
        ; lda #$00
        sta $dd00
        lda #$e0
        sta $d018

        lda #$58
        sta $d000
        lda #$70
        sta $d002
        lda #$88
        sta $d004
        lda #$a0
        sta $d006
        lda #$b8
        sta $d008
        lda #$d0
        sta $d00a
        lda #$e8
        sta $d00c
        lda #0
        sta $d00e
        lda #$80
        sta $d010
        lda #$ff
        sta $d015

        ldx #$20
-       dex
        bpl -
        lda #$3b
        sta $d011
        inc $d020

        lda #$ff
        sta $d015

        lda #0
        sta $7fff
        lda #6
        sta $d021

        dec $d020
        jsr flash_cursor

        inc $d020

        lda #RASTER_TOP
        ldx #<irq1
        ldy #>irq1
        sta $d012
        stx $0314
        sty $0315
        inc $d019
        jmp $ea31


;------------------------------------------------------------------------------
; IRQ handlers used during dialogs: grid sprites and cursor sprite disabled
;------------------------------------------------------------------------------

irq_dialogs
        lda #$00
        sta $d015

        #do_irq_macro $f9, irq_dialogs_lborder

irq_dialogs_lborder
        lda #$33
        sta $d011
        ldx #$60
-       dex
        bpl -
        lda #$3b
        sta $d011

        lda #RASTER_TOP
        ldx #<irq1
        ldy #>irq1
        sta $d012
        stx $0314
        sty $0315
        inc $d019
        jmp $ea31


; Setup sprites for the view
set_view_sprites
        lda #5
        sta $d020
        lda data.zoom_xpos
        asl a
        asl a
        asl a
        clc
        adc #$17
        sta $d002
        sta $d006
        clc
        adc #(9 * 8) + 1
        sta $d004
        sta $d008

        lda $d010
        and #%00000001
        ldx data.zoom_xpos
        cpx #30
        bcc +
        ora #%00011110
+       cpx #20
        bcc +
        ora #%00010100
+       sta $d010

        lda data.view_index
        asl a
        asl a
        asl a
        clc
        adc #$25
        sta $d003
        sta $d005
        clc
        adc #$19
        sta $d007
        sta $d009
        ldx #EDITOR_SPRITE_TOPLEFT
        stx WORKSPACE_VIDRAM + $03f9
        inx
        stx WORKSPACE_VIDRAM + $03fa
        inx
        stx WORKSPACE_VIDRAM + $03fb
        inx
        stx WORKSPACE_VIDRAM + $03fc
        lda #1
        sta $d028
        sta $d029
        sta $d02a
        sta $d02b
        lda #0
        sta $d020
        rts


;------------------------------------------------------------------------------
; Base functionality
;------------------------------------------------------------------------------
base    .binclude "base.s"

;------------------------------------------------------------------------------
; Data section, contains both variable and constant data
;------------------------------------------------------------------------------
data    .binclude "data.s"
dialogs .binclude "dialogs.s"
dialog_data .binclude "dialog_data.s"
diskmenu .binclude "diskmain.s"
edit    .binclude "edit.s"
events  .binclude "events.s"
formats .binclude "formats.s"
rle     .binclude "rle.s"
status  .binclude "status.s"
zoom    .binclude "zoom.s"

; Initialize data once
init_data .proc
        lda data.init_done
        beq +
        rts
+
        lda #0
        sta data.buffer_index
        lda #ZOOM_MODE_VIEW
        sta data.zoom_mode

        inc data.init_done
        rts
.pend


; Main entry point
main_init
        ldx #$ff
        txs
        lda #$37
        sta $01
        cld
        jsr K_RESTOR
        jsr K_IOINIT
        jsr K_SCINIT
        ; ^ one of those resets $01
        lda #$36
        sta $01

        sei
        lda #$0b
        sta $d020
        sta $d021

        lda #RASTER_TOP
        ldx #<irq1
        ldy #>irq1
        sta $d012
        stx $0314
        sty $0315

        lda #$7f
        sta $dc0d
        lda #0
        sta $dc0e
        lda #1
        sta $d01a

        ; ack IRQ's
        lda $dc0d
        lda $dd0d
        inc $d019

        lda #RASTER_TOP
-       cmp $d012
        bne -
        cli

        jsr init_data
        ldx #<dialog_data.dialogs_table
        ldy #>dialog_data.dialogs_table
        jsr dialogs.init
        jsr status.clear_lborder_sprites
        jsr status.render_lborder_sprites
        jsr zoom.init_grid
        jsr zoom.zoom_full
        lda data.zoom_mode
        beq +
        jsr zoom.render_view
+
        jsr status.render_status

        ; display zoom grid
        lda #2
        sta $dd00
        lda #8
        sta $d016
        lda #$78
        sta $d018
        lda #$3b
        sta $d011

;        lda #$36
;        sta $01

        lda #((EDITOR_SPRITES & $3fff) / 64)
        sta WORKSPACE_VIDRAM + $03f8
        lda #1
        sta $d027
        sta $d015
        lda #$17
        sta $d000
        lda #$2a
        sta $d001

        ; text marks
        jsr status.update_marks

        lda data.welcome_shown
        bne +
        ; show welcome dialog
        lda #0
        ldx #4
        ldy #12
        jsr dialogs.show_dialog
        lda #1
        sta data.welcome_shown
+

        jmp events.main_loop


;------------------------------------------------------------------------------
; IRQ just above the first screen row - setup view/zoom sprites
;------------------------------------------------------------------------------
irq1
        lda #$3b
        sta $d011
        lda #6
        sta $d021
        dec $d020
        lda $d010
        and #$fe
        sta $d010
        lda data.cursor_ypos
        clc
        asl a
        asl a
        ldx data.zoom_mode
        beq +
        adc #$6a
        bne ++
+       adc #$2a
+       sta $d001
        lda data.cursor_xpos
        asl a
        asl a
        asl a
        clc
        adc #$17
        sta $d000
        lda data.cursor_xpos
        cmp #30
        bcc +
        lda $d010
        ora #1
        sta $d010
+
        lda #EDITOR_SPRITE_PIXEL
        sta WORKSPACE_VIDRAM + $3e8
cursor_color
        lda #1
        sta $d027


        lda #$02
        sta $dd00
        lda #$78
        sta $d018
        lda #8
        sta $d016
        inc $d020

        lda data.zoom_mode
        beq _zoom_mode_full

        dec $d020
        lda #$18
        sta $d016
        lda #%00011111
        sta $d015
        inc $d020
        jsr set_view_sprites

        lda BUFFER1_BGCOLOR
        ldx data.buffer_index
        beq +
        lda BUFFER2_BGCOLOR
+
        sta irqview_bgcolor + 1
        #do_irq_macro $31, irq_view_pre

_zoom_mode_full

        lda data.dialogs_active
        beq +
        lda #$00
        sta $d015
        #do_irq_macro $f9, irq_dialogs_lborder
+
        lda #$3a
        sta $d003
        sta $d005
        sta $d007
        sta $d009
        sta $d00b
        sta $d00d
        sta $d00f
        lda data.grid_color
        sta $d028
        sta $d029
        sta $d02a
        sta $d02b
        sta $d02c
        sta $d02d
        sta $d02e
        lda #$06
        sta $d021

        jsr set_grid_pointers_row0
        jsr set_grid_sprites_xpos

        lda #$ff
        sta $d015
        lda #$fe
        sta $d01d

        ; second row of sprites starts at $3a + 21
        lda #$3a + 21 -2
        ldx #<irq_full_row1
        ldy #>irq_full_row1

; save some bytes:
do_irq  sta $d012
        stx $0314
        sty $0315
        inc $d019
        jmp $ea81


#do_irq_macro $00, $00


; flash pixel cursor color
flash_cursor .proc

        DELAY_VAL = 3

_delay  lda #DELAY_VAL
        beq +
        dec _delay + 1
        rts
+       lda #DELAY_VAL
        sta _delay + 1
_index  ldx #0
        lda data.cursor_color_table,x
        bpl +
        ldx #$ff
        stx _index + 1
+       sta cursor_color + 1
        inc _index + 1
        rts
.pend


set_grid_pointers_row0 .proc
        ldx #(GRID_SPRITES & $3fff) / 64
        ldy #((GRID_SPRITES & $3fff) / 64) + 1
        stx WORKSPACE_VIDRAM + $3f9
        sty WORKSPACE_VIDRAM + $3fa
        stx WORKSPACE_VIDRAM + $3fb
        sty WORKSPACE_VIDRAM + $3fc
        stx WORKSPACE_VIDRAM + $3fd
        sty WORKSPACE_VIDRAM + $3fe
        stx WORKSPACE_VIDRAM + $3ff
        rts
.pend


set_grid_sprites_xpos .proc
        lda #$18
        sta $d002
        lda #$48
        sta $d004
        lda #$78
        sta $d006
        lda #$a8
        sta $d008
        lda #$d8
        sta $d00a
        lda #$08
        sta $d00c
        lda #$38
        sta $d00e
        lda $d010
        ora #%11000000
        sta $d010
        rts
.pend


; $4700 is the limit for now
.cerror * > EDITOR_SPRITES, "code section is too large"

;------------------------------------------------------------------------------
; Binary data - font, sprites
;------------------------------------------------------------------------------

       * = EDITOR_SPRITES
.binary "../data/editor-sprites.prg", 2
        .cerror * > GRID_SPRITES, "editor sprites overlap grid sprites"

        * = GRID_SPRITES
.binary "../data/bdp6-grid-sprites.prg", 2
        .cerror * > EDITOR_FONT, "grid sprites overlap font"

        * = EDITOR_FONT
.binary "../data/font.prg", 2

 


; Test images


TEST_IMAGE1 = "hawkeye"

; Buffer 1 image

        * = BUFFER1_BITMAP
.binary format("../data/images/%s.bitmap", TEST_IMAGE1), 2
        * = BUFFER1_VIDRAM
.binary format("../data/images/%s.vidram", TEST_IMAGE1), 2
        * = BUFFER1_COLRAM
.binary format("../data/images/%s.colram", TEST_IMAGE1) ,2
        .byte 0 ; bgcolor


; Buffer 2 image

;
;        * = BUFFER2_BITMAP
;.binary "../data/images/citadel.bitmap", 2
;        * = BUFFER2_VIDRAM
;.binary "../data/images/citadel.vidram", 2
;        * = BUFFER2_COLRAM
;.binary "../data/images/citadel.colram", 2
;        .byte 0 ; bg color


        * = BUFFER2_BITMAP
.binary "../data/images/legion2.koa", 2

