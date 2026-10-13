-- A copy button in the top-right corner of every fenced code block in Markdown
-- buffers, like the one Obsidian and GitHub show. Clicking it puts the block's
-- contents on the system clipboard; a click anywhere else behaves as usual.
--
-- The button sits on the opening fence line, at the block's right edge.
-- lua/plugins/markdown.lua makes render-markdown draw that line as the top
-- row of the block (with its default border, "hide", the line is concealed
-- and the button with it) and sizes the block from M.layout below, which is
-- how this module knows where the block's right edge is.

local M = {}

local ICON = "󰆏"
-- Cells between the button and the block's right edge
local MARGIN = 2

-- Shape of a code block, shared with render-markdown's `code` options.
-- min_width is the least they get: each buffer's blocks and H1/H2 banners are
-- stretched further to that buffer's own text width (see `sync`), so prose,
-- banners and blocks all end at the same column.
M.layout = { min_width = 80, left_pad = 2, right_pad = 4 }
local ns = vim.api.nvim_create_namespace("markdown_copy")
local query

---@class markdown_copy.Block
---@field row integer 0-based row of the opening fence
---@field col integer window column of the button, relative to the text area
---@field lines string[] the block's contents, dedented

--- The column everything in the buffer should end at: its longest line,
--- prose or padded code, but no wider than the window showing it.
---@param buf integer
---@param edges integer[] right edge each code block needs for its own code
---@param code table<integer, boolean> 1-based rows inside code blocks
---@return integer
local function text_width(buf, edges, code)
  local width = 0
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if not code[row] then
      -- Roughly as rendered: link targets and inline markers are concealed
      line = line:gsub("%[([^%]]*)%]%([^%)]*%)", "%1"):gsub("[`*]", "")
      width = math.max(width, vim.fn.strdisplaywidth(line))
    end
  end
  -- A file of short lines still gets banners and blocks of a normal width
  width = math.max(width, M.layout.min_width)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    width = math.min(width, vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff)
  end
  return math.max(width, unpack(edges))
end

---@param buf integer
---@return markdown_copy.Block[] blocks
---@return integer width the buffer's text width
local function blocks(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return {}, 0
  end
  query = query or vim.treesitter.query.parse("markdown", "(fenced_code_block) @block")

  local found, code = {}, {}
  for _, node in query:iter_captures(parser:parse()[1]:root(), buf) do
    local start_row, indent, end_row = node:range()
    local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, false)
    for row = start_row + 1, end_row do
      code[row] = true
    end

    local width = 0
    local contents = {}
    for i = 2, #lines do
      if i == #lines and lines[i]:match("^%s*[`~][`~][`~]+%s*$") then
        break
      end
      contents[#contents + 1] = lines[i]:sub(indent + 1)
      width = math.max(width, vim.fn.strdisplaywidth(contents[#contents]))
    end
    local edge = indent + M.layout.left_pad + width + M.layout.right_pad

    found[#found + 1] = { row = start_row, col = edge, lines = contents }
  end

  local edges = { 0 }
  for _, block in ipairs(found) do
    edges[#edges + 1] = block.col
  end
  local width = text_width(buf, edges, code)
  for _, block in ipairs(found) do
    block.col = width - MARGIN - 1
  end
  return found, width
end

--- Stretch render-markdown's blocks and H1/H2 banners in this buffer to its
--- text width. That is a per-buffer value and render-markdown only takes
--- widths globally, so this reaches into its per-buffer config.
---@param buf integer
---@param width integer
---@return boolean done false while render-markdown has yet to attach
local function sync(buf, width)
  -- Requiring it here would load the plugin early, before it has set itself
  -- up for the buffer, and leave the fence lines concealed
  if not package.loaded["render-markdown"] then
    return false
  end
  local ok, done = pcall(function()
    if not require("render-markdown.core.manager").attached(buf) then
      return false
    end
    local config = require("render-markdown.state").get(buf)
    if config.code.min_width ~= width then
      config.code.min_width = width
      config.heading.min_width = { width, width, 0, 0, 0, 0 }
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 then
        require("render-markdown.core.ui").update(buf, win, "MarkdownWidth", true)
      end
    end
    return true
  end)
  return ok and done
end

-- The button replaces cells of the block's top row, so it needs the block's
-- background. Redefined on every draw because a theme switch clears it.
local function highlight()
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  local code = vim.api.nvim_get_hl(0, { name = "RenderMarkdownCode", link = false })
  vim.api.nvim_set_hl(0, "MarkdownCopyButton", { fg = comment.fg, bg = code.bg })
end

---@param buf integer
---@param attempt? integer
local function draw(buf, attempt)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  highlight()
  local found, width = blocks(buf)
  attempt = attempt or 1
  if not sync(buf, width) and attempt < 20 then
    vim.defer_fn(function()
      draw(buf, attempt + 1)
    end, 100)
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, block in ipairs(found) do
    vim.api.nvim_buf_set_extmark(buf, ns, block.row, 0, {
      virt_text = { { ICON, "MarkdownCopyButton" } },
      virt_text_win_col = block.col,
      -- Above render-markdown's own overlay on the fence line
      priority = 10000,
    })
  end
end

--- The block whose button is under the mouse, if any.
---@return markdown_copy.Block?
local function clicked()
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 then
    return
  end
  local buf = vim.api.nvim_win_get_buf(mouse.winid)
  if vim.bo[buf].filetype ~= "markdown" then
    return
  end

  local info = vim.fn.getwininfo(mouse.winid)[1]
  local col = mouse.wincol - info.textoff - 1
  for _, block in ipairs(blocks(buf)) do
    -- The icon is a small target, so take the whole corner: from one cell
    -- left of it to the block's edge
    if block.row == mouse.line - 1 and col >= block.col - 1 and col <= block.col + MARGIN then
      return block
    end
  end
end

---@param block markdown_copy.Block
local function copy(block)
  vim.fn.setreg("+", table.concat(block.lines, "\n") .. "\n")
  vim.notify(("Copied %d line%s"):format(#block.lines, #block.lines == 1 and "" or "s"))
end

---@param buf integer
function M.attach(buf)
  if vim.b[buf].markdown_copy then
    return
  end
  vim.b[buf].markdown_copy = true

  -- Not during the FileType event itself: parsing the buffer before
  -- render-markdown has set up treesitter leaves the fence lines concealed
  vim.schedule(function()
    draw(buf)
  end)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter", "WinResized", "ColorScheme" }, {
    buffer = buf,
    callback = function()
      vim.schedule(function()
        draw(buf)
      end)
    end,
  })

  vim.keymap.set({ "n", "i" }, "<LeftMouse>", function()
    local block = clicked()
    if not block then
      return "<LeftMouse>"
    end
    vim.schedule(function()
      copy(block)
    end)
    return ""
  end, { buffer = buf, expr = true, desc = "Copy code block (on its copy button)" })
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(event)
      M.attach(event.buf)
    end,
  })
end

return M
