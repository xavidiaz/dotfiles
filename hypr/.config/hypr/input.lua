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

