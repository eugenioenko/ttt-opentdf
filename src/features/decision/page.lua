local U = require("core.util")
local S = require("core.state")
local UI = require("components")
local Entity = require("shared.entity")
local Store = require("features.decision.store")
local Picker = require("shared.value_picker")

local M = {}

local HINT = "Pick an entity, an action and the resource's attribute values, then press Get Decision."

local function set_field(st, key, value)
  st[key] = value
end

local function action_input(st, b)
  b:input({
    border = true,
    title = "Action",
    value = st.action,
    placeholder = "read",
    on_change = U.bind(set_field, st, "action"),
    on_submit = Store.run,
  })
end

local function request_row(st, h)
  Entity.fields(h, st.entity, Store.run)
  h:box({ width = 18, render = U.bind(action_input, st) })
  UI.button_box(h, st.busy and "Deciding…" or "Get Decision", Store.run, st.busy, "bracket")
end

local function options_row(st, h)
  h:button({ label = "Add Value", style = "bracket", on_click = U.bind(Picker.open, Store.add_resource) })
  UI.checkbox(h, "Decide each value separately", st.each, U.bind(set_field, st, "each"))
end

local function request_form(p, st)
  p:hstack({ height = 3, gap = 1, margin_top = 1, render = U.bind(request_row, st) })
  p:hstack({ height = 1, gap = 1, margin_top = 1, align = "right", render = U.bind(options_row, st) })
end

local function remove_resource(st, cmd, i)
  if cmd == "remove" then
    table.remove(st.resources, i)
    S.redraw()
  end
end

local RESOURCE_MENU = { { label = "Remove", command = "remove" } }

local RESOURCE_COLUMNS = { { label = "Attribute value FQN" }, UI.actions_column(RESOURCE_MENU) }

local function resources_body(st, rows, b)
  b:table({
    inset = 1,
    columns = RESOURCE_COLUMNS,
    rows = rows,
    empty = "Add the attribute values the resource carries",
    key_commands = { d = "remove", x = "remove" },
    node_menu = RESOURCE_MENU,
    on_command = U.bind(remove_resource, st),
  })
end

local function resources_table(p, st)
  local rows = {}
  for i, f in ipairs(st.resources) do
    rows[i] = { f }
  end
  local height = math.max(math.min(#rows, 8), 2) + 4
  UI.frame(p, "Resource attribute values", U.bind(resources_body, st, rows), { height = height })
end

local function verdict_detail(detail, b)
  b:label({ text = detail, style = "muted" })
end

local function verdict_row(permit, detail, h)
  h:label({
    text = permit and " ✓ PERMIT" or " ✕ DENY",
    style = permit and "success" or "danger",
    border = true,
    width = 14,
  })
  h:box({ padding_top = 1, render = U.bind(verdict_detail, detail) })
end

local function decision_rows(r)
  local rows, styles = {}, {}
  for i, d in ipairs(r.decisions) do
    local ok = d.decision == "DECISION_PERMIT"
    rows[i] = { ok and "Permit" or "Deny", d.label }
    styles[i] = ok and "success" or "danger"
  end
  if #r.obligations > 0 then
    rows[#rows + 1] = { "", "" }
    for _, o in ipairs(r.obligations) do
      rows[#rows + 1] = { "Obligation", o }
      styles[#rows] = "warning"
    end
  end
  return rows, styles
end

local function decisions_body(r, b)
  local rows, styles = decision_rows(r)
  b:table({
    inset = 1,
    columns = { { label = "Decision", width = 10 }, { label = "Resource" } },
    rows = rows,
    row_styles = styles,
  })
end

local function result(p, r)
  local permitted = Store.permitted(r.decisions)
  local permit = #r.decisions > 0 and permitted == #r.decisions
  local detail = r.entity .. "  ·  " .. r.action
  if #r.decisions > 1 then
    detail = detail .. "  ·  " .. permitted .. " of " .. #r.decisions .. " permitted"
  end
  p:hstack({ height = 3, gap = 1, margin_top = 1, render = U.bind(verdict_row, permit, detail) })
  UI.frame(p, "Decisions", U.bind(decisions_body, r), { margin_top = 1 })
end

local function render(p)
  local st = Store.state
  request_form(p, st)
  resources_table(p, st)
  if st.err then
    p:label({ text = "✕ " .. st.err, style = "danger", margin_top = 1, padding_left = 1 })
  elseif not st.result then
    p:label({ text = HINT, style = "muted", margin_top = 1, padding_left = 1 })
  else
    result(p, st.result)
  end
end

function M.page()
  return { title = "Decision", render = render }
end

return M
