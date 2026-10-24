local U = require("core.util")
local UI = require("components")
local Store = require("features.actions.store")
local Commands = require("features.actions.commands")

local M = {}

local COLUMNS = {
  { label = "Name" },
  { label = "Type", width = 9 },
  { label = "Namespace" },
  { label = "Created", width = 16 },
}

local KEYS = { n = "new", e = "rename", d = "delete" }

local MENU = {
  { label = "Rename", command = "rename" },
  { label = "Delete", command = "delete" },
}

local function row(a)
  return { a.name, a.kind, a.namespace and a.namespace.name or "", U.created(a) }
end

local function filters(lv, h)
  UI.namespace_filter(h, lv)
end

local function actions(h)
  h:button({ label = "New", on_click = Commands.new })
  UI.refresh_button(h, Store.list)
end

local function render(p)
  local lv = Store.list
  UI.ensure(lv)
  UI.toolbar(p, U.bind(filters, lv))
  UI.table(p, lv, {
    frame = "Actions",
    noun = "actions",
    columns = COLUMNS,
    row = row,
    style = Store.style,
    on_open = U.bind(Commands.run, "rename"),
    keys = KEYS,
    menu = MENU,
    on_command = Commands.run,
  })
end

function M.page()
  return { title = "Actions", actions = actions, render = render }
end

return M
