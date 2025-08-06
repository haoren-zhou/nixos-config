local function diff_source()
  local gitsigns = vim.b.gitsigns_status_dict
  if gitsigns then
    return {
      added = gitsigns.added,
      modified = gitsigns.changed,
      removed = gitsigns.removed,
    }
  end
end

return {
  "nvim-lualine/lualine.nvim",
  event = "BufReadPost",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      disabled_filetypes = { "undotree", "NvimTree" },
    },
    refresh = {
      refresh_time = 32,
    },
    sections = {
      lualine_b = {
        { "b:gitsigns_head", icon = "" },
        { "diff", source = diff_source() },
      },
      lualine_c = {
        { "filename" },
        { "filetype" },
      },

      lualine_x = {
        "searchcount",
        "selectioncount",
        {
          "macro",
          fmt = function()
            local reg = vim.fn.reg_recording()
            if reg ~= "" then
              return "recording @" .. reg
            end
            return nil
          end,
          color = {
            fg = "#ff9e64",
            gui = "bold",
          },
          draw_empty = false,
        },
        "diagnostics",
        "lsp_status",
      },
      lualine_y = { "location" },
      lualine_z = {
        {
          function()
            return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          end,
          icon = " ",
        },
      },
    },
  },
}
