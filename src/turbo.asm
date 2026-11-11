; =====================================================================
;  Mickey Mania (SNES) v2 "turbo" - ROM de 4 MB con bloques ya descomprimidos
;
;  $BF:A657 -> Turbo. Busca el bloque de origen en una tabla (por banco).
;   - encontrado: copia los datos ya descomprimidos desde $C0-$FF a WRAM con
;     DMA (canal 2 -> $2180) en trozos de 512 bytes, guardando y restaurando
;     los registros del canal 2.
;   - no encontrado: salta al descompresor RNC rápido de la v1 ($9E:E800).
;  Mismo contrato que la rutina original (argumentos en pila, RTL en 16 bits).
;
;  Tabla (generada por build_v2.py) en !TBIDX:
;    TBIDX[64] (palabras): offset de la primera entrada de cada banco $80-$BF,
;                          seguido de un centinela (TBIDX[64] = fin).
;    TBENT: entradas de 8 bytes: dir_origen(2) dir_datos(2) banco_datos(1) 0(1) longitud(2)
; =====================================================================
lorom

!TBIDX  = $FF8000
!TBENT  = $FF8082
!DECOMP = $9EE800

!SRC    = $10       ; dirección de los datos ($12 = banco)
!DST    = $14
!WBANK  = $16       ; bit de banco WRAM (0 = $7E, 1 = $7F)
!LEN    = $1C
!CH     = $1E
!SAVE   = $20       ; $20-$2B: copia de $4320-$432B
!END    = $2C

!CHUNK  = 512

org $BFA657
    jml Turbo

org $9EFB00
Turbo:
    rep #$30
    lda $08,s               ; banco de origen
    and.w #$003F
    asl
    tax
    lda.l !TBIDX+2,x
    sta !END
    lda.l !TBIDX,x
    tax
.scan:
    cpx !END
    bcs .miss
    lda.l !TBENT,x
    cmp $0A,s               ; dirección de origen
    beq .hit
    txa
    clc
    adc.w #8
    tax
    bra .scan
.miss:
    jml !DECOMP

.hit:
    lda.l !TBENT+2,x
    sta !SRC
    lda.l !TBENT+4,x
    and.w #$00FF
    sta $12
    lda.l !TBENT+6,x
    sta !LEN
    lda $06,s
    sta !DST
    lda $04,s
    and.w #$0001
    sta !WBANK

    lda.l $004320           ; guardar canal 2
    sta !SAVE
    lda.l $004322
    sta !SAVE+2
    lda.l $004324
    sta !SAVE+4
    lda.l $004326
    sta !SAVE+6
    lda.l $004328
    sta !SAVE+8
    lda.l $00432A
    sta !SAVE+10

.chunk:
    lda !LEN
    beq .done
    lda.w #0                ; bytes hasta el final del banco de ROM
    sec
    sbc !SRC
    cmp.w #!CHUNK
    bcc +
    lda.w #!CHUNK
+   cmp !LEN
    bcc +
    lda !LEN
+   sta !CH

    sep #$20
    lda #$00
    sta.l $004320           ; A->B, incremento, 1 registro
    lda #$80
    sta.l $004321           ; B-bus $2180 (WMDATA)
    lda $12
    sta.l $004324
    lda !WBANK
    sta.l $002183
    rep #$20
    lda !SRC
    sta.l $004322
    lda !CH
    sta.l $004325
    lda !DST
    sta.l $002181
    sep #$20
    lda #$04
    sta.l $00420B           ; disparar canal 2
    rep #$20

    lda !DST
    clc
    adc !CH
    sta !DST
    lda !LEN
    sec
    sbc !CH
    sta !LEN
    lda !SRC
    clc
    adc !CH
    sta !SRC
    bne .chunk
    lda.w #$8000            ; siguiente banco de ROM
    sta !SRC
    inc $12
    bra .chunk

.done:
    lda !SAVE               ; restaurar canal 2
    sta.l $004320
    lda !SAVE+2
    sta.l $004322
    lda !SAVE+4
    sta.l $004324
    lda !SAVE+6
    sta.l $004326
    lda !SAVE+8
    sta.l $004328
    lda !SAVE+10
    sta.l $00432A
    rtl

print "Turbo: ", hex(Turbo), " - ", pc
assert pc() <= $9F0000
