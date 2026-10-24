local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Store = require("features.kas.store")

local M = {}

local function needs_private(vals)
  return vals.mode == "KEY_MODE_CONFIG_ROOT_KEY" or vals.mode == "KEY_MODE_PROVIDER_ROOT_KEY"
end

local function needs_provider(vals)
  return vals.mode == "KEY_MODE_PROVIDER_ROOT_KEY" or vals.mode == "KEY_MODE_REMOTE"
end

-- Creating and rotating share one form: rotating sends the same fields as the
-- replacement key and the platform marks the old key as rotated.
function M.open(tab, kas, rotating)
  if not rotating and (not kas or kas.all) then
    ttt.notify("Select a key access server first", "warning")
    return
  end
  local old = rotating and rotating.key or {}
  local target = rotating and U.host(rotating.kasUri) or (kas.name or U.host(kas.uri))
  local form = UI.new_form({
    submit = rotating and "Rotate" or "Create Key",
    fields = {
      { key = "key_id", label = "Key ID", required = true, placeholder = rotating and (old.keyId .. "-2") or "r1" },
      { key = "alg", label = "Algorithm", kind = "enum", options = Store.ALGS, value = old.keyAlgorithm },
      { key = "mode", label = "Mode", kind = "enum", options = Store.MODES, value = old.keyMode },
      {
        key = "pem",
        label = "Public key (PEM)",
        kind = "multiline",
        rows = 8,
        required = true,
        placeholder = "-----BEGIN PUBLIC KEY-----",
      },
      {
        key = "wrapped",
        label = "Wrapped private key (base64)",
        kind = "multiline",
        rows = 3,
        required = true,
        show = needs_private,
      },
      {
        key = "provider",
        label = "Provider config",
        kind = "enum",
        options = function()
          return S.providers
        end,
        show = needs_provider,
      },
    },
    on_submit = function(v, done)
      local key = {
        keyId = U.trim(v.key_id),
        keyMode = v.mode,
        publicKeyCtx = { pem = crypto.base64_encode(U.trim(v.pem) .. "\n") },
      }
      if needs_private(v) then
        key.privateKeyCtx = { keyId = U.trim(v.key_id), wrappedKey = U.trim(v.wrapped) }
      end
      if needs_provider(v) then
        key.providerConfigId = v.provider
      end
      local path, req
      if rotating then
        key.algorithm = v.alg
        path, req = SVC.KAS .. "RotateKey", { id = old.id, newKey = key }
      else
        key.keyAlgorithm = v.alg
        key.kasId = kas.id
        path, req = SVC.KAS .. "CreateKey", key
      end
      UI.save(path, req, done, function()
        ttt.notify((rotating and "Rotated to " or "Created key ") .. key.keyId)
        Router.back(tab)
        Store.invalidate_keys()
        UI.load(Store.keys, true)
        UI.load(Store.servers, true)
        Api.refresh_counts()
      end)
    end,
  })
  Router.push(tab, {
    title = (rotating and ("Rotate " .. old.keyId) or "New Key") .. " · " .. target,
    render = function(p)
      local w = p:size()
      p:hstack({
        render = function(h)
          h:box({
            width = math.min(w, 96),
            padding_top = 1,
            render = function(b)
              UI.render_form(b, form, function()
                Router.back(tab)
              end)
            end,
          })
        end,
      })
    end,
  })
end

return M
