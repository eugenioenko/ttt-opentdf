local ttt = require("ttt")
local U = require("core.util")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Policy = require("shared.policy")
local Store = require("features.actions.store")
local NamespaceActions = require("shared.namespace_actions")

local M = {}

local function reload()
  NamespaceActions.forget()
  UI.load(Store.list, true)
end

local function created(name, after)
  ttt.notify("Created action " .. name)
  reload()
  Api.refresh_counts()
  if after then
    after()
  end
end

local function create(after, v, done)
  local name = U.trim(v.name)
  UI.save(SVC.ACT .. "CreateAction", { namespaceId = v.namespace, name = name }, done, U.bind(created, name, after))
end

function M.new(ns, after)
  UI.dialog({
    title = "New Action",
    submit = "Create",
    fields = {
      Policy.namespace_field(ns or Store.list.namespace),
      { key = "name", label = "Name", placeholder = "approve", required = true },
    },
    on_submit = U.bind(create, after),
  })
end

local function renamed(a, name)
  a.name = name
  NamespaceActions.forget()
end

local function rename(a, v, done)
  local name = U.trim(v.name)
  UI.save(SVC.ACT .. "UpdateAction", { id = a.id, name = name }, done, U.bind(renamed, a, name))
end

local function deleted()
  reload()
  Api.refresh_counts()
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
      on_submit = U.bind(rename, a),
    })
  elseif cmd == "delete" then
    UI.confirm(
      "Delete action " .. a.name .. "?",
      SVC.ACT .. "DeleteAction",
      { id = a.id },
      "Deleted " .. a.name,
      deleted
    )
  end
end

return M
