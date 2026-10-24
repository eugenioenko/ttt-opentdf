local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Entity = require("shared.entity")

local M = {}

M.state = {
  entity = Entity.new(),
  comprehensive = true,
  busy = false,
  err = nil,
  ran = nil,
  list = UI.list("entitlements", { client = true }),
}

local function rows_from(entities)
  local rows = {}
  for _, ent in ipairs(entities) do
    for fqn, list in pairs(ent.actionsPerAttributeValueFqn or {}) do
      local names = {}
      for _, a in ipairs(list.actions or {}) do
        names[#names + 1] = a.name
      end
      table.sort(names)
      rows[#rows + 1] = { fqn = fqn, actions = table.concat(names, ", "), entity = ent.ephemeralId or "" }
    end
  end
  table.sort(rows, function(a, b)
    if a.fqn == b.fqn then
      return a.entity < b.entity
    end
    return a.fqn < b.fqn
  end)
  return rows
end

function M.filter()
  local st = M.state
  local term = st.list.search:lower()
  local out = {}
  for _, r in ipairs(st.all or {}) do
    if term == "" or r.fqn:lower():find(term, 1, true) or r.actions:lower():find(term, 1, true) then
      out[#out + 1] = r
    end
  end
  st.list.all = out
  st.list.offset = 0
  st.list.sel = 1
  UI.slice(st.list)
end

function M.run()
  local st = M.state
  if Entity.missing(st) then
    return
  end
  st.busy = true
  st.err = nil
  st.list.loading = true
  S.redraw()
  local label = Entity.label(st.entity)
  Api.call(SVC.AUTHZ .. "GetEntitlements", {
    entityIdentifier = Entity.identifier(st.entity),
    withComprehensiveHierarchy = st.comprehensive,
  }, function(err, data)
    st.busy = false
    st.list.loading = false
    if err then
      st.err = err
      st.list.all = {}
      UI.slice(st.list)
      S.redraw()
      return
    end
    local entities = data.entitlements or {}
    st.all = rows_from(entities)
    st.entities = #entities
    st.ran = label
    M.filter()
    S.redraw()
  end)
end

function M.summary()
  local st = M.state
  if st.err then
    return "✕ " .. st.err, "danger"
  end
  if not st.ran then
    return "", "muted"
  end
  local n = #(st.all or {})
  local text = n .. " entitled value" .. (n == 1 and "" or "s") .. " for " .. st.ran
  if (st.entities or 0) > 1 then
    text = text .. " across " .. st.entities .. " entities"
  end
  return text, "muted"
end

return M
