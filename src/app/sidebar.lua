local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local Nav = require("app.nav")
local Router = require("app.router")
local Connection = require("app.connection")
local Connections = require("core.connections")

local M = {}

local function status_item()
  local host = U.host(S.conn.url)
  local item = Connections.find(Connections.active_id)
  local name = item and item.name or S.conn.client_id
  return { id = "conn", icon = "●", label = name .. " · " .. host }
end

local function badge(key)
  local n = S.counts[key]
  if S.status ~= "ok" or not n then
    return nil
  end
  return tostring(n)
end

local function open(node)
  if node.id == "conn" then
    Connection.dialog()
  else
    Router.open(node.id)
    S.redraw()
  end
end

-- "activate" comes on every click and Enter, also for the row that is already
-- selected, which on_select misses on older ttt; arrowing only moves.
local function on_command(command, node)
  if command == "activate" then
    open(node)
  elseif command == "disconnect" then
    Connection.disconnect()
  elseif command == "connections" then
    Connection.dialog()
  elseif command:sub(1, 8) == "connect:" then
    local item = Connections.find(command:sub(9))
    if item then
      Connection.connect(item)
    end
  end
end

local function connection_menu()
  local menu = {}
  for _, item in ipairs(Connections.items) do
    menu[#menu + 1] = {
      label = item.name,
      command = "connect:" .. item.id,
      checked = item.id == Connections.active_id and (S.status == "ok" or S.status == "connecting"),
    }
  end
  menu[#menu + 1] = { separator = true }
  menu[#menu + 1] = { label = "Manage Connections…", command = "connections" }
  if S.status == "ok" or S.status == "connecting" then
    menu[#menu + 1] = { separator = true }
    menu[#menu + 1] = { label = "Disconnect", command = "disconnect" }
  end
  return menu
end

local function link_list(items, b)
  local menu
  if items[1].id == "conn" then
    menu = connection_menu()
  end
  b:list({
    items = items,
    active_id = S.active_view,
    inset = 1,
    badge_right = true,
    on_command = on_command,
    node_menu = menu,
    menu_icon = "⋮",
  })
end

local function links(p, items)
  p:box({ height = #items, render = U.bind(link_list, items) })
end

local function section(p, s)
  local muted = S.status ~= "ok"
  local items = {}
  for i, item in ipairs(s.items) do
    items[i] = { id = item.id, label = item.label, badge = item.count and badge(item.id), muted = muted }
  end
  p:label({ text = "• " .. s.title, style = "muted", margin_top = 1, padding_left = 1 })
  links(p, items)
end

local function nothing() end

local function connection_button(h)
  local label = #Connections.items == 0 and "Add Connection" or "Connect…"
  if S.status == "connecting" then
    label = "Connecting…"
  end
  h:button({ label = label, disabled = S.status == "connecting", on_click = Connection.dialog })
end

function M.render(p)
  S.panels.sidebar = p
  Api.ensure_connected()
  if S.status ~= "ok" then
    p:hstack({ height = 1, align = "center", padding_top = 1, render = connection_button })
    if S.status == "error" then
      p:label({ text = "✕ " .. S.message, style = "danger", padding_left = 1, margin_top = 1 })
    end
    return
  end
  for _, s in ipairs(Nav.sections) do
    section(p, s)
  end
  p:box({ render = nothing })
  p:divider()
  links(p, { status_item() })
end

return M
