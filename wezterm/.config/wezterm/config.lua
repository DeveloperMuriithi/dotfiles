local wezterm = require("wezterm")
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.automatically_reload_config = true
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false
config.check_for_updates = false

config.font = wezterm.font("JetBrains Mono", { weight = "Bold" })
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

config.colors = {
  foreground = "#00ff9c",
  background = "#000000",
  cursor_bg = "#00ff9c",
  cursor_border = "#00ff9c",
  cursor_fg = "#000000",
  selection_bg = "#003300",
  selection_fg = "#00ff9c",
  ansi = {
    "#000000",  -- black
    "#ff5555",  -- red (wrong commands)
    "#00ff9c",  -- green (valid commands)
    "#00ffff",  -- yellow / options
    "#00ff00",  -- blue / directories
    "#ff00ff",  -- magenta
    "#00ffff",  -- cyan / paths
    "#ffffff",  -- white
  },

  brights = {
    "#003300",
    "#ff6666",  -- bright red
    "#00ffcc",
    "#00ffff",
    "#00ff66",
    "#ff66ff",
    "#66ffff",
    "#ffffff",
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

