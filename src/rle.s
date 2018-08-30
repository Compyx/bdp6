; vim: set et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - RLE functions

        ZP_RLE  = $60


data .block

source_start    .word 0
source_end      .word 0
target_start    .word 0
target_end      .word 0

.bend

inc_word .macro
        inc \1
        bne +
        inc \1 + 1
+
.endm


wipe_workspace
        lda #0
        ldx #$50
        sta ZP_TMP
        stx ZP_TMP + 1
        ldx #$2f
        tay
-       sta (ZP_TMP),y
        iny
        bne -
        inc ZP_TMP + 1
        dex
        bpl -
        rts


set_source_start .proc
        stx rle.data.source_start
        sty rle.data.source_start + 1
        rts
.pend

set_source_end .proc
        stx rle.data.source_end
        sty rle.data.source_end + 1
        rts
.pend


; @brief        Set target start address
;
; This sets either the destination of the unpacked data during unpacking, or
; the address to store packed data during packing
;
; @param X      LSB
; @param Y      LSB
;
set_target_start .proc
        stx rle.data.target_start
        sty rle.data.target_start + 1
        rts
.pend


; @brief        Set target end address
;
; This sets either the upper limit of the unpacked data during unpacking, or
; the upper limit to store packed data during packing
;
; @param X      LSB
; @param Y      LSB
;
set_target_end .proc
        stx rle.data.target_start
        sty rle.data.target_start + 1
        rts
.pend




; @brief        Decode generic RLE data - non-safe
;
; @param A      run indicator
; @param X      source LSB
; @param Y      source MSB
;
; @return X     end address LSB
; @return Y     end address MSB
;
; @zeropage     ZP_RLE - ZP_RLE+6
; @clobbers     all
;
unpack_generic .proc

        src = ZP_RLE
        dst = ZP_RLE + 2
        packbyte = ZP_RLE + 4
        length = ZP_RLE + 5
        value = ZP_RLE + 6

        sta packbyte
        stx src
        sty src + 1

        lda rle.data.target_start
        sta dst
        lda rle.data.target_start + 1
        sta dst + 1

next
        ldy #0
        lda (src),y
        cmp packbyte
        beq decode_run
        sta (dst),y

        #inc_word src
        #inc_word dst
        jmp next + 2    ; skip LDY #0

decode_run
        iny
        lda (src),y
        bne +
        ; 0 zero length, EOF:
        ldx dst
        ldy dst + 1
        rts
+
        sta length
        iny
        lda (src),y
        sta value

        ldx length

        ldy #0
-       sta (dst),y
        iny
        dex
        bne -

        #word_add_val src, 3
        lda dst
        clc
        adc length
        sta dst
        bcc +
        inc dst + 1
+
        jmp next
.pend


; @brief        Determine value in data to pack with the lowest occurence
;
; @return Y     value with the lowest occurence
;
; @clobbers     A,C,X
; @zeropage     ZP_RLE - ZP_RLE+5
;
pack_determine_runbyte .proc
        src = ZP_RLE
        end = ZP_RLE + 2
        lowest = ZP_RLE + 4
        index = ZP_RLE + 5
        freq = $0400

        ldx rle.data.source_start
        ldy rle.data.source_start + 1
        stx src
        sty src + 1
        ldx rle.data.source_end
        ldy rle.data.source_end + 1
        stx end
        sty end + 1

        ; clear frequency table
        ldy #0
        tya
-       sta freq,y
        iny
        bne -
-
        lda (src),y
        tax
        lda freq,x
        cmp #$ff
        beq +
        inc freq,x
+
        #inc_word src

        lda src + 1
        cmp end + 1
        bne -
        lda src
        cmp end
        bne -

        sty index
        lda #$ff
        sta lowest

        ; determine byte with the lowest count
-       lda freq,y
        beq _done       ; 0 is the ideal situation

        cmp lowest
        bcs +
        sta lowest
        sty index
+       iny
        bne -

        ldy index
_done
        rts
.pend



; @brief        Use run length encoding on a slab of data
;
; This assume `rle.data.source_start`, `rle.data.source_end` having been set.
;

; @param A      run indicator byte
; @param X      target LSB
; @param Y      target MSB
;
; @return X     packed data end address LSB
; @return Y     packed data end address MSB
pack_generic .proc

        source = ZP_RLE
        source_end = ZP_RLE + 2
        target = ZP_RLE + 4
        runbyte = ZP_RLE + 6
        runlen = ZP_RLE + 7
        runval = ZP_RLE + 8

        sta runbyte
        stx target
        sty target + 1

        jsr wipe_workspace

        lda rle.data.source_start
        sta source
        lda rle.data.source_start + 1
        sta source + 1
        lda rle.data.source_end
        sta source_end
        lda rle.data.source_end + 1
        sta source_end + 1


more
        ldy #0
        lda (source),y
        iny
        cmp (source),y
        beq handle_run
        dey

        ; check if it's the runbyte
        cmp runbyte
        bne rb_ok

        ; store runbyte + 1 + runbyte
        sta (target),y
        iny
        lda #1
        sta (target),y
        iny
        lda runbyte
        sta (target),y
        ; update target
        lda target
        clc
        adc #3
        sta target
        bcc +
        inc target + 1
+       jmp inc_source

rb_ok
        sta (target),y

        #inc_word target
inc_source
        #inc_word source

check_end
        lda source + 1
        cmp source_end + 1
        bcc more
        lda source
        cmp source_end
        bne more

        ; END of data reached

        ldy #0
        lda runbyte
        sta (target),y
        iny
        lda #0
        sta (target),y

        ldy target + 1
        lda target
        clc
        adc #2
        tax
        bcc +
        iny
+
        rts
handle_run
        ; determine run length
        ldy #2
-       cmp (source),y
        bne +
        iny
        bne -
        dey     ; make ff

+
        sta runval
        sty runlen

        ; TODO: adjust run length if over source_end


        cpy #3
        bcc run_store_literal



        ; store encoded run
        ldy #2
        lda runval
        sta (target),y  ; value
        dey
        lda runlen
        sta (target),y  ; length
        dey
        lda runbyte
        sta (target),y

        lda source
        clc
        adc runlen
        sta source
        bcc +
        inc source + 1
+
        lda target
        clc
        adc #3
        sta target
        bcc +
        inc target + 1
+
        jmp check_end

run_store_literal
-       lda (source),y
        sta (target),y
        dey
        bpl -

        lda source
        clc
        adc runlen
        sta source
        bcc +
        inc source + 1
+
        lda target
        clc
        adc runlen
        sta target
        bcc +
        inc target + 1
+
        jmp check_end


        rts


.pend


