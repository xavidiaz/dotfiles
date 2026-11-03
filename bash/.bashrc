# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# Our own environment (cargo, .NET tools), also needed by non-login shells
[[ -r ~/.profile ]] && source ~/.profile

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Vim keybindings for the command line
set -o vi

# Omarchy loads its inputrc before the switch to vi mode, so its key bindings only
# reach the emacs keymap. Apply the same file to both vi keymaps.
bind -f "$OMARCHY_PATH/default/bash/inputrc"
bind -m vi-command -f "$OMARCHY_PATH/default/bash/inputrc"

# Show the mode like Neovim does: bar cursor in insert, block in normal, and a
# lualine-style chip on the prompt's input line in the theme's green and blue.
# A short timeout makes Esc switch immediately.
bind 'set show-mode-in-prompt on'
bind 'set vi-ins-mode-string "\1\e[6 q\e[32m\2\1\e[1;30;42m\2 INSERT \1\e[0;32m\2\1\e[0m\2"'
bind 'set vi-cmd-mode-string "\1\e[2 q\e[34m\2\1\e[1;30;44m\2 NORMAL \1\e[0;34m\2\1\e[0m\2"'
bind 'set keyseq-timeout 50'

# LazyVim-style leader keys in normal mode: Space then ff, sg, gg, e or :
# Space alone must be unbound, otherwise the timeout above ends the sequence.
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
bind -m vi-command -r ' '
bind -m vi-command -x '" ff": __leader_files'
bind -m vi-command -x '" sg": __leader_grep'
bind -m vi-command -x '" gg": __leader_lazygit'
bind -m vi-command -x '" e": __leader_explorer'
bind -m vi-command -x '" :": __leader_history'
bind -m vi-command '"gg": beginning-of-history'
bind -m vi-command '"G": end-of-history'
bind -m vi-command '"gcc": insert-comment'

# / and ? search history in an fzf picker, like a LazyVim picker: matches update as
# you type, Enter puts the command on the line to edit, Esc cancels. The same look
# applies to Ctrl+R. Colours are fzf's ANSI defaults, so they follow the theme.
export FZF_CTRL_R_OPTS="--height=40% --layout=reverse --border=rounded --border-label=' History ' --prompt='/ ' --pointer='▌' --info=inline-right --color=border:blue,label:blue:bold,prompt:blue"
__leader_history() { __fzf_history__; printf '\e[2 q'; }
bind -m vi-command -x '"/": __leader_history'
bind -m vi-command -x '"?": __leader_history'

# Keep coloured log levels (info/warn/fail) from .NET apps when their output is piped, e.g. under `dotnet watch`
export DOTNET_SYSTEM_CONSOLE_ALLOW_ANSI_COLOR_REDIRECTION=1

# Highlight URLs in piped output: dotnet watch --project LMS.API 2>&1 | hlurl
hlurl() { sed -u -E $'s#https?://[^][:space:]"\'<>)]+#\e[1;4;34m&\e[0m#g'; }

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
  printf '\e]2;%s\a' "$__title_where"
}
__title_preexec() {
  local cmd
  read -r _ cmd <<<"$(HISTTIMEFORMAT= builtin history 1)"
  printf '\e]2;%s · %s\a' "${cmd//[[:cntrl:]]/}" "$__title_where"
}
PROMPT_COMMAND+=(__title_precmd)
PS0+='$(__title_preexec)'
