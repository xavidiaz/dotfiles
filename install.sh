#!/usr/bin/env bash
# Stow every package into $HOME, backing up anything already at the
# target path (a real file, a real directory, or a foreign symlink from
# e.g. a fresh Omarchy install) that would otherwise conflict.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

packages=(
  hypr alacritty foot ghostty kitty nvim tmux btop lazygit
  herdr hyprmoncfg mise wally voxtype xournalpp autostart git
  mimeapps starship bash omarchy tuios fcitx5 codespaces bat glow chawan
  fontconfig darky
)

# Real directory, so stow links only the file inside it: if stow linked the
# whole folder, ~/.ssh/config.d/codespaces-host (private, holds the CodeSpaces
# host address) would be written into this public repo.
mkdir -p "$HOME/.ssh/config.d" && chmod 700 "$HOME/.ssh"

# Same for the shell plugins folder: it holds git-cloned plugins (see
# omarchy-plugins.txt) next to the personal ones stowed from omarchy/, and a
# folded link would clone them into this repo.
mkdir -p "$HOME/.config/omarchy/plugins"

# Same for Darky's state folder (only settings.json is shared; the current mode
# and override are per machine) and systemd's user folder (systemctl enable
# writes its links there).
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/darky" "$HOME/.config/systemd/user"
chmod 700 "${XDG_STATE_HOME:-$HOME/.local/state}/darky"

if ! command -v stow >/dev/null; then
  echo "GNU Stow not found. Install it first, e.g.: sudo pacman -S stow" >&2
  exit 1
fi

# Full system update first. Arch doesn't support partial upgrades: adding a
# package to an out-of-date system can pull in a build made for newer libraries
# (kdeconnect needing Qt 6.12 on a Qt 6.11 system), which then fails to start.
# -y answers Omarchy's prompts and never reboots by itself; it only says when a
# reboot is due. Stopping on failure keeps the installs below off a half-updated system.
if command -v omarchy >/dev/null; then
  omarchy update -y || { echo "omarchy update failed; fix it and re-run install.sh" >&2; exit 1; }
fi

# Packages the configs rely on: glow renders Markdown for the bat wrapper in
# ~/.bashrc, chawan is the terminal web browser (cha), and ble.sh (AUR) gives
# bash its Vim editing and the prompt's mode chip.
# ~/.bashrc falls back to plain readline when ble.sh is missing (e.g. a Codespace).
if command -v omarchy >/dev/null; then
  omarchy pkg add glow || echo "Failed to install glow" >&2
  omarchy pkg add chawan || echo "Failed to install chawan" >&2
  omarchy pkg aur add blesh-git || echo "Failed to install blesh-git from the AUR" >&2
fi

# Atkinson Hyperlegible fonts, designed so similar letters (I l 1, O 0, b d p q)
# are hard to mix up: the Mono, patched with Nerd Font icons, for terminals and
# the bar, and Next for interface text. fontconfig/ makes them the monospace
# and sans-serif defaults; GTK apps take their font from gsettings.
if command -v omarchy >/dev/null; then
  omarchy pkg add otf-atkinsonhyperlegiblemono-nerd || echo "Failed to install otf-atkinsonhyperlegiblemono-nerd" >&2
  omarchy pkg aur add otf-atkinson-hyperlegible-next || echo "Failed to install otf-atkinson-hyperlegible-next from the AUR" >&2
  gsettings set org.gnome.desktop.interface font-name 'Atkinson Hyperlegible Next 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name 'AtkynsonMono Nerd Font 11' 2>/dev/null || true
fi

# Tailscale, for the bar's omarchy.tailscale widget. Omarchy's installer also
# logs in (it prints a login link), lets $USER manage it and saves Taildrop
# files to ~/Downloads, so it only runs where Tailscale is missing.
if command -v omarchy >/dev/null && ! command -v tailscale >/dev/null; then
  omarchy install service tailscale || echo "Failed to install Tailscale" >&2
fi

# KeePass Picker (omarchy-plugins.txt, Super+Shift+K): keepassxc-cli holds the
# vault, pinentry-qt asks for the master password (qt6ct paints it in the
# theme), and wl-copy + wtype paste into the focused window. Point it at the
# vault once per machine with:
#   ~/.config/omarchy/plugins/mkelk.keepass-picker/bin/keepass-picker-ctl configure
if command -v omarchy >/dev/null; then
  omarchy pkg add keepassxc pinentry qt6ct wl-clipboard wtype || echo "Failed to install the KeePass Picker packages" >&2
fi

# KDE Connect: clipboard sync with the phone (Android -> desktop via the
# notification's "Send clipboard"), and sshfs + kio-fuse for "Browse device".
# The daemon starts at login from /etc/xdg/autostart. ufw needs its ports
# open; sudo is only asked for when the rules are missing.
if command -v omarchy >/dev/null; then
  omarchy pkg add kdeconnect sshfs kio-fuse || echo "Failed to install KDE Connect" >&2
  # LAN only. The Bluetooth backend keeps the adapter scanning and probes every
  # nearby device with a Serial Port service, earbuds included, which made the
  # JLab GO Pop ANC stutter and drop. The phone pairs over Wi-Fi anyway.
  # (Kept out of stow: ~/.config/kdeconnect also holds this machine's keys.)
  kwriteconfig6 --file ~/.config/kdeconnect/config --group General \
    --key disabled_providers_v2 "loopback,bluetooth"
  if systemctl is-active -q ufw && ! grep -qs '1714:1764' /etc/ufw/user.rules; then
    { sudo ufw allow 1714:1764/udp && sudo ufw allow 1714:1764/tcp; } >/dev/null \
      || echo "Failed to open the KDE Connect ports in ufw" >&2
  fi
fi

# Configurador FNMT-RCM: generates the keys when requesting a Spanish FNMT
# digital certificate (sede.fnmt.gob.es). AUR repackaging of the official .deb;
# it pulls in a Java runtime. hypr/hyprland.lua sets _JAVA_AWT_WM_NONREPARENTING
# so its window isn't blank.
if command -v omarchy >/dev/null; then
  omarchy pkg aur add configuradorfnmt || echo "Failed to install configuradorfnmt from the AUR" >&2
fi

# Intel MacBook Pros (2016-2017) with the Cirrus CS8409 codec: the in-kernel
# driver leaves the speaker amps off, so audio "plays" in silence. This DKMS
# driver replaces it with one that drives them.
if command -v omarchy >/dev/null && grep -qs 'CS8409' /proc/asound/card*/codec#*; then
  omarchy pkg aur add snd-hda-macbookpro-dkms-git || echo "Failed to install snd-hda-macbookpro-dkms-git from the AUR" >&2
fi

# Darky (inside the Omarchy shell) keeps its settings in memory and saves them
# back the moment its file is moved aside, which would overwrite the repo's with
# this machine's. Stop the shell while stowing; it's restarted after the plugins.
if command -v quickshell >/dev/null; then
  while timeout 30 quickshell kill -p "${OMARCHY_PATH:-/usr/share/omarchy}/shell" --any-display >/dev/null 2>&1; do :; done
fi

# git-hooks/post-merge re-stows whatever a later `git pull` changes
git config core.hooksPath git-hooks

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

# Darky (the light/dark plugin) replaces its symlinks with plain files when it
# saves; this watcher re-links them, moving the new contents into the repo.
systemctl --user daemon-reload
systemctl --user enable --now darky-relink.path

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

# Wireless Peripheral Battery reads batteries through its own sandboxed system
# service (a root oneshot on a 30s timer, no network, writes only to known
# Logitech/SteelSeries/HyperX devices). Its install.sh copies the reader into
# /usr/local/lib, so it is re-run after every plugin update to keep them level.
battery_service="$HOME/.config/omarchy/plugins/gexavi.peripheral-battery/service/install.sh"
if [ -x "$battery_service" ] || [ -f "$battery_service" ]; then
  sudo bash "$battery_service" >/dev/null || echo "Failed to install the peripheral-battery service" >&2
fi

# Read Aloud (omarchy-plugins.txt, Super+R) runs offline TTS from an engine and
# voice model it installs outside the plugin folder (~/.local/share/omarchy-read-aloud,
# ~/.local/bin/read-aloud, a user service). Its setup is the plugin's own; run it
# when missing or when a plugin update bumped the engine. The Super+R block in
# bindings.lua is stowed with hypr/.
read_aloud="$HOME/.config/omarchy/plugins/jebin2.read-aloud/bin/read-aloud-setup"
if [ -x "$read_aloud" ] && "$read_aloud" check | grep -qE '"installed":false|"update":true'; then
  omarchy pkg add bun || echo "Failed to install Bun" >&2
  "$read_aloud" setup || echo "Failed to set up Read Aloud" >&2
fi

# Pi coding agent: mise/ pins its version. Pi rewrites ~/.pi/agent/settings.json
# itself, so it isn't stowed; pi-settings.json is merged in instead, keeping this
# machine's own keys. Its "ifMissing" keys only fill gaps (Pi saves the model
# picked with /model as defaultModel, and a re-run mustn't undo that); its
# "always" keys win, and a package listed there replaces any other version of
# that package. Then Pi installs the packages at those versions. The Azure login
# (key plus endpoint) stays per machine and out of this public repo; see README.md.
if command -v mise >/dev/null && command -v jq >/dev/null; then
  mise install pi >/dev/null 2>&1 || echo "Failed to install Pi" >&2
  pi_settings="$HOME/.pi/agent/settings.json"
  mkdir -p "${pi_settings%/*}"
  [ -s "$pi_settings" ] || echo '{}' >"$pi_settings"
  if jq --slurpfile f pi-settings.json '
      def name: (if type == "string" then . else .source end) | sub("@[^@/]+$"; "");
      ($f[0].always.packages // []) as $new | ($new | map(name)) as $names
      | ($f[0].ifMissing // {}) * . * ($f[0].always // {} | del(.packages))
      | .packages = ([(.packages // [])[] | select(name | IN($names[]) | not)] + $new)
    ' "$pi_settings" >"$pi_settings.tmp"; then
    mv "$pi_settings.tmp" "$pi_settings"
    mise exec pi -- pi update --extensions >/dev/null || echo "Failed to install Pi packages" >&2
  else
    rm -f "$pi_settings.tmp"
    echo "Failed to merge pi-settings.json into $pi_settings" >&2
  fi
fi

# Claude Code mods (claude-mods/): the folder is a plugin marketplace, and an
# installed plugin from a folder marketplace runs from that folder itself, so
# edits here reach Claude Code after /reload-plugins, with no reinstall.
if command -v claude >/dev/null; then
  claude plugin marketplace add "$PWD/claude-mods" >/dev/null 2>&1 || true
  for mod in code-cards; do
    claude plugin install "$mod@dotfiles-mods" --scope user >/dev/null \
      || echo "Failed to install Claude Code mod $mod" >&2
  done
fi

echo "Done. Remember: gh auth login, /login azure in pi (README.md, Pi), and see README.md for _system-reference/ (keyd)."
