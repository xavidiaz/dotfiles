-- Kitty's scrollback in this Neovim, with colours and the cursor where it was:
-- select with v/V/Ctrl-v or / search, y copies to the clipboard and returns to
-- kitty, Ctrl-Enter runs the selection at the prompt, Shift-Enter pastes it there.
-- Opened from kitty, see kitty.conf.
local in_scrollback = vim.env.KITTY_SCROLLBACK_NVIM == "true"

return {
  -- kitty-scrollback starts Neovim without a file, so the dashboard would flash
  -- before the scrollback replaces it
  {
    "folke/snacks.nvim",
    opts = { dashboard = { enabled = not in_scrollback } },
  },
  {
    "mikesmithgh/kitty-scrollback.nvim",
    lazy = true,
    cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth", "KittyScrollbackGenerateCommandLineEditing" },
    event = { "User KittyScrollbackLaunch" },
    opts = {
      {
        -- The kitty icon in the corner goes away once the scrollback is ready
        status_window = { autoclose = true },
        -- Selections in the theme's Visual colour, as in any other buffer
        visual_selection_highlight_mode = "nvim",
        paste_window = {
          highlight_as_normal_win = true,
          winopts_overrides = function()
            return { border = "rounded", title = " Edit, then Ctrl-Enter to run ", title_pos = "center" }
          end,
        },
        callbacks = {
          -- Plain y would open the paste window (LazyVim yanks to the unnamed
          -- register); yank to the clipboard instead, which closes the scrollback
          after_ready = function()
            vim.keymap.set({ "n", "x" }, "y", '"+y', { buffer = 0, desc = "Copy to clipboard and close" })
            -- Look like the terminal itself with a movable cursor (like tuios's copy
            -- mode) rather than an editor: no status line, tab line or gutter
            local ok, lualine = pcall(require, "lualine")
            if ok then
              lualine.hide({ place = { "statusline", "tabline", "winbar" }, unhide = false })
            end
            vim.o.laststatus = 0
            vim.o.showtabline = 0
            vim.o.cmdheight = 0
            vim.o.ruler = false
            vim.wo.number = false
            vim.wo.relativenumber = false
            vim.wo.signcolumn = "no"
            vim.wo.foldcolumn = "0"
            vim.wo.statuscolumn = ""
          end,
        },
      },
    },
  },
}
