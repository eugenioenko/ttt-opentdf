local U = require("core.util")
local UI = require("components")
local Conditions = require("shared.conditions")
local Store = require("features.subject_mappings.store")
local Commands = require("features.subject_mappings.commands")

local M = {}

local COLUMNS = {
  { label = "Attribute value" },
  { label = "Actions", width = 24 },
  { label = "Conditions", width = 36 },
  { label = "Created", width = 16 },
}

local KEYS = { n = "new", e = "edit", c = "conditions", l = "labels", d = "delete" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "Edit", command = "edit" },
  { label = "Edit Labels", command = "labels" },
  { label = "Open Condition Set", command = "conditions" },
  { separator = true },
  { label = "Delete", command = "delete" },
}

local function row(sm)
  return { Store.fqn(sm), U.action_names(sm.actions), Conditions.summary(sm.subjectConditionSet), U.created(sm) }
end

local function filters(lv, h)
  UI.search(h, lv, "Search attribute values or labels…")
  UI.namespace_filter(h, lv)
end

local function actions(h, tab)
  h:button({ label = "New", on_click = U.bind(Commands.run, tab, "new", nil) })
  UI.refresh_button(h, Store.list)
end

local function render(p, tab)
  local lv = Store.list
  UI.ensure(lv)
  UI.toolbar(p, U.bind(filters, lv))
  UI.table(p, lv, {
    frame = "Subject Mappings",
    noun = "subject mappings",
    columns = COLUMNS,
    row = row,
    on_open = U.bind(Commands.run, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.run, tab),
  })
end

function M.page()
  return { title = "Subject Mappings", actions = actions, render = render }
end

return M
