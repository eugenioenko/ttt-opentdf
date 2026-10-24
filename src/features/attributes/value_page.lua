local U = require("core.util")
local UI = require("components")
local Policy = require("shared.policy")
local Commands = require("features.attributes.commands")

local M = {}

function M.page(a, v)
  return {
    title = v.value,
    actions = function(h, tab)
      Policy.actions(h, v, function(cmd)
        Commands.value(tab, cmd, a, v)
      end)
    end,
    render = function(p)
      p:keyvalue(UI.kv({
        { "FQN", v.fqn },
        { "Attribute", a.fqn },
        { "Value", v.value },
        { "Status", U.active(v.active) },
        { "Labels", U.labels(v.metadata) },
        { "ID", v.id },
      }))
    end,
  }
end

return M
