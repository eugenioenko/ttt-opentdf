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

local function request(lv)
  if lv.namespace and lv.namespace ~= "" then
    return { namespaceId = lv.namespace }
  end
  return {}
end

M.list = UI.list("actions", { method = SVC.ACT .. "ListActions", request = request, extract = M.extract })

function M.namespace_list(ns_id)
  local lv =
    UI.sub_list("ns-actions:" .. ns_id, { method = SVC.ACT .. "ListActions", request = request, extract = M.extract })
  lv.namespace = ns_id
  return lv
end

function M.style(a)
  return a.kind == "Standard" and "muted" or "default"
end

return M
