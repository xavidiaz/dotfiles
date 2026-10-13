-- Quieter Markdown buffers on top of LazyVim's lang.markdown extra.
local markdownlint_config = vim.fn.stdpath("config") .. "/.markdownlint-cli2.yaml"
local code_layout = require("config.markdown_copy").layout

return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = {
        -- "-" reads the buffer from stdin, as nvim-lint's default does
        args = { "--config", markdownlint_config, "-" },
      }

      -- Inline diagnostics cannot wrap, so a full markdownlint message runs
      -- off the window. Show "MD034 Bare URL used" beside the line, and expand
      -- to the full message, wrapped, under the line the cursor is on.
      vim.diagnostic.config({
        virtual_text = {
          current_line = false,
          spacing = 4,
          source = false,
          prefix = "●",
          format = function(diagnostic)
            local rule, text = diagnostic.message:match("(MD%d+)%S*%s+(.*)")
            if not rule then
              return diagnostic.message
            end
            return rule .. " " .. text:gsub("%s*%[.*%]$", "")
          end,
        },
        virtual_lines = {
          current_line = true,
          format = function(diagnostic)
            -- Virtual lines do not wrap either; break the message ourselves
            local room = math.max(30, vim.api.nvim_win_get_width(0) - diagnostic.col - 16)
            local lines, line = {}, ""
            for word in diagnostic.message:gsub("^error%s+", ""):gmatch("%S+") do
              if line ~= "" and #line + #word + 1 > room then
                lines[#lines + 1] = line
                line = word
              else
                line = line == "" and word or line .. " " .. word
              end
            end
            lines[#lines + 1] = line
            return table.concat(lines, "\n")
          end,
        },
      }, require("lint").get_namespace("markdownlint-cli2"))
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", markdownlint_config },
        },
      },
    },
  },
  {
    -- Live preview like Obsidian's: the document stays rendered in every mode,
    -- insert included, and only the line under the cursor shows raw Markdown.
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      render_modes = true,
      anti_conceal = { enabled = true, above = 0, below = 0 },
      heading = {
        -- LazyVim empties this list, which leaves the #'s on screen
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        width = "block",
        right_pad = 1,
        -- A terminal has one font size, so rank is shown by weight instead:
        -- H1 and H2 are banners as wide as a code block with a rule above
        -- and below, the rest are as wide as their text. Colours per level
        -- come from lua/config/markdown_headings.lua.
        min_width = { code_layout.min_width, code_layout.min_width, 0, 0, 0, 0 },
        border = { true, true, false, false, false, false },
        border_virtual = true,
      },
      checkbox = { enabled = true },
      code = {
        -- Every block is as wide as a column of prose, so they all line up
        -- whatever they hold; only longer code makes one wider
        width = "block",
        min_width = code_layout.min_width,
        left_pad = code_layout.left_pad,
        right_pad = code_layout.right_pad,
        -- Draw the fence lines as rows of the block instead of hiding them:
        -- padding above and below, and a top row for the language label and
        -- the copy button of lua/config/markdown_copy.lua
        border = "thick",
        language_pad = 2,
      },
    },
  },
}
