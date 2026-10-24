local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local Entity = require("shared.entity")

local M = {}

M.state = {
  entity = Entity.new(),
  action = "read",
  resources = {},
  each = false,
  busy = false,
  err = nil,
  result = nil,
}

-- Prefills the form, for example from an entitlement row.
function M.prefill(entity, fqn)
  M.state.entity = { kind = entity.kind, value = entity.value }
  M.state.resources = { fqn }
end

function M.add_resource(fqn)
  for _, f in ipairs(M.state.resources) do
    if f == fqn then
      return
    end
  end
  M.state.resources[#M.state.resources + 1] = fqn
  S.redraw()
end

local function decide_together(st, action, done)
  local fqns = {}
  for i, f in ipairs(st.resources) do
    fqns[i] = f
  end
  Api.call(SVC.AUTHZ .. "GetDecision", {
    entityIdentifier = Entity.identifier(st.entity),
    action = { name = action },
    resource = { ephemeralId = "resource", attributeValues = { fqns = fqns } },
  }, function(err, data)
    if err then
      return done(err)
    end
    local d = data.decision or {}
    done(
      nil,
      { { label = #fqns .. " value" .. (#fqns == 1 and "" or "s") .. " together", decision = d.decision } },
      d.requiredObligations
    )
  end)
end

local function decide_each(st, action, done)
  local resources = {}
  for i, f in ipairs(st.resources) do
    resources[i] = { ephemeralId = "r" .. i, attributeValues = { fqns = { f } } }
  end
  Api.call(SVC.AUTHZ .. "GetDecisionMultiResource", {
    entityIdentifier = Entity.identifier(st.entity),
    action = { name = action },
    resources = resources,
  }, function(err, data)
    if err then
      return done(err)
    end
    local out, obligations = {}, {}
    for _, d in ipairs(data.resourceDecisions or {}) do
      local i = tonumber((d.ephemeralResourceId or ""):sub(2))
      out[#out + 1] = { label = st.resources[i] or d.ephemeralResourceId, decision = d.decision }
      for _, o in ipairs(d.requiredObligations or {}) do
        obligations[#obligations + 1] = o
      end
    end
    done(nil, out, obligations)
  end)
end

function M.run()
  local st = M.state
  if Entity.missing(st) then
    return
  end
  if #st.resources == 0 then
    st.err = "Add at least one attribute value"
    S.redraw()
    return
  end
  st.busy = true
  st.err = nil
  S.redraw()
  local action = U.trim(st.action)
  if action == "" then
    action = "read"
  end
  local label = Entity.label(st.entity)
  local done = function(err, decisions, obligations)
    st.busy = false
    if err then
      st.err = err
      st.result = nil
    else
      st.result = { entity = label, action = action, decisions = decisions, obligations = obligations or {} }
    end
    S.redraw()
  end
  if st.each then
    decide_each(st, action, done)
  else
    decide_together(st, action, done)
  end
end

function M.permitted(decisions)
  local n = 0
  for _, d in ipairs(decisions) do
    if d.decision == "DECISION_PERMIT" then
      n = n + 1
    end
  end
  return n
end

return M
