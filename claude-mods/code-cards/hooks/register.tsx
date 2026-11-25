import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

// Blocks copied in the last moments, by id: their button reads "Copied".
const copied = atom({ plugin: 'code-cards', key: 'copied' } as const, [], { shape: 'copied-1' })

// Nerd Font icons by language (the terminal font is a Nerd Font).
const ICONS: Record<string, string> = {
  python: '\ue606', py: '\ue606',
  bash: '\ue795', sh: '\ue795', zsh: '\ue795', shell: '\ue795', console: '\ue795',
  javascript: '\ue74e', js: '\ue74e', jsx: '\ue74e',
  typescript: '\ue628', ts: '\ue628', tsx: '\ue628',
  json: '\ue60b', jsonc: '\ue60b',
  rust: '\ue7a8', rs: '\ue7a8', go: '\ue627', lua: '\ue620',
  toml: '\ue6b2', yaml: '\ue6a8', yml: '\ue6a8',
  html: '\ue736', css: '\ue749', markdown: '\ue73e', md: '\ue73e',
  diff: '\uf440', sql: '\ue706', c: '\ue61e', cpp: '\ue61d', java: '\ue738',
  dockerfile: '\uf308', docker: '\uf308', nix: '\uf313',
}
const CODE_ICON = '\uf121'

// A block's id: its language and text, so the same block keeps its id across redraws.
function blockId(lang: string, source: string): string {
  let h = 5381
  for (const ch of lang + '\n' + source) h = ((h << 5) + h + ch.charCodeAt(0)) | 0
  return (h >>> 0).toString(36)
}

// Code blocks in Claude's replies drawn as cards, as Obsidian does: a shaded
// background, the language on top and a copy button. The rest of a reply is
// drawn by Claude Code's own markdown renderer.

type Part =
  | { kind: 'text'; text: string }
  | { kind: 'code'; lang: string; source: string }

const OPEN = /^( {0,3})(`{3,}|~{3,})\s*([^\s`]*)[^`]*$/

function split(markdown: string): Part[] {
  const parts: Part[] = []
  const lines = markdown.split('\n')
  let prose: string[] = []
  const flush = () => {
    const text = prose.join('\n')
    if (text.trim()) parts.push({ kind: 'text', text })
    prose = []
  }
  let i = 0
  while (i < lines.length) {
    const line = lines[i] ?? ''
    const m = OPEN.exec(line)
    if (!m) {
      prose.push(line)
      i += 1
      continue
    }
    const indent = m[1] ?? '', fence = m[2] ?? '```', lang = m[3] ?? ''
    const close = new RegExp(`^ {0,3}${fence[0] === '`' ? '`' : '~'}{${fence.length},}\\s*$`)
    const body: string[] = []
    let j = i + 1
    // An unclosed fence (a reply still streaming) runs to the end.
    while (j < lines.length && !close.test(lines[j] ?? '')) {
      const row = lines[j] ?? ''
      body.push(indent ? row.replace(new RegExp(`^ {0,${indent.length}}`), '') : row)
      j += 1
    }
    flush()
    parts.push({ kind: 'code', lang, source: body.join('\n') })
    i = j + 1
  }
  flush()
  return parts
}

// The card's shade: the terminal background nudged toward the text, read from
// Omarchy's current kitty theme so it follows theme changes. Where that file is
// missing (a container, an ssh host) the card gets a border instead.
async function shade($: EngineInterface): Promise<string | null> {
  try {
    const home = await $.env.get('HOME')
    const conf = await $.fs.read(`${home}/.local/state/omarchy/current/theme/kitty.conf`)
    const m = /^background\s+#?([0-9a-f]{6})\s*$/im.exec(conf)
    const hex = m?.[1]
    if (!hex) return null
    const [r = 0, g = 0, b = 0] = [0, 2, 4].map(k => parseInt(hex.slice(k, k + 2), 16))
    const isLight = 0.299 * r + 0.587 * g + 0.114 * b > 128
    const nudge = (c: number) => Math.max(0, Math.min(255, isLight ? c - 16 : c + 20))
    return '#' + [r, g, b].map(c => nudge(c).toString(16).padStart(2, '0')).join('')
  } catch {
    return null
  }
}

export const register: Register = on => {
  let cached: { at: number; colour: string | null } | null = null

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.props.isSummary || !/^ {0,3}(```|~~~)/m.test(e.props.text)) {
      return next(e)
    }
    const now = await $.clock.now()
    if (!cached || now - cached.at > 10_000) {
      cached = { at: now, colour: await shade($) }
    }
    const bg = cached.colour
    const done = new Set(await read($, copied))
    const { Box, Text, Button, Code, Markdown } = $.ui.resolve(e)

    let n = 0
    // Claude Code's own frame around a reply block: a blank row above, then the
    // "●" bullet (first block of a reply) or its 2-column indent.
    return (
      <Box flexDirection="row" marginTop={1}>
        <Box width={2} flexShrink={0}>
          <Text>{e.props.isFirstOfReply ? '●' : ' '}</Text>
        </Box>
        <Box flexDirection="column" gap={1} flexGrow={1}>
        {split(e.props.text).map((part, k) => {
          if (part.kind === 'text') {
            return <Markdown key={`text-${k}`} text={part.text} />
          }
          n += 1
          const source = part.source
          const lang = part.lang.toLowerCase()
          const id = blockId(lang, source)
          const isCopied = done.has(id)
          const card = bg ? { backgroundColor: bg } : { borderStyle: 'round', borderColor: 'subtle' }
          return (
            <Box key={`card-${k}`} flexDirection="column" paddingX={2} paddingBottom={bg ? 1 : 0} {...card}>
              <Box flexDirection="row" justifyContent="space-between">
                <Text dimColor>{`${ICONS[lang] ?? CODE_ICON}  ${part.lang || 'code'}`}</Text>
                <Button
                  key={`copy-${n}`}
                  label={isCopied ? '\uf00c Copied' : '\uf4bb Copy'}
                  plain
                  dimColor={!isCopied}
                  {...(isCopied ? { color: 'success' } : {})}
                  onPress={async press => {
                    const result = await $.ui.copy({ text: source, surface: press.surface })
                    if (!result.isCopied) {
                      $.ui.toast(`Not copied: ${result.reason}`)
                      return
                    }
                    await update($, copied, ids => [...ids.filter(x => x !== id), id].slice(-20))
                    $.clock.after(2000, () => {
                      void update($, copied, ids => ids.filter(x => x !== id))
                    })
                  }}
                />
              </Box>
              <Code source={source} language={part.lang || undefined} />
            </Box>
          )
        })}
        </Box>
      </Box>
    )
  })
}
