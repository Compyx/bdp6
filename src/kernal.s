; vim: set smartindent et ts=8 sts=8 sw=8 fdm=marker syntax=64tass:
;
; BDP 6 - KERNAL replacement calls/fixes


;; @brief       Replacement for KERNAL RESTOR that doesn't clobber RAM
;
; The KERNAL RESTOR ($fd15) function clobbers RAM at $fd30-$fd4f, which is fine
; with older CBM machines that don't have RAM 'under' $e000-$ffff, but shouldn't
; happen on C64/C128. (I'm told this screws IDE64)
;
; @clobbers     Y,N,Z
;
k_restor_fixed .proc
        ldy #$1f
-       lda $fd30,y
        sta $0314,y
        dey
        bpl -
        rts
.pend
