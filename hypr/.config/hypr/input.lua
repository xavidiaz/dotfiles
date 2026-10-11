-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
input = {
     -- Standard Swedish Mac layout for every keyboard by default (external
     -- keyboards like the ZSA Voyager report normal scancodes).
     kb_layout = "se",
     kb_variant = "mac",
     kb_options = "compose:caps,shift:both_capslock_cancel",
     }
    }
)

-- This MacBook's internal keyboard reports the TLDE/LSGT keys swapped, so it
-- alone gets the "fixed" variant from ~/.config/xkb/symbols/omarchy-se-mac-fix
-- that swaps them back (see macbook-section-lessgreater-swap memory). Applying
-- that fix globally would wrongly swap < /> into §/° on normal external
-- keyboards (e.g. the ZSA Voyager).
hl.device({
    name = "apple-spi-keyboard",
    kb_layout = "omarchy-se-mac-fix",
    kb_variant = "fixed",
})


-- Three-finger swipe up toggles Exposé (its hot corner is disabled).
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function() hl.dispatch(hl.dsp.event("expose.window-overview:toggle")) end,
})

-- Three-finger swipe left/right switches workspaces. The Exposé helper pauses
-- the swipe while the overview is open so the desktop behind it doesn't move.
local expose_gesture_path = os.getenv("HOME") .. "/.config/omarchy/plugins/expose.window-overview/workspace-gesture.lua"
local expose_gesture_loader = loadfile(expose_gesture_path)
if expose_gesture_loader then
  expose_gesture_loader()({ fingers = 3 })
else
  hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
end
