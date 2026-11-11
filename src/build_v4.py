"""v4 = v2 turbo + extras.asm (rótulo saltable y caché de canción).
Uso: python3 build_v4.py v2.sfc salida.sfc asar extras.asm"""
import struct, subprocess, sys
src, dst, asar, asm = sys.argv[1:5]
rom = bytearray(open(src, "rb").read()); assert len(rom) == 0x400000
open(dst, "wb").write(rom)
r = subprocess.run([asar, "--fix-checksum=off", asm, dst], capture_output=True, text=True)
print(r.stdout.strip(), r.stderr.strip()); assert r.returncode == 0
rom = bytearray(open(dst, "rb").read()); assert len(rom) == 0x400000
rom[0x7FDC:0x7FE0] = b"\xFF\xFF\x00\x00"
s = sum(rom) & 0xFFFF
rom[0x7FDE:0x7FE0] = struct.pack("<H", s); rom[0x7FDC:0x7FDE] = struct.pack("<H", s ^ 0xFFFF)
open(dst, "wb").write(rom); print(f"checksum {s:#06x}")
