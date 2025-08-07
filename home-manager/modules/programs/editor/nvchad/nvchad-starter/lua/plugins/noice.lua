return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        -- ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
      },
      signature = {
        enabled = true,
        auto_open = {
          enabled = false,
          trigger = false,
        },
      },
      hover = {
        enabled = true,
        silent = true,
      },
    },
    notify = {
      enabled = false,
    },
    presets = {
      command_palette = true,
      long_message_to_split = true,
      lsp_doc_border = true,
    },
  },
  dependencies = {
    "MunifTanjim/nui.nvim",
    -- "rcarriga/nvim-notify",
  },
}
