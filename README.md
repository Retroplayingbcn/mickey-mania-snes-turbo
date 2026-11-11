# Mickey Mania (SNES, USA) – Turbo 4MB

Load-time patch for **Mickey Mania: The Timeless Adventures of Mickey Mouse** (Traveller's Tales / Sony Imagesoft, 1994) for the Super Nintendo. It removes almost all of the "Mickey checks his watch" loading pauses **without changing gameplay**.

Made with AI (Claude) by [RetroPlayingBCN](https://www.retroplayingbcn.es).

**[⬇ Download the latest release](https://github.com/Retroplayingbcn/mickey-mania-snes-turbo/releases/latest)** · [Article on RetroPlayingBCN (Spanish)](https://www.retroplayingbcn.es/2026/11/mickey-mania-parche-mejora-snes.html)

## Which patch do I need?

Use the patch that matches your ROM (no copier header). Apply it with Floating IPS (Flips), Rom Patcher JS or any BPS patcher.

| Patch | Base ROM | Base MD5 | Result MD5 | Result CRC32 |
|---|---|---|---|---|
| `Mickey Mania (USA) - Turbo 4MB v4.bps` (**recommended**) | USA | `e3f9cc6d8321fa661a30cabe5dce141a` | `bbbb8aa83a135b924c26222720d23cfe` | `bd53c387` |
| `Mickey Mania (USA) - FastROM fix.bps` | USA | `e3f9cc6d8321fa661a30cabe5dce141a` | `e683d0a4852e855db4cc489cf85d7fff` | `20be1d73` |
| `Mickey Mania (Japan) - FastROM fix.bps` | Japan | `ac416a3a1d727895c404aeebd9633f32` | `2bb6723922df9ab89e492cceec843570` | `b449d364` |

- The Turbo patch outputs a 4 MB LoROM image. Your flash cart or emulator must support 4 MB ROMs.
- The FastROM-only patches keep the original 2 MB size and only fix the FastROM bug.

## Results

Measured in Mesen with identical input and no scenes skipped:

| | Original | Turbo v4 |
|---|---|---|
| Menu → first level | 21.1 s | 13.1 s |
| The Wharf → The Mad Doctor | 21.4 s | 13.5 s |
| "Watch" screen between levels | 5.6 s | 0.7 s |

On a real SNES with an SD2SNES, loads take about one second. The remaining time between stages is mostly the game's own scenes (pencil intro, title card), plus about a second to upload music to the sound chip.

## What the patch does

- **FastROM enabled.** The header declares FastROM, but the boot code never sets `$420D`, so the whole game ran from slow ROM.
- **RNC ProPack decompressor rewritten.** The method 1 decompressor at `$BF:A657` was rewritten in 65816 with direct-lookup Huffman tables, a 32-bit bit window and `MVN` copies. It is 1.8× faster and was verified byte-for-byte against the original on all 299 blocks.
- **Pre-decompressed data (4 MB).** All 299 RNC1 blocks are stored already decompressed in banks `$C0`–`$FE`, with a lookup table at `$FF:8000`. They are copied to WRAM by DMA (channel 2, unused by the game) in 512-byte chunks, roughly 75× faster than decompressing. Any block not in the table falls back to the fast decompressor.
- **Skippable title cards.** Movie title cards (e.g. "THE MAD DOCTOR 1933") can be skipped with Start/A/B/X/Y once they finish fading in. The Congratulations screen and the pencil intro were already skippable with Start in the original.
- **Song cache.** When the requested song is already loaded in the SPC700 (for example, after losing a life), it is no longer uploaded again. That upload used to cost about a second. The last song number is kept in `$436B`, a free DMA register byte.

Physics, enemies, difficulty, animations and music are unchanged.

## Building from source

Requires Python 3 and [asar](https://github.com/RPGHacker/asar).

```sh
./build.sh "Mickey Mania - The Timeless Adventures of Mickey Mouse (USA).sfc" /path/to/asar
```

This writes `build/mickey_mania_turbo_v4.sfc` and checks its CRC32 (`BD53C387`). The output is byte-identical to the released patch.

| File | Purpose |
|---|---|
| `src/fastrom_patch.py` | FastROM fix |
| `src/gen_tables.py`, `src/rnc_fast.asm` | Fast RNC1 decompressor |
| `src/rnc.py` | Reference RNC1 decoder in Python, with CRC check |
| `src/build_v2.py`, `src/turbo.asm` | 4 MB expansion, pre-decompressed blocks, lookup table and DMA path |
| `src/build_v4.py`, `src/extras.asm` | Skippable title cards and song cache |
| `test/` | Mesen harness that compares the new decompressor with the original, block by block |

## Testing

- Real SNES with SD2SNES: first level and stage-to-stage transitions.
- Mesen:
  - all 23 stage transitions of the game sequence;
  - repeated deaths and respawns;
  - boot, title and menus, with audio identical to the original;
  - SPC700 RAM and decompressed data compared byte-for-byte with the original where relevant.
- Not tested yet: a full playthrough to the ending on real hardware.

## Notes

No ROMs are provided here. You must supply your own dump.

Feedback and bug reports are welcome at [retroplayingbcn.es](https://www.retroplayingbcn.es) or in this repository's Issues.

---

**Español:** parche que elimina casi todas las cargas de Mickey Mania en Super Nintendo: activa el FastROM, reescribe el descompresor y amplía la ROM a 4 MB con los datos ya descomprimidos. La jugabilidad no cambia. Artículo completo en [RetroPlayingBCN](https://www.retroplayingbcn.es/2026/11/mickey-mania-parche-mejora-snes.html).
