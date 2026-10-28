if vim.g.loaded_ridiculous then
  return
end
vim.g.loaded_ridiculous = true

local SUBCOMMANDS = {
  panel = function()
    require("ridiculous").panel()
  end,
  toggle = function(feature)
    local r = require("ridiculous")
    local value = r.toggle(feature)
    vim.notify(("ridiculous.nvim: %s %s"):format(feature or "enabled", value and "on" or "off"))
  end,
  enable = function()
    require("ridiculous").enable()
  end,
  disable = function()
    require("ridiculous").disable()
  end,
  reset = function()
    require("ridiculous").reset()
  end,
  forget = function()
    require("ridiculous").forget()
  end,
  stats = function()
    vim.notify(require("ridiculous").stats(), vim.log.levels.INFO)
  end,
  demo = function()
    require("ridiculous").demo()
  end,
  ["regen-sounds"] = function()
    require("ridiculous").regen_sounds()
  end,
}

vim.api.nvim_create_user_command("Ridiculous", function(opts)
  local sub = opts.fargs[1] or "panel"
  local fn = SUBCOMMANDS[sub]
  if not fn then
    vim.notify("ridiculous.nvim: unknown subcommand " .. sub, vim.log.levels.ERROR)
    return
  end
  fn(opts.fargs[2])
end, {
  nargs = "*",
  desc = "Ridiculous Coding",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    if #args <= 2 then
      return vim.tbl_keys(SUBCOMMANDS)
    end
    if args[2] == "toggle" then
      local names = { "enabled" }
      for _, f in ipairs(require("ridiculous.config").features) do
        names[#names + 1] = f.name
      end
      return names
    end
    return {}
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("RidiculousBoot", { clear = true }),
  once = true,
  callback = function()
    if vim.g.ridiculous ~= nil then
      local r = require("ridiculous")
      if not r.is_setup() then
        r.setup(type(vim.g.ridiculous) == "table" and vim.g.ridiculous or {})
      end
    end
  end,
})
