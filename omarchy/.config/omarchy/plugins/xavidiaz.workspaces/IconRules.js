.pragma library

// What a Hyprland window is, as a Nerd Font glyph plus a short name, looked
// up in three ordered tables where the first match wins:
//
//   apps            matched against the window class only. Titles say what
//                   is *in* a window, so a terminal titled "Vi mode in Brave"
//                   or a page titled "Claude Code" must not decide the app.
//   sites           for browser windows (and their web apps, whose class
//                   carries the domain): matched against title and class.
//   terminalTitles  for terminal windows: the program running in them.
//
// Find a window's class and title with:
//   hyprctl clients -j | jq -r '.[] | "\(.class)\t\(.title)"'
//
// Icon map adapted from the `saif.workspaces` plugin by Saif Omar (MIT), via
// TheTrueFerret's Decent Workspaces (MIT).

var BROWSER = "browser"
var TERMINAL = "terminal"

var apps = [
  // Browsers: Chromium-based web apps get classes like brave-claude.ai__-Default,
  // which these catch too; `sites` then names them by their domain.
  { pattern: "^(brave|brave-browser)", icon: "\u{EDDE}", name: "Brave", kind: BROWSER },
  { pattern: "firefox|librewolf|floorp|mercury-browser|cachy-browser|waterfox|^zen", icon: "\u{F0239}", name: "Firefox", kind: BROWSER },
  { pattern: "microsoft-edge", icon: "\u{F01E9}", name: "Edge", kind: BROWSER },
  { pattern: "tor browser", icon: "\u{F0582}", name: "Tor", kind: BROWSER },
  { pattern: "^(chromium|thorium|chrome|google-chrome)", icon: "\u{F02AF}", name: "Chrome", kind: BROWSER },

  // Terminals
  { pattern: "^kitty$", icon: "\u{F018D}", name: "Terminal", kind: TERMINAL },
  { pattern: "alacritty|^foot|konsole|wezterm|ghostty", icon: "\u{F018D}", name: "Terminal", kind: TERMINAL },

  // Notes, editors & docs
  { pattern: "obsidian", icon: "\u{F082E}", name: "Obsidian" },
  { pattern: "ai.opencode.desktop|opencode", icon: "\u{F140}", name: "OpenCode" },
  { pattern: "^(code|code-oss|code-url-handler|vscodium|codium)", icon: "\u{F0A1E}", name: "VS Code" },
  { pattern: "dev.zed.zed", icon: "\u{F14DE}", name: "Zed" },
  { pattern: "^subl", icon: "\u{F0173}", name: "Sublime" },
  { pattern: "jetbrains-", icon: "\u{F0169}", name: "JetBrains" },
  { pattern: "android-studio", icon: "\u{F0034}", name: "Android Studio" },
  { pattern: "^(nvim|neovide)", icon: "\u{E62B}", name: "Neovim" },
  { pattern: "mousepad|org.gnome.texteditor|ghostwriter", icon: "\u{F0DC8}", name: "Editor" },
  { pattern: "xournalpp", icon: "\u{F0DC8}", name: "Xournal++" },
  { pattern: "libreoffice-writer", icon: "\u{F0219}", name: "Writer" },
  { pattern: "libreoffice-calc", icon: "\u{F09F7}", name: "Calc" },
  { pattern: "libreoffice", icon: "\u{F03C6}", name: "LibreOffice" },
  { pattern: "zathura|evince|papers|okular", icon: "\u{F0226}", name: "PDF" },
  { pattern: "keepassxc", icon: "\u{F0306}", name: "KeePassXC" },

  // Chat & mail
  { pattern: "signal", icon: "\u{F0361}", name: "Signal" },
  { pattern: "telegram|tdesktop", icon: "\u{F0626}", name: "Telegram" },
  { pattern: "discord|webcord|vesktop", icon: "\u{F066F}", name: "Discord" },
  { pattern: "slack", icon: "\u{F04B1}", name: "Slack" },
  { pattern: "thunderbird|betterbird|claws-mail|evolution|geary", icon: "\u{F01EE}", name: "Mail" },
  { pattern: "zapzap|whatsapp", icon: "\u{F05A3}", name: "WhatsApp" },
  { pattern: "^zoom", icon: "\u{F0567}", name: "Zoom" },

  // Media
  { pattern: "^mpv$|celluloid", icon: "\u{F0439}", name: "Video" },
  { pattern: "^vlc$", icon: "\u{F057C}", name: "VLC" },
  { pattern: "spotify", icon: "\u{F04C7}", name: "Spotify" },
  { pattern: "jellyfin", icon: "\u{F0F01}", name: "Jellyfin" },
  { pattern: "elisa|lollypop|org.gnome.music|rhythmbox|cider", icon: "\u{F075A}", name: "Music" },
  { pattern: "^obs$|com.obsproject.studio", icon: "\u{F040D}", name: "OBS" },
  { pattern: "gimp", icon: "\u{F03D8}", name: "GIMP" },
  { pattern: "imv|org.gnome.loupe", icon: "\u{F02E9}", name: "Image" },

  // System & tools
  { pattern: "nautilus|thunar|nemo", icon: "\u{F0770}", name: "Files" },
  { pattern: "pavucontrol|helvum|wiremix", icon: "\u{F04C3}", name: "Audio" },
  { pattern: "virt-manager|virtualbox", icon: "\u{F037A}", name: "VM" },
  { pattern: "remmina", icon: "\u{F08B9}", name: "Remote" },
  { pattern: "transmission|fragments", icon: "\u{F0120}", name: "Torrent" },
  { pattern: "gparted", icon: "\u{F02CA}", name: "GParted" },
  { pattern: "^steam", icon: "\u{F04D3}", name: "Steam" },
  { pattern: "prusaslicer|ultimaker-cura|orcaslicer", icon: "\u{F042B}", name: "Slicer" },
  { pattern: "nwg-look", icon: "\u{F0521}", name: "Appearance" },
  { pattern: "polkit", icon: "\u{F0483}", name: "Auth" }
]

var sites = [
  { pattern: "claude", icon: "\u{F0B79}", name: "Claude" },
  { pattern: "chatgpt", icon: "\u{F0B79}", name: "ChatGPT" },
  { pattern: "deepseek|qwen|gemini", icon: "\u{F0B79}", name: "AI chat" },
  { pattern: "github", icon: "\u{F02A4}", name: "GitHub" },
  { pattern: "youtube", icon: "\u{F05C3}", name: "YouTube" },
  { pattern: "gmail|proton.*mail|mail\\.proton", icon: "\u{F02AB}", name: "Mail" },
  { pattern: "whatsapp", icon: "\u{F05A3}", name: "WhatsApp" },
  { pattern: "figma", icon: "\u{F08D9}", name: "Figma" },
  { pattern: "jira", icon: "\u{F0303}", name: "Jira" },
  { pattern: "reddit", icon: "\u{F044D}", name: "Reddit" },
  { pattern: "amazon", icon: "\u{F0E29}", name: "Amazon" },
  { pattern: "facebook|messenger", icon: "\u{F020E}", name: "Facebook" },
  { pattern: "x\\.com|twitter", icon: "\u{F0544}", name: "X" },
  { pattern: "monkeytype", icon: "\u{F030C}", name: "Monkeytype" },
  { pattern: "picture-in-picture", icon: "\u{F0439}", name: "Video" }
]

var terminalTitles = [
  // Claude Code puts a status glyph (✳ idle, a spinner while working) in front
  // of its title.
  { pattern: "^[✳✶✻✽✢·◐-◓⠀-⣿]|claude", icon: "\u{F0B79}", name: "Claude Code" },
  { pattern: "\\bn?vim\\b", icon: "\u{E62B}", name: "Neovim" },
  { pattern: "lazygit", icon: "\u{F02A2}", name: "Lazygit" },
  { pattern: "\\b(btop|htop|top)\\b", icon: "\u{F029A}", name: "Monitor" },
  { pattern: "\\byazi\\b", icon: "\u{F024B}", name: "Yazi" },
  { pattern: "^ssh\\b", icon: "\u{F08B9}", name: "SSH" }
]

var fallback = "\u{F0614}"

// Rules are compiled once per QML engine rather than per render. `.pragma
// library` means one shared copy across every bar instance.
function compile(list) {
  var out = []
  for (var i = 0; i < list.length; i++)
    out.push({ re: new RegExp(list[i].pattern, "i"), icon: list[i].icon, name: list[i].name, kind: list[i].kind || "" })
  return out
}

var compiled = null

function tables() {
  if (!compiled) compiled = { apps: compile(apps), sites: compile(sites), terminalTitles: compile(terminalTitles) }
  return compiled
}

function first(list, text) {
  for (var i = 0; i < list.length; i++)
    if (list[i].re.test(text)) return list[i]
  return null
}

// Unknown classes still get a readable name: md.obsidian.Obsidian -> Obsidian.
function nameFromClass(cls) {
  var name = String(cls || "").split(".").pop().replace(/[-_]+/g, " ").replace(/^\s+|\s+$/g, "")
  if (name === "") return "Window"
  return name.charAt(0).toUpperCase() + name.slice(1)
}

// Browser titles churn constantly, so the cache is capped and dropped wholesale
// once it grows past the limit instead of tracking per-entry age.
var cache = {}
var cacheCount = 0
var cacheLimit = 500

// Returns { icon, name } for a window.
function resolve(cls, title) {
  var key = cls + "\u0001" + title
  var hit = cache[key]
  if (hit !== undefined) return hit

  var t = tables()
  var app = first(t.apps, cls)
  var result
  if (!app) {
    result = { icon: fallback, name: nameFromClass(cls) }
  } else {
    var inner = null
    if (app.kind === BROWSER) inner = first(t.sites, title + " " + cls)
    else if (app.kind === TERMINAL) inner = first(t.terminalTitles, title)
    result = inner ? { icon: inner.icon, name: inner.name } : { icon: app.icon, name: app.name }
  }

  if (cacheCount >= cacheLimit) {
    cache = {}
    cacheCount = 0
  }
  cache[key] = result
  cacheCount++
  return result
}
