local U = require("core.util")
local UI = require("components")
local Conditions = require("shared.conditions")
local Store = require("features.condition_sets.store")
local Commands = require("features.condition_sets.commands")

local M = {}

local COLUMNS = {
  { label = "Conditions" },
  { label = "Namespace", width = 20 },
  { label = "ID", width = 8 },
  { label = "Labels", width = 24 },
  { label = "Created", width = 16 },
}

local KEYS = { n = "new", e = "edit", l = "labels", d = "delete" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "Edit Conditions", command = "edit" },
  { label = "Edit Labels", command = "labels" },
  { label = "Delete", command = "delete" },
}

local function row(scs)
  return { Conditions.summary(scs), Store.namespace(scs), Store.short_id(scs), U.labels(scs.metadata), U.created(scs) }
end

local function filters(lv, h)
  UI.search(h, lv, "Search labels…")
  UI.namespace_filter(h, lv)
end

local function actions(h, tab)
  h:button({ label = "New", on_click = U.bind(Commands.new, tab) })
  UI.refresh_button(h, Store.list)
end

local function render(p, tab)
  local lv = Store.list
  UI.ensure(lv)
  UI.toolbar(p, U.bind(filters, lv))
  UI.table(p, lv, {
    frame = "Subject Condition Sets",
    noun = "condition sets",
    columns = COLUMNS,
    row = row,
    on_open = U.bind(Commands.run, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.run, tab),
  })
end

function M.page()
  return { title = "Condition Sets", actions = actions, render = render }
end

return M
