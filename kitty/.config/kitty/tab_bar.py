# Tab title for kitty.conf's tab_title_template "{custom}": a berth session title
# ("ai901:claude", or "nvim · ai901:claude" while a command runs) gets its session
# name as a chip (black on a background colour of its own), so windows of one
# pod tell apart.
#
# A tab running ssh gets the host in front as a chip of the same kind ("nixpi"
# then "✳ Claude Code"), since ~/.bashrc's "host: " prefix over SSH is lost when
# a full-screen program like Claude Code sets a title of its own.
import os
import re

from kitty.fast_data_types import get_boss

# Fixed colours, not the theme palette: some themes (e.g. the current light one)
# are all blues and purples, so a palette colour can match the tab background.
# Light enough for black text, none of them blue.
COLOURS = ('ffb454', '7fd962', 'ffd866', 'ff7eb6', 'c3a6ff')
BERTH = re.compile(r'^(.*?)([\w.-]+):([\w.-]+)$')
# ssh options that take a value (ssh(1) synopsis).
SSH_VALUE_OPTS = set('BbcDEeFIiJLlmOoPpQRSWw')


def ssh_host(tab_id):
    """The host the tab's active window is ssh'd into, or None."""
    try:
        window = get_boss().tab_for_id(tab_id).active_window
        procs = window.child.foreground_processes
    except Exception:
        return None
    for proc in procs:
        args = proc['cmdline']
        if not args or os.path.basename(args[0]) != 'ssh':
            continue
        rest = iter(args[1:])
        for arg in rest:
            if arg == '--':
                arg = next(rest, None)
            elif arg.startswith('-') and len(arg) > 1:
                # A flag cluster like -vp: a value option's value is the rest of
                # the cluster, or the next argument when nothing is left.
                for i, c in enumerate(arg[1:], 2):
                    if c in SSH_VALUE_OPTS:
                        if i == len(arg):
                            next(rest, None)
                        break
                continue
            return arg.rpartition('@')[2] if arg else None
    return None


def chip(fmt, text):
    """text in black on a colour of its own, then back to the tab's colours."""
    colour = getattr(fmt.bg, f'_{COLOURS[sum(map(ord, text)) % len(COLOURS)]}')
    return f'{colour}{fmt.fg._000000} {text} {fmt.bg.tab}{fmt.fg.tab}'


def draw_title(data):
    title = data['title']
    fmt = data['fmt']
    host = ssh_host(data['tab'].tab_id)
    prefix = ''
    if host:
        # The remote bash may already have put "host: " in front.
        title = title.removeprefix(f'{host}: ')
        prefix = chip(fmt, host) + ' '
    m = BERTH.match(title)
    if not m:
        return prefix + title
    head, pod, session = m.groups()
    return f'{prefix}{head}{pod}:{chip(fmt, session)}'
