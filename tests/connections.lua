package.path = "src/?.lua;src/?/init.lua;" .. package.path
unpack = unpack or table.unpack

local function clone(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = clone(v)
  end
  return out
end

local saved, responses, pending = {}, {}, {}
package.preload["ttt.storage"] = function()
  return {
    get = function(key)
      return clone(saved[key])
    end,
    set = function(key, value)
      saved[key] = clone(value)
    end,
    remove = function(key)
      saved[key] = nil
    end,
  }
end
package.preload["ttt.json"] = function()
  return {
    encode = function()
      return "{}"
    end,
    decode = function(body)
      return responses[body]
    end,
  }
end
package.preload["ttt.net"] = function()
  return {
    get_async = function(url, cb)
      pending[#pending + 1] = { url = url, cb = cb }
    end,
    post_async = function(url, opts, cb)
      pending[#pending + 1] = { url = url, opts = opts, cb = cb }
    end,
  }
end

saved.connection = { url = "http://legacy", client_id = "old", client_secret = "old-secret" }
local Profiles = require("core.connections")
assert(#Profiles.items == 1 and Profiles.active_id == "1")
assert(saved.connection == nil and saved.connections[1].client_secret == "old-secret")
package.loaded["core.connections"] = nil
Profiles = require("core.connections")
assert(#Profiles.items == 1)

local first = Profiles.save(nil, {
  name = " Staging ",
  url = " http://staging/ ",
  client_id = " admin ",
  client_secret = "session-secret",
  remember_secret = false,
})
assert(first.name == "Staging" and first.url == "http://staging" and first.client_id == "admin")
assert(saved.connections[2].client_secret == nil)
local second = Profiles.save(nil, {
  name = "Production",
  url = "http://production",
  client_id = "admin",
  client_secret = "saved-secret",
  remember_secret = true,
})
assert(#Profiles.items == 3 and saved.connections[3].client_secret == "saved-secret")
assert(Profiles.credentials(first, "prompted-secret").client_secret == "prompted-secret")
assert(Profiles.credentials(second).client_secret == "saved-secret")
Profiles.save(second.id, {
  name = "Renamed",
  url = second.url,
  client_id = second.client_id,
  client_secret = "saved-secret",
  remember_secret = false,
})
assert(#Profiles.items == 3 and saved.connections[3].client_secret == nil)
Profiles.active_id = first.id
Profiles.persist()
Profiles.delete(second.id)
assert(#Profiles.items == 2 and Profiles.active_id == first.id)
Profiles.delete(first.id)
assert(#Profiles.items == 1 and Profiles.active_id == nil and saved.active_connection == nil)

local S = require("core.state")
local Api = require("core.api")
S.conn = { url = "http://one", client_id = "a", client_secret = "secret" }
Api.connect()
assert(#pending == 1 and S.status == "connecting")
local old_discovery = table.remove(pending, 1)
Api.disconnect()
Api.ensure_connected()
assert(S.status == "disconnected" and #pending == 0 and S.token == nil and S.conn.client_secret == "")
responses.discovery = { idp = { token_endpoint = "http://idp/token" } }
old_discovery.cb({ status = 200, body = "discovery" })
assert(#pending == 0 and S.token_endpoint == nil and S.status == "disconnected")

local function reply(body)
  local req = table.remove(pending, 1)
  assert(req, "expected a request")
  req.cb({ status = 200, body = body })
  return req
end
S.conn = { url = "http://two", client_id = "b", client_secret = "secret" }
Api.connect()
reply("discovery")
responses.token = { access_token = "token-two", expires_in = 300 }
reply("token")
local old_connect = table.remove(pending, 1)
responses.list = { pagination = { total = 7 } }
Api.disconnect()
S.conn = { url = "http://three", client_id = "c", client_secret = "secret" }
Api.connect()
old_connect.cb({ status = 200, body = "list" })
assert(S.status == "connecting" and next(S.counts) == nil and #pending == 1)
reply("discovery")
local old_token = table.remove(pending, 1)
Api.disconnect()
old_token.cb({ status = 200, body = "token" })
assert(S.token == nil and #pending == 0)

S.conn = { url = "http://four", client_id = "d", client_secret = "secret" }
Api.connect()
reply("discovery")
reply("token")
reply("list")
assert(S.status == "ok" and S.counts.namespaces == 7 and #pending > 0)
local old_counts = pending
pending = {}
S.lists.test = { gen = 4, loaded = true, loading = true, items = { "old" } }
Api.disconnect()
for _, req in ipairs(old_counts) do
  req.cb({ status = 200, body = "list" })
end
assert(S.status == "disconnected" and next(S.counts) == nil and S.token == nil)
assert(S.lists.test.gen == 5 and not S.lists.test.loading and #S.lists.test.items == 0)
Api.refresh_counts()
Api.ensure_connected()
assert(#pending == 0)
print("connections: migration, secret storage, editing, deletion, disconnect and stale responses passed")
