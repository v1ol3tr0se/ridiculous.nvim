local M = {}

M.rate = 22050

local function u32(n)
  n = math.floor(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

local function u16(n)
  n = math.floor(n)
  return string.char(n % 256, math.floor(n / 256) % 256)
end

---@param samples number[]
---@return string
local function encode(samples)
  local out = {}
  for i = 1, #samples do
    local v = samples[i]
    if v > 1 then
      v = 1
    elseif v < -1 then
      v = -1
    end
    local s = math.floor(v * 32000 + 0.5)
    if s < 0 then
      s = s + 65536
    end
    out[i] = string.char(s % 256, math.floor(s / 256))
  end
  local pcm = table.concat(out)
  -- stylua: ignore
  return table.concat({
    "RIFF", u32(36 + #pcm), "WAVE",
    "fmt ", u32(16), u16(1), u16(1), u32(M.rate), u32(M.rate * 2), u16(2), u16(16),
    "data", u32(#pcm), pcm,
  })
end

local seed = 20250730
local function rnd()
  seed = (seed * 16807) % 2147483647
  return seed / 2147483647
end

local function noise()
  return rnd() * 2 - 1
end

local function edges(i, n, attack, release)
  local t = i / M.rate
  local tail = (n - i) / M.rate
  return math.min(1, t / attack) * math.min(1, tail / release)
end

---@param freq number
function M.blip(freq)
  local n = math.floor(M.rate * 0.055)
  local s, phase = {}, 0
  for i = 0, n - 1 do
    local t = i / M.rate
    local env = math.exp(-t * 48) * edges(i, n, 0.002, 0.006)
    phase = phase + freq / M.rate
    local square = (phase % 1) < 0.5 and 1 or -1
    s[i + 1] = 0.32 * env * (0.5 * square + 0.5 * math.sin(2 * math.pi * phase))
  end
  return encode(s)
end

function M.boom()
  local n = math.floor(M.rate * 0.30)
  local s, phase = {}, 0
  for i = 0, n - 1 do
    local t = i / M.rate
    local f = 40 + 180 * math.exp(-t * 11)
    phase = phase + f / M.rate
    local low = math.sin(2 * math.pi * phase) * math.exp(-t * 8)
    local ns = noise() * math.exp(-t * 22)
    s[i + 1] = 0.55 * edges(i, n, 0.002, 0.02) * (0.62 * low + 0.38 * ns)
  end
  return encode(s)
end

function M.newline()
  local n = math.floor(M.rate * 0.10)
  local s, phase = {}, 0
  for i = 0, n - 1 do
    local t = i / M.rate
    local f = 380 + 780 * (1 - math.exp(-t * 26))
    phase = phase + f / M.rate
    local env = math.exp(-t * 18) * edges(i, n, 0.003, 0.01)
    s[i + 1] = 0.28 * env * (math.sin(2 * math.pi * phase) + 0.3 * math.sin(4 * math.pi * phase))
  end
  return encode(s)
end

function M.levelup()
  local notes = { 523.25, 659.25, 783.99, 1046.50 }
  local step = 0.10
  local n = math.floor(M.rate * (step * (#notes - 1) + 0.75))
  local s = {}
  for i = 1, n do
    s[i] = 0
  end
  for idx, f in ipairs(notes) do
    local start = math.floor(M.rate * step * (idx - 1))
    local phase = 0
    for i = start, n - 1 do
      local t = (i - start) / M.rate
      local env = math.exp(-t * 2.6) * math.min(1, t / 0.004)
      phase = phase + f / M.rate
      local body = math.sin(2 * math.pi * phase)
        + 0.30 * math.sin(4 * math.pi * phase)
        + 0.15 * math.sin(6 * math.pi * phase)
      s[i + 1] = s[i + 1] + 0.16 * env * body
    end
  end
  return encode(s)
end

return M
