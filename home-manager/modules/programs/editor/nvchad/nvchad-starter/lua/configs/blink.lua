local opts = require "nvchad.blink.config"
opts.keymap = {
  preset = "default",
  ["<CR>"] = { "accept", "fallback" },
  ["<C-b>"] = { "scroll_documentation_up", "fallback" },
  ["<C-f>"] = { "scroll_documentation_down", "fallback" },
  -- Switch priority of tab when in snippet
  ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
  ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
}

return opts
