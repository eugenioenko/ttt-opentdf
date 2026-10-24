local U = require("core.util")
local UI = require("components")
local Store = require("features.attributes.store")
local Commands = require("features.attributes.commands")
local Values = require("features.attributes.values_table")

-- Attributes on the left, the selected attribute's values on the right.
local M = {}

local COLUMNS = {
  { label = "Attribute" },
  { label = "Rule", width = 9 },
  { label = "Values", width = 6, align = "right" },
}

local KEYS = { n = "new", v = "value", d = "deactivate", e = "labels" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "New Value", command = "value" },
  { label = "Edit Labels", command = "labels" },
  { label = "Deactivate", command = "deactivate" },
}

local function row(item)
  local ns = item.namespace and item.namespace.name or ""
  return { ns .. "/" .. item.name, U.rule(item), tostring(#(item.values or {})) }
end

local function attribute_filters(lv, t)
  UI.search(t, lv, "Search attributes…")
  UI.namespace_filter(t, lv)
  UI.state_filter(t, lv)
end

local function left_filters(lv, b)
  UI.toolbar(b, U.bind(attribute_filters, lv), 0)
end

local function right_filters(b)
  Values.filters(b, Store.values, Store.values_follow)
end

local function filters(lv, left, h)
  h:box({ width = left, padding_right = 1, render = U.bind(left_filters, lv) })
  h:box({ render = right_filters })
end

local function attributes_table(tab, lv, b)
  UI.table(b, lv, {
    noun = "attributes",
    columns = COLUMNS,
    row = row,
    style = U.inactive_style,
    on_move = Store.values_follow,
    on_page = Store.values_follow,
    on_open = U.bind(Commands.attribute, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.attribute, tab),
  })
end

local function values_table(tab, a, b)
  Values.table(b, tab, a, Store.values)
end

local function panes(tab, lv, left, h)
  local a = UI.selected(lv)
  UI.frame(h, "Attributes", U.bind(attributes_table, tab, lv), { width = left })
  UI.frame(h, a and ("Values · " .. a.fqn) or "Values", U.bind(values_table, tab, a))
end

local function actions(h)
  h:button({ label = "New", on_click = Commands.new_attribute })
  UI.refresh_button(h, Store.attributes)
end

local function render(p, tab)
  local lv = Store.attributes
  UI.ensure(lv)
  local left = math.max(36, math.floor(p:size() * 0.5))
  p:hstack({ height = 1, margin_top = 1, render = U.bind(filters, lv, left) })
  p:hstack({ render = U.bind(panes, tab, lv, left) })
end

function M.page()
  return { title = "Attributes", actions = actions, render = render }
end

return M
