return {
  "nvim-treesitter/nvim-treesitter-context",
  opts = {
    enable = true,
  },

  keys = {
    { "n", "[c", function() require("treesitter-context").go_to_context(vim.v.count1) end, desc = "Go to TS Context" },
  },
}
