# ridiculous.nvim 💥

there's a [vs code extension](https://marketplace.visualstudio.com/items?itemName=Merenut.ridiculous-coding) by Merenut that makes your editor explode while you type, and i got jealous. that one is a port of [jotson's godot plugin](https://github.com/jotson/ridiculous_coding), so this is a port of a port, for neovim

what it does:
- **blips** float up from the cursor on every character, and they show the character you actually typed
- **booms** when you delete stuff. backspace, `x`, `dd`, `u`, all of it, and bigger deletes get bigger booms
- a little blue **swoosh** on a new line
- **shake**, which grows with how fast you're typing. one key on its own doesn't move anything, a fast streak gets you up to five lines each way
- **fireworks** and a `LEVEL N` banner when you level up
- **sound**: a tick per key that climbs in pitch with your combo, a thud on delete, a tiny fanfare on level up
- **xp** that carries over between sessions

it watches the real edits instead of keystrokes, so normal mode counts too. `dd` on a long function is kinda therapeutic

none of this is useful, it's in the name

### installing
with lazy.nvim:

```lua
{ "v1ol3tr0se/ridiculous.nvim", event = "VeryLazy", opts = {} }
```

or with vim.pack (0.12+):

```lua
vim.pack.add({ "https://github.com/v1ol3tr0se/ridiculous.nvim" })
require("ridiculous").setup({})
```

nothing to build and no sound files to download. you'll want `termguicolors` on (without it the colors and the fading look pretty crude), a nerd font for the statusline icons, and something that plays a `.wav` if you want sound. `:checkhealth ridiculous` tells you what it found

### xp
one xp per character. level n costs `base_xp * growth^(n-1)`, so with the defaults that's 50 for level 2, 67 more for 3, 91 for 4 and so on

one edit caps at 40 xp, so pasting a whole library in doesn't count

progress saves to `stdpath("data")/ridiculous.nvim/state.json` a few seconds after you stop typing, and again when you quit

### sound
there are no audio files in here. every sound gets synthesized in lua (square waves for the blips, filtered noise for the boom, an arpeggio for the level up) and written as `.wav` into `stdpath("cache")` the first time it runs

to play them it uses the first of these it finds: `pw-play`, `paplay`, `afplay`, `ffplay`, `mpv`, `play`, `aplay`, `powershell`. set `audio.player` if you want a specific one

### statusline
```lua
-- lualine
local xp = require("ridiculous.statusline")
sections = { lualine_x = { xp.combo_lualine(), xp.lualine() } }

-- plain statusline
vim.o.statusline = vim.o.statusline .. "%{v:lua.require'ridiculous.statusline'.status()}"
```

it looks like `󰈸 8  󰊴 7 ▰▰▰▰▱▱ 62%`. the first bit is your combo, it only shows while you're typing, goes from yellow to red as it climbs and fades out about a second after you stop. `combo_min` is how high it has to get before it shows up at all

`status()` doubles the `%` because a statusline eats a single one. if you're printing it anywhere else use `text()`

### commands
- `:Ridiculous` opens the panel. every effect toggles with one key in there and it shows your level, so it's the only one i'd map
- `:Ridiculous demo` fires everything once without touching your buffer
- `:Ridiculous toggle <feature>` flips one (`blips`, `chars`, `explosions`, `newline`, `fireworks`, `shake`, `sound`, `reduced_effects`, or `enabled` for all of it)
- `:Ridiculous stats`
- `:Ridiculous reset` wipes your progress
- `:Ridiculous forget` wipes saved settings
- `:Ridiculous enable` / `disable`
- `:Ridiculous regen-sounds` rebuilds the sounds
- `:checkhealth ridiculous` for the audio player, the cache, colors and what's saved

```lua
vim.keymap.set("n", "<leader>ur", "<cmd>Ridiculous<cr>", { desc = "Ridiculous Coding" })
```

### config
heads up, whatever you flip from the panel or with `:Ridiculous toggle` / `enable` / `disable` gets saved to `stdpath("data")/ridiculous.nvim/prefs.json` and wins over `setup()` from then on. only the keys you touched, everything else still comes from your config. so if an option here looks ignored, that's why. `:Ridiculous forget` clears it (restart after)

the defaults:

```lua
require("ridiculous").setup({
  enabled = true,

  blips = true,       -- animation on every character typed
  chars = true,       -- blips show the character you typed, not a symbol
  explosions = true,  -- boom when you delete
  newline = true,     -- swoosh on a new line
  fireworks = true,   -- level up
  shake = true,       -- scales with typing speed
  sound = true,

  reduced_effects = false,  -- no animation, no audio, xp still counts

  volume = 0.5,
  shake_intensity = 1.0,

  leveling = {
    base_xp = 50,
    growth = 1.35,
    xp_per_char = 1,
    max_xp_per_event = 40,
  },

  effects = {
    fps = 60,
    max_particles = 96,
    blip_life = 0.45,
    boom_particles = 10,
    boom_life = 0.55,
    firework_bursts = 4,
    firework_particles = 22,
    banner = true,
  },

  audio = {
    player = nil,        -- nil autodetects
    throttle_ms = 28,    -- minimum gap between typing blips
    max_concurrent = 8,  -- player processes at once
  },

  statusline = {
    icon = "󰊴",
    width = 6,
    combo_icon = "󰈸",
    combo_min = 2,       -- combo stays hidden below this
  },

  ignore = {
    filetypes = { "TelescopePrompt", "neo-tree", "lazy", "help", "qf" },  -- plus snacks, mason, oil and a few more
    buftypes = { "nofile", "prompt", "terminal", "quickfix", "help" },
  },
})
```

### colors
every group is set with `default = true`, so if you set one yourself it stays yours:

```lua
vim.api.nvim_set_hl(0, "RidiculousBlip1", { fg = "#00ff00", bold = true })
```

- `RidiculousBlip1` to `4`, cream to red. the combo counter borrows these too
- `RidiculousBoom1` to `5`
- `RidiculousNewline1` to `3`
- `RidiculousFirework1` to `6`
- `RidiculousBanner`
- panel and statusline: `RidiculousLevel`, `RidiculousXp`, `RidiculousBar`, `RidiculousBarEmpty`, `RidiculousPanelTitle`, `RidiculousOn`, `RidiculousOff`, `RidiculousKey`

### how it works, quickly
every particle is its own tiny floating window, one cell big, reused from a pool and closed once nothing's moving. one big float over the screen would've been easier, but even an empty cell in a float paints over your code

the shake moves `topline`, so it's always whole lines (a terminal can't scroll half a cell) and your cursor stays put. if the whole file fits on screen there's nothing to scroll against, so it just doesn't shake there

you're 50 characters away from level 2
