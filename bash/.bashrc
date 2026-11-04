# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# Our own environment (cargo, .NET tools), also needed by non-login shells
[[ -r ~/.profile ]] && source ~/.profile

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# ble.sh replaces readline. Load it before Omarchy's rc so Starship and fzf set
# themselves up for it; it attaches at the end of this file.
[[ -r /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --noattach

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Vim keybindings for the command line
set -o vi

# LazyVim-style leader actions, shared by ble.sh and the readline fallback below.
# The printf puts back the NORMAL block cursor the launched program changed.
__leader_files() { local f; f=$(fzf --preview 'bat --style=numbers --color=always {}') && n "$f"; printf '\e[2 q'; }
__leader_grep() {
  local m
  m=$(rg --line-number --color=always --smart-case "" 2>/dev/null |
    fzf --ansi --delimiter : --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' --preview-window '+{2}/2') &&
    n "+$(cut -d: -f2 <<<"$m")" "$(cut -d: -f1 <<<"$m")"
  printf '\e[2 q'
}
__leader_lazygit() { lazygit; printf '\e[2 q'; }
__leader_explorer() { n; printf '\e[2 q'; }

# / and ? search history in an fzf picker, like a LazyVim picker: matches update as
# you type, Enter puts the command on the line to edit, Esc cancels. The same look
# applies to Ctrl+R. Colours are fzf's ANSI defaults, so they follow the theme.
export FZF_CTRL_R_OPTS="--height=40% --layout=reverse --border=rounded --border-label=' History ' --prompt='/ ' --pointer='▌' --info=inline-right --color=border:blue,label:blue:bold,prompt:blue"
__leader_history() { __fzf_history__; printf '\e[2 q'; }

if [[ ${BLE_VERSION-} ]]; then
  # ble.sh: real Vim editing (visual mode, text objects like ciw and di", counts,
  # registers, undo), syntax highlighting and fish-style autosuggestions.
  ble-import -d integration/fzf-key-bindings

  # The mode as a chip in front of the input line, in Neovim's colours: green
  # INSERT, blue NORMAL, magenta VISUAL. Fixed colours, like the Starship chips.
  function ble/prompt/backslash:vi-chip {
    local mode=i name bg fg=255\;255\;255
    # The first prompt draws before ble.sh loads its vi module; a shell starts in INSERT
    ble/is-function ble/keymap:vi/script/get-mode && ble/keymap:vi/script/get-mode
    case $mode in
    (i)           name=INSERT    bg='34;197;94' fg='0;0;0' ;;
    (R | $'\x12') name=REPLACE   bg='239;68;68' ;;
    (*v)          name=VISUAL    bg='217;70;239' ;;
    (*V)          name='V-LINE'  bg='217;70;239' ;;
    (*$'\x16')    name='V-BLOCK' bg='217;70;239' ;;
    (*c)          name=COMMAND   bg='245;158;11' fg='0;0;0' ;;
    (*)           name=NORMAL    bg='59;130;246' ;;
    esac
    ble/prompt/print $'\e[38;2;'$bg$'m\e[1;38;2;'$fg';48;2;'$bg'm '$name$' \e[0;38;2;'$bg$'m\e[m'
  }
  # Starship ends its prompt with a line break and a space; put the chip before
  # that space. Runs after Starship's own PRECMD hook, which builds PS1.
  __vi_chip_prompt() { PS1=${PS1%' '}'\q{vi-chip} '; }
  blehook PRECMD+=__vi_chip_prompt

  # Yanks and deletes to the unnamed or + register also go to the Wayland
  # clipboard, and p/P paste whatever is on it, like Neovim's clipboard=unnamedplus
  __clip_copy() {
    local reg=${ADVICE_WORDS[1]} content=${ADVICE_WORDS[3]}
    [[ ! $reg || $reg == 34 || $reg == 43 ]] || return 0
    printf '%s' "$content" | wl-copy 2>/dev/null
  }
  # Before p/P: the register typed before them ("+p) is still pending here
  __clip_paste() {
    local reg=$_ble_keymap_vi_reg clip
    [[ ! $reg || $reg == 34 || $reg == 43 ]] || return 0
    clip=$(wl-paste --no-newline 2>/dev/null) || return 0
    # Keep the kill ring (and so linewise yy/dd) when the clipboard still holds it
    [[ $clip == "${_ble_edit_kill_ring%$'\n'}" ]] && return 0
    if [[ $reg == 43 ]]; then
      _ble_keymap_vi_register[43]=/$clip
    else
      ble-edit/content/push-kill-ring "$clip" ''
    fi
  }

  # ble.sh loads its vi module lazily, so its options, widgets and keymaps only
  # exist from here on
  __ble_vi_setup() {
    bleopt keymap_vi_mode_show=
    bleopt keymap_vi_mode_update_prompt=1

    # Bar cursor in INSERT, block in NORMAL and VISUAL, underline while an
    # operator waits for its motion (d, c, y...)
    ble-bind -m vi_imap --cursor 6
    ble-bind -m vi_nmap --cursor 2
    ble-bind -m vi_xmap --cursor 2
    ble-bind -m vi_omap --cursor 4

    if [[ $WAYLAND_DISPLAY ]] && command -v wl-copy >/dev/null; then
      ble/function#advice after ble/keymap:vi/register#set __clip_copy
      local widget
      for widget in vi_nmap/paste-after vi_nmap/paste-before vi_xmap/paste-after vi_xmap/paste-before; do
        ble/function#advice before "ble/widget/$widget" __clip_paste
      done
    fi

    # Leader keys in NORMAL mode: Space then ff, sg, gg, e, : or v (edit the line
    # in Neovim; save and quit runs it). / and ? open the fzf history picker.
    ble-bind -m vi_nmap -c 'SP f f' __leader_files
    ble-bind -m vi_nmap -c 'SP s g' __leader_grep
    ble-bind -m vi_nmap -c 'SP g g' __leader_lazygit
    ble-bind -m vi_nmap -c 'SP e' __leader_explorer
    ble-bind -m vi_nmap -x 'SP :' __leader_history
    ble-bind -m vi_nmap -f 'SP v' vi-command/edit-and-execute-command
    ble-bind -m vi_nmap -x '/' __leader_history
    ble-bind -m vi_nmap -x '?' __leader_history
    ble-bind -m vi_nmap -f 'g c c' vi-rlfunc/insert-comment
  }
  blehook/eval-after-load keymap_vi __ble_vi_setup
else
  # Without ble.sh (e.g. a Codespace): readline vi mode
  # Omarchy loads its inputrc before the switch to vi mode, so its key bindings only
  # reach the emacs keymap. Apply the same file to both vi keymaps.
  bind -f "$OMARCHY_PATH/default/bash/inputrc"
  bind -m vi-command -f "$OMARCHY_PATH/default/bash/inputrc"

  # Show the mode like Neovim does: bar cursor in insert, block in normal, and a
  # lualine-style chip on the prompt's input line in the same colours as above.
  # A short timeout makes Esc switch immediately.
  bind 'set show-mode-in-prompt on'
  bind $'set vi-ins-mode-string "\1\e[6 q\e[38;2;34;197;94m\2\ue0ba\1\e[1;38;2;0;0;0;48;2;34;197;94m\2 INSERT \1\e[0;38;2;34;197;94m\2\ue0bc\1\e[0m\2"'
  bind $'set vi-cmd-mode-string "\1\e[2 q\e[38;2;59;130;246m\2\ue0ba\1\e[1;38;2;255;255;255;48;2;59;130;246m\2 NORMAL \1\e[0;38;2;59;130;246m\2\ue0bc\1\e[0m\2"'
  bind 'set keyseq-timeout 50'

  # LazyVim-style leader keys in normal mode: Space then ff, sg, gg, e or :
  # Space alone must be unbound, otherwise the timeout above ends the sequence.
  bind -m vi-command -r ' '
  bind -m vi-command -x '" ff": __leader_files'
  bind -m vi-command -x '" sg": __leader_grep'
  bind -m vi-command -x '" gg": __leader_lazygit'
  bind -m vi-command -x '" e": __leader_explorer'
  bind -m vi-command -x '" :": __leader_history'
  bind -m vi-command '"gg": beginning-of-history'
  bind -m vi-command '"G": end-of-history'
  bind -m vi-command '"gcc": insert-comment'
  bind -m vi-command -x '"/": __leader_history'
  bind -m vi-command -x '"?": __leader_history'
fi

# Keep coloured log levels (info/warn/fail) from .NET apps when their output is piped, e.g. under `dotnet watch`
export DOTNET_SYSTEM_CONSOLE_ALLOW_ANSI_COLOR_REDIRECTION=1

# Highlight URLs in piped output: dotnet watch --project LMS.API 2>&1 | hlurl
hlurl() { sed -u -E $'s#https?://[^][:space:]"\'<>)]+#\e[1;4;34m&\e[0m#g'; }

# Tell kitty when tuios runs, so Ctrl+Space reaches tuios as its leader instead of
# opening the scrollback (see kitty.conf)
tuios() {
  printf '\e]1337;SetUserVar=in_tuios=MQ==\a'
  command tuios "$@"
  local status=$?
  printf '\e]1337;SetUserVar=in_tuios\a'
  return $status
}

# glow in the terminal's ANSI colours, so Markdown follows the Omarchy theme (its
# "auto" style turns dark on a light kitty). Passed as a flag because glow expands
# neither ~ nor $HOME in glow.yml, nor reads GLAMOUR_STYLE.
glow() { command glow --style "$HOME/.config/glow/theme.json" "$@"; }

# `bat FILE` in the terminal shows the file the most readable way: Markdown
# rendered by glow, images inline in kitty, JSON pretty-printed, a directory as a
# tree. Flags, several files, pipes and fzf previews go to the real bat.
bat() {
  if [[ $# -ne 1 || $1 == -* || ! -t 1 ]]; then command bat "$@"; return; fi
  if [[ -d $1 ]]; then eza --tree --level=2 --icons --git-ignore -- "$1"; return; fi
  [[ -f $1 ]] || { command bat "$@"; return; }
  case ${1,,} in
  *.md | *.markdown) glow --pager --width "$((COLUMNS < 100 ? COLUMNS : 100))" -- "$1" ;;
  *.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp)
    if [[ $TERM == xterm-kitty ]]; then kitty +kitten icat -- "$1"; else command bat "$1"; fi ;;
  *.json)
    if jq empty -- "$1" 2>/dev/null; then jq -C . -- "$1" | less -RF; else command bat "$1"; fi ;;
  *) command bat "$1" ;;
  esac
}

# Window title for kitty's tab bar: the repo and branch (or the directory outside a
# repo) at the prompt, and the running command in front of it while it runs
__title_precmd() {
  local git top branch
  git=$(git rev-parse --show-toplevel --abbrev-ref HEAD 2>/dev/null)
  top=${git%%$'\n'*} branch=${git#*$'\n'}
  if [[ -n $top ]]; then
    [[ $branch == HEAD || $branch == "$git" ]] && branch=$(git rev-parse --short HEAD 2>/dev/null)
    __title_where="${top##*/}${branch:+  $branch}"
  else
    __title_where=${PWD/#$HOME/\~}
  fi
  [[ -n $SSH_CONNECTION ]] && __title_where="${HOSTNAME%%.*}: $__title_where"
  # In a berth pod: the pod and session (e.g. "ai901:claude"), as in the prompt chip
  [[ -n $BERTH_SPACE ]] && __title_where="$BERTH_SPACE: $__title_where"
  printf '\e]2;%s\a' "$__title_where"
}
__title_preexec() {
  local cmd
  read -r _ cmd <<<"$(HISTTIMEFORMAT= builtin history 1)"
  printf '\e]2;%s · %s\a' "${cmd//[[:cntrl:]]/}" "$__title_where"
}
PROMPT_COMMAND+=(__title_precmd)
PS0+='$(__title_preexec)'

# History: bigger, without duplicates, timestamped, and shared across kitty tabs
# right away (append after each command, read in what other shells appended)
HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
HISTIGNORE='ls:ll:cd:cd -:pwd:exit:clear:history'
__history_sync() { builtin history -a; builtin history -n; }
PROMPT_COMMAND+=(__history_sync)

# Keep last
[[ ! ${BLE_VERSION-} ]] || ble-attach
