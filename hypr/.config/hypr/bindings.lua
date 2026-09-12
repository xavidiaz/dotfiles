-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Brackets on Left Alt + number row.
-- The se(mac) layout puts [ ] { } on AltGr (Right Alt = Mod5): AltGr+8/9 and
-- AltGr+Shift+8/9. This replays that exact chord to the focused surface so the
-- left Option key works too. Modelled on Omarchy's universal-clipboard binds.
local function send_mod5_key_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

o.bind("ALT + 8", "Bracket left [", send_mod5_key_once("MOD5", "8"))
o.bind("ALT + 9", "Bracket right ]", send_mod5_key_once("MOD5", "9"))
o.bind("ALT + SHIFT + 8", "Brace left {", send_mod5_key_once("MOD5 SHIFT", "8"))
o.bind("ALT + SHIFT + 9", "Brace right }", send_mod5_key_once("MOD5 SHIFT", "9"))
