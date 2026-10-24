local SVC = require("core.services")
local UI = require("components")

local M = {}

local function request(lv)
  return { state = lv.state }
end

local function extract(data)
  return data.namespaces
end

M.list =
  UI.list("namespaces", { method = SVC.NS .. "ListNamespaces", search = true, request = request, extract = extract })

return M
