local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Store = require("features.attributes.store")
local Commands = require("features.attributes.commands")
local Values = require("features.attributes.values_table")

local M = {}

function M.page(a)
  local page = { title = a.fqn }
  local values = Store.attribute_values(a)
  page.actions = function(h, tab)
    if page.tab == "values" then
      h:button({
        label = "New",
        on_click = function()
          Commands.new_value(a)
        end,
      })
    else
      Policy.actions(h, a, function(cmd)
        Commands.attribute(tab, cmd, a)
      end)
    end
  end
  page.render = function(p, tab)
    local current = Router.tab_strip(p, page, {
      { id = "details", label = "Details" },
      { id = "values", label = "Values (" .. #(a.values or {}) .. ")" },
    })
    if current == "values" then
      local refilter = function()
        values.all = Store.filter_values(a.values, values)
        UI.slice(values)
      end
      refilter()
      Values.filters(p, values, refilter, 1)
      Values.table(p, tab, a, values, "Values")
      return
    end
    p:keyvalue(UI.kv({
      { "FQN", a.fqn },
      { "Namespace", a.namespace and a.namespace.name },
      { "Name", a.name },
      { "Rule", U.rule(a) },
      { "Status", U.active(a.active) },
      { "Values", tostring(#(a.values or {})) },
      { "Labels", U.labels(a.metadata) },
      { "ID", a.id },
      { "Created", U.created(a) },
      { "Updated", U.updated(a) },
    }))
  end
  return page
end

return M
