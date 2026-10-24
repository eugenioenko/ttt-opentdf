local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Store = require("features.attributes.store")
local Commands = require("features.attributes.commands")
local Values = require("features.attributes.values_table")

local M = {}

local function tabs(a)
  return {
    { id = "details", label = "Details" },
    { id = "values", label = "Values (" .. #(a.values or {}) .. ")" },
  }
end

local function details(p, a)
  p:keyvalue(UI.kv({
    { "FQN", a.fqn },
    { "Namespace", a.namespace and a.namespace.name },
    { "Name", a.name },
    { "Rule", U.rule(a) },
    { "Status", U.active(a.active) },
    { "Values", tostring(#(a.values or {})) },
    { "Labels", U.labels(a.metadata) },
    { "ID", a.id },
    { "Created", U.created(a) },
    { "Updated", U.updated(a) },
  }))
end

local function values_tab(p, tab, a, values)
  Store.refilter(a, values)
  Values.filters(p, values, U.bind(Store.refilter, a, values), 1)
  Values.table(p, tab, a, values, "Values")
end

local function actions(page, a, h, tab)
  if page.tab == "values" then
    h:button({ label = "New", on_click = U.bind(Commands.new_value, a) })
  else
    Policy.actions(h, a, U.bind(Commands.attribute, tab))
  end
end

local function render(page, a, values, p, tab)
  if Router.tab_strip(p, page, tabs(a)) == "values" then
    values_tab(p, tab, a, values)
  else
    details(p, a)
  end
end

function M.page(a)
  local page = { title = a.fqn, tab_title = a.name }
  local values = Store.attribute_values(a)
  page.actions = U.bind(actions, page, a)
  page.render = U.bind(render, page, a, values)
  return page
end

return M
