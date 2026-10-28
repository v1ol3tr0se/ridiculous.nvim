local ridiculous = require("ridiculous")
local config = require("ridiculous.config")

ridiculous.setup({ sound = false })
ridiculous.setup({ sound = false, blips = false, volume = 3 })
assert(ridiculous.is_setup())
assert(config.options.blips == false, "second setup() should still apply options")
assert(config.options.volume == 1, "volume should clamp to 1")

local warnings = 0
vim.notify = function(_, level)
  if level == vim.log.levels.WARN then
    warnings = warnings + 1
  end
end

for _, name in ipairs({ "volume", "shake_intensity", "leveling", "statusline", "nope" }) do
  local kind = type(config.options[name])
  assert(ridiculous.toggle(name) == false, "toggle should refuse " .. name)
  assert(type(config.options[name]) == kind, "toggle changed " .. name)
end
assert(warnings == 5, "every refused toggle should warn")

assert(ridiculous.toggle("blips") == true)
assert(ridiculous.toggle("blips") == false)
assert(ridiculous.toggle() == false)
assert(ridiculous.toggle("enabled") == true)
