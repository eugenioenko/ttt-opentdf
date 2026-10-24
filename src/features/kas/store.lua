local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local UI = require("components")

local M = {}

M.SOURCES = {
  { label = "Internal", value = "SOURCE_TYPE_INTERNAL" },
  { label = "External", value = "SOURCE_TYPE_EXTERNAL" },
  { label = "Unspecified", value = "SOURCE_TYPE_UNSPECIFIED" },
}

M.ALGS = {
  { label = "RSA 2048", value = "ALGORITHM_RSA_2048" },
  { label = "RSA 4096", value = "ALGORITHM_RSA_4096" },
  { label = "EC P-256", value = "ALGORITHM_EC_P256" },
  { label = "EC P-384", value = "ALGORITHM_EC_P384" },
  { label = "EC P-521", value = "ALGORITHM_EC_P521" },
}

M.MODES = {
  { label = "Public key only", value = "KEY_MODE_PUBLIC_KEY_ONLY" },
  { label = "Config root key (wrapped locally)", value = "KEY_MODE_CONFIG_ROOT_KEY" },
  { label = "Provider root key (wrapped by a provider)", value = "KEY_MODE_PROVIDER_ROOT_KEY" },
  { label = "Remote (key stays in the provider)", value = "KEY_MODE_REMOTE" },
}

-- The pinned first row of the servers list.
M.ALL_KEYS = { all = true, name = "All keys" }

-- lv.kas is the server whose keys the list shows; nil or ALL_KEYS shows all.
local function keys_request(lv)
  local req = {}
  if lv.kas and not lv.kas.all then
    req.kasId = lv.kas.id
  end
  if lv.alg and lv.alg ~= "" then
    req.keyAlgorithm = lv.alg
  end
  return req
end

local function extract_keys(data)
  return data.kasKeys
end

local KEYS_SPEC = { method = SVC.KAS .. "ListKeys", search = true, request = keys_request, extract = extract_keys }

-- The keys of the server selected in M.servers.
M.keys = UI.list("keys", KEYS_SPEC)

function M.server_keys(k)
  local lv = UI.sub_list("kas-keys:" .. k.id, KEYS_SPEC)
  lv.kas = k
  return lv
end

function M.invalidate_keys()
  for name, lv in pairs(S.lists) do
    if name == "keys" or name:find("^kas%-keys:") then
      lv.loaded = false
    end
  end
end

local keys_later, keys_cancel = ttt.debounce(150, U.bind(UI.load, M.keys))

-- Arrow keys move through servers quickly, so key loads wait for a pause.
function M.keys_follow(now)
  local k = UI.selected(M.servers)
  if M.keys.kas == k and M.keys.loaded then
    return
  end
  M.keys.kas = k
  M.keys.offset = 0
  M.keys.sel = 1
  if now then
    keys_cancel()
    UI.load(M.keys)
    return
  end
  M.keys.loading = true
  keys_later()
end

local function extract_servers(data)
  local out = { M.ALL_KEYS }
  for _, k in ipairs(data.keyAccessServers or {}) do
    out[#out + 1] = k
  end
  return out
end

M.servers = UI.list("kas", {
  method = SVC.KAS .. "ListKeyAccessServers",
  search = true,
  extract = extract_servers,
  on_loaded = U.bind(M.keys_follow, true),
})

function M.is_base(kk)
  return S.base and kk.key and S.base.kid == kk.key.keyId and S.base.kas_id == kk.kasId
end

function M.can_be_base(kk)
  local key = kk and kk.key
  return key ~= nil
    and key.keyMode ~= "KEY_MODE_PUBLIC_KEY_ONLY"
    and key.keyStatus == "KEY_STATUS_ACTIVE"
    and not M.is_base(kk)
end

function M.pem(kk)
  local ctx = kk.key and kk.key.publicKeyCtx
  if not ctx or not ctx.pem then
    return nil
  end
  return crypto.base64_decode(ctx.pem) or ctx.pem
end

return M
