local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Store = require("features.resources.store")
local ValueForm = require("features.resources.value_form")

local M = {}

local function namespaces()
  return UI.with_all("No namespace", S.namespaces)
end

local function reload()
  UI.load(Store.resources, true)
  Api.refresh_counts()
end

local function created(name)
  ttt.notify("Created resource " .. name)
  reload()
end

local function create(v, done)
  local req = { name = U.trim(v.name), values = U.split(v.values, ",") }
  if v.namespace ~= "" then
    req.namespaceId = v.namespace
  end
  UI.save(SVC.RR .. "CreateRegisteredResource", req, done, U.bind(created, req.name))
end

function M.new()
  UI.dialog({
    title = "New Registered Resource",
    submit = "Create",
    fields = {
      { key = "name", label = "Name", placeholder = "document-store", required = true },
      { key = "namespace", label = "Namespace", kind = "enum", options = namespaces, value = "" },
      { key = "values", label = "Values, comma separated", placeholder = "prod, staging" },
    },
    on_submit = create,
  })
end

local function renamed(r, name)
  r.name = name
end

local function rename(r, v, done)
  local name = U.trim(v.name)
  UI.save(SVC.RR .. "UpdateRegisteredResource", { id = r.id, name = name }, done, U.bind(renamed, r, name))
end

local function deleted(r)
  Router.close_page("rr:" .. r.id)
  reload()
end

function M.resource(tab, cmd, r)
  if cmd == "new" then
    M.new()
  elseif not r then
    return
  elseif cmd == "open" then
    Router.show(tab, "rr:" .. r.id, require("features.resources.detail_page").page(r))
  elseif cmd == "edit" then
    UI.dialog({
      title = "Rename Resource",
      submit = "Save",
      fields = { { key = "name", label = "Name", value = r.name, required = true } },
      on_submit = U.bind(rename, r),
    })
  elseif cmd == "labels" then
    Policy.labels_dialog(r.name, r, SVC.RR .. "UpdateRegisteredResource")
  elseif cmd == "value" then
    ValueForm.open(tab, r, nil)
  elseif cmd == "delete" then
    UI.confirm(
      "Delete resource " .. r.name .. " and its values?",
      SVC.RR .. "DeleteRegisteredResource",
      { id = r.id },
      "Deleted " .. r.name,
      U.bind(deleted, r)
    )
  end
end

local function value_deleted(v)
  Router.close_page("rrv:" .. v.id)
  Store.reload_values()
  UI.load(Store.resources, true)
end

function M.value(tab, r, cmd, v)
  if cmd == "new" then
    ValueForm.open(tab, r, nil)
  elseif not v then
    return
  elseif cmd == "open" then
    Router.show(tab, "rrv:" .. v.id, require("features.resources.value_page").page(r, v))
  elseif cmd == "edit" then
    ValueForm.open(tab, r, v)
  elseif cmd == "labels" then
    Policy.labels_dialog(v.value, v, SVC.RR .. "UpdateRegisteredResourceValue")
  elseif cmd == "delete" then
    UI.confirm(
      "Delete value " .. v.value .. "?",
      SVC.RR .. "DeleteRegisteredResourceValue",
      { id = v.id },
      "Deleted " .. v.value,
      U.bind(value_deleted, v)
    )
  end
end

return M
