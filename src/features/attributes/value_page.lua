local U = require("core.util")
local UI = require("components")
local Policy = require("shared.policy")
local Commands = require("features.attributes.commands")

local M = {}

local function actions(a, v, h, tab)
  Policy.actions(h, v, U.bind(Commands.value, tab, a))
end

local function render(a, v, p)
  p:keyvalue(UI.kv({
    { "FQN", v.fqn },
    { "Attribute", a.fqn },
    { "Value", v.value },
    { "Status", U.active(v.active) },
    { "Labels", U.labels(v.metadata) },
    { "ID", v.id },
  }))
end

function M.page(a, v)
  return { title = v.value, actions = U.bind(actions, a, v), render = U.bind(render, a, v) }
end

return M
