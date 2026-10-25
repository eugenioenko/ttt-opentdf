local SVC = require("core.services")
local UI = require("components")

local M = {}

function M.request(lv)
  if lv.namespace and lv.namespace ~= "" then
    return { namespaceId = lv.namespace }
  end
  return {}
end

function M.extract(data)
  return data.subjectConditionSets
end

M.SPEC = { method = SVC.SM .. "ListSubjectConditionSets", search = true, request = M.request, extract = M.extract }

M.list = UI.list("condition_sets", M.SPEC)

function M.short_id(scs)
  return (scs.id or ""):sub(1, 8)
end

function M.namespace(x)
  return x.namespace and x.namespace.name or ""
end

return M
