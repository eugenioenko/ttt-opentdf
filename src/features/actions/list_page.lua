local U = require("core.util")
local UI = require("components")
local Store = require("features.actions.store")
local Commands = require("features.actions.commands")

local M = {}

function M.page()
  return {
    title = "Actions",
    actions = function(h)
      h:button({
        label = "New",
        on_click = function()
          Commands.new()
        end,
      })
      UI.refresh_button(h, Store.list)
    end,
    render = function(p)
      local lv = Store.list
      UI.ensure(lv)
      UI.toolbar(p, function(h)
        UI.namespace_filter(h, lv)
      end)
      UI.table(p, lv, {
        frame = "Actions",
        noun = "actions",
        columns = {
          { label = "Name" },
          { label = "Type", width = 9 },
          { label = "Namespace" },
          { label = "Created", width = 16 },
        },
        row = function(a)
          return { a.name, a.kind, a.namespace and a.namespace.name or "", U.created(a) }
        end,
        style = Store.style,
        on_open = function(a)
          Commands.run("rename", a)
        end,
        keys = { n = "new", e = "rename", d = "delete" },
        menu = {
          { label = "Rename", command = "rename" },
          { label = "Delete", command = "delete" },
        },
        on_command = Commands.run,
      })
    end,
  }
end

return M
