local config = require("ridiculous.config")

local uv = vim.uv or vim.loop

local M = {}

local active = false
local timer = nil

local MAX_AMPLITUDE = 5

local STEP_SLOW, STEP_FAST = 34, 26

---@param amp integer
---@return integer[] bi
---@return integer[] uni
local function build(amp)
  local bi, uni = {}, {}
  local v = amp
  while v >= 1 do
    bi[#bi + 1], bi[#bi + 2] = v, -v
    uni[#uni + 1], uni[#uni + 2] = v, 0
    v = math.floor(v * 0.65)
  end
  bi[#bi + 1] = 0
  return bi, uni
end

---@param intensity number 0..1
---@return table|nil
local function pattern_for(intensity)
  local amp = math.floor(intensity * MAX_AMPLITUDE + 0.5)
  if amp < 1 then
    return nil
  end
  local bi, uni = build(amp)
  return {
    bi = bi,
    uni = uni,
    step = math.floor(STEP_SLOW - (STEP_SLOW - STEP_FAST) * intensity + 0.5),
  }
end

---@return boolean ok
---@return integer|nil topline
---@return integer|nil pos how far `topline` may increase
---@return integer|nil neg how far `topline` may decrease
local function room()
  if active or config.muted() or not config.options.shake then
    return false
  end
  if vim.o.lazyredraw or vim.fn.reg_executing() ~= "" then
    return false
  end
  if vim.fn.getcmdwintype() ~= "" then
    return false
  end

  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end

  local height = vim.api.nvim_win_get_height(win)
  if height < 6 then
    return false
  end

  local view = vim.fn.winsaveview()
  local topline = view.topline
  local last = vim.api.nvim_buf_line_count(0)
  local sl = vim.fn.winline()
  local so = math.min(vim.o.scrolloff, math.floor(height / 2))

  local pos = math.min(sl - so - 2, last - height + 1 - topline)
  local neg = math.min(topline - 1, height - so - 1 - sl)

  return true, topline, math.max(0, pos), math.max(0, neg)
end

---@return integer[]|nil
local function fit(pattern, pos, neg)
  local both = math.min(pos, neg)
  local frames = {}

  if both >= 1 then
    for i, f in ipairs(pattern.bi) do
      if f > 0 then
        frames[i] = math.min(f, both)
      elseif f < 0 then
        frames[i] = -math.min(-f, both)
      else
        frames[i] = 0
      end
    end
    return frames
  end

  local sign, avail = 1, pos
  if neg > pos then
    sign, avail = -1, neg
  end
  if avail < 1 then
    return nil
  end
  for i, f in ipairs(pattern.uni) do
    frames[i] = sign * math.min(f, avail)
  end
  return frames
end

local function restore(topline)
  pcall(vim.fn.winrestview, { topline = topline })
end

---@param intensity number 0..1, typically derived from typing combo
function M.shake(intensity)
  intensity = math.max(0, math.min(1, (intensity or 0.5) * config.options.shake_intensity))

  local pattern = pattern_for(intensity)
  if not pattern then
    return
  end
  local ok, topline, pos, neg = room()
  if not ok then
    return
  end
  local frames = fit(pattern, pos, neg)
  if not frames then
    return
  end
  local step = pattern.step

  active = true
  timer = uv.new_timer()
  local i = 0
  timer:start(
    0,
    step,
    vim.schedule_wrap(function()
      i = i + 1
      local offset = frames[i]
      if offset == nil then
        if timer then
          timer:stop()
          pcall(function()
            timer:close()
          end)
          timer = nil
        end
        active = false
        return
      end
      restore(topline + offset)
    end)
  )
end

function M.stop()
  if timer then
    timer:stop()
    pcall(function()
      timer:close()
    end)
    timer = nil
  end
  active = false
end

return M
