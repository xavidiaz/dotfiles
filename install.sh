#!/usr/bin/env bash
# Stow every package into $HOME, backing up any pre-existing real files
# (not symlinks) that would otherwise conflict.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

packages=(
  hypr alacritty foot ghostty kitty nvim tmux btop lazygit keepassxc
  herdr hyprmoncfg mise wally voxtype xournalpp autostart git
  mimeapps starship bash omarchy
)

if ! command -v stow >/dev/null; then
  echo "GNU Stow not found. Install it first, e.g.: sudo pacman -S stow" >&2
  exit 1
fi

# Pre-flight: back up any real (non-symlink) files stow would conflict on.
conflicts=$(stow -n -v -t "$HOME" "${packages[@]}" 2>&1 >/dev/null \
  | grep '^\s*\*' | sed -E 's/.*existing target ([^ ]+) since.*/\1/' || true)

for rel in $conflicts; do
  target="$HOME/$rel"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up existing $target -> $target.pre-stow-backup"
    mv "$target" "$target.pre-stow-backup"
  fi
done

stow -v -t "$HOME" "${packages[@]}"
echo "Done. Remember: gh auth login, and see README.md for _system-reference/ (keyd)."
