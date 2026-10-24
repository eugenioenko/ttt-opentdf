local ttt = require("ttt")
local U = require("core.util")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Policy = require("shared.policy")
local Store = require("features.actions.store")

local M = {}

function M.new(ns, after)
  UI.dialog({
    title = "New Action",
    submit = "Create",
    fields = {
      Policy.namespace_field(ns or Store.list.namespace),
      { key = "name", label = "Name", placeholder = "approve", required = true },
    },
    on_submit = function(v, done)
      UI.save(SVC.ACT .. "CreateAction", { namespaceId = v.namespace, name = U.trim(v.name) }, done, function()
        ttt.notify("Created action " .. U.trim(v.name))
        UI.load(Store.list, true)
        Api.refresh_counts()
        if after then
          after()
        end
      end)
    end,
  })
end

function M.run(cmd, a)
  if cmd == "new" then
    M.new()
  elseif not a then
    return
  elseif a.kind == "Standard" and (cmd == "rename" or cmd == "delete") then
    ttt.notify("Standard actions can't be changed", "warning")
  elseif cmd == "rename" then
    UI.dialog({
      title = "Rename Action",
      submit = "Save",
      fields = { { key = "name", label = "Name", value = a.name, required = true } },
      on_submit = function(v, done)
        UI.save(SVC.ACT .. "UpdateAction", { id = a.id, name = U.trim(v.name) }, done, function()
          a.name = U.trim(v.name)
        end)
      end,
    })
  elseif cmd == "delete" then
    UI.confirm(
      "Delete action " .. a.name .. "?",
      SVC.ACT .. "DeleteAction",
      { id = a.id },
      "Deleted " .. a.name,
      function()
        UI.load(Store.list, true)
        Api.refresh_counts()
      end
    )
  end
end

return M
