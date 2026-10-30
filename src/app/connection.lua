local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local Connections = require("core.connections")
local UI = require("components")
local Form = require("components.form")

local M = {}
local secrets = {}

local function show_connections()
  ttt.close_dialog()
  M.dialog()
end

local function form_body(form, p)
  Form.render_form(p, form, show_connections)
end

local function connected(done, err)
  if not err then
    ttt.notify("Connected to " .. S.conn.url)
  end
  if done then
    done(err)
  elseif err then
    ttt.notify(err, "error")
  end
end

local function reset_results()
  require("features.decision.store").reset()
  require("features.entitlements.store").reset()
end

local function reset_views()
  require("app.router").close_all()
  reset_results()
  for _, lv in pairs(S.lists) do
    lv.offset = 0
    lv.sel = 1
    lv.namespace = nil
    lv.attr = nil
  end
end

local function connect(item, secret, done)
  if Connections.active_id ~= item.id then
    reset_views()
  end
  reset_results()
  Api.disconnect()
  S.conn = Connections.credentials(item, secret)
  Connections.active_id = item.id
  Connections.persist()
  Api.connect(U.bind(connected, done))
end

local function with_secret(item, values, done)
  connect(item, values.client_secret, done)
end

function M.connect(item)
  item = item or Connections.find(Connections.active_id)
  if not item then
    return M.dialog()
  end
  local secret = secrets[item.id] or item.client_secret
  if secret and secret ~= "" then
    ttt.close_dialog()
    return connect(item, secret)
  end
  ttt.close_dialog()
  UI.dialog({
    title = "Connect to " .. item.name,
    submit = "Connect",
    width = 64,
    fields = { { key = "client_secret", label = "Client secret", password = true, required = true } },
    on_submit = U.bind(with_secret, item),
  })
end

function M.disconnect()
  reset_results()
  secrets[Connections.active_id or ""] = nil
  Api.disconnect()
end

local function save(id, values, done)
  local item = Connections.save(id, values)
  secrets[item.id] = values.client_secret ~= "" and values.client_secret or nil
  if Connections.active_id == item.id then
    reset_views()
    Api.disconnect()
    S.conn = Connections.credentials(item)
  end
  done()
end

function M.edit(item)
  ttt.close_dialog()
  item = item or {}
  local form = Form.new_form({
    title = item.id and "Edit Connection" or "Add Connection",
    submit = "Save",
    fields = {
      { key = "name", label = "Name", value = item.name, required = true, placeholder = "Local development" },
      { key = "url", label = "Platform URL", value = item.url or "http://localhost:8080", required = true },
      { key = "client_id", label = "Client ID", value = item.client_id or "opentdf", required = true },
      {
        key = "client_secret",
        label = "Client secret (optional)",
        value = secrets[item.id] or item.client_secret,
        password = true,
      },
      {
        key = "remember_secret",
        label = "Save client secret",
        kind = "checkbox",
        value = item.client_secret ~= nil and item.client_secret ~= "",
      },
    },
    on_submit = U.bind(save, item.id),
    on_done = show_connections,
  })
  UI.open_dialog(form.spec.title, 70, Form.form_height(form), U.bind(form_body, form))
end

local function deleted(item)
  if Connections.active_id == item.id then
    reset_views()
    M.disconnect()
    S.conn = { url = "http://localhost:8080", client_id = "opentdf", client_secret = "" }
  end
  secrets[item.id] = nil
  Connections.delete(item.id)
  if #Connections.items > 0 then
    M.dialog()
  end
  S.redraw()
end

local function delete(item)
  ttt.close_dialog()
  ttt.confirm('Delete connection "' .. item.name .. '"?', U.bind(deleted, item))
end

local function row_command(command, i)
  local item = Connections.items[i]
  if not item then
    return
  end
  if command == "connect" then
    M.connect(item)
  elseif command == "edit" then
    M.edit(item)
  elseif command == "delete" then
    delete(item)
  end
end

local function add()
  M.edit()
end

local function select_connection(dialog, i)
  dialog.selected = i
  S.redraw()
end

local function connect_selected(dialog)
  local item = Connections.items[dialog.selected]
  if item then
    M.connect(item)
  end
end

local function manager_toolbar(h)
  h:button({ label = "New Connection", on_click = add })
end

local function manager_buttons(dialog, h)
  h:button({ label = "Close", style = "muted", on_click = ttt.close_dialog })
  h:button({
    label = "Connect",
    disabled = Connections.items[dialog.selected] == nil,
    on_click = U.bind(connect_selected, dialog),
  })
end

local function manager(dialog, p)
  p:hstack({ height = 1, align = "right", margin_bottom = 1, render = manager_toolbar })
  local rows, styles = {}, {}
  for i, item in ipairs(Connections.items) do
    local name = item.name
    if item.id == Connections.active_id and S.status == "ok" then
      name = "● " .. name
    end
    styles[i] = i == dialog.selected and "selected" or "default"
    rows[i] = {
      name,
      item.url,
      item.client_id,
      item.client_secret and item.client_secret ~= "" and "Saved" or "Ask on connect",
    }
  end
  p:table({
    inset = 1,
    columns = {
      { label = "Name", min_width = 12 },
      { label = "Platform", min_width = 24 },
      { label = "Client ID", min_width = 10 },
      { label = "Secret", width = 14 },
      {
        label = "",
        actions = {
          {
            menu = {
              { label = "Edit…", command = "edit" },
              { label = "Delete", command = "delete" },
            },
          },
        },
      },
    },
    rows = rows,
    row_styles = styles,
    selected = dialog.selected,
    on_select = U.bind(select_connection, dialog),
    on_activate = U.bind(row_command, "connect"),
    on_command = row_command,
  })
  p:hstack({ height = 1, gap = 1, align = "right", render = U.bind(manager_buttons, dialog) })
end

function M.dialog()
  if #Connections.items == 0 then
    return M.edit()
  end
  local _, selected = Connections.find(Connections.active_id)
  local dialog = { selected = selected or 1 }
  UI.open_dialog("OpenTDF Connections", 100, math.min(20, #Connections.items + 7), U.bind(manager, dialog))
end

local function buttons(h)
  h:button({ label = #Connections.items == 0 and "Add Connection" or "Connect…", on_click = M.dialog })
end

function M.not_connected(p)
  local text = "Not connected."
  if S.status == "connecting" then
    text = "Connecting to " .. S.conn.url .. "…"
  elseif S.status == "error" then
    text = "✕ " .. S.message
  elseif #Connections.items == 0 then
    text = "Add a connection to get started."
  end
  p:label({ text = text, style = S.status == "error" and "danger" or "muted", margin_top = 1, padding_left = 1 })
  p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = buttons })
end

return M
