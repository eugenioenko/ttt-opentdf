local U = require("core.util")
local UI = require("components")
local Store = require("features.namespaces.store")
local Commands = require("features.namespaces.commands")

local M = {}

function M.page()
  return {
    title = "Namespaces",
    actions = function(h)
      h:button({ label = "New", on_click = Commands.new })
      UI.refresh_button(h, Store.list)
    end,
    render = function(p, tab)
      local lv = Store.list
      UI.ensure(lv)
      UI.toolbar(p, function(h)
        UI.search(h, lv, "Search namespaces…")
        UI.state_filter(h, lv)
      end)
      UI.table(p, lv, {
        frame = "Namespaces",
        noun = "namespaces",
        columns = {
          { label = "Name" },
          { label = "Status", width = 9 },
          { label = "Labels" },
          { label = "Created", width = 16 },
        },
        row = function(n)
          return { n.name, U.active(n.active), U.labels(n.metadata), U.created(n) }
        end,
        style = U.inactive_style,
        on_open = function(n)
          Commands.run(tab, "open", n)
        end,
        keys = { n = "new", e = "labels", d = "deactivate", a = "attributes", c = "actions" },
        menu = {
          { label = "Open", command = "open" },
          { label = "Edit Labels", command = "labels" },
          { label = "Deactivate", command = "deactivate" },
          { separator = true },
          { label = "Show Attributes", command = "attributes" },
          { label = "Show Actions", command = "actions" },
        },
        on_command = function(cmd, n)
          Commands.run(tab, cmd, n)
        end,
      })
    end,
  }
end

return M
