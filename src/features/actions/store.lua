local SVC = require("core.services")
local UI = require("components")

local M = {}

function M.extract(data)
  local out = {}
  for _, a in ipairs(data.actionsStandard or {}) do
    a.kind = "Standard"
    out[#out + 1] = a
  end
  for _, a in ipairs(data.actionsCustom or {}) do
    a.kind = "Custom"
    out[#out + 1] = a
  end
  return out
end

M.list = UI.list("actions", {
  method = SVC.ACT .. "ListActions",
  request = function(lv)
    if lv.namespace and lv.namespace ~= "" then
      return { namespaceId = lv.namespace }
    end
    return {}
  end,
  extract = M.extract,
})

function M.namespace_list(ns_id)
  return UI.sub_list("ns-actions:" .. ns_id, {
    method = SVC.ACT .. "ListActions",
    request = function()
      return { namespaceId = ns_id }
    end,
    extract = M.extract,
  })
end

function M.style(a)
  return a.kind == "Standard" and "muted" or "default"
end

return M
