local ttt = require("ttt")
local U = require("core.util")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Store = require("features.namespaces.store")
local Attributes = require("features.attributes")
local Actions = require("features.actions")

local M = {}

function M.new()
  UI.dialog({
    title = "New Namespace",
    submit = "Create",
    fields = {
      { key = "name", label = "Name", placeholder = "example.com", required = true },
      { key = "labels", label = "Labels", placeholder = Policy.LABELS_HINT },
    },
    on_submit = function(v, done)
      local req = { name = U.trim(v.name) }
      local labels = U.parse_labels(v.labels)
      if next(labels) then
        req.metadata = { labels = labels }
      end
      UI.save(SVC.NS .. "CreateNamespace", req, done, function()
        ttt.notify("Created namespace " .. req.name)
        UI.load(Store.list, true)
        Api.refresh_counts()
        Api.load_pickers()
      end)
    end,
  })
end

function M.run(tab, cmd, n)
  if cmd == "new" then
    M.new()
  elseif not n then
    return
  elseif cmd == "open" then
    Router.show(tab, "namespace:" .. n.id, require("features.namespaces.detail_page").page(n))
  elseif cmd == "labels" then
    Policy.labels_dialog("Namespace " .. n.name, n, SVC.NS .. "UpdateNamespace", function()
      UI.load(Store.list, true)
    end)
  elseif cmd == "deactivate" then
    UI.confirm(
      "Deactivate namespace " .. n.name .. "? Its attributes and values are deactivated too.",
      SVC.NS .. "DeactivateNamespace",
      { id = n.id },
      "Deactivated " .. n.name,
      function()
        n.active = false
        UI.load(Store.list, true)
        Api.refresh_counts()
      end
    )
  elseif cmd == "attributes" then
    Router.open_for_namespace("attributes", Attributes.store.attributes, n.id)
  elseif cmd == "actions" then
    Router.open_for_namespace("actions", Actions.store.list, n.id)
  end
end

return M
