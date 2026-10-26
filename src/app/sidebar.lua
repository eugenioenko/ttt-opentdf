local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local Nav = require("app.nav")
local Router = require("app.router")
local Connection = require("app.connection")

local M = {}

local function status_item()
  local host = U.host(S.conn.url)
  if S.status == "ok" then
    return { id = "conn", icon = "●", label = host .. " · " .. S.conn.client_id }
  elseif S.status == "connecting" then
    return { id = "conn", icon = "◌", label = "Connecting to " .. host .. "…", muted = true }
  elseif S.status == "error" then
    return { id = "conn", icon = "✕", label = host .. " · not connected", muted = true }
  end
  return { id = "conn", icon = "○", label = "Set up connection…", muted = true }
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
  end
end

-- "activate" comes on every click and Enter, also for the row that is already
-- selected, which on_select misses on older ttt; arrowing only moves.
local function on_command(command, node)
  if command == "activate" then
    open(node)
  end
end

local function link_list(items, b)
  b:list({ items = items, inset = 1, badge_right = true, on_command = on_command })
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

function M.render(p)
  S.panels.sidebar = p
  Api.ensure_connected()
  for _, s in ipairs(Nav.sections) do
    section(p, s)
  end
  p:box({ render = nothing })
  if S.status == "error" then
    p:label({ text = "✕ " .. S.message, style = "danger", padding_left = 1 })
  end
  p:divider()
  links(p, { status_item() })
end

return M
