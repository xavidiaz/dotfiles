#!/usr/bin/env bash
# Stow every package into $HOME, backing up anything already at the
# target path (a real file, a real directory, or a foreign symlink from
# e.g. a fresh Omarchy install) that would otherwise conflict.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

packages=(
  hypr alacritty foot ghostty kitty nvim tmux btop lazygit keepassxc
  herdr hyprmoncfg mise wally voxtype xournalpp autostart git
  mimeapps starship bash omarchy tuios fcitx5 codespaces bat glow
)

# Real directory, so stow links only the file inside it: if stow linked the
# whole folder, ~/.ssh/config.d/codespaces-host (private, holds the CodeSpaces
# host address) would be written into this public repo.
mkdir -p "$HOME/.ssh/config.d" && chmod 700 "$HOME/.ssh"

if ! command -v stow >/dev/null; then
  echo "GNU Stow not found. Install it first, e.g.: sudo pacman -S stow" >&2
  exit 1
fi

# Packages the configs rely on: glow renders Markdown for the bat wrapper in
# ~/.bashrc, and ble.sh (AUR) gives bash its Vim editing and the prompt's mode chip.
# ~/.bashrc falls back to plain readline when ble.sh is missing (e.g. a Codespace).
if command -v omarchy >/dev/null; then
  omarchy pkg add glow || echo "Failed to install glow" >&2
  omarchy pkg aur add blesh-git || echo "Failed to install blesh-git from the AUR" >&2
fi

# Pre-flight: extract conflicting target paths from stow's dry-run output.
# Stow reports conflicts in at least two different wordings, so match both:
#   * cannot stow dotfiles/PKG/PATH over existing target PATH since ...
#   * existing target is not owned by stow: PATH
conflicts=$(stow -n -v -t "$HOME" "${packages[@]}" 2>&1 >/dev/null \
  | sed -n -E \
      -e 's/^\s*\*\s*existing target is not owned by stow:\s*(.+)$/\1/p' \
      -e 's/^\s*\*.*existing target ([^ ]+) since.*/\1/p' \
  || true)

for rel in $conflicts; do
  target="$HOME/$rel"
  # Skip if it's already a symlink into this dotfiles checkout (nothing to do).
  if [ -L "$target" ]; then
    case "$(readlink "$target")" in
      *dotfiles*) continue ;;
    esac
  fi
  # Back up whatever is there: a real file, a real directory, or a
  # foreign symlink (e.g. a fresh Omarchy install's default).
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Backing up existing $target -> $target.pre-stow-backup"
    mv "$target" "$target.pre-stow-backup"
  fi
done

stow -v -t "$HOME" "${packages[@]}"

# Neovim plugins at the versions in lazy-lock.json, so kitty.conf's scrollback
# kitten (kitty-scrollback.nvim) exists before Neovim is ever opened
if command -v nvim >/dev/null; then
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || echo "Failed to install Neovim plugins" >&2
fi

# Darky (the light/dark plugin) replaces symlinks when it saves, so its settings
# are seeded as a copy instead; hooks/darky.d/sync-dotfiles.hook copies changes
# back (and re-links light-dark.conf, which Darky also rewrites).
darky_settings="${XDG_STATE_HOME:-$HOME/.local/state}/darky/settings.json"
if [ ! -e "$darky_settings" ]; then
  mkdir -p "${darky_settings%/*}" && cp _seed/darky/settings.json "$darky_settings"
fi

# monitors.lua differs per machine, so it isn't tracked, but hyprland.lua
# requires it: start from Omarchy's default where it's missing
monitors="$HOME/.config/hypr/monitors.lua"
if [ ! -e "$monitors" ] && [ -f /usr/share/omarchy/config/hypr/monitors.lua ]; then
  cp /usr/share/omarchy/config/hypr/monitors.lua "$monitors"
fi

# Vim keys in Brave: a managed policy force-installs Vimium. It lives in /etc,
# so sudo is only asked for when the policy is missing or out of date.
if command -v brave >/dev/null; then
  brave_policy=/etc/brave/policies/managed/vim.json
  brave_vim='{"ExtensionInstallForcelist":["dbepggeogbaibhgnhhndojpepiihcmeb"]}'
  if [ "$(cat "$brave_policy" 2>/dev/null)" != "$brave_vim" ]; then
    sudo mkdir -p "${brave_policy%/*}" && echo "$brave_vim" | sudo tee "$brave_policy" >/dev/null \
      || echo "Failed to write the Brave Vimium policy" >&2
  fi
fi

# Omarchy shell plugins aren't stowed (the plugins/ dir is a git-clone
# cache), so add any listed in omarchy-plugins.txt that this machine lacks
# and update the rest. Old clones can predate Omarchy's plugin API changes
# and silently ignore their shell.json settings (e.g. Exposé < 5.0 kept its
# hot corner on despite hotCornerEnabled: false).
if command -v omarchy >/dev/null; then
  plugin_dir="$HOME/.config/omarchy/plugins"
  while read -r id url; do
    case "$id" in "" | \#*) continue ;; esac
    if [ -d "$plugin_dir/$id" ]; then
      echo "Updating Omarchy plugin $id"
      omarchy plugin update "$id" --yes </dev/null || echo "Failed to update plugin $id" >&2
    else
      echo "Adding Omarchy plugin $id"
      omarchy plugin add "$url" --yes </dev/null || echo "Failed to add plugin $id from $url" >&2
    fi
  done <omarchy-plugins.txt
  omarchy restart shell >/dev/null 2>&1 || true
fi

echo "Done. Remember: gh auth login, and see README.md for _system-reference/ (keyd)."
