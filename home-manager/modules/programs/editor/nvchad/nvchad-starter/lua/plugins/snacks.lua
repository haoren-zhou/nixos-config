-- hash map to store messages to filter out
local filtered_msgs = {
  ["No signature help available"] = true,
}

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@diagnostic disable-next-line: undefined-doc-name
  ---@type snacks.Config
  opts = {
    -- input = { enabled = true },
    notifier = {
      enabled = true,
      filter = function(notif)
        if filtered_msgs[notif.msg] then
          return false
        end
        return true
      end,
    },
  },
}
