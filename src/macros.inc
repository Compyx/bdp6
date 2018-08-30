; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - general purpose macro's
;


; @brief        Add a value (byte/word) to a word at an address in memory
;
; Optimizes code when value < 256.
;
;
; @param \1     memory location
; @param \2     value to add
;
; @clobbers     A,C
;
word_add_val .macro
        lda \1
        clc
        adc #<\2
        sta \1
  .if \2 < 256
        ; add byte
        bcc +
        inc \1 + 1
+
  .else
        ; add word
        lda \1 + 1
        adc #>\2
        sta \1 + 1
  .endif
.endm


; @brief        Subtract a value (byte/word) from a word at an address in memory
;
; Optimizes code when value < 256.
;
;
; @param \1     memory location
; @param \2     value to add
;
; @clobbers     A,C
;
word_sub_val .macro
        lda \1
        sec
        sbc #<\2
        sta \1
  .if \2 < 256
        ; add byte
        bcs +
        dec \1 + 1
+
  .else
        ; add word
        lda \1 + 1
        sbc #>\2
        sta \1 + 1
  .endif
.endm




; Set grid sprite Y positions (sprites 1-7)
;
; @param \1     new vertical position
;
; @clobbers     A
set_grid_sprites_ypos .macro
        lda #\1
        jsr gspr_set_ypos
.endm


; Set grid sprite pointers (sprites 1-7)
;
; The grid uses two different sprites per row of sprites
;
; @param \1     value for lowest pointer value
;
; @clobbers     X,Y
;
set_grid_sprites_ptrs .macro
        ldx #((GRID_SPRITES & $3fff) / 64) + \1 + 0
        ldy #((GRID_SPRITES & $3fff) / 64) + \1 + 1
        jsr gspr_set_ptrs
.endm


; Jump to main.do_irq, setting new raster/IRQ vector and ACK'ing IRQ
;
; @param \1     new raster position
; @param \2     new IRQ vector
;
; @clobbers     A,X,Y
;
do_irq_macro .macro
        lda #\1
        ldx #<\2
        ldy #>\2
        jmp do_irq
.endm



; DEBUG macros

; @brief        Store A in \1 if DEBUG enabled
;
; @param \1     address to store A
;
dbg_sta .macro
    .if DEBUG
        sta \1
    .endif
.endm


; @brief        Store X in \1 if DEBUG enabled
;
; @param \1     address to store X
;
dbg_stx .macro
    .if DEBUG
        stx \1
    .endif
.endm


; @brief        Store Y in \1 if DEBUG enabled
;
; @param \1     address to store Y
;
dbg_sty .macro
    .if DEBUG
        sty \1
    .endif
.endm



