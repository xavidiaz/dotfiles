# Tab title for kitty.conf's tab_title_template "{custom}": a berth session title
# ("ai901:claude", or "nvim · ai901:claude" while a command runs) gets its session
# name as a chip (black on a background colour of its own), so windows of one
# pod tell apart.
import re

# Fixed colours, not the theme palette: some themes (e.g. the current light one)
# are all blues and purples, so a palette colour can match the tab background.
# Light enough for black text, none of them blue.
COLOURS = ('ffb454', '7fd962', 'ffd866', 'ff7eb6', 'c3a6ff')
BERTH = re.compile(r'^(.*?)([\w.-]+):([\w.-]+)$')


def draw_title(data):
    title = data['title']
    m = BERTH.match(title)
    if not m:
        return title
    head, pod, session = m.groups()
    fmt = data['fmt']
    colour = getattr(fmt.bg, f'_{COLOURS[sum(map(ord, session)) % len(COLOURS)]}')
    return f'{head}{pod}:{colour}{fmt.fg._000000} {session} {fmt.bg.tab}{fmt.fg.tab}'
