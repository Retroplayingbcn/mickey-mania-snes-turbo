; =====================================================================
;  Mickey Mania (SNES) v3 - extras sobre la v2 "turbo"
;  1. Rótulo de película ("STEAMBOAT WILLIE 1928", etc.) saltable con
;     Start/A/B/X/Y una vez que ha terminado el fundido de entrada.
;     (La pantalla de Congratulations y la intro del lápiz ya se pueden
;      saltar en el juego original.)
; =====================================================================
lorom

org $BC9899
    jsl CardSkip            ; antes: JSL $BDD42B

org $9EFD20
CardSkip:
    jsl $BDD42B
    lda.l $000103           ; mando en el frame anterior
    pha
    jsl $BDCD7D             ; lee el mando (A = estado, también en $0103)
    pla
    eor.w #$FFFF
    and.l $000103           ; botones recién pulsados
    and.w #$D0C0            ; B, Y, Start, A, X
    beq +
    lda $A5
    cmp.w #$000F            ; solo con la pantalla ya encendida del todo
    bne +
    lda.w #$0001
    sta.l $0006C2           ; "escena terminada" -> fundido y carga del nivel
+   rtl
print "extras: ", hex(CardSkip), " - ", pc

; ---------------------------------------------------------------------
;  2. (v4) No volver a subir al SPC700 la canción que ya está cargada
;     (al morir o reiniciar el juego repetía la subida completa, ~1 s).
;     Se guarda el número de la última canción en $436B (byte libre de
;     los registros DMA, sin uso en el juego). Al arrancar el driver de
;     sonido se pone a 0 (ninguna canción válida es 0).
; ---------------------------------------------------------------------
org $A195A3
    jml SongLoad            ; antes: JSR $97A0 / RTL
org $A195A7
    jml DrvBoot             ; antes: JSR $9A36 / RTL

org $9EFD60
SongLoad:
    php
    sep #$20
    pha
    tya
    cmp.l $00436B
    beq .skip
    sta.l $00436B
    pla
    plp
    pea.w $959D             ; el RTS de $97A0 vuelve al RTL de $A1:959E
    jml $A197A0
.skip:
    pla
    plp
    rtl

DrvBoot:
    php
    sep #$20
    pha
    lda.b #$00
    sta.l $00436B
    pla
    plp
    pea.w $959D
    jml $A19A36
print "song cache: ", hex(SongLoad), " - ", pc
