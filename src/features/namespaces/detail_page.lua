local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Commands = require("features.namespaces.commands")
local Attributes = require("features.attributes")
local Actions = require("features.actions")

local M = {}

local TABS = {
  { id = "details", label = "Details" },
  { id = "attributes", label = "Attributes" },
  { id = "actions", label = "Actions" },
}

local ATTRIBUTE_COLUMNS = {
  { label = "Name" },
  { label = "Rule", width = 9 },
  { label = "Values", width = 6, align = "right" },
  { label = "Status", width = 9 },
}

local ACTION_COLUMNS = { { label = "Name" }, { label = "Type", width = 9 }, { label = "Created", width = 16 } }

local function attribute_row(a)
  return { a.name, U.rule(a), tostring(#(a.values or {})), U.active(a.active) }
end

local function action_row(a)
  return { a.name, a.kind, U.created(a) }
end

local function attribute_filters(n, attrs, h)
  UI.search(h, attrs, "Search attributes in " .. n.name .. "…")
  UI.state_filter(h, attrs)
end

local function attributes_tab(p, tab, n, attrs)
  UI.ensure(attrs)
  UI.toolbar(p, U.bind(attribute_filters, n, attrs))
  UI.table(p, attrs, {
    frame = "Attributes",
    noun = "attributes",
    columns = ATTRIBUTE_COLUMNS,
    row = attribute_row,
    style = U.inactive_style,
    on_open = U.bind(Attributes.commands.attribute, tab, "open"),
  })
end

local function actions_tab(p, acts)
  UI.ensure(acts)
  UI.table(p, acts, {
    frame = "Actions",
    frame_opts = { margin_top = 1 },
    noun = "actions",
    columns = ACTION_COLUMNS,
    row = action_row,
    style = Actions.store.style,
    on_open = U.bind(Actions.commands.run, "rename"),
    open_label = "Rename",
  })
end

local function details(p, n)
  p:keyvalue(UI.kv({
    { "Name", n.name },
    { "FQN", n.fqn },
    { "Status", U.active(n.active) },
    { "Labels", U.labels(n.metadata) },
    { "ID", n.id },
    { "Created", U.created(n) },
    { "Updated", U.updated(n) },
  }))
end

local function new_attribute(n, attrs)
  Attributes.commands.new_attribute(n.id, U.bind(UI.load, attrs, true))
end

local function new_action(n, acts)
  Actions.commands.new(n.id, U.bind(UI.load, acts, true))
end

local function actions(page, n, lists, h, tab)
  if page.tab == "attributes" then
    h:button({ label = "New", on_click = U.bind(new_attribute, n, lists.attrs) })
    UI.refresh_button(h, lists.attrs)
  elseif page.tab == "actions" then
    h:button({ label = "New", on_click = U.bind(new_action, n, lists.acts) })
    UI.refresh_button(h, lists.acts)
  else
    Policy.actions(h, n, U.bind(Commands.run, tab))
  end
end

local function render(page, n, lists, p, tab)
  local current = Router.tab_strip(p, page, TABS)
  if current == "attributes" then
    attributes_tab(p, tab, n, lists.attrs)
  elseif current == "actions" then
    actions_tab(p, lists.acts)
  else
    details(p, n)
  end
end

function M.page(n)
  local page = { title = n.name }
  local lists = { attrs = Attributes.store.namespace_list(n.id), acts = Actions.store.namespace_list(n.id) }
  page.actions = U.bind(actions, page, n, lists)
  page.render = U.bind(render, page, n, lists)
  return page
end

return M
