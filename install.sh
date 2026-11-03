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
