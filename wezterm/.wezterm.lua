local wezterm = require("wezterm")
local config = require("config")
require("events")

-- Window/transparency overrides. Fonts and colors live in config.lua so there
-- is one source of truth for theming.
config.window_background_opacity = 0.85
config.macos_window_background_blur = 15
config.window_decorations = "RESIZE" -- keeps resizable, no full borders
config.window_padding = { left = 5, right = 5, top = 2, bottom = 2 }

return config
