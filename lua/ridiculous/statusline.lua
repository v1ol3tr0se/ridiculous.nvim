local config = require("ridiculous.config")
local state = require("ridiculous.state")

local M = {}

local FILLED = "▰"
local EMPTY = "▱"

---@param width? integer
function M.bar(width)
  width = width or config.options.statusline.width
  local filled = math.floor(state.progress() * width + 0.5)
  return FILLED:rep(filled) .. EMPTY:rep(math.max(0, width - filled))
end

---@return string
function M.status()
  local s = config.options.statusline
  local icon = s.icon ~= "" and (s.icon .. " ") or ""
  return ("%s%d %s %d%%%%"):format(icon, state.data.level, M.bar(), math.floor(state.progress() * 100))
end

---@return string
function M.text()
  local s = config.options.statusline
  local icon = s.icon ~= "" and (s.icon .. " ") or ""
  return ("%s%d %s %d%%"):format(icon, state.data.level, M.bar(), math.floor(state.progress() * 100))
end

function M.lualine()
  return {
    M.status,
    cond = function()
      return config.options.enabled
    end,
  }
end

local COMBO_HEAT = { "RidiculousBlip2", "RidiculousBlip3", "RidiculousBlip4" }

---@return number
local function combo()
  return require("ridiculous.tracker").combo()
end

---@return string
function M.combo()
  local s = config.options.statusline
  local c = combo()
  if c < s.combo_min then
    return ""
  end
  local icon = s.combo_icon ~= "" and (s.combo_icon .. " ") or ""
  return ("%s%d"):format(icon, math.floor(c))
end

function M.combo_lualine()
  return {
    M.combo,
    cond = function()
      return config.options.enabled and combo() >= config.options.statusline.combo_min
    end,
    color = function()
      local i = math.min(#COMBO_HEAT, math.floor(combo() / 18 * #COMBO_HEAT) + 1)
      local group = vim.api.nvim_get_hl(0, { name = COMBO_HEAT[i], link = false })
      return { fg = group.fg and ("#%06x"):format(group.fg) or nil, gui = "bold" }
    end,
  }
end

return M
