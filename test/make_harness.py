"""Genera el arnés de prueba del descompresor.

Crea harness.asm (lista de bloques + bucle que llama a JSL $BFA657 para cada uno
con destino $7F:0000) y harness_blocks.lua (tamaños y CRC esperados).
Uso: python3 -I make_harness.py ROM salida_dir
"""
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))
from rnc import blocks  # noqa: E402

rom = open(sys.argv[1], "rb").read()
out = sys.argv[2]
bl = list(blocks(rom))

asm = [
    "lorom",
    "org $00FEE8",
    "    jml Harness",
    "org $00FFFC",
    "    dw $FEE8",
    "org $88F8B0",
    "Harness:",
    "    sei", "    clc", "    xce",
    "    rep #$30",
    "    lda.w #$0000", "    tcd",
    "    lda.w #$1FFF", "    tcs",
    "    sep #$20",
    "    lda #$80", "    sta $2100",
    "    stz $4200",
    "    lda #$01", "    sta $420D",
    "    rep #$30",
    "    ldx.w #0",
    "Next:",
    "    lda.l Blocks+2,x",
    "    cmp.w #$FFFF",
    "    beq Done",
    "    phx",
    "    lda.l Blocks,x", "    pha",
    "    lda.l Blocks+2,x", "    pha",
    "    pea $0000",
    "    pea $007F",
    "    jsl $BFA657",
    "    pla", "    pla", "    pla", "    pla",
    "Mark:",
    "    nop",
    "    plx",
    "    inx", "    inx", "    inx", "    inx",
    "    bra Next",
    "Done:",
    "    bra Done",
    "Blocks:",
]
lua = ["HB = {"]
for o in bl:
    bank = 0x80 | (o // 0x8000)
    addr = 0x8000 + (o % 0x8000)
    unp = struct.unpack(">I", rom[o + 4:o + 8])[0]
    crc = struct.unpack(">H", rom[o + 12:o + 14])[0]
    asm.append(f"    dw ${addr:04X},${bank:04X}")
    lua.append(f"  {{{o},{unp},{crc}}},")
asm += ["    dw $0000,$FFFF",
        'print "MARK=", hex(Mark)',
        'print "DONE=", hex(Done)',
        'print "START=", hex(Harness)',
        "assert pc() <= $890000"]
lua.append("}")
open(os.path.join(out, "harness.asm"), "w").write("\n".join(asm) + "\n")
open(os.path.join(out, "harness_blocks.lua"), "w").write("\n".join(lua) + "\n")
print(len(bl), "bloques")
