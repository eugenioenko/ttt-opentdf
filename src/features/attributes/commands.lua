local ttt = require("ttt")
local U = require("core.util")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Store = require("features.attributes.store")

local M = {}

local function pages()
  return require("features.attributes.detail_page"), require("features.attributes.value_page")
end

local function reload()
  UI.load(Store.attributes, true)
end

local function attribute_created(name, after)
  ttt.notify("Created attribute " .. name)
  reload()
  Api.refresh_counts()
  if after then
    after()
  end
end

local function create_attribute(after, v, done)
  local req = { namespaceId = v.namespace, name = U.trim(v.name), rule = v.rule }
  local values = U.split(v.values, ",")
  if #values > 0 then
    req.values = values
  end
  UI.save(SVC.ATTR .. "CreateAttribute", req, done, U.bind(attribute_created, req.name, after))
end

function M.new_attribute(ns, after)
  UI.dialog({
    title = "New Attribute",
    submit = "Create",
    fields = {
      Policy.namespace_field(ns or Store.attributes.namespace),
      { key = "name", label = "Name", placeholder = "classification", required = true },
      { key = "rule", label = "Rule", kind = "enum", options = Store.RULES },
      { key = "values", label = "Values", placeholder = "secret, confidential, public" },
    },
    on_submit = U.bind(create_attribute, after),
  })
end

local function value_created(a, name, data)
  if data.value then
    Store.add_value(a, data.value)
  end
  ttt.notify("Created value " .. name)
end

local function create_value(a, v, done)
  local name = U.trim(v.value)
  UI.save(
    SVC.ATTR .. "CreateAttributeValue",
    { attributeId = a.id, value = name },
    done,
    U.bind(value_created, a, name)
  )
end

function M.new_value(a)
  UI.dialog({
    title = "New Value · " .. a.fqn,
    submit = "Create",
    fields = {
      { key = "value", label = "Value", placeholder = "confidential", required = true },
    },
    on_submit = U.bind(create_value, a),
  })
end

local function attribute_deactivated(a)
  a.active = false
  reload()
end

function M.attribute(tab, cmd, a)
  if cmd == "new" then
    M.new_attribute()
  elseif not a then
    return
  elseif cmd == "open" then
    Router.show(tab, "attribute:" .. a.id, (pages()).page(a))
  elseif cmd == "value" then
    M.new_value(a)
  elseif cmd == "labels" then
    Policy.labels_dialog("Attribute " .. a.name, a, SVC.ATTR .. "UpdateAttribute", reload)
  elseif cmd == "deactivate" then
    UI.confirm(
      "Deactivate attribute " .. a.fqn .. "? Its values are deactivated too.",
      SVC.ATTR .. "DeactivateAttribute",
      { id = a.id },
      "Deactivated " .. a.name,
      U.bind(attribute_deactivated, a)
    )
  end
end

local function value_deactivated(v)
  v.active = false
end

function M.value(tab, a, cmd, v)
  if not a then
    return
  end
  if cmd == "new" then
    M.new_value(a)
  elseif not v then
    return
  elseif cmd == "open" then
    local _, value_page = pages()
    Router.show(tab, "value:" .. v.id, value_page.page(a, v))
  elseif cmd == "labels" then
    Policy.labels_dialog("Value " .. v.value, v, SVC.ATTR .. "UpdateAttributeValue", nil)
  elseif cmd == "deactivate" then
    UI.confirm(
      "Deactivate value " .. v.fqn .. "?",
      SVC.ATTR .. "DeactivateAttributeValue",
      { id = v.id },
      "Deactivated " .. v.value,
      U.bind(value_deactivated, v)
    )
  end
end

return M
