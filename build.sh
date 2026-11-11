#!/bin/sh
# Construye Mickey Mania Turbo 4MB v4 desde la ROM USA original.
# Uso: ./build.sh "Mickey Mania - The Timeless Adventures of Mickey Mouse (USA).sfc" [ruta/a/asar]
set -e
BASE="$1"; ASAR="${2:-asar}"
[ -f "$BASE" ] || { echo "Uso: $0 rom_usa.sfc [asar]"; exit 1; }
D=$(cd "$(dirname "$0")" && pwd); B="$D/build"; mkdir -p "$B"
python3 "$D/src/fastrom_patch.py" "$BASE" "$B/v1.sfc"
( cd "$D/src" && python3 gen_tables.py tablas.asm )
"$ASAR" --fix-checksum=on "$D/src/rnc_fast.asm" "$B/v1.sfc"
python3 "$D/src/build_v2.py" "$B/v1.sfc" "$B/v2.sfc" "$ASAR" "$D/src/turbo.asm"
python3 "$D/src/build_v4.py" "$B/v2.sfc" "$B/mickey_mania_turbo_v4.sfc" "$ASAR" "$D/src/extras.asm"
python3 -c "import zlib,sys;d=open(sys.argv[1],'rb').read();print('CRC32 %08X (esperado BD53C387)'%zlib.crc32(d))" "$B/mickey_mania_turbo_v4.sfc"
