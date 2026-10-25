local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
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
  return data.resources
end

-- lv.resource is the resource whose values the list shows.
local function values_request(lv)
  return { resourceId = lv.resource and lv.resource.id }
end

local function extract_values(data)
  return data.values
end

local VALUES_SPEC =
  { method = SVC.RR .. "ListRegisteredResourceValues", request = values_request, extract = extract_values }

-- The values of the resource selected in M.resources.
M.values = UI.list("resource-values", VALUES_SPEC)

function M.resource_values(r)
  local lv = UI.sub_list("rr-values:" .. r.id, VALUES_SPEC)
  lv.resource = r
  return lv
end

local values_later, values_cancel = ttt.debounce(150, U.bind(UI.load, M.values))

function M.values_follow(now)
  local r = UI.selected(M.resources)
  if not r then
    values_cancel()
    M.values.resource = nil
    M.values.items, M.values.total, M.values.loaded, M.values.loading = {}, 0, true, false
    return
  end
  if M.values.resource == r and M.values.loaded then
    return
  end
  M.values.resource = r
  M.values.offset = 0
  M.values.sel = 1
  if now then
    values_cancel()
    UI.load(M.values)
    return
  end
  M.values.loading = true
  values_later()
end

M.resources = UI.list("resources", {
  method = SVC.RR .. "ListRegisteredResources",
  search = true,
  request = request,
  extract = extract,
  on_loaded = U.bind(M.values_follow, true),
})

function M.reload_values()
  for name, lv in pairs(S.lists) do
    if name == "resource-values" or name:find("^rr%-values:") then
      lv.loaded = false
      if lv.resource then
        UI.load(lv, true)
      end
    end
  end
end

function M.namespace(x)
  return x.namespace and x.namespace.name or ""
end

function M.grant_text(aav)
  local action = aav.action and aav.action.name or "?"
  local value = aav.attributeValue and aav.attributeValue.fqn or "?"
  return action .. " → " .. value
end

function M.grants(v)
  local parts = {}
  for i, aav in ipairs(v.actionAttributeValues or {}) do
    parts[i] = M.grant_text(aav)
  end
  return table.concat(parts, "; ")
end

return M
