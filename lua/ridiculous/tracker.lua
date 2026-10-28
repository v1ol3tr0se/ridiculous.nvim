local config = require("ridiculous.config")
local effects = require("ridiculous.effects")
local shake = require("ridiculous.shake")
local sound = require("ridiculous.sound")
local state = require("ridiculous.state")

local uv = vim.uv or vim.loop

local M = {}

local attached = {}
local last_char = nil
local combo = 0
local last_key_ms = 0
local decay_timer = nil

local DECAY = 2.2

local SHAKE_MAX_COMBO = 10

local function bump_combo()
  local now = uv.now()
  local dt = last_key_ms > 0 and (now - last_key_ms) / 1000 or 10
  last_key_ms = now
  combo = math.min(combo * math.exp(-DECAY * dt) + 1, 18)
  return combo
end

---@return number
function M.combo()
  if last_key_ms == 0 then
    return 0
  end
  return combo * math.exp(-DECAY * (uv.now() - last_key_ms) / 1000)
end

local function stop_decay()
  if decay_timer then
    decay_timer:stop()
    pcall(function()
      decay_timer:close()
    end)
    decay_timer = nil
  end
end

local function redraw_statusline()
  local lualine = package.loaded["lualine"]
  if lualine then
    pcall(lualine.refresh, { place = { "statusline" } })
  else
    pcall(vim.cmd, "redrawstatus")
  end
end

local function refresh_combo()
  if decay_timer then
    return
  end
  decay_timer = uv.new_timer()
  decay_timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      redraw_statusline()
      if M.combo() < config.options.statusline.combo_min then
        stop_decay()
      end
    end)
  )
end

---@param buf integer
local function ignored(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return true
  end
  local ig = config.options.ignore
  if vim.tbl_contains(ig.buftypes, vim.bo[buf].buftype) then
    return true
  end
  if vim.tbl_contains(ig.filetypes, vim.bo[buf].filetype) then
    return true
  end
  return false
end

local function should_react(buf)
  if not config.options.enabled then
    return false
  end
  if buf ~= vim.api.nvim_get_current_buf() then
    return false
  end
  if vim.fn.reg_executing() ~= "" then
    return false
  end
  if vim.fn.getcmdwintype() ~= "" then
    return false
  end
  if ignored(buf) then
    return false
  end
  return true
end

---@param buf integer
---@param inserted integer bytes added
---@param deleted integer bytes removed
---@param added_lines integer
local function react(buf, inserted, deleted, added_lines)
  if not should_react(buf) then
    return
  end

  local o = config.options
  local net = inserted - deleted

  if net > 0 then
    local chars = math.max(1, math.min(net, o.leveling.max_xp_per_event))
    state.bump("chars", chars)
    local gained = state.add_xp(chars * o.leveling.xp_per_char)

    if added_lines > 0 then
      state.bump("newlines", added_lines)
      effects.newline()
      sound.newline()
      shake.shake(0.5)
    else
      local c = bump_combo()
      effects.blip(last_char, c)
      sound.blip(c)
      shake.shake((c - 1) / (SHAKE_MAX_COMBO - 1))
      refresh_combo()
    end

    if gained > 0 then
      effects.fireworks(state.data.level)
      sound.levelup()
    end
  elseif net < 0 then
    state.bump("deletes", 1)
    local magnitude = 1
    if -net > 40 then
      magnitude = 4
    elseif -net > 10 then
      magnitude = 3
    elseif -net > 2 then
      magnitude = 2
    end
    effects.boom(magnitude)
    sound.boom()
    shake.shake(0.25 * magnitude)
  end

  last_char = nil
end

---@param buf integer
function M.attach(buf)
  if attached[buf] or ignored(buf) then
    return
  end
  attached[buf] = true

  vim.api.nvim_buf_attach(buf, false, {
    on_bytes = function(_, b, _, _, _, _, _, _, old_len, new_end_row, _, new_len)
      if not config.options.enabled then
        return
      end
      if old_len == new_len then
        return
      end
      vim.schedule(function()
        react(b, new_len, old_len, new_end_row)
      end)
    end,
    on_detach = function(_, b)
      attached[b] = nil
    end,
    on_reload = function() end,
  })
end

function M.detach_all()
  attached = {}
end

function M.setup()
  local group = vim.api.nvim_create_augroup("RidiculousTracker", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    callback = function()
      last_char = vim.v.char
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "TabLeave" }, {
    group = group,
    callback = function()
      effects.clear()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      effects.clear()
      shake.stop()
      stop_decay()
      state.save()
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.attach(buf)
    end
  end
end

return M
