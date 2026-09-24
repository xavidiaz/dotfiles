# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Neovim configuration built on [LazyVim](https://github.com/LazyVim/LazyVim), with customizations for the [Omarchy](https://omarchy.org) desktop (live theme switching, transparency, remote-clipboard). Not a Lua project with a build/test cycle — changes are validated by running Neovim.

## Commands

- Format Lua: `stylua .` (config in `stylua.toml` — 2-space indent, 120 columns). CI/pre-commit is not set up; run it manually.
- Sync/update plugins headlessly: `nvim --headless "+Lazy! sync" +qa`
- Check health / plugin state: open `nvim`, then `:Lazy`, `:LazyExtras`, `:checkhealth`
- `lazy-lock.json` is the committed lockfile; `:Lazy update` / `:Lazy restore` manage it.

## Architecture

### Load order (LazyVim conventions)

1. `init.lua` → `lua/config/lazy.lua` bootstraps lazy.nvim and calls `require("lazy").setup`.
2. Spec resolution: `LazyVim/LazyVim` core plugins first, then everything under `lua/plugins/` (auto-imported, order-independent, merged by plugin URL).
3. `lua/config/options.lua` loads before lazy startup; `autocmds.lua` and `keymaps.lua` load on `VeryLazy`.
4. `plugin/after/transparency.lua` runs after all plugins as a standard Neovim runtime plugin.

`lua/config/` overrides LazyVim's defaults. `options.lua` sets `vim.g.autoformat = false` (no format-on-save) and disables `relativenumber`.

### LazyVim extras

Enabled extras live in `lazyvim.json` (`extras` array), not in Lua. Edit that file or use `:LazyExtras` — do not hand-write specs that an extra already provides. Notable: `ai.claudecode`, `dap.core`, `lang.dotnet`, `lang.typescript`, `lang.tailwind`, `editor.neo-tree`, `util.rest`.

### `lua/plugins/` — customization pattern

Each file returns a lazy.nvim spec fragment. To tune a LazyVim plugin, re-declare it by URL with `opts = {...}` (deep-merged) or `opts = function(_, opts)` (for lists). Examples: `snacks-animated-scrolling-off.lua`, `disable-news-alert.lua`. `example.lua` is an inert reference (guarded by `if true then return {} end`) — never enable it.

### `lua/plugins/dotnet.lua` — C# / .NET / Razor

LazyVim's `lang.dotnet` extra (v16, enabled in `lazyvim.json`) sets up **OmniSharp**. This file overrides that to use **Roslyn** instead, which also covers Razor:

- Adds `seblyng/roslyn.nvim` (`ft = { "cs", "razor" }`, `razor` being Neovim's built-in filetype for `.razor`/`.cshtml`). Razor support comes from Roslyn's "co-hosting" feature and supersedes the old `rzls.nvim` — don't install that plugin or the standalone `rzls` server alongside this.
- Server binary is the Mason package `roslyn` (Crashdummyy's registry, added here), found via `$PATH` as `roslyn-language-server`. Mason's default `roslyn-language-server` package (from nuget.org) lags behind and doesn't support Razor until `5.12.0-1.26453.19+`; Crashdummyy's `roslyn` tracks the vscode-csharp version instead. If migrating, `:MasonUninstall roslyn-language-server` once `roslyn` is installed.
- Sets `omnisharp`, `roslyn_ls`, and `fsautocomplete` to `{ enabled = false }` in the lspconfig opts. `enabled = false` (not `nil`) is required — it adds the server to mason-lspconfig's `automatic_enable` exclude list, otherwise mason-lspconfig starts any server whose package is installed on disk. Both `OmniSharp` and `roslyn_ls` packages are installed, so all three previously attached to every `.cs` buffer at once.
- Enables the `html` LSP server (Mason `html-lsp`). Required, not optional: Roslyn forwards Razor's HTML requests to an `html` client on a hidden `*__virtual.html` buffer, and roslyn.nvim blocks in `vim.wait(5000)` waiting for it, so without it every cursor move in a `.razor` buffer freezes Neovim for ~5s.
- Adds `razor` to nvim-treesitter's `ensure_installed` (highlight/injection/fold queries ship with nvim-treesitter already; filetype `razor` maps to the `razor` parser automatically).
- Aliases `razor` to `html` in nvim-ts-autotag's opts; tags don't auto-close/rename in `.razor`/`.cshtml` without it, since the plugin skips filetypes it doesn't know.
- Debugging: `dap.core` extra is enabled (`lazyvim.json`), which — combined with `lang.dotnet` — gives `netcoredbg` + a `dap.configurations.cs` "Launch file" config. This file aliases `dap.configurations.razor = dap.configurations.cs` so `<leader>dc` works with focus in a `.razor` buffer; there's no real Razor-markup debugging, breakpoints belong in `.cs` code-behind or `@code {}` blocks.
- Disables `neotest` / `neotest-vstest` (no test integration yet — enable the `test.core` extra via `:LazyExtras` to add it back).
- Formatting: `csharpier` (Mason, v1.x) via conform, format-on-save, `cs` only. `.cshtml`/`.razor` are **not** formatted — csharpier doesn't handle Razor over stdin, and roslyn.nvim's own LSP-based Razor formatting is broken upstream as of writing (seblyng/roslyn.nvim#386). Linting needs no separate setup: Roslyn's compiler/analyzer diagnostics apply to `razor` buffers the same as `cs` once the LSP client attaches.

Format-on-save is global (`vim.g.autoformat = true` in `options.lua`).

### Omarchy theming (the main custom subsystem)

- `lua/plugins/theme.lua` — the **active** colorscheme. On an Omarchy machine this file is regenerated by Omarchy from `default/themed/neovim.lua.tpl` when the user switches themes; here it is checked in as `flexoki-light`. It declares the theme plugin plus a `LazyVim/LazyVim` `opts.colorscheme` override.
- `lua/plugins/all-themes.lua` — every supported colorscheme plugin, all `lazy = true`, so any theme is instantly available for hot-reload without a network clone. Plugin `name`/`branch` fields must match Omarchy's generated specs exactly (see the in-file comments about `aether` — a mismatch causes a first-launch clone and tokyonight fallback).
- `lua/plugins/omarchy-theme-hotreload.lua` — a local pseudo-plugin (`dir = stdpath("config")`) listening for the `User LazyReload` autocmd. When Omarchy rewrites `theme.lua` and triggers a reload, it clears highlights, unloads the old theme's Lua modules, applies the new colorscheme, and re-sources the transparency file. Changes to `theme.lua`'s shape must stay compatible with the spec-walking logic here.
- `plugin/after/transparency.lua` — strips `bg` from a fixed list of highlight groups after theme load. Add groups here when a plugin's floats/panels don't honor transparency.

### `lua/config/remote_clipboard.lua`

Sets `vim.g.clipboard` only when running under tmux, SSH, or `herdr` (detected via env vars and walking `/proc/<pid>/status` ancestors). Yanks are broadcast via OSC 52 (and `wl-copy --sensitive` when a Wayland display is present); paste prefers the local Wayland clipboard, falling back to an OSC 52 query. `vim.g.omarchy_remote_clipboard_osc52 = false` disables the OSC 52 emission. Called explicitly from `options.lua`.
