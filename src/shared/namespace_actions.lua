local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local Actions = require("features.actions.store")

-- Action names by namespace, for forms that pair actions with attribute
-- values: every namespace has its own standard and custom actions.
local M = {}

local cache = {}

function M.namespace_id(fqn)
  local host = type(fqn) == "string" and fqn:match("^%a+://([^/]+)")
  for _, ns in ipairs(S.namespaces) do
    if ns.label == host then
      return ns.value
    end
  end
  return nil
end

local function loaded(ns_id, err, data)
  local names, seen = {}, {}
  for _, a in ipairs(err and {} or Actions.extract(data)) do
    if a.name and not seen[a.name] then
      seen[a.name] = true
      names[#names + 1] = a.name
    end
  end
  cache[ns_id] = { names = names, err = err }
  S.redraw()
end

-- The namespace's action names, or nil while they load; err when they failed.
function M.names(ns_id)
  if not ns_id then
    return nil
  end
  local entry = cache[ns_id]
  if entry == nil then
    cache[ns_id] = false
    Api.call(SVC.ACT .. "ListActions", { namespaceId = ns_id, pagination = { limit = 1000 } }, U.bind(loaded, ns_id))
    return nil
  end
  if entry == false then
    return nil
  end
  return entry.names, entry.err
end

function M.forget()
  cache = {}
end

return M
