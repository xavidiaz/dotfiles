#!/usr/bin/env bash
# Stow every package into $HOME, backing up anything already at the
# target path (a real file, a real directory, or a foreign symlink from
# e.g. a fresh Omarchy install) that would otherwise conflict.
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
echo "Done. Remember: gh auth login, and see README.md for _system-reference/ (keyd)."
