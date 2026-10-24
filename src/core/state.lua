local storage = require("ttt.storage")

local S = {}

S.conn = storage.get("connection") or {}
S.conn.url = S.conn.url or "http://localhost:8080"
S.conn.client_id = S.conn.client_id or "opentdf"
S.conn.client_secret = S.conn.client_secret or ""
S.settings = storage.get("settings") or {}
S.page_size = tonumber(S.settings.page_size) or 50
S.status = "idle"
S.message = ""
S.token = nil
S.token_exp = 0
S.token_endpoint = nil
S.counts = {}
S.namespaces = {}
S.providers = {}
S.base = nil
S.panels = {}
S.lists = {}

function S.redraw()
  for _, p in pairs(S.panels) do
    pcall(function()
      p:redraw()
    end)
    return
  end
end

function S.configured()
  return S.conn.client_secret ~= "" and S.conn.url ~= ""
end

function S.reset_lists()
  for _, lv in pairs(S.lists) do
    lv.offset = 0
    lv.sel = 1
    lv.loaded = false
  end
end

return S
