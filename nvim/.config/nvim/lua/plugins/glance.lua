return {
  "dnlhc/glance.nvim",
  cmd = "Glance",
  keys = {
    { "gpd", "<cmd>Glance definitions<cr>",      desc = "Peek definition" },
    { "gpt", "<cmd>Glance type_definitions<cr>", desc = "Peek type definition" },
    { "gpr", "<cmd>Glance references<cr>",       desc = "Peek references" },
    { "gpi", "<cmd>Glance implementations<cr>",  desc = "Peek implementations" },
  },
  opts = {},
}
