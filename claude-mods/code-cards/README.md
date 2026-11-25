# code-cards

Claude Code mod: code blocks in Claude's replies are drawn as cards, as in
Obsidian. Each card has a shaded background, a header with the language's
Nerd Font icon and name, and a Copy button that copies the block to the
clipboard (through the terminal, so it also works over ssh) and reads
"Copied" for two seconds.

The shade is the Omarchy theme's kitty background nudged toward the text, read
from `~/.local/state/omarchy/current/theme/kitty.conf` (about every 10 s, so it
follows theme changes). Where that file is missing the card gets a grey border.

Clicks need to reach Claude Code: kitty must not grab plain clicks in apps that
use the mouse (see kitty.conf). kitty's Ctrl+Shift+Y (`code_blocks.py`) reads
these cards too.
