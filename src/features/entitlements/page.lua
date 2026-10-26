local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Entity = require("shared.entity")
local Store = require("features.entitlements.store")
local Decision = require("features.decision")

local M = {}

local function set_comprehensive(st, v)
  st.comprehensive = v
end

local function request_row(st, h)
  Entity.fields(h, st.entity, Store.run)
  UI.checkbox(h, "Full hierarchy", st.comprehensive, U.bind(set_comprehensive, st), { padding_top = 1 })
  UI.button_box(h, st.busy and "Checking…" or "Get Entitlements", Store.run, st.busy, "bracket")
end

local function summary_row(st, width, h)
  local summary, style = Store.summary()
  h:label({ text = summary, style = style, padding_left = 1, width = math.max(width - 44, 10) })
  UI.search(h, st.list, "Filter values or actions…", Store.filter)
end

local function columns(many)
  local out = { { label = "Attribute value" }, { label = "Actions", width = 28 } }
  if many then
    table.insert(out, 1, { label = "Entity", width = 28 })
  end
  return out
end

local function row(many, r)
  if many then
    return { r.entity, r.fqn, r.actions }
  end
  return { r.fqn, r.actions }
end

local function decide(st, r)
  Decision.store.prefill(st.entity, r.fqn)
  Router.open(Decision.id)
end

local function render(p)
  local st = Store.state
  local many = (st.entities or 0) > 1
  p:hstack({ height = 3, gap = 1, margin_top = 1, render = U.bind(request_row, st) })
  p:hstack({ height = 1, gap = 2, margin_top = 1, render = U.bind(summary_row, st, (p:size())) })
  UI.table(p, st.list, {
    frame = "Entitlements",
    noun = "entitlements",
    empty = st.ran and "This entity isn't entitled to any attribute values"
      or "Choose an entity and press Get Entitlements",
    columns = columns(many),
    row = U.bind(row, many),
    on_open = U.bind(decide, st),
  })
end

function M.page()
  return { title = "Entitlements", render = render }
end

return M
