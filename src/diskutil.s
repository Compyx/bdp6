; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; Diskmenu - utility functions: mathematics and conversion

; {{{ const data
; Table for converting PETSCII to screen codes
;
; Each byte covers 32 bytes of the PETSCII range and needs to be added to the
; PETSCII code to get a screencode
petscii_to_screen_table
        .byte $80, $00, $c0, $e0, $40, $c0, $80, $80

screen_to_petscii_table
        .byte $40, $00, $80, $40, $80, $c0, $c0, $00


; Helper table for int to decimal digits conversion
;
; Entries for each 2^n, with n = 0-15
decimal_table
        .byte 0, 0, 0, 0, 1
        .byte 0, 0, 0, 0, 2
        .byte 0, 0, 0, 0, 4
        .byte 0, 0, 0, 0, 8
        .byte 0, 0, 0, 1, 6
        .byte 0, 0, 0, 3, 2
        .byte 0, 0, 0, 6, 4
        .byte 0, 0, 1, 2, 8
        .byte 0, 0, 2, 5, 6
        .byte 0, 0, 5, 1, 2
        .byte 0, 1, 0, 2, 4
        .byte 0, 2, 0, 4, 8
        .byte 0, 4, 0, 9, 6
        .byte 0, 8, 1, 9, 2
        .byte 1, 6, 3, 8, 4
        .byte 3, 2, 7, 6, 8
; }}}

; {{{ variable data
; Result buffer for 16-bit integer to decimal digits conversion
decimal_result
        .fill 5, 0

decimal_input
        .word 0
; }}}


; {{{ (A)       petscii_to_screen(A)
; Convert PETSCII code to screen code
;
; Input:        A - PETSCII code
; Output:       A - screen code
petscii_to_screen .proc
        cmp #$ff
        bne +
        lda #$5e        ; Special case 'Pi'
        rts
+       pha
        stx _xtmp + 1
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        pla
        clc
        adc petscii_to_screen_table,x
_xtmp   ldx #0  ; restore X
        rts
.pend   ; }}}

; {{{ (A)       screen_to_petscii(A)
; Convert screen code to PETSCII code
;
; Input:        A - screen code
; Output:       A - PETSCII code
screen_to_petscii .proc
        cmp #$5e
        bne +
        lda #$ff        ; Special case 'Pi'
        rts
+       pha
        stx _xtmp + 1
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        pla
        clc
        adc screen_to_petscii_table,x
_xtmp   ldx #0  ; restore X
        rts
.pend   ; }}}

; {{{ (A,X)     mul_byte_11(A)
; Multiply a byte by 11 (for the file type list)
;
; Input:        A: value to multiply by 11
; Output:       A: result LSB
;               X: result MSB
; Stack use:    1
; Zero page:    +10 - + 13
;
mul_byte_11 .proc
        temp = DISKMENU_ZP + 10
        result = DISKMENU_ZP + 12

        pha     ; remember original input

        ldx #0
        stx temp
        stx temp + 1

        stx result
        stx result + 1

        asl a
        rol result + 1
        sta result              ; remember input * 2
        sta temp
        ldx result + 1
        stx temp + 1

        asl a
        rol result + 1
        asl a
        rol result + 1          ; we now have input * 8 in result
        sta result

        lda result
        clc
        adc temp
        sta result
        lda result + 1
        adc temp + 1
        sta result + 1

        pla
        clc
        adc result
        sta result
        bcc +
        inc result + 1
+
        lda result
        ldx result + 1
        rts
.pend   ; }}}

; {{{ (A,X)     mul_byte_24(A)
; Multiply byte by 24
mul_byte_24 .proc

        result = DISKMENU_ZP + 10
        temp = DISKMENU_ZP + 12
        pha
        lda #0
        sta result
        sta result + 1
        sta temp
        sta temp + 1
        pla
        ; multiply by 8
        asl a
        rol result + 1
        asl a
        rol result + 1
        asl a
        rol result + 1
        sta result

        ldx result
        stx temp
        ldx result + 1
        stx temp +1

        asl a
        rol result + 1
        sta result
        clc
        adc temp
        sta result
        lda temp + 1
        adc result + 1
        sta result + 1

        lda result
        ldx result + 1
        rts
.pend   ; }}}

; {{{ (A,X)     mul_byte_40(A)
mul_byte_40 .proc
        result = DISKMENU_ZP + 10
        temp = DISKMENU_ZP + 12

        ldx #0
        stx result
        stx result + 1
        stx temp
        stx temp + 1

        ; multiply by 8
        asl a
        rol result + 1
        asl a
        rol result + 1
        asl a
        rol result + 1
        pha
        sta temp
        lda result + 1
        sta temp + 1
        pla

        ; multiply by 4
        asl a
        rol result + 1
        asl a
        rol result + 1

        clc
        adc temp
        sta result
        lda temp + 1
        adc result + 1
        tax
        lda result
.if DISKMENU_DEBUG
        sta $0400
        stx $0401
.endif
        rts
.pend   ; }}}

; {{{ void      decimal_digits(X,Y)
; Convert unsigned 16-bit word in X/Y to decimal digits
;
; Uses `decimal_table`, `decimal_result` and `decimal_input`.
;
; Input:        X/Y: LSB/MSB
; Output:       result in `decimal_result`
;
decimal_digits .proc

        lsb = decimal_input
        msb = decimal_input + 1

        stx lsb
        sty msb

        ; clear result buffer
        ldx #4
        lda #0
-       sta decimal_result,x
        dex
        bpl -

        ldx #4  ; last entry of the first row of the power-of-two table

_wtd_more
        ; check if we're done:
        lda lsb
        ora msb
        bne +

        ; generate proper digits
        ldx #4
-       lda decimal_result,x
        ora #$30
        sta decimal_result,x
        dex
        bpl -
        rts     ; done
+
        ; divide by two
        lsr msb
        ror lsb
        bcs +   ; add digits

        txa     ; no need to add digits, continue
        adc #5
        tax
        jmp _wtd_more

+
        clc     ; only clear C here
        ldy #4
-       lda decimal_result,y
        adc decimal_table,x
        cmp #10
        bcc +
        sbc #10         ; overflow, restore digit
+       sta decimal_result,y
        dex
        dey
        bpl -

        txa     ; move pointer in table to the next power-of-two, last digit
        clc
        adc #5 + 5
        tax
        jmp _wtd_more
.pend   ; }}}

; {{{ void      decimal_digits_trim_zeroes(void)
; Trim leading zeroes from the decimal digits result string
decimal_digits_trim_zeroes .proc
        ldx #0
-       lda decimal_result,x
        cmp #$30
        bne +
        lda #$20
        sta decimal_result,x
        inx
        cpx #5
        bne -
+       rts
.pend   ; }}}

; {{{ void      decimal_digits_left_align(void)
; Left align decimal digits result string (and trim leading zeroes)
decimal_digits_left_align .proc
        jsr decimal_digits_trim_zeroes

        ; determine zeroes to skip, but keep the last digit intact
        ldx #0
-       lda decimal_result,x
        cmp #$20
        bne +
        inx
        cpx #4
        bne -
+
        ldy #0
-       lda decimal_result,x
        cpx #5
        bcc +
        lda #$20
+       sta decimal_result,y
        inx
        iny
        cpy #5
        bne -

        rts
.pend   ; }}}

; {{{ (A,X)     hex_digits(A)
; @brief        Convert byte to hexadecimal digits (screen codes)
;
; @param A      byte value
;
; @return A     high nybble (screen code)
; @return X     low nybble (screen code)
hex_digits .proc
        pha
        and #$0f
        cmp #$0a
        bcc +
        sbc #$39
+       adc #$30
        tax
        pla
        lsr a
        lsr a
        lsr a
        lsr a
        cmp #$0a
        bcc +
        sbc #$39
+       adc #$30
        rts
.pend   ; }}}

