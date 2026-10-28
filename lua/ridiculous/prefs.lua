local uv = vim.uv or vim.loop

local M = {}

M.dir = vim.fs.joinpath(vim.fn.stdpath("data"), "ridiculous.nvim")
M.path = vim.fs.joinpath(M.dir, "prefs.json")

---@type table<string, boolean|number>
M.data = {}

local loaded = false
local dirty = false
local save_timer = nil

---@return table<string, boolean|number>
function M.load()
  if loaded then
    return M.data
  end
  loaded = true

  local fd = uv.fs_open(M.path, "r", 438)
  if not fd then
    return M.data
  end
  local stat = uv.fs_fstat(fd)
  local content = stat and uv.fs_read(fd, stat.size, 0) or nil
  uv.fs_close(fd)
  if not content or content == "" then
    return M.data
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    for k, v in pairs(decoded) do
      if type(k) == "string" and (type(v) == "boolean" or type(v) == "number") then
        M.data[k] = v
      end
    end
  end
  return M.data
end

function M.flush()
  if not dirty then
    return
  end
  vim.fn.mkdir(M.dir, "p")

  local payload = next(M.data) ~= nil and M.data or vim.empty_dict()
  local ok, encoded = pcall(vim.json.encode, payload)
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

local function schedule_flush()
  dirty = true
  if save_timer then
    save_timer:stop()
  else
    save_timer = uv.new_timer()
  end
  save_timer:start(500, 0, vim.schedule_wrap(M.flush))
end

---@param key string
---@param value boolean|number
function M.set(key, value)
  M.load()
  if M.data[key] == value then
    return
  end
  M.data[key] = value
  schedule_flush()
end

function M.clear()
  M.load()
  M.data = {}
  dirty = true
  M.flush()
end

return M
