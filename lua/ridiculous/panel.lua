local config = require("ridiculous.config")
local state = require("ridiculous.state")
local statusline = require("ridiculous.statusline")

local M = {}

local ns = vim.api.nvim_create_namespace("ridiculous_panel")
local win, buf = nil, nil

local WIDTH = 40

local function comma(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

---@return string joined
---@return integer byte offset the right chunk starts at
local function justify(left, right)
  local gap = math.max(1, (WIDTH - 2) - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right))
  return left .. (" "):rep(gap) .. right, #left + gap
end

---@return string[] lines
---@return table[] marks {line, col_start, col_end, hl}
local function render()
  local o = config.options
  local lines, marks = {}, {}

  local function add(text)
    lines[#lines + 1] = text
    return #lines - 1
  end

  local function mark(line, from, to, group)
    marks[#marks + 1] = { line, from, to, group }
  end

  add("")
  local lvl = ("  LEVEL %d"):format(state.data.level)
  local xp = ("%s XP total"):format(comma(state.data.total_xp))
  local text, at = justify(lvl, xp)
  local row = add(text)
  mark(row, 2, #lvl, "RidiculousLevel")
  mark(row, at, -1, "RidiculousXp")

  local bar = statusline.bar(18)
  local need = ("%s / %s"):format(comma(state.data.xp), comma(state.xp_for(state.data.level)))
  row = add("  " .. bar .. "  " .. need)
  local filled = math.floor(state.progress() * 18 + 0.5)
  mark(row, 2, 2 + filled * 3, "RidiculousBar")
  mark(row, 2 + filled * 3, 2 + 18 * 3, "RidiculousBarEmpty")
  mark(row, 2 + 18 * 3, -1, "RidiculousXp")

  add("")
  row = add("  " .. ("─"):rep(WIDTH - 4))
  mark(row, 0, -1, "RidiculousBarEmpty")

  for _, f in ipairs(config.features) do
    local on = o[f.name] and true or false
    local status = on and "● on " or "○ off"
    local left = ("  %s  %s"):format(f.key, f.label)
    text, at = justify(left, status)
    row = add(text)
    mark(row, 2, 3, "RidiculousKey")
    mark(row, at, -1, on and "RidiculousOn" or "RidiculousOff")
  end

  row = add("  " .. ("─"):rep(WIDTH - 4))
  mark(row, 0, -1, "RidiculousBarEmpty")

  text, at = justify(("  %s typed"):format(comma(state.data.chars)), ("%s deleted"):format(comma(state.data.deletes)))
  row = add(text)
  mark(row, 0, -1, "RidiculousXp")

  local footer = "  R reset   d demo   q close"
  row = add(footer)
  for _, col in ipairs({ 2, 12, 21 }) do
    mark(row, col, col + 1, "RidiculousKey")
  end
  add("")

  return lines, marks
end

local function redraw()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines, marks = render()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    local line, from, to, group = m[1], m[2], m[3], m[4]
    local len = #(lines[line + 1] or "")
    if to == -1 or to > len then
      to = len
    end
    if from < to then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, line, from, { end_col = to, hl_group = group })
    end
  end
end

function M.close()
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  win = nil
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.open()
  if M.is_open() then
    M.close()
    return
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "ridiculous"

  local lines = render()
  win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 2),
    col = math.max(0, math.floor((vim.o.columns - WIDTH) / 2)),
    width = WIDTH,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " Ridiculous Coding ",
    title_pos = "center",
    zindex = 200,
  })
  vim.wo[win].winhighlight = "FloatTitle:RidiculousPanelTitle"
  vim.wo[win].cursorline = false
  redraw()

  local ridiculous = require("ridiculous")
  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  for _, f in ipairs(config.features) do
    map(f.key, function()
      ridiculous.toggle(f.name)
      redraw()
    end)
  end
  map("R", function()
    ridiculous.reset()
    redraw()
  end)
  map("d", function()
    ridiculous.demo()
  end)
  map("q", M.close)
  map("<Esc>", M.close)

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(M.close)
    end,
  })
end

M.redraw = redraw

return M
