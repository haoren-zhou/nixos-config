local options = {
  formatters_by_ft = {
    css = { "prettierd", "prettier" },
    html = { "prettierd", "prettier" },
    javascript = { "prettierd", "prettier" },
    typescript = { "prettierd", "prettier" },
    json = { "prettierd", "prettier" },
    markdown = { "prettierd", "prettier" },

    python = { "black", "isort" },

    cpp = { "clang_format" },
    c = { "clang_format" },

    lua = { "stylua" },

    nix = { "alejandra" },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
