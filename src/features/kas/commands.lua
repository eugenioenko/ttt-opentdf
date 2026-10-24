local ttt = require("ttt")
local U = require("core.util")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Store = require("features.kas.store")
local KeyForm = require("features.kas.key_form")

local M = {}

local function fields(k)
  k = k or {}
  return {
    { key = "name", label = "Name", value = k.name, placeholder = "kas-us-east-1" },
    { key = "uri", label = "URI", value = k.uri, placeholder = "https://kas.example.com", required = true },
    {
      key = "source",
      label = "Source",
      kind = "enum",
      options = Store.SOURCES,
      value = k.sourceType or "SOURCE_TYPE_INTERNAL",
    },
  }
end

local function request(v, id)
  local req = { id = id, uri = U.trim(v.uri), sourceType = v.source }
  if U.trim(v.name) ~= "" then
    req.name = U.trim(v.name)
  end
  return req
end

function M.new_server()
  UI.dialog({
    title = "New Key Access Server",
    submit = "Create",
    fields = fields(nil),
    on_submit = function(v, done)
      local req = request(v)
      UI.save(SVC.KAS .. "CreateKeyAccessServer", req, done, function()
        ttt.notify("Created key access server " .. (req.name or req.uri))
        UI.load(Store.servers, true)
        Api.refresh_counts()
      end)
    end,
  })
end

function M.edit_server(k)
  UI.dialog({
    title = "Edit Key Access Server",
    submit = "Save",
    fields = fields(k),
    on_submit = function(v, done)
      local req = request(v, k.id)
      UI.save(SVC.KAS .. "UpdateKeyAccessServer", req, done, function()
        k.name, k.uri, k.sourceType = req.name, req.uri, req.sourceType
      end)
    end,
  })
end

function M.server(tab, cmd, k)
  if cmd == "new" then
    M.new_server()
  elseif not k or k.all then
    return
  elseif cmd == "open" then
    Router.push(tab, require("features.kas.detail_page").page(k))
  elseif cmd == "edit" then
    M.edit_server(k)
  elseif cmd == "key" then
    KeyForm.open(tab, k, nil)
  elseif cmd == "delete" then
    UI.confirm(
      "Delete key access server " .. (k.name or k.uri) .. "?",
      SVC.KAS .. "DeleteKeyAccessServer",
      { id = k.id },
      "Deleted " .. (k.name or k.uri),
      function()
        UI.load(Store.servers, true)
        Api.refresh_counts()
      end
    )
  end
end

function M.key(tab, cmd, kk)
  if not kk or not kk.key then
    return
  end
  if cmd == "open" then
    Router.push(tab, require("features.kas.key_page").page(kk))
  elseif cmd == "rotate" then
    KeyForm.open(tab, nil, kk)
  elseif cmd == "base" and not Store.can_be_base(kk) then
    if kk.key.keyMode == "KEY_MODE_PUBLIC_KEY_ONLY" then
      ttt.notify(
        "A public-key-only key can't be the base key: the platform has no private key to decrypt with",
        "warning"
      )
    elseif Store.is_base(kk) then
      ttt.notify(kk.key.keyId .. " is already the base key")
    else
      ttt.notify("Only an active key can be the base key", "warning")
    end
  elseif cmd == "base" then
    UI.confirm(
      "Make " .. kk.key.keyId .. " on " .. U.host(kk.kasUri) .. " the base key? New TDFs use it by default.",
      SVC.KAS .. "SetBaseKey",
      { id = kk.key.id },
      "Base key is now " .. kk.key.keyId,
      function()
        Api.load_base_key()
      end
    )
  end
end

return M
