local SVC = require("core.services")
local UI = require("components")

local M = {}

local function request(lv)
  if lv.namespace and lv.namespace ~= "" then
    return { namespaceId = lv.namespace }
  end
  return {}
end

local function extract(data)
  return data.subjectMappings
end

M.list = UI.list(
  "subject_mappings",
  { method = SVC.SM .. "ListSubjectMappings", search = true, request = request, extract = extract }
)

function M.fqn(sm)
  return sm.attributeValue and sm.attributeValue.fqn or ""
end

function M.namespace(sm)
  return sm.namespace and sm.namespace.name or ""
end

return M
