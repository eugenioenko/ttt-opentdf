local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local UI = require("components")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")
local Keys = require("features.kas.keys_panel")

-- Key access servers on the left, the selected server's keys on the right.
local M = {}

local COLUMNS = { { label = "Name" }, { label = "Keys", width = 5, align = "right" } }

local KEYS = { n = "new", e = "edit", d = "delete" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "Edit", command = "edit" },
  { label = "Delete", command = "delete" },
  { separator = true },
  { label = "New Key", command = "key" },
}

local function row(item)
  if item.all then
    return { "All keys", tostring(S.counts.keys or "") }
  end
  return { item.name or U.host(item.uri), tostring(#(item.kasKeys or {})) }
end

local function style(item)
  return item.all and "bold" or "default"
end

local function servers_table(tab, lv, b)
  UI.table(b, lv, {
    noun = "servers",
    columns = COLUMNS,
    row = row,
    style = style,
    on_move = U.bind(Store.keys_follow, false),
    on_page = U.bind(Store.keys_follow, true),
    on_open = U.bind(Commands.server, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.server, tab),
  })
end

local function keys_panel(tab, k, b)
  Keys.render(b, tab, k, Store.keys)
end

local function keys_title(k)
  if k and not k.all then
    return "Keys · " .. (k.name or U.host(k.uri))
  end
  return "Keys · all servers"
end

local function panes(tab, lv, left, h)
  local k = UI.selected(lv)
  UI.frame(h, "Key Access Servers", U.bind(servers_table, tab, lv), { width = left })
  UI.frame(h, keys_title(k), U.bind(keys_panel, tab, k))
end

local function search(lv, h)
  UI.search(h, lv, "Search key access servers…")
end

local function actions(h)
  h:button({ label = "New", on_click = Commands.new_server })
  UI.refresh_button(h, Store.servers, Api.load_base_key)
end

local function render(p, tab)
  local lv = Store.servers
  UI.ensure(lv)
  UI.toolbar(p, U.bind(search, lv))
  local left = math.max(32, math.floor(p:size() * 0.36))
  p:hstack({ render = U.bind(panes, tab, lv, left) })
end

function M.page()
  return { title = "KAS & Keys", actions = actions, render = render }
end

return M
