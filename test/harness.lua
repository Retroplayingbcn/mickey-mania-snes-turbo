-- Arnés: en cada marca calcula CRC16 de la salida en $7F:0000 y ciclos/relojes.
-- Constantes MARK/DONE/START/BLOCKS/OUT se sustituyen al generar el script.
local MARK, DONE, START = __MARK__, __DONE__, __START__
local OUT = "__OUT__"
dofile("__BLOCKS__")

local crct = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c & 1 == 1 then c = (c >> 1) ~ 0xA001 else c = c >> 1 end
  end
  crct[i] = c
end

local idx = 0
local lastM, lastC = nil, nil
local res = {}

emu.addMemoryCallback(function()
  local s = emu.getState()
  lastM, lastC = s["masterClock"], s["cpu.cycleCount"]
end, emu.callbackType.exec, START, START, emu.cpuType.snes, emu.memType.snesMemory)

emu.addMemoryCallback(function()
  local s = emu.getState()
  local m, c = s["masterClock"], s["cpu.cycleCount"]
  idx = idx + 1
  local b = HB[idx]
  local n = b[2]
  local crc = 0
  for a = 0, n - 1 do
    local v = emu.read(0x7F0000 + a, emu.memType.snesMemory)
    crc = crct[(crc ~ v) & 0xFF] ~ (crc >> 8)
  end
  res[#res + 1] = string.format("%d,%d,%d,%d,%d,%d", b[1], n, b[3], crc, m - lastM, c - lastC)
  lastM, lastC = m, c
end, emu.callbackType.exec, MARK, MARK, emu.cpuType.snes, emu.memType.snesMemory)

emu.addMemoryCallback(function()
  local f = io.open(OUT, "w")
  f:write("off,unp,crc_exp,crc_got,master,cycles\n")
  for _, l in ipairs(res) do f:write(l, "\n") end
  f:close()
  emu.stop(0)
end, emu.callbackType.exec, DONE, DONE, emu.cpuType.snes, emu.memType.snesMemory)
