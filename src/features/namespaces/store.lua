local SVC = require("core.services")
local UI = require("components")

local M = {}

M.list = UI.list("namespaces", {
  method = SVC.NS .. "ListNamespaces",
  search = true,
  request = function(lv)
    return { state = lv.state }
  end,
  extract = function(data)
    return data.namespaces
  end,
})

return M
