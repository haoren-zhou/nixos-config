require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set
local wk = require "which-key"

-- common --
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map({ "n", "v" }, "<C-s>", "<cmd> w <cr>", { desc = "Save current buffer" })
map("n", "<C-u>", function()
  vim.cmd "normal! "
  vim.cmd "normal! zz"
end, { desc = "Scroll up half page and center" })
map("n", "<C-d>", function()
  vim.cmd "normal! "
  vim.cmd "normal! zz"
end, { desc = "Scroll down half page and center" })

-- LSP --
map("n", "<leader>li", function ()
  local is_enabled = vim.lsp.inlay_hint.is_enabled()
  vim.lsp.inlay_hint.enable(not is_enabled)

  if is_enabled then
    vim.notify("LSP Inlay Hints Disabled", vim.log.levels.INFO)
  else
    vim.notify("LSP Inlay Hints Enabled", vim.log.levels.INFO)
  end
end, { desc = "Toggle LSP Inlay Hints"})

-- nvzone/menu --
-- Keyboard users
map("n", "<C-t>", function()
  require("menu").open "default"
end, { desc = "menu open" })

-- mouse users + nvimtree users!
map({ "n", "v" }, "<RightMouse>", function()
  require("menu.utils").delete_old_menus()

  vim.cmd.exec '"normal! \\<RightMouse>"'

  -- clicked buf
  local buf = vim.api.nvim_win_get_buf(vim.fn.getmousepos().winid)
  local options = vim.bo[buf].ft == "NvimTree" and "nvimtree" or "default"

  require("menu").open(options, { mouse = true })
end, { desc = "menu open by right mouse click" })

-- nvzone/minty --
wk.add {
  "<leader>ms",
  function()
    require("minty.shades").open()
  end,
  mode = "n",
  icon = { icon = "", color = "green" },
  desc = "minty open shades tool",
}
wk.add {
  "<leader>mh",
  function()
    require("minty.huefy").open()
  end,
  mode = "n",
  icon = { icon = "", color = "green" },
  desc = "minty open huefy tool",
}

-- telescope --
map("n", "<leader>fs", require("telescope.builtin").lsp_document_symbols, { desc = "telescope document symbols" })

-- treesitter-context --
-- map("n", "[c", function()
--   require("treesitter-context").go_to_context(vim.v.count1)
-- end, { silent = true })
