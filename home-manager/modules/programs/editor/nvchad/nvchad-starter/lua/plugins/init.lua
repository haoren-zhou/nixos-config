return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "cmake",
        "cpp",
        "css",
        "dockerfile",
        "gitignore",
        "html",
        "javascript",
        "json",
        "htmldjango",
        "lua",
        "nix",
        "python",
        "requirements",
        "scss",
        "sql",
        "toml",
        "vim",
        "vimdoc",
        "yaml",
      },
    },
  },
}
