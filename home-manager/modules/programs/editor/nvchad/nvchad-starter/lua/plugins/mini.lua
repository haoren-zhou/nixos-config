local module_names = {
  { name = "mini.ai" },
  { name = "mini.animate" },
  { name = "mini.cursorword" },
  { name = "mini.move" },
  { name = "mini.splitjoin" },
  { name = "mini.surround" },
}

local mini_modules = {}

for _, mod in ipairs(module_names) do
  table.insert(mini_modules, {
    "echasnovski/" .. mod.name,
    event = "VeryLazy",
    version = false,
    opts = mod.opts or {},
  })
end

return mini_modules
