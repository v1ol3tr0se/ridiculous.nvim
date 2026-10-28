local config = require("ridiculous.config")
local synth = require("ridiculous.synth")

local uv = vim.uv or vim.loop

local M = {}

local CACHE_VERSION = 1
local SEMITONES = 12
local BASE_FREQ = 600

M.dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "ridiculous.nvim", "sounds-v" .. CACHE_VERSION)

local generated = false
local in_flight = 0
local last_blip = 0

local PLAYERS = {
  {
    cmd = "pw-play",
    build = function(f, v)
      return { "pw-play", ("--volume=%.2f"):format(v), f }
    end,
  },
  {
    cmd = "paplay",
    build = function(f, v)
      return { "paplay", "--volume=" .. math.floor(v * 65536), f }
    end,
  },
  {
    cmd = "afplay",
    build = function(f, v)
      return { "afplay", "-v", ("%.2f"):format(v), f }
    end,
  },
  {
    cmd = "ffplay",
    build = function(f, v)
      return { "ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-volume", tostring(math.floor(v * 100)), f }
    end,
  },
  {
    cmd = "mpv",
    build = function(f, v)
      return { "mpv", "--no-video", "--really-quiet", "--volume=" .. math.floor(v * 100), f }
    end,
  },
  {
    cmd = "play",
    build = function(f, v)
      return { "play", "-q", "-v", ("%.2f"):format(v), f }
    end,
  },
  {
    cmd = "aplay",
    build = function(f, _)
      return { "aplay", "-q", f }
    end,
  },
  {
    cmd = "powershell",
    build = function(f, _)
      return {
        "powershell",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        ("(New-Object Media.SoundPlayer '%s').PlaySync()"):format(f),
      }
    end,
  },
}

local player_cache = false

---@return table|nil player entry
function M.player()
  if player_cache ~= false then
    return player_cache
  end
  local want = config.options.audio.player
  for _, p in ipairs(PLAYERS) do
    if (not want or want == p.cmd) and vim.fn.executable(p.cmd) == 1 then
      player_cache = p
      return p
    end
  end
  player_cache = nil
  return nil
end

function M.reset_player()
  player_cache = false
end

local function write_file(path, data)
  local fd, err = uv.fs_open(path, "w", 420)
  if not fd then
    return false, err
  end
  uv.fs_write(fd, data)
  uv.fs_close(fd)
  return true
end

local function catalog()
  local files = {
    ["boom.wav"] = synth.boom,
    ["newline.wav"] = synth.newline,
    ["levelup.wav"] = synth.levelup,
  }
  for i = 0, SEMITONES do
    files[("blip_%d.wav"):format(i)] = function()
      return synth.blip(BASE_FREQ * 2 ^ (i / 12))
    end
  end
  return files
end

---@param force boolean|nil regenerate even if the files already exist
function M.ensure(force)
  if generated and not force then
    return true
  end
  vim.fn.mkdir(M.dir, "p")
  local made = 0
  for name, gen in pairs(catalog()) do
    local path = vim.fs.joinpath(M.dir, name)
    if force or vim.fn.filereadable(path) == 0 then
      local ok, data = pcall(gen)
      if ok then
        write_file(path, data)
        made = made + 1
      end
    end
  end
  generated = true
  return made
end

local function spawn(argv)
  in_flight = in_flight + 1
  local done = function()
    in_flight = math.max(0, in_flight - 1)
  end
  if vim.system then
    local ok = pcall(vim.system, argv, { text = false }, vim.schedule_wrap(done))
    if not ok then
      done()
    end
  else
    local ok = pcall(vim.fn.jobstart, argv, { detach = false, on_exit = done })
    if not ok then
      done()
    end
  end
end

---@param name string file name inside the cache dir
---@param opts? { throttle?: boolean, volume?: number }
function M.play(name, opts)
  opts = opts or {}
  local o = config.options
  if config.muted() or not o.sound then
    return
  end
  local p = M.player()
  if not p then
    return
  end
  if in_flight >= o.audio.max_concurrent then
    return
  end
  if opts.throttle then
    local now = uv.now()
    if now - last_blip < o.audio.throttle_ms then
      return
    end
    last_blip = now
  end
  M.ensure(false)
  local path = vim.fs.joinpath(M.dir, name)
  if vim.fn.filereadable(path) == 0 then
    return
  end
  local vol = math.max(0, math.min(1, (opts.volume or 1) * o.volume))
  spawn(p.build(path, vol))
end

---@param combo number
function M.blip(combo)
  local step = math.max(0, math.min(SEMITONES, math.floor(combo or 0)))
  M.play(("blip_%d.wav"):format(step), { throttle = true, volume = 0.9 })
end

function M.boom()
  M.play("boom.wav", { volume = 1.0 })
end

function M.newline()
  M.play("newline.wav", { volume = 0.8 })
end

function M.levelup()
  M.play("levelup.wav", { volume = 1.0 })
end

return M
