-- One colour per Markdown heading level, taken from the Omarchy theme's
-- palette so it follows theme switches. Aether-based themes give all six
-- levels the same colour, which leaves nothing but the icon to tell them apart.
-- Greyscale themes get a ramp from strongest to faintest instead.

local M = {}

local THEME_PATH = vim.fn.expand("~/.local/state/omarchy/current/theme/")

-- Palette colour for H1..H6
local LEVELS = { "blue", "magenta", "cyan", "green", "yellow", "red" }

-- How much of the heading's colour goes into its background band
local BAND = 0.14

---@return table<string, string>?
local function palette()
  -- colors.terminal.toml is the contrast-corrected palette the
  -- terminal-contrast theme-set hook writes for light themes
  for _, name in ipairs({ "colors.terminal.toml", "colors.toml" }) do
    local file = io.open(THEME_PATH .. name)
    if file then
      local colors = {}
      for line in file:lines() do
        local key, value = line:match('^([%w_]+)%s*=%s*"(#%x%x%x%x%x%x)"')
        if key then
          colors[key] = value
        end
      end
      file:close()
      return colors
    end
  end
end

---@param color string
---@param base string
---@param amount number
local function blend(color, base, amount)
  local mixed = {}
  for i = 2, 6, 2 do
    local c, b = tonumber(color:sub(i, i + 1), 16), tonumber(base:sub(i, i + 1), 16)
    mixed[#mixed + 1] = ("%02x"):format(math.floor(b + (c - b) * amount + 0.5))
  end
  return "#" .. table.concat(mixed)
end

---@param color string
---@return number[] red, green and blue, 0..1
local function rgb(color)
  local parts = {}
  for i = 2, 6, 2 do
    parts[#parts + 1] = tonumber(color:sub(i, i + 1), 16) / 255
  end
  return parts
end

---@param color string
local function saturation(color)
  local c = rgb(color)
  local high, low = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
  return high == 0 and 0 or (high - low) / high
end

---@param color string
local function brightness(color)
  local c = rgb(color)
  return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]
end

--- The colour of each heading level.
---@param colors table<string, string>
---@return string[]
local function ramp(colors)
  local shades, greys = {}, true
  for _, name in ipairs(LEVELS) do
    if colors[name] then
      shades[#shades + 1] = colors[name]
      greys = greys and saturation(colors[name]) < 0.15
    end
  end
  -- A greyscale theme has no hues to tell levels apart, so rank them by how
  -- much they stand out from the background: H1 strongest, H6 faintest
  if greys then
    local base = brightness(colors.background)
    table.sort(shades, function(a, b)
      return math.abs(brightness(a) - base) > math.abs(brightness(b) - base)
    end)
  end
  return shades
end

function M.apply()
  local colors = palette()
  if not colors or not colors.background then
    return
  end
  for level, fg in ipairs(ramp(colors)) do
    vim.api.nvim_set_hl(0, ("@markup.heading.%d.markdown"):format(level), { fg = fg, bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level, { fg = fg, bold = true })
    vim.api.nvim_set_hl(0, ("RenderMarkdownH%dBg"):format(level), {
      fg = fg,
      bg = blend(fg, colors.background, BAND),
      bold = true,
    })
  end
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = M.apply })
end

return M
