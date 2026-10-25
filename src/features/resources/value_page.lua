local U = require("core.util")
local UI = require("components")
local Commands = require("features.resources.commands")

local M = {}

local COLUMNS = { { label = "Action", width = 20 }, { label = "Attribute value" } }

local function grants_body(v, b)
  local rows = {}
  for i, aav in ipairs(v.actionAttributeValues or {}) do
    rows[i] = { aav.action and aav.action.name or "", aav.attributeValue and aav.attributeValue.fqn or "" }
  end
  b:table({ inset = 1, columns = COLUMNS, rows = rows, empty = "No actions on attribute values" })
end

local function render(r, v, p)
  p:keyvalue(UI.kv({
    { "Value", v.value },
    { "FQN", v.fqn },
    { "Resource", r.name },
    { "Labels", U.labels(v.metadata) },
    { "ID", v.id },
    { "Created", U.created(v) },
    { "Updated", U.updated(v) },
  }))
  UI.frame(p, "Actions on attribute values", U.bind(grants_body, v), { margin_top = 1 })
end

local function actions(r, v, h, tab)
  h:button({ label = "Edit", on_click = U.bind(Commands.value, tab, r, "edit", v) })
  h:button({ label = "Labels", on_click = U.bind(Commands.value, tab, r, "labels", v) })
  h:button({ label = "Delete", on_click = U.bind(Commands.value, tab, r, "delete", v) })
end

function M.page(r, v)
  return {
    title = v.value,
    tab_title = r.name .. " · " .. v.value,
    actions = U.bind(actions, r, v),
    render = U.bind(render, r, v),
  }
end

return M
