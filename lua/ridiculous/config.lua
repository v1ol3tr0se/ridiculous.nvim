local prefs = require("ridiculous.prefs")

local M = {}

M.defaults = {
  enabled = true,

  blips = true,
  chars = true,
  explosions = true,
  newline = true,
  fireworks = true,
  shake = true,
  sound = true,

  reduced_effects = false,

  volume = 0.5,
  shake_intensity = 1.0,

  leveling = {
    base_xp = 50,
    growth = 1.35,
    xp_per_char = 1,
    max_xp_per_event = 40,
  },

  effects = {
    fps = 60,
    max_particles = 96,
    blip_life = 0.45,
    boom_particles = 10,
    boom_life = 0.55,
    firework_bursts = 4,
    firework_particles = 22,
    banner = true,
  },

  audio = {
    player = nil,
    throttle_ms = 28,
    max_concurrent = 8,
  },

  statusline = {
    icon = "󰊴",
    width = 6,
    combo_icon = "󰈸",
    combo_min = 2,
  },

  ignore = {
    filetypes = {
      "TelescopePrompt",
      "neo-tree",
      "snacks_picker_input",
      "snacks_picker_list",
      "snacks_dashboard",
      "dashboard",
      "alpha",
      "lazy",
      "mason",
      "help",
      "qf",
      "oil",
      "NvimTree",
      "gitcommit.diff",
    },
    buftypes = { "nofile", "prompt", "terminal", "quickfix", "help" },
  },
}

---@type table
M.options = vim.deepcopy(M.defaults)

M.features = {
  { key = "b", name = "blips", label = "blips" },
  { key = "c", name = "chars", label = "typed chars" },
  { key = "e", name = "explosions", label = "explosions" },
  { key = "n", name = "newline", label = "newline swoosh" },
  { key = "f", name = "fireworks", label = "fireworks" },
  { key = "s", name = "shake", label = "screen shake" },
  { key = "a", name = "sound", label = "audio" },
  { key = "r", name = "reduced_effects", label = "reduced effects" },
}

M.persisted = { "enabled", "volume", "shake_intensity" }
for _, f in ipairs(M.features) do
  M.persisted[#M.persisted + 1] = f.name
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  for _, key in ipairs(M.persisted) do
    local saved = prefs.load()[key]
    if saved ~= nil and type(saved) == type(M.options[key]) then
      M.options[key] = saved
    end
  end

  M.options.volume = math.max(0, math.min(1, M.options.volume))
  return M.options
end

---@param key string
---@param value boolean|number
function M.remember(key, value)
  if vim.tbl_contains(M.persisted, key) then
    prefs.set(key, value)
  end
end

function M.forget()
  prefs.clear()
end

function M.muted()
  return not M.options.enabled or M.options.reduced_effects
end

return setmetatable(M, {
  __index = function(_, k)
    return M.options[k]
  end,
})
