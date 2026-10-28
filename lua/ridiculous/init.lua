local config = require("ridiculous.config")
local effects = require("ridiculous.effects")
local highlights = require("ridiculous.highlights")
local prefs = require("ridiculous.prefs")
local shake = require("ridiculous.shake")
local sound = require("ridiculous.sound")
local state = require("ridiculous.state")
local statusline = require("ridiculous.statusline")
local tracker = require("ridiculous.tracker")

local M = {}

M.config = config
M.state = state

local did_setup = false

---@param opts? table see config.defaults
function M.setup(opts)
  config.setup(opts)
  if did_setup then
    return
  end
  did_setup = true

  highlights.apply()
  state.load()
  tracker.setup()

  local group = vim.api.nvim_create_augroup("Ridiculous", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = highlights.apply,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      prefs.flush()
      state.save()
    end,
  })

  if config.options.sound then
    vim.defer_fn(function()
      pcall(sound.ensure, false)
    end, 400)
  end
end

function M.is_setup()
  return did_setup
end

function M.statusline()
  return statusline.text()
end

---@param feature? string one of config.features, or nil / "enabled"
---@return boolean new value
function M.toggle(feature)
  feature = feature or "enabled"
  local o = config.options
  if type(o[feature]) ~= "boolean" then
    vim.notify("ridiculous.nvim: unknown feature " .. tostring(feature), vim.log.levels.WARN)
    return false
  end
  o[feature] = not o[feature]
  config.remember(feature, o[feature])

  if feature == "enabled" or feature == "reduced_effects" then
    if config.muted() then
      effects.clear()
      shake.stop()
    end
  elseif not o[feature] then
    effects.clear()
  end

  if feature == "sound" and o.sound then
    vim.defer_fn(function()
      pcall(sound.ensure, false)
    end, 0)
  end
  return o[feature]
end

function M.enable()
  config.options.enabled = true
  config.remember("enabled", true)
end

function M.disable()
  config.options.enabled = false
  config.remember("enabled", false)
  effects.clear()
  shake.stop()
end

function M.reset()
  state.reset()
  vim.notify("ridiculous.nvim: progress reset", vim.log.levels.INFO)
end

function M.forget()
  config.forget()
  vim.notify("ridiculous.nvim: saved settings forgotten (restart to apply)", vim.log.levels.INFO)
end

function M.panel()
  require("ridiculous.panel").open()
end

function M.stats()
  local d = state.data
  return table.concat({
    ("level %d  (%d / %d xp)"):format(d.level, d.xp, state.xp_for(d.level)),
    ("%d xp lifetime"):format(d.total_xp),
    ("%d chars typed, %d deletions, %d newlines"):format(d.chars, d.deletes, d.newlines),
    ("audio: %s"):format(sound.player() and sound.player().cmd or "none found"),
  }, "\n")
end

function M.demo()
  local was = config.options.enabled
  config.options.enabled = true
  effects.blip("R", 8)
  vim.defer_fn(function()
    effects.newline()
    sound.newline()
  end, 220)
  vim.defer_fn(function()
    effects.boom(3)
    sound.boom()
    shake.shake(0.9)
  end, 520)
  vim.defer_fn(function()
    effects.fireworks(state.data.level)
    sound.levelup()
  end, 1000)
  vim.defer_fn(function()
    config.options.enabled = was
  end, 3000)
end

function M.regen_sounds()
  sound.reset_player()
  local n = sound.ensure(true)
  vim.notify(("ridiculous.nvim: regenerated %d sounds in %s"):format(n, sound.dir), vim.log.levels.INFO)
end

return M
