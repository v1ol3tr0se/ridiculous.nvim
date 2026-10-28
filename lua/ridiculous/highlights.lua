local M = {}

M.groups = {
  RidiculousBlip1 = { fg = "#fff8dc", bold = true },
  RidiculousBlip2 = { fg = "#ffd43b", bold = true },
  RidiculousBlip3 = { fg = "#ff922b" },
  RidiculousBlip4 = { fg = "#f03e3e" },

  RidiculousBoom1 = { fg = "#ffffff", bold = true },
  RidiculousBoom2 = { fg = "#ffe066", bold = true },
  RidiculousBoom3 = { fg = "#ff922b" },
  RidiculousBoom4 = { fg = "#f03e3e" },
  RidiculousBoom5 = { fg = "#7d3232" },

  RidiculousNewline1 = { fg = "#a5d8ff", bold = true },
  RidiculousNewline2 = { fg = "#4dabf7" },
  RidiculousNewline3 = { fg = "#1864ab" },

  RidiculousFirework1 = { fg = "#ff6ec7", bold = true },
  RidiculousFirework2 = { fg = "#66d9ef", bold = true },
  RidiculousFirework3 = { fg = "#a6e22e", bold = true },
  RidiculousFirework4 = { fg = "#e6db74", bold = true },
  RidiculousFirework5 = { fg = "#ae81ff", bold = true },
  RidiculousFirework6 = { fg = "#fd971f", bold = true },

  RidiculousBanner = { fg = "#ffd43b", bold = true },
  RidiculousLevel = { link = "Special" },
  RidiculousXp = { link = "Comment" },
  RidiculousBar = { fg = "#ffd43b" },
  RidiculousBarEmpty = { link = "NonText" },
  RidiculousPanelTitle = { fg = "#ffd43b", bold = true },
  RidiculousOn = { fg = "#a6e22e", bold = true },
  RidiculousOff = { link = "Comment" },
  RidiculousKey = { fg = "#66d9ef", bold = true },
}

M.blip_gradient = { "RidiculousBlip1", "RidiculousBlip2", "RidiculousBlip3", "RidiculousBlip4" }
M.boom_gradient = { "RidiculousBoom1", "RidiculousBoom2", "RidiculousBoom3", "RidiculousBoom4", "RidiculousBoom5" }
M.newline_gradient = { "RidiculousNewline1", "RidiculousNewline2", "RidiculousNewline3" }
M.firework_colors = {
  "RidiculousFirework1",
  "RidiculousFirework2",
  "RidiculousFirework3",
  "RidiculousFirework4",
  "RidiculousFirework5",
  "RidiculousFirework6",
}

function M.apply()
  for name, spec in pairs(M.groups) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", { default = true }, spec))
  end
end

return M
