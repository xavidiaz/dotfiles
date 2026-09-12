-- .NET / C# setup, layered on LazyVim's `lang.dotnet` extra (enabled in
-- lazyvim.json). That extra wires up OmniSharp; here we disable it and use
-- the Roslyn language server (via roslyn.nvim) instead.
return {
  -- Roslyn LSP. Server binary comes from Mason (`roslyn-language-server`),
  -- which roslyn.nvim picks up from $PATH (Mason's bin dir is on it).
  {
    "seblyng/roslyn.nvim",
    ft = "cs",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {},
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "roslyn-language-server" } },
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
    end,
  },
  { "Hoffs/omnisharp-extended-lsp.nvim", enabled = false },

  -- Not doing test/debug integration yet. Enable the `test.core` / `dap.core`
  -- LazyVim extras (`:LazyExtras`) and delete these lines when you want them.
  { "nvim-neotest/neotest", optional = true, enabled = false },
  { "Nsidorenco/neotest-vstest", optional = true, enabled = false },

  -- Format C# with csharpier (Mason-installed, v1.x). The LazyVim extra
  -- already maps `cs -> csharpier`; this is just here to be explicit.
  -- Note: csharpier 1.2.x does not format .cshtml/.razor via stdin (returns
  -- nothing), so those files (filetype `razor`) are left unformatted.
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
