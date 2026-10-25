local U = require("core.util")
local UI = require("components")
local Store = require("features.resources.store")
local Commands = require("features.resources.commands")
local Values = require("features.resources.values_table")

-- Resources on the left, the selected resource's values on the right.
local M = {}

local COLUMNS = {
  { label = "Name" },
  { label = "Namespace", width = 18 },
  { label = "Values", width = 6, align = "right" },
}

local KEYS = { n = "new", v = "value", e = "edit", l = "labels", d = "delete" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "New Value", command = "value" },
  { label = "Rename", command = "edit" },
  { label = "Edit Labels", command = "labels" },
  { separator = true },
  { label = "Delete", command = "delete" },
}

local function row(r)
  return { r.name or "", Store.namespace(r), tostring(#(r.values or {})) }
end

local function resources_table(tab, lv, b)
  UI.table(b, lv, {
    noun = "resources",
    columns = COLUMNS,
    row = row,
    on_move = U.bind(Store.values_follow, false),
    on_page = U.bind(Store.values_follow, true),
    on_open = U.bind(Commands.resource, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.resource, tab),
  })
end

local function values_table(tab, r, b)
  Values.table(b, tab, r, Store.values)
end

local function panes(tab, lv, left, h)
  local r = UI.selected(lv)
  UI.frame(h, "Registered Resources", U.bind(resources_table, tab, lv), { width = left })
  UI.frame(h, r and ("Values · " .. r.name) or "Values", U.bind(values_table, tab, r))
end

local function filters(lv, h)
  UI.search(h, lv, "Search resources…")
  UI.namespace_filter(h, lv)
end

local function new_value(tab)
  Commands.value(tab, UI.selected(Store.resources), "new")
end

local function actions(h, tab)
  h:button({ label = "New", on_click = Commands.new })
  h:button({ label = "New Value", on_click = U.bind(new_value, tab) })
  UI.refresh_button(h, Store.resources)
end

local function render(p, tab)
  local lv = Store.resources
  UI.ensure(lv)
  UI.toolbar(p, U.bind(filters, lv))
  local left = math.max(36, math.floor(p:size() * 0.4))
  p:hstack({ render = U.bind(panes, tab, lv, left) })
end

function M.page()
  return { title = "Registered Resources", actions = actions, render = render }
end

return M
