local net = require("ttt.net")
local json = require("ttt.json")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")

local Api = {}

function Api.reset()
  S.token = nil
  S.token_exp = 0
  S.token_endpoint = nil
end

function Api.decode(body)
  if type(body) ~= "string" or body == "" then
    return {}
  end
  local data = json.decode(body)
  if type(data) ~= "table" then
    return {}
  end
  return data
end

function Api.discover(cb)
  if S.token_endpoint then
    return cb(nil)
  end
  net.get_async(S.conn.url .. "/.well-known/opentdf-configuration", function(resp)
    if resp.error then
      return cb(resp.error)
    end
    if resp.status ~= 200 then
      return cb("well-known configuration returned HTTP " .. resp.status)
    end
    local cfg = Api.decode(resp.body)
    if not cfg.idp or not cfg.idp.token_endpoint then
      return cb("the platform does not advertise a token endpoint")
    end
    S.token_endpoint = cfg.idp.token_endpoint
    cb(nil)
  end)
end

function Api.token(cb)
  if S.token and os.time() < S.token_exp - 30 then
    return cb(nil, S.token)
  end
  Api.discover(function(err)
    if err then
      return cb(err)
    end
    net.post_async(S.token_endpoint, {
      headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
      body = U.form({
        grant_type = "client_credentials",
        client_id = S.conn.client_id,
        client_secret = S.conn.client_secret,
      }),
    }, function(resp)
      if resp.error then
        return cb(resp.error)
      end
      local data = Api.decode(resp.body)
      if resp.status ~= 200 or not data.access_token then
        return cb(data.error_description or data.error or ("token request returned HTTP " .. resp.status))
      end
      S.token = data.access_token
      S.token_exp = os.time() + (data.expires_in or 300)
      cb(nil, S.token)
    end)
  end)
end

function Api.call(path, req, cb)
  Api.token(function(err, token)
    if err then
      return cb(err)
    end
    net.post_async(S.conn.url .. "/" .. path, {
      headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. token },
      body = U.encode(req or {}),
    }, function(resp)
      if resp.error then
        return cb(resp.error)
      end
      local data = Api.decode(resp.body)
      if resp.status == 401 then
        S.token = nil
      end
      if resp.status ~= 200 then
        return cb(data.message or ("HTTP " .. resp.status))
      end
      cb(nil, data)
    end)
  end)
end

function Api.total(data)
  return (data.pagination and data.pagination.total) or 0
end

function Api.count(key, path, req)
  req = req or {}
  req.pagination = { limit = 1 }
  Api.call(path, req, function(err, data)
    if not err then
      S.counts[key] = Api.total(data)
      S.redraw()
    end
  end)
end

function Api.refresh_counts()
  Api.count("namespaces", SVC.NS .. "ListNamespaces")
  Api.count("attributes", SVC.ATTR .. "ListAttributes")
  Api.count("actions", SVC.ACT .. "ListActions")
  Api.count("kas", SVC.KAS .. "ListKeyAccessServers")
  Api.count("keys", SVC.KAS .. "ListKeys")
end

function Api.load_pickers()
  Api.call(SVC.NS .. "ListNamespaces", { pagination = { limit = 1000 } }, function(err, data)
    if err then
      return
    end
    local list = {}
    for _, n in ipairs(data.namespaces or {}) do
      list[#list + 1] = { label = n.name, value = n.id }
    end
    table.sort(list, function(a, b)
      return a.label < b.label
    end)
    S.namespaces = list
    S.redraw()
  end)
  Api.call(SVC.KM .. "ListProviderConfigs", { pagination = { limit = 1000 } }, function(err, data)
    if err then
      return
    end
    local list = {}
    for _, pc in ipairs(data.providerConfigs or {}) do
      list[#list + 1] = { label = pc.name .. "  (" .. (pc.manager or "") .. ")", value = pc.id }
    end
    S.providers = list
  end)
  Api.load_base_key()
end

function Api.load_base_key()
  Api.call(SVC.KAS .. "GetBaseKey", {}, function(err, data)
    if err then
      return
    end
    local bk = data.baseKey
    if bk and bk.publicKey and bk.publicKey.kid then
      S.base = { kas_id = bk.kasId, kid = bk.publicKey.kid }
    else
      S.base = nil
    end
    S.redraw()
  end)
end

function Api.connect(cb)
  S.status = "connecting"
  S.message = ""
  Api.reset()
  S.redraw()
  Api.call(SVC.NS .. "ListNamespaces", { pagination = { limit = 1 } }, function(err, data)
    if err then
      S.status = "error"
      S.message = err
      S.redraw()
      if cb then
        cb(err)
      end
      return
    end
    S.status = "ok"
    S.counts.namespaces = Api.total(data)
    Api.refresh_counts()
    Api.load_pickers()
    for _, lv in pairs(S.lists) do
      lv.loaded = false
    end
    S.redraw()
    if cb then
      cb(nil)
    end
  end)
end

function Api.ensure_connected()
  if S.status == "idle" and S.configured() then
    Api.connect()
  end
end

return Api
