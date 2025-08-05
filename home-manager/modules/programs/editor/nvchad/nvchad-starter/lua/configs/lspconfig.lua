require("nvchad.configs.lspconfig").defaults()

local servers = {
  cssls = {},
  tailwindcss = {},
  html = {},
  jsonls = {},
  ts_ls = {},
  eslint = {},
  nixd = {},
  docker_compose_language_service = {},
  dockerls = {},
  clangd = {},
  cmake = {},
  pyright = {},
  marksman = {},
  texlab = {},
}

for name, opts in pairs(servers) do
  vim.lsp.enable(name)
  vim.lsp.config(name, opts)
end

-- read :h vim.lsp.config for changing options of lsp servers
