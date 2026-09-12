-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.opt.relativenumber = false
vim.g.autoformat = true

-- Show the filename in a bar above every split, so it's clear which
-- buffer each pane holds without relying on the shared bufferline.
vim.opt.winbar = "%#WinBar# %t %m"

local winbar_exclude = {
  "neo-tree",
  "snacks_dashboard",
  "help",
  "lazy",
  "mason",
  "trouble",
  "TelescopePrompt",
}
vim.api.nvim_create_autocmd("FileType", {
  pattern = winbar_exclude,
  callback = function()
    vim.opt_local.winbar = ""
  end,
})
