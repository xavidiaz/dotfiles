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

-- Scrolling screenshot (whole page, like a phone). Press again to stop early.
o.bind("SHIFT + PRINT", "Scrolling screenshot", "~/.config/hypr/scripts/screenshot-scroll")

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

-- tmux and herdr are uninstalled; drop the default bindings that launch them.
hl.unbind("SUPER + ALT + RETURN")
hl.unbind("SUPER + CTRL + RETURN")
hl.unbind("SUPER + ALT + K")
hl.unbind("SUPER + CTRL + K")

-- Global workspaces, as before Omarchy 4.5 made them per monitor (each monitor
-- its own 1-10, the second monitor numbered 11-20). Super + 1-5 are the laptop's
-- and Super + 6-0 the external display's, through the workspace rules in
-- monitors.lua. Turning off the reconcile stops Omarchy renumbering workspaces
-- into per-monitor blocks on reload or when a monitor comes and goes.
o.workspaces.reconcile = function() end

for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  local id = tostring(workspace)
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + ALT + " .. key)
  o.bind("SUPER + " .. key, "Switch to workspace " .. id, hl.dsp.focus({ workspace = id }))
  o.bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. id, hl.dsp.window.move({ workspace = id }))
  o.bind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. id,
    hl.dsp.window.move({ workspace = id, follow = false }))
end

-- Moving a workspace to another monitor keeps its number.
for _, dir in ipairs({ { "LEFT", "l" }, { "RIGHT", "r" }, { "UP", "u" }, { "DOWN", "d" } }) do
  hl.unbind("SUPER + SHIFT + ALT + " .. dir[1])
  o.bind("SUPER + SHIFT + ALT + " .. dir[1], "Move workspace to " .. dir[1]:lower() .. " monitor", function()
    local target = hl.get_monitor(dir[2])
    if target then
      hl.dispatch(hl.dsp.workspace.move({ monitor = target.name }))
    end
  end)
end

-- KeePass Picker: search the vault and type a password into the focused window.
o.bind("SUPER + SHIFT + K", "KeePass Picker", "omarchy-shell shell toggle mkelk.keepass-picker")

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end
