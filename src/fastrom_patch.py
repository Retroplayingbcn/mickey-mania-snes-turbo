"""Corrige STZ $420D -> STA $420D (activa FastROM) y recalcula el checksum LoROM.
Uso: python3 -I fastrom_patch.py entrada.sfc salida.sfc
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
d = bytearray(open(src, "rb").read())

# Buscar la secuencia exacta: LDA #$01 ; STZ $420D
pat = bytes.fromhex("a901 9c0d42")
hits = [i for i in range(len(d) - len(pat)) if d[i:i + len(pat)] == pat]
assert len(hits) == 1, f"esperaba 1 coincidencia, hay {len(hits)}: {[hex(h) for h in hits]}"
off = hits[0] + 2
d[off] = 0x8D  # STA abs
print(f"parcheado STZ->STA en offset {off:#x}")

# Checksum LoROM (cabecera en $7FC0): complemento en $7FDC, checksum en $7FDE
d[0x7FDC:0x7FE0] = b"\xff\xff\x00\x00"
s = sum(d) & 0xFFFF
d[0x7FDE] = s & 0xFF; d[0x7FDF] = s >> 8
c = s ^ 0xFFFF
d[0x7FDC] = c & 0xFF; d[0x7FDD] = c >> 8
assert sum(d) & 0xFFFF == s
print(f"checksum {s:#06x}")
open(dst, "wb").write(d)
