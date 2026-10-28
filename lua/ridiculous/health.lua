local M = {}

function M.check()
  local start = vim.health.start or vim.health.report_start
  local ok = vim.health.ok or vim.health.report_ok
  local warn = vim.health.warn or vim.health.report_warn
  local info = vim.health.info or vim.health.report_info

  start("ridiculous.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("neovim " .. tostring(vim.version()))
  else
    warn("neovim 0.10+ recommended")
  end

  local ridiculous = require("ridiculous")
  if ridiculous.is_setup() then
    ok("setup() has been called")
  else
    warn("setup() has not been called; nothing is tracking edits")
  end

  if vim.o.termguicolors then
    ok("termguicolors is on (effects fade with 'winblend')")
  else
    warn("termguicolors is off; effect colors and fading will be crude", {
      "set vim.o.termguicolors = true",
    })
  end

  start("ridiculous.nvim: audio")
  local sound = require("ridiculous.sound")
  local player = sound.player()
  if player then
    ok("player: " .. player.cmd)
  else
    warn("no audio player found", {
      "install one of: pw-play, paplay, aplay, afplay, ffplay, mpv, play",
      "or set sound = false to silence this",
    })
  end

  if vim.fn.isdirectory(sound.dir) == 1 then
    local n = #vim.fn.globpath(sound.dir, "*.wav", false, true)
    ok(("sound cache: %d files in %s"):format(n, sound.dir))
  else
    info("sound cache not generated yet (:Ridiculous regen-sounds)")
  end

  start("ridiculous.nvim: progress")
  local state = require("ridiculous.state")
  info(
    ("level %d, %d/%d xp, %d lifetime"):format(
      state.data.level,
      state.data.xp,
      state.xp_for(state.data.level),
      state.data.total_xp
    )
  )
  if vim.fn.filereadable(state.path) == 1 then
    ok("state file: " .. state.path)
  else
    info("state file not written yet: " .. state.path)
  end

  start("ridiculous.nvim: saved settings")
  local prefs = require("ridiculous.prefs")
  local saved = prefs.load()
  local keys = vim.tbl_keys(saved)
  table.sort(keys)
  if #keys == 0 then
    info("nothing saved; every option is coming from setup()")
    info("prefs file: " .. prefs.path .. " (not written yet)")
  else
    local parts = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = ("%s = %s"):format(k, tostring(saved[k]))
    end
    ok("overriding setup(): " .. table.concat(parts, ", "))
    info("prefs file: " .. prefs.path)
    info(":Ridiculous forget clears it")
  end
end

return M
