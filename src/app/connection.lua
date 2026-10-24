local ttt = require("ttt")
local storage = require("ttt.storage")
local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local UI = require("components")

local M = {}

local function connected(done, err)
  if err then
    return done(err)
  end
  storage.set("connection", S.conn)
  ttt.notify("Connected to " .. S.conn.url)
  done()
end

local function connect(v, done)
  local url = U.trim(v.url):gsub("/+$", "")
  S.conn = { url = url, client_id = U.trim(v.client_id), client_secret = v.client_secret }
  Api.connect(U.bind(connected, done))
end

function M.dialog()
  UI.dialog({
    title = "OpenTDF Connection",
    submit = "Connect",
    width = 70,
    fields = {
      {
        key = "url",
        label = "Platform URL",
        value = S.conn.url,
        required = true,
        placeholder = "http://localhost:8080",
      },
      { key = "client_id", label = "Client ID", value = S.conn.client_id, required = true, placeholder = "opentdf" },
      {
        key = "client_secret",
        label = "Client secret",
        value = S.conn.client_secret,
        password = true,
        required = true,
      },
    },
    on_submit = connect,
  })
end

local function buttons(h)
  h:button({ label = "Connection…", on_click = M.dialog })
  if S.configured() then
    h:button({ label = "Retry", on_click = Api.connect })
  end
end

-- Shown in a tab while there is no working connection.
function M.not_connected(p)
  local text = "Not connected."
  if S.status == "connecting" then
    text = "Connecting to " .. S.conn.url .. "…"
  elseif S.status == "error" then
    text = "✕ " .. S.message
  elseif not S.configured() then
    text = "Not configured. Set the platform URL and client credentials first."
  end
  p:label({ text = text, style = S.status == "error" and "danger" or "muted", margin_top = 1, padding_left = 1 })
  p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = buttons })
end

return M
