local wezterm = require("wezterm")
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.automatically_reload_config = true
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false
config.check_for_updates = false

config.font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Bold" })
config.font_size = 12.5

config.enable_tab_bar = false
config.use_fancy_tab_bar = false

config.window_decorations = "RESIZE"

config.window_padding = {
  left = 10,
  right = 10,
  top = 8,
  bottom = 6,
}

config.default_cursor_style = "SteadyBar"
config.cursor_blink_rate = 500


config.window_background_opacity = 0.75
config.macos_window_background_blur = 25
config.text_background_opacity = 0.85

-- n1ghtw1ng "hacker" palette, shared with Starship, fish, and kitty.
config.colors = {
  foreground = "#E6EDF3",
  background = "#000000",
  cursor_bg = "#00FF87",
  cursor_border = "#00FF87",
  cursor_fg = "#000000",
  selection_bg = "#1F2933",
  selection_fg = "#E6EDF3",
  ansi = {
    "#1F2933", -- black
    "#FF5F56", -- red
    "#00FF87", -- green
    "#FFD75F", -- yellow
    "#00D9FF", -- blue
    "#D787FF", -- magenta
    "#00D9FF", -- cyan
    "#E6EDF3", -- white
  },
  brights = {
    "#7F8C8D", -- bright black
    "#FF5F56", -- bright red
    "#00FF87", -- bright green
    "#FFD75F", -- bright yellow
    "#00D9FF", -- bright blue
    "#D787FF", -- bright magenta
    "#00D9FF", -- bright cyan
    "#FFFFFF", -- bright white
  },
}

config.keys = {
  { key = "Enter", mods = "CTRL", action = wezterm.action({ SendString = "\x1b[13;5u" }) },
  { key = "Enter", mods = "SHIFT", action = wezterm.action({ SendString = "\x1b[13;2u" }) },
}

config.hyperlink_rules = {
  { regex = "\\((\\w+://\\S+)\\)", format = "$1", highlight = 1 },
  { regex = "\\[(\\w+://\\S+)\\]", format = "$1", highlight = 1 },
  { regex = "\\{(\\w+://\\S+)\\}", format = "$1", highlight = 1 },
  { regex = "<(\\w+://\\S+)>", format = "$1", highlight = 1 },
  { regex = "[^(]\\b(\\w+://\\S+[)/a-zA-Z0-9-]+)", format = "$1", highlight = 1 },
}

return config

