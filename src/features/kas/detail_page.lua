local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")
local KeyForm = require("features.kas.key_form")
local Keys = require("features.kas.keys_panel")

local M = {}

local function tabs(k)
  return {
    { id = "details", label = "Details" },
    { id = "keys", label = "Keys (" .. #(k.kasKeys or {}) .. ")" },
  }
end

local function details(p, k)
  p:keyvalue(UI.kv({
    { "Name", k.name },
    { "URI", k.uri },
    { "Source", U.human(k.sourceType, "SOURCE_TYPE_") },
    { "Keys", tostring(#(k.kasKeys or {})) },
    { "ID", k.id },
    { "Created", U.created(k) },
    { "Updated", U.updated(k) },
  }))
end

local function keys_filters(keys, h)
  Keys.filters(h, keys)
end

local function keys_table(tab, k, keys, b)
  Keys.table(b, tab, k, keys)
end

local function keys_tab(p, tab, k, keys)
  UI.ensure(keys)
  UI.toolbar(p, U.bind(keys_filters, keys))
  UI.frame(p, "Keys", U.bind(keys_table, tab, k, keys))
end

local function actions(page, k, keys, h, tab)
  if page.tab == "keys" then
    Keys.actions(h, tab, k, keys)
    UI.refresh_button(h, keys)
    return
  end
  h:button({ label = "New Key", on_click = U.bind(KeyForm.open, tab, k, nil) })
  h:button({ label = "Edit", on_click = U.bind(Commands.edit_server, k) })
  h:button({ label = "Delete", on_click = U.bind(Commands.server, tab, "delete", k) })
end

local function render(page, k, keys, p, tab)
  if Router.tab_strip(p, page, tabs(k)) == "keys" then
    keys_tab(p, tab, k, keys)
  else
    details(p, k)
  end
end

function M.page(k)
  local page = { title = k.name or U.host(k.uri) }
  local keys = Store.server_keys(k)
  page.actions = U.bind(actions, page, k, keys)
  page.render = U.bind(render, page, k, keys)
  return page
end

return M
