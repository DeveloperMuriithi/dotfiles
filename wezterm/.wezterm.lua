local wezterm = require("wezterm")
local config = require("config")
require("events")

-- Transparency & window
config.window_background_opacity = 0.85
config.macos_window_background_blur = 15
config.window_decorations = "RESIZE" -- keeps resizable, no full borders

-- Fonts
config.font = wezterm.font("JetBrains Mono", { weight = "Bold" })
config.font_size = 12.5

-- Remove tab bar
config.enable_tab_bar = false
config.use_fancy_tab_bar = false

-- Hacker green color palette
config.colors = {
  foreground = "#00ff00",
  background = "#000000",
  cursor_bg = "#00ff00",
  cursor_fg = "#000000",
  cursor_border = "#00ff00",
  selection_bg = "#003300",
  selection_fg = "#00ff00",

  -- ANSI palette for Zsh-syntax-highlighting
  ansi = {
    "#001100", -- black
    "#ff5555", -- red
    "#00cc00", -- green
    "#66ff66", -- yellow
    "#0033ff", -- blue
    "#ff00ff", -- magenta
    "#00ffff", -- cyan
    "#aaaaaa", -- white
  },
  brights = {
    "#555555", -- bright black / grey
    "#ff5555", -- bright red
    "#00ff00", -- bright green (commands)
    "#ccff66", -- bright yellow (flags/options)
    "#3399ff", -- bright blue
    "#ff55ff", -- bright magenta (hidden files)
    "#33ffff", -- bright cyan (normal files)
    "#ffffff", -- bright white
  }
}

-- Optional: force cursor style and padding
config.default_cursor_style = "SteadyBar"
config.window_padding = { left=5, right=5, top=2, bottom=2 }

return config

