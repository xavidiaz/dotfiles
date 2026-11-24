# Tab title for kitty.conf's tab_title_template "{custom}": a berth session title
# ("ai901:claude", or "nvim · ai901:claude" while a command runs) gets its session
# name as a chip (black on a background colour of its own), so windows of one
# pod tell apart.
#
# A tab running ssh gets the host in front ("nixpi: ✳ Claude Code"), as ~/.bashrc
# does over SSH: full-screen programs like Claude Code set a title of their own.
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


def draw_title(data):
    title = data['title']
    host = ssh_host(data['tab'].tab_id)
    if host and not title.startswith(f'{host}:'):
        title = f'{host}: {title}'
    m = BERTH.match(title)
    if not m:
        return title
    head, pod, session = m.groups()
    fmt = data['fmt']
    colour = getattr(fmt.bg, f'_{COLOURS[sum(map(ord, session)) % len(COLOURS)]}')
    return f'{head}{pod}:{colour}{fmt.fg._000000} {session} {fmt.bg.tab}{fmt.fg.tab}'
