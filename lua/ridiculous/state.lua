local config = require("ridiculous.config")

local uv = vim.uv or vim.loop

local M = {}

M.dir = vim.fs.joinpath(vim.fn.stdpath("data"), "ridiculous.nvim")
M.path = vim.fs.joinpath(M.dir, "state.json")

M.data = {
  level = 1,
  xp = 0,
  total_xp = 0,
  chars = 0,
  deletes = 0,
  newlines = 0,
}

local dirty = false
local save_timer = nil

---@param level integer
---@return integer
function M.xp_for(level)
  local l = config.options.leveling
  return math.max(1, math.floor(l.base_xp * (l.growth ^ (level - 1))))
end

function M.progress()
  return math.max(0, math.min(1, M.data.xp / M.xp_for(M.data.level)))
end

function M.load()
  local fd = uv.fs_open(M.path, "r", 438)
  if not fd then
    return
  end
  local stat = uv.fs_fstat(fd)
  local content = stat and uv.fs_read(fd, stat.size, 0) or nil
  uv.fs_close(fd)
  if not content or content == "" then
    return
  end
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    for k, v in pairs(M.data) do
      if type(decoded[k]) == type(v) then
        M.data[k] = decoded[k]
      end
    end
    M.data.level = math.max(1, math.floor(M.data.level))
  end
end

function M.save()
  if not dirty then
    return
  end
  vim.fn.mkdir(M.dir, "p")
  local ok, encoded = pcall(vim.json.encode, M.data)
  if not ok then
    return
  end
  local fd = uv.fs_open(M.path, "w", 420)
  if not fd then
    return
  end
  uv.fs_write(fd, encoded)
  uv.fs_close(fd)
  dirty = false
end

local function schedule_save()
  dirty = true
  if save_timer then
    save_timer:stop()
  else
    save_timer = uv.new_timer()
  end
  save_timer:start(5000, 0, vim.schedule_wrap(M.save))
end

---@param amount number
---@return integer levels_gained
function M.add_xp(amount)
  amount = math.max(0, math.floor(amount))
  if amount == 0 then
    return 0
  end
  M.data.xp = M.data.xp + amount
  M.data.total_xp = M.data.total_xp + amount

  local gained = 0
  while M.data.xp >= M.xp_for(M.data.level) do
    M.data.xp = M.data.xp - M.xp_for(M.data.level)
    M.data.level = M.data.level + 1
    gained = gained + 1
    if gained > 50 then
      break
    end
  end

  schedule_save()
  return gained
end

---@param field "chars"|"deletes"|"newlines"
---@param n? integer
function M.bump(field, n)
  M.data[field] = (M.data[field] or 0) + (n or 1)
  schedule_save()
end

function M.reset()
  M.data = { level = 1, xp = 0, total_xp = 0, chars = 0, deletes = 0, newlines = 0 }
  dirty = true
  M.save()
end

return M
