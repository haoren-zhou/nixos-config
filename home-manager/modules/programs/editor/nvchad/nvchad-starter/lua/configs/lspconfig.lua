require("nvchad.configs.lspconfig").defaults()

local servers = {
  "ts_ls",
  "cssls",
  "html",
  "nixd",
  "clangd",
  "pyright",
  "marksman",
}
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
