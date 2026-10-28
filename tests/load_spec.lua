for _, file in ipairs(vim.api.nvim_get_runtime_file("lua/ridiculous/*.lua", true)) do
  local name = vim.fn.fnamemodify(file, ":t:r")
  require(name == "init" and "ridiculous" or "ridiculous." .. name)
end

assert(vim.fn.exists(":Ridiculous") == 2, ":Ridiculous is missing")

local doc = vim.api.nvim_get_runtime_file("doc/ridiculous.txt", false)[1]
assert(doc, "doc/ridiculous.txt is missing")
vim.cmd.helptags(vim.fn.fnameescape(vim.fs.dirname(doc)))

vim.cmd.help("ridiculous")
vim.cmd.help(":Ridiculous")
for line in io.lines(doc) do
  for link in line:gmatch("|([^|%s]+)|") do
    vim.cmd.help(link)
  end
end
