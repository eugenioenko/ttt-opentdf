local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Store = require("features.resources.store")
local Commands = require("features.resources.commands")
local Values = require("features.resources.values_table")

local M = {}

local function tabs(r)
  return {
    { id = "details", label = "Details" },
    { id = "values", label = "Values (" .. #(r.values or {}) .. ")" },
  }
end

local function details(p, r)
  p:keyvalue(UI.kv({
    { "Name", r.name },
    { "Namespace", Store.namespace(r) },
    { "Values", tostring(#(r.values or {})) },
    { "Labels", U.labels(r.metadata) },
    { "ID", r.id },
    { "Created", U.created(r) },
    { "Updated", U.updated(r) },
  }))
end

local function actions(page, r, h, tab)
  if page.tab == "values" then
    h:button({ label = "New Value", on_click = U.bind(Commands.value, tab, r, "new", nil) })
    return
  end
  h:button({ label = "Rename", on_click = U.bind(Commands.resource, tab, "edit", r) })
  h:button({ label = "Labels", on_click = U.bind(Commands.resource, tab, "labels", r) })
  h:button({ label = "Delete", on_click = U.bind(Commands.resource, tab, "delete", r) })
end

local function render(page, r, lv, p, tab)
  if Router.tab_strip(p, page, tabs(r)) == "values" then
    UI.ensure(lv)
    Values.table(p, tab, r, lv, "Values")
  else
    details(p, r)
  end
end

function M.page(r)
  local page = { title = r.name }
  local lv = Store.resource_values(r)
  page.actions = U.bind(actions, page, r)
  page.render = U.bind(render, page, r, lv)
  return page
end

return M
