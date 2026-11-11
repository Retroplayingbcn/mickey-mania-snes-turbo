; =====================================================================
;  Mickey Mania (SNES) - descompresor RNC ProPack método 1 rápido
;  Sustituye la rutina de Traveller's Tales en $BF:A657 (versión USA).
;
;  Contrato (idéntico al original):
;    PEA src_addr ; PEA src_bank ; PEA dst_addr ; PEA dst_bank ; SEI
;    JSL $BFA657 ; CLI ; PLA x4
;  Sale con A/X/Y en 16 bits y el DB del llamador restaurado.
;  Usa como temporal lo mismo que el original: DP $10-$2D y $7E:2000-$219F.
;
;  Modelo de bits (equivalente a ProPack):
;    ventana de 32 bits = CUR (16) + NXT (16); O2 = 2 * bits consumidos de CUR.
;    Q = dirección de NXT en el flujo; p de ProPack = (O2 == 0) ? Q-2 : Q.
; =====================================================================
lorom

!Q      = $10       ; dirección de NXT ($12 = banco)
!DST    = $14
!CUR    = $16
!NXT    = $18
!O2     = $1A
!CNT    = $1C
!CHK    = $1E
!T0     = $20
!T1     = $22
!T2     = $24
!T3     = $26       ; offset canon de la tabla (t*34)
!T4     = $28       ; offset LUT de la tabla (t*64)
!T5     = $2A
!T6     = $2C

!LUT    = $7E2000   ; 3 x 64 bytes: e = (sym<<4)|L, 0 = escape
!CANON  = $7E20C0   ; 3 x 34: counts[0..16] (17 bytes) + syms[0..15]
!LENS   = $7E2130   ; 16 bytes
!OFFS   = $7E2150   ; 17 bytes
!STUBL  = $7E2170   ; MVN dst,src ; RTL  (literales)
!STUBM  = $7E2174   ; MVN dst,dst ; RTL  (coincidencias)

macro consume()             ; A = 2*n bits a consumir; conserva X e Y
    clc
    adc !O2
    cmp.w #32
    bcc ?ok
    sbc.w #32
    sta !O2
    jsr Refill
    bra ?done
?ok:
    sta !O2
?done:
endmacro


macro getval(t)             ; A = valor decodificado con la tabla <t> (Z según A)
    ldx !O2
    jsr (PeekTab,x)
    sta !T2                 ; P = ventana alineada (>= 9 bits válidos)
    and.w #$003F
    tax
    lda.l !LUT+(<t>*64),x
    and.w #$00FF
    asl
    tax                     ; X = 2e
    lda.l TabC2,x
    beq ?slow
    bmi ?long
    %consume()              ; consume L+n de una vez
    lda.l TabS2,x
    cmp.w #4
    bcc ?small
    stx !T6
    lda.l TabSh2,x
    tax
    lda !T2
    jsr (ShrTab,x)          ; P >> L
    ldx !T6
    and.l TabMaskE,x
    ora.l TabBaseE,x
    bra ?done
?small:
    lsr
    bra ?done
?long:
    and.w #$7FFF            ; sólo el código; los bits extra van aparte
    %consume()
    lda.l TabS2,x
    jsr Extra
    bra ?done
?slow:
    lda.w #<t>*34
    sta !T3
    jsr SlowSym
    jsr Extra
?done:
endmacro

; ---------------------------------------------------------------------
org $BFA657
    jml Decomp

org $9EE800
Decomp:
    rep #$39
    lda $06,s
    sta !DST
    lda $08,s
    sta $12
    lda $0A,s
    sta !Q
    lda $04,s
    phb
    xba
    pha
    plb
    plb                     ; DB = banco destino (como el original)

    sep #$20                ; preparar los stubs MVN en WRAM
    phb
    pla
    sta.l !STUBL+1
    sta.l !STUBM+1
    sta.l !STUBM+2
    lda $12
    sta.l !STUBL+2
    lda #$54
    sta.l !STUBL
    sta.l !STUBM
    lda #$6B
    sta.l !STUBL+3
    sta.l !STUBM+3
    rep #$20

    lda !Q                  ; +$11: nº de chunks ; +$12: flujo de bits
    clc
    adc.w #$0011
    sta !Q
    lda [!Q]
    and.w #$00FF
    sta !CHK
    inc !Q
    lda [!Q]
    sta !CUR
    inc !Q
    inc !Q
    lda [!Q]
    sta !NXT
    stz !O2
    lda.w #2                ; bits de bloqueo/clave
    jsr ReadN

.chunk:
    ldx.w #0
    jsr BuildTable
    ldx.w #1
    jsr BuildTable
    ldx.w #2
    jsr BuildTable
    lda.w #8                ; nº de subchunks (16 bits, LSB primero)
    jsr ReadN
    sta !T0
    lda.w #8
    jsr ReadN
    xba
    ora !T0
    sta !CNT

.loop:
    %getval(0)
    beq .nolit
    jsr Literal
.nolit:
    dec !CNT
    bne +
    jmp .endchunk
+
    %getval(1)
    sta !T1                 ; distancia-1
    %getval(2)              ; longitud-2
    inc                     ; longitud-1 = contador MVN
    sta !T0
    lda !DST
    clc
    sbc !T1                 ; origen = DST - distancia
    tax
    ldy !DST
    lda !T0
    jsl !STUBM
    sty !DST
    jmp .loop

.endchunk:
    dec !CHK
    beq +
    jmp .chunk
+   plb
    rtl

; ---------------------------------------------------------------------
; Copia de literales: A = n (>=1). Bytes alineados desde p de ProPack.
Literal:
    dec
    sta !T0
    lda !Q
    ldx !O2
    bne +
    sec
    sbc.w #2
+   tax
    ldy !DST
    lda !T0
    jsl !STUBL
    sty !DST
    stx !Q                  ; p' = p + n
    lda !O2                 ; bitread_fix
    beq .z
    lda [!Q]
    sta !NXT
    rts
.z: lda [!Q]
    sta !CUR
    inc !Q
    inc !Q
    lda [!Q]
    sta !NXT
    rts

; ---------------------------------------------------------------------
Refill:
    lda !NXT
    sta !CUR
    inc !Q
    inc !Q
    lda [!Q]
    sta !NXT
    rts

; ---------------------------------------------------------------------
; ReadN: A = n (1..9) -> A = n bits siguientes (Z según valor). Usa X, T6.
ReadN:
    asl
    sta !T6
    ldx !O2
    jsr (PeekTab,x)
    ldx !T6
    and.l TabMaskN,x
    pha
    lda !T6
    %consume()
    pla
    rts

; ---------------------------------------------------------------------
; Extra: A = 2*sym con el código ya consumido -> A = valor (Z según A)
Extra:
    cmp.w #4
    bcs .extra
    lsr
    rts
.extra:
    cmp.w #22
    bcs .big
    sta !T5
    ldx !O2
    jsr (PeekTab,x)
    ldx !T5
    and.l TabMaskS,x
    ora.l TabBaseS,x
    sta !T2
    lda.l TabN2S,x
    %consume()
    lda !T2
    rts
.big:                       ; sym 11..15: bits extra en dos lecturas
    sta !T5
    lda.w #8
    jsr ReadN
    sta !T2
    ldx !T5
    lda.l TabN2S,x
    lsr
    sec
    sbc.w #8
    jsr ReadN
    xba
    and.w #$FF00
    ora !T2
    ldx !T5
    ora.l TabBaseS,x
    rts

; ---------------------------------------------------------------------
; SlowSym: decodificación canónica bit a bit (códigos > 6 bits). A = 2*sym.
; Usa T0 (código), T2 (primero), T5 (índice), T6 (cuenta), Y (longitud).
SlowSym:
    stz !T0
    stz !T2
    stz !T5
    ldy.w #1
.bit:
    lda.w #1
    jsr ReadN
    ora !T0
    sta !T0
    tya
    clc
    adc !T3
    tax
    lda.l !CANON,x
    and.w #$00FF
    sta !T6
    lda !T0
    sec
    sbc !T2
    cmp !T6
    bcc .found
    lda !T5
    clc
    adc !T6
    sta !T5
    lda !T2
    clc
    adc !T6
    asl
    sta !T2
    asl !T0
    iny
    cpy.w #17
    bcc .bit
    lda.w #0
    rts
.found:
    clc
    adc !T5
    adc !T3
    tax
    lda.l !CANON+17,x
    and.w #$00FF
    asl
    rts

; ---------------------------------------------------------------------
; BuildTable: X = t (0..2). Lee la tabla Huffman del flujo y construye
; counts/syms canónicos y la LUT de 6 bits.
BuildTable:
    txa
    asl
    sta !T5
    asl
    asl
    asl
    asl
    clc
    adc !T5
    sta !T3                 ; t*34
    txa
    asl
    asl
    asl
    asl
    asl
    asl
    sta !T4                 ; t*64

    lda.w #5
    jsr ReadN
    sta !T2                 ; num

    ldx !T3                 ; counts[0..16] = 0
    sep #$20
    lda #$00
    ldy.w #17
-   sta.l !CANON,x
    inx
    dey
    bne -
    rep #$20

    ldy.w #0                ; leer longitudes
.rl:
    cpy !T2
    bcs .rlend
    phy
    lda.w #4
    jsr ReadN
    ply
    tyx
    sep #$20
    sta.l !LENS,x
    rep #$20
    and.w #$00FF
    clc
    adc !T3
    tax
    sep #$20
    lda.l !CANON,x
    inc
    sta.l !CANON,x
    rep #$20
    iny
    bra .rl
.rlend:

    stz !T0                 ; offs[L] = suma de counts[1..L-1]
    ldy.w #1
.of:
    tyx
    lda !T0
    sep #$20
    sta.l !OFFS,x
    rep #$20
    tya
    clc
    adc !T3
    tax
    lda.l !CANON,x
    and.w #$00FF
    clc
    adc !T0
    sta !T0
    iny
    cpy.w #17
    bcc .of

    ldy.w #0                ; syms ordenados por (longitud, símbolo)
.ds:
    cpy !T2
    bcs .dsend
    tyx
    lda.l !LENS,x
    and.w #$00FF
    beq .dsnext
    tax
    lda.l !OFFS,x
    and.w #$00FF
    pha
    inc
    sep #$20
    sta.l !OFFS,x
    rep #$20
    pla
    clc
    adc !T3
    tax
    tya
    sep #$20
    sta.l !CANON+17,x
    rep #$20
.dsnext:
    iny
    bra .ds
.dsend:

    ldx !T4                 ; LUT = 0 (escape)
    ldy.w #32
    lda.w #0
-   sta.l !LUT,x
    inx
    inx
    dey
    bne -

    stz !T0                 ; código canónico
    stz !T5                 ; índice en syms
    ldy.w #1                ; L
.cl:
    tya
    clc
    adc !T3
    tax
    lda.l !CANON,x
    and.w #$00FF
    sta !T6                 ; símbolos con longitud L
.cs:
    lda !T6
    beq .cnext
    lda !T5
    clc
    adc !T3
    tax
    lda.l !CANON+17,x
    and.w #$00FF
    asl
    asl
    asl
    asl
    sta !T1
    tya
    ora !T1
    sta !T1                 ; entrada = (sym<<4)|L
    sty !T2
    lda.w #8
    sec
    sbc !T2
    tax                     ; X = 8-L
    lda !T0
-   cpx.w #0
    beq +
    asl
    dex
    bra -
+   and.w #$00FF
    tax
    lda.l Rev8,x
    and.w #$00FF
    sta !T2                 ; primer índice (bits del código invertidos)
    tya
    asl
    tax
    lda.l TabMaskN,x
    inc
    sta !CNT                ; paso = 1<<L
.fl:
    lda !T2
    cmp.w #64
    bcs .fld
    clc
    adc !T4
    tax
    lda !T1
    sep #$20
    sta.l !LUT,x
    rep #$20
    lda !T2
    clc
    adc !CNT
    sta !T2
    bra .fl
.fld:
    inc !T0
    inc !T5
    dec !T6
    bra .cs
.cnext:
    asl !T0
    iny
    cpy.w #7
    bcs +
    jmp .cl
+   rts

; ShrTab: X = 2L -> A >>= L
ShrTab:
    dw S0,S1,S2,S3,S4,S5,S6
S0:  rts
S1:  lsr #1
     rts
S2:  lsr #2
     rts
S3:  lsr #3
     rts
S4:  lsr #4
     rts
S5:  lsr #5
     rts
S6:  lsr #6
     rts

; ---------------------------------------------------------------------
; PeekTab: X = O2 -> A = ventana >> o (al menos 9 bits válidos)
PeekTab:
    dw P0,P1,P2,P3,P4,P5,P6,P7,P8,P9,P10,P11,P12,P13,P14,P15
P0:  lda !CUR
     rts
P1:  lda !CUR
     lsr
     rts
P2:  lda !CUR
     lsr #2
     rts
P3:  lda !CUR
     lsr #3
     rts
P4:  lda !CUR
     lsr #4
     rts
P5:  lda !CUR
     lsr #5
     rts
P6:  lda !CUR
     lsr #6
     rts
P7:  lda !CUR
     lsr #7
     rts
P8:  lda !CUR+1
     rts
P9:  lda !CUR+1
     lsr
     rts
P10: lda !CUR+1
     lsr #2
     rts
P11: lda !CUR+1
     lsr #3
     rts
P12: lda !CUR+1
     lsr #4
     rts
P13: lda !CUR+1
     lsr #5
     rts
P14: lda !CUR+1
     lsr #6
     rts
P15: lda !CUR+1
     lsr #7
     rts

incsrc "tablas.asm"

print "fin del código nuevo: ", pc
assert pc() <= $9F8000
