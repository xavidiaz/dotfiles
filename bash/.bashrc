# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

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

# Keep coloured log levels (info/warn/fail) from .NET apps when their output is piped, e.g. under `dotnet watch`
export DOTNET_SYSTEM_CONSOLE_ALLOW_ANSI_COLOR_REDIRECTION=1

# Highlight URLs in piped output: dotnet watch --project LMS.API 2>&1 | hlurl
hlurl() { sed -u -E $'s#https?://[^][:space:]"\'<>)]+#\e[1;4;34m&\e[0m#g'; }
