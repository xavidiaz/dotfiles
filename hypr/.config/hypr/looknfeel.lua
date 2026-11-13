-- Change the default Omarchy look'n'feel.

-- A thicker border (default 2) so the focused window stands out from the rest,
-- in a warm orange: the wallpaper, the theme accent and the inactive borders
-- are all blue or purple. Fixed, so it stays the same across themes.
hl.config({
  general = {
    border_size = 4,
    col = {
      active_border = "rgb(ff9e64)",
    },
  },
  group = {
    col = {
      border_active = "rgb(ff9e64)",
    },
  },
})

-- Unfocused windows a touch see-through (Omarchy's default is 0.96), still
-- light enough to read one window while typing in another. Only windows on
-- the default-opacity tag: video, games and browsers keep their own rules.
o.window({ tag = "default-opacity" }, { opacity = "0.985 0.92" })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
