return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },

  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,

      on_colors = function(colors)
        colors.bg = "#080C09"
        colors.bg_dark = "#050805"
        colors.bg_float = "#0B110D"
        colors.bg_highlight = "#101A13"
        colors.fg = "#D7E8DC"
        colors.fg_dark = "#8FAF98"

        colors.green = "#39FF14"
        colors.green1 = "#00FF66"
        colors.green2 = "#7CFF6B"

        colors.blue = "#5CC8FF"
        colors.cyan = "#00E5FF"
        colors.yellow = "#D7FF5F"
        colors.orange = "#FFB000"
        colors.red = "#FF5555"
        colors.magenta = "#D787FF"
      end,

      on_highlights = function(hl, colors)
        -- Editor
        hl.Normal = {
          fg = colors.fg,
          bg = colors.bg,
        }

        hl.NormalFloat = {
          fg = colors.fg,
          bg = colors.bg_float,
        }

        hl.CursorLine = {
          bg = "#0D160F",
        }

        hl.LineNr = {
          fg = "#3B5542",
        }

        hl.CursorLineNr = {
          fg = colors.green,
          bold = true,
        }

        -- Selection
        hl.Visual = {
          bg = "#12351D",
        }

        -- Search
        hl.Search = {
          fg = "#080C09",
          bg = colors.green,
          bold = true,
        }

        hl.IncSearch = {
          fg = "#080C09",
          bg = colors.green2,
          bold = true,
        }

        -- Statusline
        hl.StatusLine = {
          fg = colors.green,
          bg = "#050805",
        }

        hl.StatusLineNC = {
          fg = "#496451",
          bg = "#050805",
        }

        -- Cursor
        hl.Cursor = {
          fg = colors.bg,
          bg = colors.green,
        }

        -- Comments
        hl.Comment = {
          fg = "#52705A",
          italic = true,
        }

        -- Strings
        hl.String = {
          fg = "#A8E063",
        }

        -- Functions
        hl.Function = {
          fg = "#5CC8FF",
          bold = true,
        }

        -- Keywords
        hl.Keyword = {
          fg = colors.green,
          bold = true,
        }

        -- Types
        hl.Type = {
          fg = "#00E5FF",
        }

        -- Constants
        hl.Constant = {
          fg = "#D7FF5F",
        }

        -- Numbers
        hl.Number = {
          fg = "#FFB000",
        }

        -- Operators
        hl.Operator = {
          fg = "#7CFF6B",
        }

        -- Diagnostics
        hl.DiagnosticError = {
          fg = colors.red,
        }

        hl.DiagnosticWarn = {
          fg = colors.yellow,
        }

        hl.DiagnosticInfo = {
          fg = colors.blue,
        }

        hl.DiagnosticHint = {
          fg = colors.green2,
        }

        -- Git
        hl.GitSignsAdd = {
          fg = colors.green,
        }

        hl.GitSignsChange = {
          fg = colors.yellow,
        }

        hl.GitSignsDelete = {
          fg = colors.red,
        }
      end,
    },
  },
}
