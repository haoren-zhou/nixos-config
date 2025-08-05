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

-- nvzone/menu --
-- Keyboard users
vim.keymap.set("n", "<C-t>", function()
  require("menu").open "default"
end, { desc = "menu open" })

-- mouse users + nvimtree users!
vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
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
