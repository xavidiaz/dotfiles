# Copy a code block shown in the window, picked with the keyboard (kitty_mod+y).
#
# Custom processing for kitty's hints kitten (kitten hints --customize-processing).
# mark() receives the window's screen as plain text: each row padded with NUL to
# the window width, rows separated by \n, or by \r where kitty soft-wrapped the row.
# It marks each code block as one multi-line hint; handle_result() copies the
# cleaned text of the chosen block (stored in the mark's groupdict) to the clipboard.
#
# Two kinds of block are found:
# - Fenced ``` / ~~~ blocks (pi, cat'ed markdown). The renderer's indent, box borders
#   and line-number gutters are removed, and lines the renderer wrapped are rejoined.
# - Claude Code answers, which show code without fences. The block boundaries are
#   guessed from what is on screen: inside a "● " message, blank-line-separated chunks
#   that carry syntax-highlight colours (basic SGR 30-37/90-97), or that do not read
#   like prose. The colours come from `kitten @ get-text --ansi` on the window under
#   the overlay, since mark() only gets plain text; without them the prose test
#   alone decides. Claude Code's own /copy picks its blocks exactly.

import os
import re
import shutil
import subprocess

FENCE = re.compile(r'(```+|~~~+)\s*([\w.+#-]*)\s*$')
BOX = '│┃║▏▕╎╏┆┇┊┋'
GUTTER = re.compile(r'^\s*\d+\s*[│┃|]\s?')
SGR = re.compile(r'\x1b\[([0-9;:]*)m')
ANY_ESC = re.compile(r'\x1b\[[0-9;:?]*[A-Za-z]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)')
LIST_ITEM = re.compile(r'^(?:[-*•+]|\d+[.)])\s+\S')
SENTENCE_END = re.compile(r'[.!?:;…]["\'`)\]*_]*$')
# The code-cards mod's header row: "<icon> <lang> … <icon> Copy" (or "Copied")
CARD_HEADER = re.compile(r'^\s*(?:\S\s+)?\S*\s+(?:⧉ copy|\S Copy|\S Copied)\s*$')
UI_LEAD = ('⎿', '❯', '✻', '✳', '⏺', '⏵', '▔', '─', '╭', '╰', '│')


class Row:
    __slots__ = ('start', 'cells', 'raw', 'text', 'soft', 'hl', 'bold', 'ui', 'tail', 'card')

    def __init__(self, start: int, raw: str, soft: bool) -> None:
        self.start = start              # offset of the row in the hints text
        self.cells = len(raw)           # padded to the window width
        self.raw = raw.rstrip('\0')     # cells written by the program
        self.text = self.raw.replace('\0', ' ')
        self.soft = soft                # kitty wrapped this row into the next one
        self.hl = False                 # has syntax-highlight colours
        self.bold = False               # all its text is bold (a heading)
        self.ui = False                 # starts in grey: Claude Code's own UI text
        self.tail = 0                   # grey UI text at its end (" · summary")
        self.card = False               # drawn on a background colour (a code card)

    @property
    def end(self) -> int:
        return self.start + len(self.raw)

    @property
    def blank(self) -> bool:
        return not self.text.strip()

    @property
    def indent(self) -> int:
        return len(self.text) - len(self.text.lstrip(' '))


def split_rows(text: str) -> list[Row]:
    rows, pos = [], 0
    for m in re.finditer(r'[^\r\n]*([\r\n]|$)', text):
        if m.start() == len(text) and rows:
            break
        body = m.group(0)[:-1] if m.group(1) else m.group(0)
        rows.append(Row(pos, body, m.group(1) == '\r'))
        pos = m.end()
    return rows


# Colours ###########################################################################

def target_match(kitten: str) -> str:
    # While mark() runs the overlay is not attached yet (state:overlay_parent matches
    # nothing): the target is still the active window of the overlay's tab.
    import json
    me = int(os.environ.get('KITTY_WINDOW_ID', '0') or 0)
    try:
        tree = json.loads(subprocess.run([kitten, '@', 'ls'], capture_output=True, timeout=3, check=True).stdout)
    except Exception:
        return 'state:overlay_parent'
    for osw in tree:
        for tab in osw['tabs']:
            ids = [w['id'] for w in tab['windows']]
            if me in ids:
                for w in tab['windows']:
                    if w['is_active'] and w['id'] != me:
                        return f'id:{w["id"]}'
    return 'state:overlay_parent'


def screen_ansi() -> list[str] | None:
    # The window under the hints overlay, with SGR codes and wrap markers.
    kitten = shutil.which('kitten') or os.path.join(os.environ.get('KITTY_INSTALLATION_DIR', '/usr/lib/kitty'), 'kitten')
    try:
        out = subprocess.run(
            [kitten, '@', 'get-text', '--match', target_match(kitten), '--extent', 'screen', '--ansi', '--add-wrap-markers'],
            capture_output=True, timeout=3, check=True).stdout.decode('utf-8', 'replace')
    except Exception:
        return None
    return re.split(r'\r\n|\r|\n', out)


def row_style(ansi_row: str) -> tuple[bool, bool, bool, int, bool]:
    """(has a basic-palette foreground colour, every visible character is bold,
    the first visible text is grey truecolor, length of the grey text at its end).
    A leading "●" bullet is ignored."""
    hl, bold, grey, bg, on_bg = False, False, False, False, False
    segs: list[tuple[str, bool, bool]] = []     # (text, bold, grey)
    pos = 0
    for m in list(SGR.finditer(ansi_row)) + [None]:
        seg = ANY_ESC.sub('', ansi_row[pos:m.start() if m else len(ansi_row)])
        if seg:
            segs.append((seg, bold, grey))
            on_bg = on_bg or (bg and bool(seg.strip()))
        if m is None:
            break
        pos = m.end()
        params = m.group(1)
        if ':' in params:       # 38:2:r:g:b truecolor (Claude Code's inline code, UI)
            f = params.split(':')
            if f[0] == '48':
                bg = True
            if f[0] == '38':
                rgb = [x for x in f[2:] if x][-3:]
                # mid grey only: black/white are the theme's normal text
                grey = f[1] == '2' and len(rgb) == 3 and len(set(rgb)) == 1 and 40 <= int(rgb[0] or 0) <= 215
            continue
        parts = [x for x in params.split(';') if x] or ['0']
        i = 0
        while i < len(parts):
            p = parts[i]
            if p == '48':
                bg = True
            if p in ('38', '48', '58'):      # extended colour in ; form, skip its args
                i += 3 if i + 1 < len(parts) and parts[i + 1] == '5' else 5
                continue
            n = int(p) if p.isdigit() else -1
            if 30 <= n <= 37 or 90 <= n <= 97:
                hl = True
            if n == 1:
                bold = True
            elif n in (0, 22):
                bold = False
            if n in (0, 39) or 30 <= n <= 37 or 90 <= n <= 97:
                grey = False
            if 40 <= n <= 47 or 100 <= n <= 107:
                bg = True
            elif n in (0, 49):
                bg = False
            i += 1
    if segs and segs[0][0].lstrip()[:1] in '●⏺':
        t, b, g = segs[0]
        rest = t.lstrip()[1:]
        segs[0] = (rest, b, g)
    visible = [(t, b, g) for t, b, g in segs if t.strip()]
    all_bold = bool(visible) and all(b for _, b, _ in visible)
    ui = bool(visible) and visible[0][2]
    tail = 0
    for t, _, g in reversed(segs):
        if not t.strip():
            tail += len(t)
            continue
        if not g:
            break
        tail += len(t)
    return hl, all_bold, ui, tail, on_bg


def apply_colours(rows: list[Row]) -> None:
    ansi = screen_ansi()
    if not ansi:
        return
    if len(ansi) > len(rows):
        ansi = ansi[:len(rows)]
    for row, a in zip(rows, ansi):
        # The screen may have changed since the hints snapshot: only trust rows
        # whose text still matches.
        if ANY_ESC.sub('', a).rstrip() == row.text.rstrip():
            row.hl, row.bold, row.ui, row.tail, row.card = row_style(a)


# Cleaning ##########################################################################

def strip_borders(lines: list[str]) -> list[str]:
    out = []
    for ln in lines:
        s = ln.rstrip()
        if s and s[-1] in BOX:
            s = s[:-1].rstrip()
        out.append(s)
    # A left border shared by every line ("│ code")
    nonblank = [x for x in out if x.strip()]
    if nonblank and all(x.lstrip()[:1] in BOX for x in nonblank):
        out = [re.sub(r'^\s*[' + BOX + r'] ?', '', x) for x in out]
    nonblank = [x for x in out if x.strip()]
    if nonblank and all(GUTTER.match(x) for x in nonblank):
        out = [GUTTER.sub('', x) for x in out]
    return out


def dedent(lines: list[str]) -> list[str]:
    widths = [len(x) - len(x.lstrip(' ')) for x in lines if x.strip()]
    cut = min(widths) if widths else 0
    return [x[cut:] if x.strip() else '' for x in lines]


def finish(lines: list[str]) -> str:
    lines = dedent(strip_borders(lines))
    while lines and not lines[-1].strip():
        lines.pop()
    while lines and not lines[0].strip():
        lines.pop(0)
    return '\n'.join(x.rstrip() for x in lines)


def logical(rows: list[Row]) -> list[list[Row]]:
    """Group rows that kitty soft-wrapped into one logical line."""
    groups, cur = [], []
    for r in rows:
        cur.append(r)
        if not r.soft:
            groups.append(cur)
            cur = []
    if cur:
        groups.append(cur)
    return groups


def first_word(s: str) -> str:
    return s.strip().split(' ', 1)[0] if s.strip() else ''


# Fenced blocks #####################################################################

def fenced_blocks(rows: list[Row]) -> tuple[list[tuple[int, int, str]], set[int]]:
    lines = logical(rows)
    texts = [strip_borders([''.join(r.raw.replace('\0', ' ') for r in g)])[0] for g in lines]
    fences = []
    for i, t in enumerate(texts):
        m = FENCE.match(t.lstrip())
        if m:
            fences.append((i, len(t) - len(t.lstrip()), m.group(1), m.group(2)))
    blocks, used = [], set()
    k = 0
    while k < len(fences):
        i, col, tick, lang = fences[k]
        if k + 1 < len(fences) and not fences[k + 1][3] and fences[k + 1][2][0] == tick[0]:
            j = fences[k + 1][0]
            k += 2
        elif k == 0 and not lang and (k + 1 == len(fences) or fences[k + 1][3]):
            # A closing fence whose opener scrolled off the top
            j, i = i, -1
            k += 1
        else:
            # An opener whose closer is off screen (or missing): up to the next fence
            j = fences[k + 1][0] if k + 1 < len(fences) else len(lines)
            k += 1
        body = list(range(i + 1, j))
        if not any(texts[x].strip() for x in body):
            continue
        used.update(range(max(i, 0), min(j + 1, len(lines))))
        content = [texts[x] for x in body]
        # Renderers like pi indent the content past the fence and wrap long lines
        # themselves, continuing at the fence column: rejoin those with a space.
        # (col is the opening fence's, or the closing one's if the opener scrolled off.)
        indents = [len(c) - len(c.lstrip()) for c in content if c.strip()]
        if indents:
            base = max(set(indents), key=indents.count)    # the usual content indent
            if base >= col + 2:
                # The renderer's own right edge (a pane or box can be narrower than
                # the window): the widest row of the block, border included.
                edge = max(len(r.text.rstrip()) for x in range(max(i, 0), min(j + 1, len(lines))) for r in lines[x])
                joined: list[str] = []
                for c in content:
                    ind = len(c) - len(c.lstrip())
                    if c.strip() and joined and ind <= col and len(joined[-1]) >= max(40, 0.7 * edge):
                        joined[-1] = joined[-1].rstrip() + ' ' + c.strip()
                    else:
                        joined.append(c)
                content = joined
        first, last = lines[body[0]][0], lines[body[-1]][-1]
        start = first.start + first.indent
        blocks.append((start, max(last.end, start + 1), finish(content)))
    return blocks, used


# Claude Code answers ###############################################################

def is_prose(chunk: list[Row], lines: list[str]) -> bool:
    if any(r.hl or r.card for r in chunk):
        return False                    # syntax-highlighted, or on a code card
    if all(r.bold for r in chunk if not r.blank):
        return True                     # heading or bold sentence
    first = lines[0].strip()
    items = [x for x in lines if x.strip() and len(x) - len(x.lstrip()) <= 2]
    if items and all(LIST_ITEM.match(x.strip()) for x in items):
        return True                     # list (continuation rows are indented more)
    words = ' '.join(lines).split()
    code_chars = sum(' '.join(lines).count(ch) for ch in '{}()[];=<>$\\|`')
    last = lines[-1][:len(lines[-1]) - chunk[-1].tail].strip() if chunk[-1].tail else lines[-1].strip()
    if SENTENCE_END.search(last) and len(words) >= 6 * len(lines) and code_chars <= len(words) // 5:
        return True                     # wrapped paragraph (its start may be off screen)
    body = LIST_ITEM.sub(lambda m: m.group(0)[-1], first)
    return bool(body[:1].isupper() or body[:1].isdigit()) and bool(SENTENCE_END.search(last)) \
        and len(' '.join(lines).split()) >= 4


def claude_blocks(rows: list[Row], width: int, used_rows: set[int]) -> list[tuple[int, int, str]]:
    # Messages: a "● " row and the indented rows under it. Tool calls ("● Bash(…)"
    # followed by "⎿") are skipped.
    regions: list[list[int]] = []
    heads: set[int] = set()
    # A message whose "● " row scrolled off the top: rows at the message indent
    top = []
    for i, r in enumerate(rows):
        if not (r.blank or r.text.startswith('  ')) or r.text.strip().startswith(UI_LEAD):
            break
        top.append(i)
    nonblank = [rows[i] for i in top if not rows[i].blank]
    cur = top if nonblank and min(r.indent for r in nonblank) == 2 else None
    if cur:
        regions.append(cur)
    for i, r in enumerate(rows):
        if cur is top and i in top:
            continue
        t = r.text
        if t.startswith('● ') or t.startswith('⏺ '):
            nxt = next((rows[j].text.strip() for j in range(i + 1, len(rows)) if not rows[j].blank), '')
            tool = re.match(r'^[●⏺] [\w ]+\(', t) or nxt.startswith('⎿')
            cur = None if tool else [i]
            if cur is not None:
                regions.append(cur)
                heads.add(i)
        elif cur is not None and (r.blank or t.startswith('  ')) and not t.strip().startswith(UI_LEAD):
            cur.append(i)
        else:
            cur = None

    blocks = []
    for reg in regions:
        # Chunks between blank rows
        chunks: list[list[int]] = [[]]
        for i in reg:
            ui = rows[i].ui and not rows[i].card and i not in heads
            if rows[i].blank or ui or i in used_rows or CARD_HEADER.match(rows[i].text):
                if chunks[-1]:
                    chunks.append([])
            else:
                chunks[-1].append(i)
        chunks = [c for c in chunks if c]
        code = []
        for c in chunks:
            rws = [rows[i] for i in c]
            lines = rejoin(rws, width)
            if c[0] in heads:           # the "● " bullet sits in the message indent
                lines[0] = '  ' + lines[0][2:]
            if not is_prose(rws, lines):
                code.append((c, lines, any(r.hl or r.card for r in rws)))
        # Highlighted chunks one blank row apart are one block (blank line in code)
        merged = []
        for c, lines, hl in code:
            if merged and hl and merged[-1][2] and c[0] - merged[-1][0][-1] == 2:
                pc, pl, _ = merged[-1]
                merged[-1] = (pc + c, pl + [''] + lines, True)
            else:
                merged.append((c, lines, hl))
        for c, lines, _ in merged:
            first, last = rows[c[0]], rows[c[-1]]
            start = first.start + first.indent
            blocks.append((start, max(last.end, start + 1), finish(lines)))
    return blocks


def rejoin(rws: list[Row], width: int) -> list[str]:
    """Claude Code wraps long lines itself, continuing at the message indent: join a
    row into the previous one when the previous one could not have held its first word."""
    out: list[str] = []
    prev = None
    for r in rws:
        t = r.raw.replace('\0', ' ')
        if prev is not None and (prev.soft or (r.indent <= 2 and len(prev.raw) + len(first_word(t)) >= width)):
            if prev.soft:
                out[-1] += t
            else:
                # A word wrap drops the space unless it fell in the last column; a row
                # filled to the edge without one is a word broken in the middle.
                sep = '' if prev.raw.endswith(' ') or len(prev.raw) >= width else ' '
                out[-1] += sep + t.lstrip()
        else:
            out.append(t)
        prev = r
    return out


# Hints API #########################################################################

def mark(text, args, Mark, extra_cli_args, *a):
    rows = split_rows(text)
    width = max((r.cells for r in rows), default=80)
    fenced, used_lines = fenced_blocks(rows)
    # Map logical-line indices back to rows for the Claude pass
    used_rows: set[int] = set()
    idx = 0
    for li, g in enumerate(logical(rows)):
        if li in used_lines:
            used_rows.update(range(idx, idx + len(g)))
        idx += len(g)
    blocks = fenced
    if any(r.text.startswith(('● ', '⏺ ', '❯')) or re.match(r'^✻ \w+ for \d', r.text) for r in rows):
        apply_colours(rows)
        blocks = fenced + claude_blocks(rows, width, used_rows)
    blocks.sort()
    for idx, (start, end, code) in enumerate(b for b in blocks if b[2]):
        yield Mark(idx, start, end, code.split('\n', 1)[0], {'code': code})


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    from kitty.clipboard import set_clipboard_string
    codes = [g['code'] for m, g in zip(data['match'], data['groupdicts']) if m and g and g.get('code')]
    if codes:
        set_clipboard_string('\n\n'.join(codes))
