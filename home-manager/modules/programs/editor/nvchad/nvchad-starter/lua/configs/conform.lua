local options = {
  formatters_by_ft = {
    css = { "prettierd", "prettier" },
    html = { "prettierd", "prettier" },
    javascript = { "prettierd", "prettier" },
    typescript = { "prettierd", "prettier" },
    json = { "prettierd", "prettier" },
    markdown = { "prettierd", "prettier" },

    python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },

    cpp = { "clang_format" },
    c = { "clang_format" },
    cmake = { "cmake-format" },

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
