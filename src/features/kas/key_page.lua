local U = require("core.util")
local UI = require("components")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")

local M = {}

function M.page(kk)
  local key = kk.key or {}
  return {
    title = key.keyId or "key",
    actions = function(h, tab)
      h:button({
        label = "Rotate",
        on_click = function()
          Commands.key(tab, "rotate", kk)
        end,
      })
      if Store.can_be_base(kk) then
        h:button({
          label = "Set Base",
          on_click = function()
            Commands.key(tab, "base", kk)
          end,
        })
      end
    end,
    render = function(p)
      p:keyvalue(UI.kv({
        { "Key ID", key.keyId },
        { "KAS", kk.kasUri },
        { "Algorithm", U.alg(key.keyAlgorithm) },
        { "Mode", U.human(key.keyMode, "KEY_MODE_") },
        { "Status", U.human(key.keyStatus, "KEY_STATUS_") },
        { "Base key", Store.is_base(kk) and "Yes" or "No" },
        { "Provider", key.providerConfig and key.providerConfig.name or "" },
        { "ID", key.id },
        { "Created", U.created(key) },
      }))
      local pem = Store.pem(kk)
      if pem then
        p:markdown({ text = "**Public key**\n\n```\n" .. pem .. "\n```", margin_top = 1, padding_left = 1 })
      end
    end,
  }
end

return M
