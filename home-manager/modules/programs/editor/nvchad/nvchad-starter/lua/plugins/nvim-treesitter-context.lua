return {
  "nvim-treesitter/nvim-treesitter-context",
  event = "BufReadPost",
  opts = {
    enable = true,
    mode = "cursor",
    max_lines = 3,
    multiline_threshold = 1,
  },

  keys = {
    { "n", "[c", function() require("treesitter-context").go_to_context(vim.v.count1) end, desc = "Go to TS Context" },
  },
}
