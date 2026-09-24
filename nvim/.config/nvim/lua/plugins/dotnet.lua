-- .NET / C# / Razor setup, layered on LazyVim's `lang.dotnet` extra (enabled
-- in lazyvim.json). That extra wires up OmniSharp; here we disable it and use
-- the Roslyn language server (via roslyn.nvim) instead, which also drives
-- Razor (.razor/.cshtml, filetype `razor`) support via Roslyn's "co-hosting"
-- feature. This supersedes the old rzls.nvim plugin — do not install it or
-- the standalone `rzls` server alongside this.
return {
  -- Roslyn LSP, now attaching to `cs` AND `razor` buffers (`razor` is
  -- Neovim's built-in filetype for both .razor and .cshtml). The `ft` key
  -- controls when lazy.nvim loads this plugin at all, and loading it is what
  -- runs `vim.lsp.enable("roslyn")` — leaving out "razor" here means the
  -- server never starts for a session that opens a .razor file before any
  -- .cs file.
  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor" },
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
    -- roslyn.nvim starts the server with `--daemon-mode` (one process shared
    -- across Neovim instances). In that mode the server never sends
    -- `razor/updateHtml` to us, so no `__virtual.html` buffer is created,
    -- every HTML-forwarded request comes back empty, and completion in
    -- .razor markup returns nothing at all. Run a dedicated server instead.
    -- Has to be `init`, not `config`: the plugin's own plugin/roslyn.lua
    -- enables (and starts) the client while lazy.nvim is still loading it.
    init = function()
      vim.lsp.config("roslyn", {
        cmd = { vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", "roslyn-language-server"), "--stdio" },
      })
    end,
  },

  -- Razor support needs roslyn-language-server >= 5.12.0-1.26453.19,
  -- but Mason's default nuget.org source lags behind (5.11.x as of writing).
  -- Add Crashdummyy's registry and install its `roslyn` package instead: it
  -- tracks the same version vscode-csharp ships, and still exposes the
  -- binary as `roslyn-language-server` on $PATH, which is the exact name
  -- roslyn.nvim looks for — no further config needed.
  -- One-time cleanup after switching: `:MasonUninstall roslyn-language-server`.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.registries = opts.registries or { "github:mason-org/mason-registry" }
      table.insert(opts.registries, "github:Crashdummyy/mason-registry")
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "roslyn")
    end,
  },

  -- Keep every C# server except roslyn.nvim's `roslyn` client from attaching.
  -- `enabled = false` also tells mason-lspconfig not to auto-enable a server
  -- just because its package is installed (OmniSharp, roslyn_ls both are).
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.omnisharp = { enabled = false }
      opts.servers.roslyn_ls = { enabled = false }
      opts.servers.fsautocomplete = { enabled = false }
      -- Required for Razor: Roslyn forwards the HTML parts of a .razor file
      -- to an `html` client attached to a hidden `*__virtual.html` buffer.
      -- Without one, roslyn.nvim blocks the UI in `vim.wait(5000, ...)` on
      -- every forwarded request (document highlight on cursor move, hover,
      -- completion...), freezing Neovim for 5s at a time. Mason installs
      -- `html-lsp` for this automatically.
      opts.servers.html = {}
    end,
  },
  { "Hoffs/omnisharp-extended-lsp.nvim", enabled = false },

  -- Treesitter grammar for Razor, for highlighting/indent/folds inside
  -- .razor/.cshtml. Queries ship with nvim-treesitter itself; filetype
  -- `razor` maps to parser `razor` automatically, no extra wiring needed.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "razor" } },
  },

  -- Auto-close/rename tags in Razor markup like in HTML. nvim-ts-autotag
  -- only acts on filetypes it knows, and `razor` isn't one of them.
  {
    "windwp/nvim-ts-autotag",
    opts = { aliases = { razor = "html" } },
  },

  -- Debugging: enable the `dap.core` LazyVim extra (`:LazyExtras`) to pull in
  -- nvim-dap; LazyVim's `lang.dotnet` extra then wires the `netcoredbg`
  -- adapter and a `dap.configurations.cs` "Launch file" config for you.
  -- Razor markup itself has no useful breakpoints — set them in the .cs
  -- code-behind or in `@code {}` blocks (compiled to C#) instead. This just
  -- aliases the launch config so `<leader>dc` also works with focus in a
  -- .razor buffer.
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      dap.configurations.razor = dap.configurations.cs
    end,
  },

  -- Not doing test integration yet. Enable the `test.core` LazyVim extra
  -- and delete these lines when you want it.
  { "nvim-neotest/neotest", optional = true, enabled = false },
  { "Nsidorenco/neotest-vstest", optional = true, enabled = false },

  -- Format C# with csharpier (Mason-installed, v1.x). The LazyVim extra
  -- already maps `cs -> csharpier`; this is just here to be explicit.
  -- Razor is deliberately left out: csharpier doesn't format .cshtml/.razor
  -- over stdin. With no conform formatter, LazyVim falls back to LSP
  -- formatting, and Roslyn formats Razor itself (markup and `@` blocks; C#
  -- inside `@code {}` only lightly) — as long as the `html` client is
  -- attached, since Roslyn abandons the whole format if the HTML part comes
  -- back empty. Linting needs no separate config either: Roslyn's compiler +
  -- analyzer diagnostics apply to `razor` buffers the same as `cs` once the
  -- LSP client above is attached.
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
      },
    },
  },
}
