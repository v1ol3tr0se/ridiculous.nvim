local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local home = vim.fn.tempname()

for _, kind in ipairs({ "config", "data", "state", "cache" }) do
  vim.env["XDG_" .. kind:upper() .. "_HOME"] = vim.fs.joinpath(home, kind)
end

vim.opt.runtimepath:prepend(root)
vim.cmd.runtime("plugin/ridiculous.lua")
