"""Genera tablas.asm con las tablas constantes del descompresor RNC1 rápido.

Entrada de LUT e (1 byte) = (sym << 4) | L   (L = 1..6, 0 = escape)
Tablas indexadas por X = 2*e (palabras):
  TabL2[e]  = 2*L  (0 para escape)
  TabS2[e]  = 2*sym
Tablas indexadas por X = 2*sym:
  TabMaskS[sym] = (1<<(sym-1))-1   bits extra
  TabBaseS[sym] = 1<<(sym-1)
  TabN2S[sym]   = 2*(sym-1)
Indexada por X = 2*n:  TabMaskN[n] = (1<<n)-1
Rev8[v]: inversión de 8 bits (bytes).
"""
import sys

out = sys.argv[1]
L = []


def words(name, vals):
    L.append(f"{name}:")
    for i in range(0, len(vals), 8):
        L.append("    dw " + ",".join(f"${v & 0xFFFF:04X}" for v in vals[i:i + 8]))


def bytes_(name, vals):
    L.append(f"{name}:")
    for i in range(0, len(vals), 16):
        L.append("    db " + ",".join(f"${v:02X}" for v in vals[i:i + 16]))


tl2, ts2 = [], []
for e in range(256):
    l, s = e & 15, e >> 4
    tl2.append(2 * l if 1 <= l <= 6 else 0)
    ts2.append(2 * s)
words("TabL2", tl2)
words("TabS2", ts2)
# --- tablas por entrada e para el camino rápido (valor completo en un peek) ---
c2, sh2, me, be = [], [], [], []
for e in range(256):
    l, sy = e & 15, e >> 4
    n = sy - 1 if sy >= 2 else 0
    if not (1 <= l <= 6):
        c2.append(0)
    elif l + n <= 9:
        c2.append(2 * (l + n))
    else:
        c2.append(0x8000 | (2 * l))
    sh2.append(2 * l)
    me.append((1 << n) - 1 if sy >= 2 else 0)
    be.append((1 << n) if sy >= 2 else sy)
words("TabC2", c2)
words("TabSh2", sh2)
words("TabMaskE", me)
words("TabBaseE", be)
words("TabMaskS", [((1 << (s - 1)) - 1) if s >= 2 else 0 for s in range(16)])
words("TabBaseS", [(1 << (s - 1)) if s >= 2 else s for s in range(16)])
words("TabN2S", [2 * (s - 1) if s >= 2 else 0 for s in range(16)])
words("TabMaskN", [(1 << n) - 1 for n in range(17)])
bytes_("Rev8", [int(f"{v:08b}"[::-1], 2) for v in range(256)])
open(out, "w").write("\n".join(L) + "\n")
print("ok", out)
