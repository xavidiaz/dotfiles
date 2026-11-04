# Tab title for kitty.conf's tab_title_template "{custom}": a berth session title
# ("ai901:claude", or "nvim · ai901:claude" while a command runs) gets its session
# name as a chip (black on a background colour of its own), so windows of one
# pod tell apart.
import re

# Theme palette (Omarchy sets color0-15); no blue, it's the active tab's background.
COLOURS = (1, 2, 3, 5, 6)
BERTH = re.compile(r'^(.*?)([\w.-]+):([\w.-]+)$')


def draw_title(data):
    title = data['title']
    m = BERTH.match(title)
    if not m:
        return title
    head, pod, session = m.groups()
    fmt = data['fmt']
    colour = getattr(fmt.bg, f'color{COLOURS[sum(map(ord, session)) % len(COLOURS)]}')
    return f'{head}{pod}:{colour}{fmt.fg._000000} {session} {fmt.bg.tab}{fmt.fg.tab}'
