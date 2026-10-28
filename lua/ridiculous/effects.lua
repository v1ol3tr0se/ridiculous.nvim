local config = require("ridiculous.config")
local hl = require("ridiculous.highlights")
local particles = require("ridiculous.particles")

local M = {}

local ASPECT = 2.0

local BLIP_GLYPHS = { "*", "✦", "+", "•" }
local BOOM_GLYPHS = { "✳", "✶", "✦", "*", "+", "·" }
local SPARKS = { "✦", "✧", "*", "·", "•", "◦" }

local function rand(lo, hi)
  return lo + math.random() * (hi - lo)
end

---@return integer|nil row
---@return integer|nil col
function M.cursor_cell()
  local ok, pos = pcall(vim.fn.screenpos, 0, vim.fn.line("."), vim.fn.col("."))
  if not ok or not pos or pos.row == 0 then
    return nil
  end
  return pos.row - 1, (pos.curscol or pos.col) - 1
end

local function glyph_for(char)
  if not char or char == "" then
    return nil
  end
  if char == " " then
    return "·"
  end
  if char == "\t" then
    return "»"
  end
  if vim.fn.strdisplaywidth(char) < 1 or char:match("^%c$") then
    return nil
  end
  return char
end

---@param char string|nil the character that was typed
---@param combo number typing speed, roughly chars per second
function M.blip(char, combo)
  local o = config.options
  if config.muted() or not o.blips then
    return
  end
  local row, col = M.cursor_cell()
  if not row then
    return
  end

  local glyph
  if o.chars then
    glyph = glyph_for(char)
  end
  glyph = glyph or BLIP_GLYPHS[math.random(#BLIP_GLYPHS)]

  local heat = math.min(1, (combo or 0) / 10)
  particles.emit({
    {
      x = col,
      y = row,
      vx = rand(-2, 2) * ASPECT,
      vy = -rand(8, 12) - heat * 6,
      gravity = 6,
      life = o.effects.blip_life,
      glyphs = { glyph },
      hls = hl.blip_gradient,
      blend = { 0, 90 },
    },
  })
end

---@param magnitude number 1 for a single character, larger for bigger deletes
function M.boom(magnitude)
  local o = config.options
  if config.muted() or not o.explosions then
    return
  end
  local row, col = M.cursor_cell()
  if not row then
    return
  end

  magnitude = math.max(1, math.min(4, magnitude or 1))
  local count = math.floor(o.effects.boom_particles * (0.6 + 0.4 * magnitude))
  local list = {}
  for i = 1, count do
    local angle = (i / count) * math.pi * 2 + rand(-0.2, 0.2)
    local speed = rand(9, 17) * (0.8 + 0.2 * magnitude)
    list[i] = {
      x = col,
      y = row,
      vx = math.cos(angle) * speed * ASPECT,
      vy = math.sin(angle) * speed * 0.6,
      gravity = 26,
      life = o.effects.boom_life * rand(0.7, 1.1),
      glyphs = BOOM_GLYPHS,
      hls = hl.boom_gradient,
      blend = { 0, 85 },
    }
  end
  particles.emit(list)
end

function M.newline()
  local o = config.options
  if config.muted() or not o.newline then
    return
  end
  local row, col = M.cursor_cell()
  if not row then
    return
  end

  local list = {}
  for i = 1, 7 do
    list[i] = {
      x = col - i * 1.5,
      y = row - 1,
      vx = rand(-16, -6) * ASPECT,
      vy = rand(-1.5, 1.5),
      gravity = 3,
      life = 0.34 * rand(0.7, 1.2),
      glyphs = { "─", "╌", "·" },
      hls = hl.newline_gradient,
      blend = { 10, 95 },
    }
  end
  particles.emit(list)
end

---@param level integer
function M.fireworks(level)
  local o = config.options
  if config.muted() or not o.fireworks then
    return
  end

  local bottom = math.max(1, vim.o.lines - vim.o.cmdheight - 2)
  for burst = 1, o.effects.firework_bursts do
    local delay = (burst - 1) * 160 + math.random(0, 90)
    vim.defer_fn(function()
      if config.muted() or not config.options.fireworks then
        return
      end
      local cx = rand(vim.o.columns * 0.15, vim.o.columns * 0.85)
      local cy = rand(bottom * 0.15, bottom * 0.65)
      local color = hl.firework_colors[math.random(#hl.firework_colors)]
      local list = {}
      for i = 1, o.effects.firework_particles do
        local angle = (i / o.effects.firework_particles) * math.pi * 2 + rand(-0.15, 0.15)
        local speed = rand(6, 14)
        list[i] = {
          x = cx,
          y = cy,
          vx = math.cos(angle) * speed * ASPECT,
          vy = math.sin(angle) * speed * 0.6,
          gravity = 14,
          life = rand(0.9, 1.5),
          glyphs = SPARKS,
          hls = { color, color, "RidiculousBoom3", "RidiculousBoom5" },
          blend = { 0, 92 },
        }
      end
      particles.emit(list)
    end, delay)
  end

  if o.effects.banner then
    M.banner(("★  LEVEL %d  ★"):format(level))
  end
end

local banner_win = nil
local banner_buf = nil

---@param text string
---@param duration? integer milliseconds
function M.banner(text, duration)
  if config.muted() then
    return
  end
  M.close_banner()

  if not (banner_buf and vim.api.nvim_buf_is_valid(banner_buf)) then
    banner_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[banner_buf].bufhidden = "hide"
  end
  local pad = "  "
  local line = pad .. text .. pad
  vim.api.nvim_buf_set_lines(banner_buf, 0, -1, false, { line })

  local width = vim.fn.strdisplaywidth(line)
  local ok, win = pcall(vim.api.nvim_open_win, banner_buf, false, {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - vim.o.cmdheight) / 2) - 2),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    width = width,
    height = 1,
    style = "minimal",
    focusable = false,
    noautocmd = true,
    zindex = 310,
    border = "rounded",
  })
  if not ok then
    return
  end
  banner_win = win
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:RidiculousBanner,NormalFloat:RidiculousBanner,FloatBorder:RidiculousBanner",
    { win = win }
  )

  local steps = 12
  local total = duration or 1500
  for i = 1, steps do
    vim.defer_fn(function()
      if banner_win == win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_set_option_value, "winblend", math.floor((i / steps) * 100), { win = win })
      end
    end, math.floor(total * 0.5) + math.floor((total * 0.5) * (i / steps)))
  end
  vim.defer_fn(function()
    if banner_win == win then
      M.close_banner()
    end
  end, total)
end

function M.close_banner()
  if banner_win and vim.api.nvim_win_is_valid(banner_win) then
    pcall(vim.api.nvim_win_close, banner_win, true)
  end
  banner_win = nil
end

function M.clear()
  particles.stop()
  M.close_banner()
end

return M
