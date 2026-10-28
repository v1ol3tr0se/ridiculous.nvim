local config = require("ridiculous.config")

local uv = vim.uv or vim.loop

local M = {}

---@class RidiculousParticle
---@field x number column, in cells, fractional
---@field y number row, in cells, fractional
---@field vx number cells per second
---@field vy number cells per second
---@field gravity number cells per second squared
---@field life number seconds remaining
---@field max_life number
---@field glyphs string[] cycled over the lifetime
---@field hls string[] cycled over the lifetime
---@field blend [number, number] winblend at birth and at death

local particles = {}
local pool = {}
local timer = nil
local last_tick = nil

local IGNORE_EVENTS = table.concat({
  "WinNew",
  "WinClosed",
  "WinEnter",
  "WinLeave",
  "WinScrolled",
  "WinResized",
  "BufAdd",
  "BufNew",
  "BufEnter",
  "BufLeave",
  "BufWinEnter",
  "BufWinLeave",
  "BufHidden",
  "TabEnter",
  "TabLeave",
}, ",")

local function max_row()
  return math.max(0, vim.o.lines - vim.o.cmdheight - 1)
end

local function new_slot()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  return { buf = buf, text = nil, win = nil, hl = nil, blend = nil, row = nil, col = nil, width = nil }
end

local function release_slot(slot)
  if slot.win and vim.api.nvim_win_is_valid(slot.win) then
    pcall(vim.api.nvim_win_close, slot.win, true)
  end
  slot.win = nil
  slot.row, slot.col, slot.width, slot.hl, slot.blend = nil, nil, nil, nil, nil
end

local function draw(slot, row, col, text, hl, blend)
  local width = math.max(1, vim.fn.strdisplaywidth(text))
  if col + width > vim.o.columns then
    width = vim.o.columns - col
    if width < 1 then
      return false
    end
  end

  if slot.text ~= text then
    pcall(vim.api.nvim_buf_set_lines, slot.buf, 0, -1, false, { text })
    slot.text = text
  end

  if slot.win and vim.api.nvim_win_is_valid(slot.win) then
    if slot.row ~= row or slot.col ~= col or slot.width ~= width then
      local ok = pcall(vim.api.nvim_win_set_config, slot.win, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = 1,
      })
      if not ok then
        release_slot(slot)
      else
        slot.row, slot.col, slot.width = row, col, width
      end
    end
  end

  if not (slot.win and vim.api.nvim_win_is_valid(slot.win)) then
    local ok, win = pcall(vim.api.nvim_open_win, slot.buf, false, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = 1,
      style = "minimal",
      border = "none",
      focusable = false,
      noautocmd = true,
      zindex = 300,
    })
    if not ok then
      return false
    end
    slot.win = win
    slot.row, slot.col, slot.width = row, col, width
    slot.hl, slot.blend = nil, nil
    vim.wo[win].wrap = false
    vim.wo[win].list = false
  end

  if slot.hl ~= hl then
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:" .. hl .. ",NormalFloat:" .. hl, { win = slot.win })
    slot.hl = hl
  end
  if slot.blend ~= blend then
    pcall(vim.api.nvim_set_option_value, "winblend", blend, { win = slot.win })
    slot.blend = blend
  end
  return true
end

local function at(list, progress, fallback)
  local n = list and #list or 0
  if n == 0 then
    return fallback
  end
  local i = math.floor(progress * n) + 1
  return list[math.max(1, math.min(n, i))] or fallback
end

function M.stop()
  if timer then
    timer:stop()
    pcall(function()
      timer:close()
    end)
    timer = nil
  end
  last_tick = nil
  particles = {}
  for _, slot in ipairs(pool) do
    release_slot(slot)
  end
end

local function tick()
  local now = uv.hrtime()
  local dt = last_tick and math.min((now - last_tick) / 1e9, 0.1) or 0.016
  last_tick = now

  local alive = {}
  for _, p in ipairs(particles) do
    p.life = p.life - dt
    if p.life > 0 then
      p.vy = p.vy + p.gravity * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      alive[#alive + 1] = p
    end
  end
  particles = alive

  if #particles == 0 then
    M.stop()
    return
  end

  local function paint()
    local bottom, right = max_row(), vim.o.columns - 1
    local used = 0
    for _, p in ipairs(particles) do
      local row = math.floor(p.y + 0.5)
      local col = math.floor(p.x + 0.5)
      if row >= 0 and row <= bottom and col >= 0 and col <= right then
        used = used + 1
        local slot = pool[used]
        if not slot then
          slot = new_slot()
          pool[used] = slot
        end
        local progress = 1 - (p.life / p.max_life)
        local b0, b1 = p.blend[1], p.blend[2]
        local blend = math.floor(b0 + (b1 - b0) * progress + 0.5)
        local glyph = at(p.glyphs, progress, "*")
        local group = at(p.hls, progress, "Normal")
        if not draw(slot, row, col, glyph, group, blend) then
          used = used - 1
        end
      end
    end

    for i = used + 1, #pool do
      release_slot(pool[i])
    end
  end

  local ei = vim.o.eventignore
  vim.o.eventignore = IGNORE_EVENTS
  local ok, err = pcall(paint)
  vim.o.eventignore = ei
  if not ok then
    error(err, 0)
  end
end

local function ensure_timer()
  if timer then
    return
  end
  timer = uv.new_timer()
  last_tick = nil
  local interval = math.max(8, math.floor(1000 / config.options.effects.fps))
  timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      local ok, err = pcall(tick)
      if not ok then
        M.stop()
        vim.notify("ridiculous.nvim: particle error: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  )
end

---@param list RidiculousParticle[]
function M.emit(list)
  if config.muted() then
    return
  end
  local budget = config.options.effects.max_particles - #particles
  if budget <= 0 then
    return
  end
  for i = 1, math.min(#list, budget) do
    local p = list[i]
    p.max_life = p.life
    p.gravity = p.gravity or 0
    p.blend = p.blend or { 0, 0 }
    particles[#particles + 1] = p
  end
  ensure_timer()
end

function M.count()
  return #particles
end

return M
