"""Construye la v2 'turbo' (4 MB) a partir de la ROM v1 (FastROM + RNC rápido).

1. Amplía la ROM a 4 MB (LoROM, bancos $C0-$FF).
2. Descomprime los 299 bloques RNC1 (validados por CRC) y los guarda seguidos
   desde el offset 0x200000 (pueden cruzar bancos: la DMA trocea en el límite).
3. Escribe la tabla de búsqueda por banco en $FF:8000.
4. Ensambla turbo.asm (gancho en $BF:A657).
5. Ajusta el tamaño en la cabecera ($0C = 4 MB) y recalcula el checksum.

Uso: python3 -I build_v2.py v1.sfc salida.sfc asar turbo.asm
"""
import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rnc import blocks, crc16, decode  # noqa: E402

src, dst, asar, asm = sys.argv[1:5]
rom = bytearray(open(src, "rb").read())
assert len(rom) == 0x200000
rom += b"\xFF" * 0x200000

DATA0, TABLE = 0x200000, 0x3F8000


def snes(off):
    return 0x800000 | ((off // 0x8000) << 16) | (0x8000 + off % 0x8000)


entries = []
pos = DATA0
for o in blocks(rom[:0x200000]):
    out, st, (unp, pk, ucrc, pcrc, ch) = decode(rom, o)
    assert len(out) == unp and crc16(out) == ucrc, hex(o)
    rom[pos:pos + unp] = out
    a = snes(o)
    entries.append(((a >> 16) & 0xFF, a & 0xFFFF, snes(pos), unp))
    pos += unp
assert pos <= TABLE, f"los datos ({pos:#x}) invaden la tabla"

entries.sort()
idx, ent = [], bytearray()
i = 0
for b in range(0x80, 0xC0):
    idx.append(len(ent))
    while i < len(entries) and entries[i][0] == b:
        _, addr, dptr, unp = entries[i]
        assert unp <= 0xFFFF
        ent += struct.pack("<HHBBH", addr, dptr & 0xFFFF, dptr >> 16, 0, unp)
        i += 1
idx.append(len(ent))
assert i == len(entries)
tbl = b"".join(struct.pack("<H", v) for v in idx) + ent
assert len(idx) * 2 == 0x82, "TBENT debe empezar en $FF8082"
assert len(tbl) <= 0x8000
rom[TABLE:TABLE + len(tbl)] = tbl
open(dst, "wb").write(rom)

r = subprocess.run([asar, "--fix-checksum=off", asm, dst], capture_output=True, text=True)
print(r.stdout.strip(), r.stderr.strip())
assert r.returncode == 0

rom = bytearray(open(dst, "rb").read())
assert len(rom) == 0x400000
rom[0x7FD7] = 0x0C                       # 4 MB
rom[0x7FDC:0x7FE0] = b"\xFF\xFF\x00\x00"
s = sum(rom) & 0xFFFF
rom[0x7FDE:0x7FE0] = struct.pack("<H", s)
rom[0x7FDC:0x7FDE] = struct.pack("<H", s ^ 0xFFFF)
assert sum(rom) & 0xFFFF == s
open(dst, "wb").write(rom)
print(f"bloques: {len(entries)}, datos hasta {pos:#x} ({(pos - DATA0) / 1024:.1f} KB), "
      f"tabla {len(tbl)} bytes, checksum {s:#06x}")
