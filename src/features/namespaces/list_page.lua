local U = require("core.util")
local UI = require("components")
local Store = require("features.namespaces.store")
local Commands = require("features.namespaces.commands")

local M = {}

local COLUMNS = {
  { label = "Name" },
  { label = "Status", width = 9 },
  { label = "Labels" },
  { label = "Created", width = 16 },
}

local KEYS = { n = "new", e = "labels", d = "deactivate", a = "attributes", c = "actions" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "Edit Labels", command = "labels" },
  { label = "Deactivate", command = "deactivate" },
  { separator = true },
  { label = "Show Attributes", command = "attributes" },
  { label = "Show Actions", command = "actions" },
}

local function row(n)
  return { n.name, U.active(n.active), U.labels(n.metadata), U.created(n) }
end

local function filters(lv, h)
  UI.search(h, lv, "Search namespaces…")
  UI.state_filter(h, lv)
end

local function actions(h)
  h:button({ label = "New", on_click = Commands.new })
  UI.refresh_button(h, Store.list)
end

local function render(p, tab)
  local lv = Store.list
  UI.ensure(lv)
  UI.toolbar(p, U.bind(filters, lv))
  UI.table(p, lv, {
    frame = "Namespaces",
    noun = "namespaces",
    columns = COLUMNS,
    row = row,
    style = U.inactive_style,
    on_open = U.bind(Commands.run, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.run, tab),
  })
end

function M.page()
  return { title = "Namespaces", actions = actions, render = render }
end

return M
