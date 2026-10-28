local statusline = require("ridiculous.statusline")
local state = require("ridiculous.state")

assert(statusline.text() == "󰊴 1 ▱▱▱▱▱▱ 0%", "statusline should render before setup()")

require("ridiculous").setup({ sound = false })

assert(state.xp_for(1) == 50)
assert(state.xp_for(2) == 67)
assert(state.xp_for(3) == 91)

assert(state.add_xp(0) == 0)
assert(state.add_xp(-5) == 0)
assert(state.add_xp(49) == 0)
assert(state.add_xp(1) == 1)
assert(state.data.level == 2 and state.data.xp == 0)
assert(state.add_xp(67 + 91 + 5) == 2)
assert(state.data.level == 4 and state.data.xp == 5)
assert(state.data.total_xp == 49 + 1 + 67 + 91 + 5)

state.reset()
state.add_xp(31)
assert(statusline.text() == "󰊴 1 ▰▰▰▰▱▱ 62%", statusline.text())
assert(statusline.status() == "󰊴 1 ▰▰▰▰▱▱ 62%%", statusline.status())
assert(statusline.combo() == "", "combo should hide while idle")

require("ridiculous").setup({ sound = false, statusline = { icon = "", width = 4 } })
assert(statusline.text() == "1 ▰▰▱▱ 62%", statusline.text())
