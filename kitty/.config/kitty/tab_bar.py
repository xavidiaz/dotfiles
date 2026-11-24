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


def ssh_destination(window):
    """For a window running ssh in the foreground: the ssh command up to and
    including its destination (no remote command), and the destination's host.
    None otherwise. paste_image.py uses it too."""
    try:
        procs = window.child.foreground_processes
    except Exception:
        return None
    for proc in procs:
        args = proc['cmdline']
        if not args or os.path.basename(args[0]) != 'ssh':
            continue
        i = 1
        while i < len(args):
            arg = args[i]
            if arg == '--':
                i += 1
                break
            if not arg.startswith('-') or len(arg) == 1:
                break
            # A flag cluster like -vp: a value option's value is the rest of the
            # cluster, or the next argument when nothing is left.
            for j, c in enumerate(arg[1:], 2):
                if c in SSH_VALUE_OPTS:
                    if j == len(arg):
                        i += 1
                    break
            i += 1
        if i < len(args):
            return args[:i + 1], args[i].rpartition('@')[2]
    return None


def ssh_host(tab_id):
    """The host the tab's active window is ssh'd into, or None."""
    try:
        window = get_boss().tab_for_id(tab_id).active_window
    except Exception:
        return None
    dest = ssh_destination(window)
    return dest[1] if dest else None


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
