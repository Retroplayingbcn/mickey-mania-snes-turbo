"""Decodificador de referencia Rob Northen Compression (ProPack) método 1.

Sigue la semántica de ProPack (equivalente al 'dernc' clásico):
  - búfer de bits de 32 bits, LSB = siguiente bit; se recarga cuando quedan <16
    bits leyendo la siguiente palabra little-endian en el puntero p.
  - p apunta a la última palabra cargada en la parte alta del búfer.
  - los literales se copian desde p (alineados a byte) y después 'bitread_fix'
    sustituye los 16 bits altos por la palabra en el nuevo p.

Uso como módulo: decode(data, offset) -> (salida, stats, cabecera)
CLI: python3 -I rnc.py ROM   (valida todos los bloques RNC1 por longitud y CRC)
"""
import re
import struct
import sys
from collections import Counter

_CRC = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0xA001 if _c & 1 else _c >> 1
    _CRC.append(_c)


def crc16(data):
    crc = 0
    for b in data:
        crc = _CRC[(crc ^ b) & 0xFF] ^ (crc >> 8)
    return crc


class Bits:
    def __init__(self, d, p):
        self.d, self.p = d, p
        self.buf = self.lword(p)
        self.cnt = 16

    def lword(self, p):
        return self.d[p] | (self.d[p + 1] << 8)

    def advance(self, n):
        self.buf >>= n
        self.cnt -= n
        if self.cnt < 16:
            self.p += 2
            self.buf |= self.lword(self.p) << self.cnt
            self.cnt += 16

    def read(self, n):
        v = self.buf & ((1 << n) - 1)
        self.advance(n)
        return v

    def fix(self):
        self.cnt -= 16
        self.buf &= (1 << self.cnt) - 1
        self.buf |= self.lword(self.p) << self.cnt
        self.cnt += 16


def mirror(x, n):
    r = 0
    for _ in range(n):
        r = (r << 1) | (x & 1)
        x >>= 1
    return r


def read_table(bs):
    num = bs.read(5)
    lens = [bs.read(4) for _ in range(num)]
    tab = []
    codeb = 0
    for k in range(1, 17):
        for i, l in enumerate(lens):
            if l == k:
                tab.append((mirror(codeb >> (16 - k), k), k, i))
                codeb += 1 << (16 - k)
    return tab, lens


def huf_read(bs, tab, st):
    for idx, (code, L, val) in enumerate(tab):
        if bs.buf & ((1 << L) - 1) == code:
            break
    else:
        raise ValueError("Huffman inválido")
    st["codelen"][L] += 1
    st["search_steps"] += idx + 1
    bs.advance(L)
    if val >= 2:
        v = 1 << (val - 1)
        v |= bs.read(val - 1)
        st["extra_bits"] += val - 1
        return v
    return val


def decode(d, off=0):
    if d[off:off + 3] != b"RNC" or d[off + 3] != 1:
        raise ValueError("no es RNC1")
    unp, pk = struct.unpack(">II", d[off + 4:off + 12])
    ucrc, pcrc = struct.unpack(">HH", d[off + 12:off + 16])
    st = {"codelen": Counter(), "search_steps": 0, "extra_bits": 0, "literals": 0,
          "matches": 0, "match_bytes": 0, "chunks": 0, "symbols": 0, "tables": []}
    bs = Bits(d, off + 18)
    bs.advance(2)
    out = bytearray()
    while len(out) < unp:
        st["chunks"] += 1
        raw, lr = read_table(bs)
        dist, ld = read_table(bs)
        ln, ll = read_table(bs)
        st["tables"].append((lr, ld, ll))
        cnt = bs.read(16)
        while True:
            n = huf_read(bs, raw, st)
            st["symbols"] += 1
            if n:
                out += d[bs.p:bs.p + n]
                bs.p += n
                st["literals"] += n
                bs.fix()
            cnt -= 1
            if cnt <= 0:
                break
            pos = huf_read(bs, dist, st) + 1
            L = huf_read(bs, ln, st) + 2
            st["symbols"] += 2
            st["matches"] += 1
            st["match_bytes"] += L
            for _ in range(L):
                out.append(out[-pos])
    return bytes(out), st, (unp, pk, ucrc, pcrc, d[off + 17])


def blocks(rom):
    for m in re.finditer(rb"RNC\x01", rom):
        o = m.start()
        unp, pk = struct.unpack(">II", rom[o + 4:o + 12])
        if 0 < unp < 0x100000 and pk <= len(rom):
            yield o


if __name__ == "__main__":
    rom = open(sys.argv[1], "rb").read()
    ok = bad = 0
    agg = Counter()
    tot = Counter()
    for o in blocks(rom):
        try:
            out, st, (unp, pk, ucrc, pcrc, ch) = decode(rom, o)
            good = len(out) == unp and crc16(out) == ucrc
        except Exception as e:
            good, st = False, None
            print("excepción", hex(o), e)
        if good:
            ok += 1
            agg.update(st["codelen"])
            for k in ("search_steps", "extra_bits", "literals", "matches", "match_bytes", "symbols"):
                tot[k] += st[k]
            tot["out"] += len(out)
        else:
            bad += 1
            if bad <= 5:
                print("fallo en", hex(o))
    print(f"bloques RNC1 OK {ok}, fallidos {bad}")
    s = sum(agg.values())
    print("longitud de código Huffman (% símbolos):",
          {k: round(100 * v / s, 1) for k, v in sorted(agg.items())})
    acc = 0
    for k in sorted(agg):
        acc += agg[k]
        print(f"  <= {k:2d} bits: {100 * acc / s:5.1f}%")
    print("totales:", dict(tot))
    print(f"pasos de búsqueda lineal por símbolo: {tot['search_steps'] / tot['symbols']:.2f}")
