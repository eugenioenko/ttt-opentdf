local net = require("ttt.net")
local json = require("ttt.json")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")

local Api = {}
local generation = 0

local function current(cb)
  local started = generation
  return function(...)
    if started == generation then
      cb(...)
    end
  end
end

function Api.reset()
  generation = generation + 1
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

local function on_configuration(cb, resp)
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
end

function Api.discover(cb)
  if S.token_endpoint then
    return cb(nil)
  end
  net.get_async(S.conn.url .. "/.well-known/opentdf-configuration", current(U.bind(on_configuration, cb)))
end

local function on_token(cb, resp)
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
end

local function request_token(cb, err)
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
  }, current(U.bind(on_token, cb)))
end

function Api.token(cb)
  if S.token and os.time() < S.token_exp - 30 then
    return cb(nil, S.token)
  end
  Api.discover(U.bind(request_token, cb))
end

local function on_response(cb, resp)
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
end

local function post(path, req, cb, err, token)
  if err then
    return cb(err)
  end
  net.post_async(S.conn.url .. "/" .. path, {
    headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. token },
    body = U.encode(req or {}),
  }, current(U.bind(on_response, cb)))
end

function Api.call(path, req, cb)
  if S.status == "disconnected" then
    return cb("Not connected")
  end
  Api.token(U.bind(post, path, req, cb))
end

function Api.total(data)
  return (data.pagination and data.pagination.total) or 0
end

local function set_count(key, err, data)
  if not err then
    S.counts[key] = Api.total(data)
    S.redraw()
  end
end

function Api.count(key, path, req)
  req = req or {}
  req.pagination = { limit = 1 }
  Api.call(path, req, U.bind(set_count, key))
end

function Api.refresh_counts()
  if S.status ~= "ok" then
    return
  end
  Api.count("namespaces", SVC.NS .. "ListNamespaces")
  Api.count("attributes", SVC.ATTR .. "ListAttributes")
  Api.count("actions", SVC.ACT .. "ListActions")
  Api.count("kas", SVC.KAS .. "ListKeyAccessServers")
  Api.count("keys", SVC.KAS .. "ListKeys")
  Api.count("resources", SVC.RR .. "ListRegisteredResources")
  Api.count("subject_mappings", SVC.SM .. "ListSubjectMappings")
  Api.count("condition_sets", SVC.SM .. "ListSubjectConditionSets")
end

local function by_label(a, b)
  return a.label < b.label
end

local function set_namespaces(err, data)
  if err then
    return
  end
  local list = {}
  for _, n in ipairs(data.namespaces or {}) do
    list[#list + 1] = { label = n.name, value = n.id }
  end
  table.sort(list, by_label)
  S.namespaces = list
  S.redraw()
end

local function set_providers(err, data)
  if err then
    return
  end
  local list = {}
  for _, pc in ipairs(data.providerConfigs or {}) do
    list[#list + 1] = { label = pc.name .. "  (" .. (pc.manager or "") .. ")", value = pc.id }
  end
  S.providers = list
end

local function set_base_key(err, data)
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
end

function Api.load_pickers()
  Api.call(SVC.NS .. "ListNamespaces", { pagination = { limit = 1000 } }, set_namespaces)
  Api.call(SVC.KM .. "ListProviderConfigs", { pagination = { limit = 1000 } }, set_providers)
  Api.load_base_key()
end

function Api.load_base_key()
  Api.call(SVC.KAS .. "GetBaseKey", {}, set_base_key)
end

local function on_connected(cb, err, data)
  if err then
    S.status = "error"
    S.message = err
  else
    S.status = "ok"
    S.counts.namespaces = Api.total(data)
    Api.refresh_counts()
    Api.load_pickers()
    for _, lv in pairs(S.lists) do
      lv.loaded = false
    end
  end
  S.redraw()
  if cb then
    cb(err)
  end
end

function Api.connect(cb)
  S.status = "connecting"
  S.message = ""
  Api.reset()
  S.redraw()
  Api.call(SVC.NS .. "ListNamespaces", { pagination = { limit = 1 } }, U.bind(on_connected, cb))
end

function Api.disconnect()
  Api.reset()
  S.status = "disconnected"
  S.message = ""
  S.conn.client_secret = ""
  S.counts = {}
  S.namespaces = {}
  S.providers = {}
  S.base = nil
  for _, lv in pairs(S.lists) do
    lv.gen = lv.gen + 1
    lv.loading = false
    lv.loaded = false
    lv.items = {}
    lv.all = nil
    lv.err = nil
  end
  S.redraw()
end

function Api.ensure_connected()
  if S.status == "idle" and S.configured() then
    Api.connect()
  end
end

return Api
