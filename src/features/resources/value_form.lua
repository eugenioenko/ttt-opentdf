local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local ValuePicker = require("shared.value_picker")
local NamespaceActions = require("shared.namespace_actions")
local Store = require("features.resources.store")

-- Creating and editing a resource value and the action and attribute value
-- pairs it stands for.
local M = {}

local HINT = "Each pair is an action on an attribute value that this resource value carries in decisions."

local function set_text(f, text)
  f.value = text
end

local function pick(pair, key, value)
  pair[key] = value
  S.redraw()
end

local function value_picked(pair, fqn, id)
  pair.fqn, pair.value_id = fqn, id
  S.redraw()
end

local function remove(f, i)
  table.remove(f.pairs, i)
  S.redraw()
end

local function add(f)
  f.pairs[#f.pairs + 1] = {}
  S.redraw()
end

local function action_picker(pair, b)
  local names = pair.fqn and NamespaceActions.names(NamespaceActions.namespace_id(pair.fqn))
  if not pair.fqn then
    b:label({ text = "Choose a value first", style = "muted", padding_left = 1 })
  elseif not names then
    b:label({ text = "Loading…", style = "muted", padding_left = 1 })
  else
    local options = {}
    for i, name in ipairs(names) do
      options[i] = { label = name, value = name }
    end
    UI.dropdown(b, options, pair.action_name, U.bind(pick, pair, "action_name"))
  end
end

local function value_text(pair, b)
  b:label({ text = pair.fqn or "Choose an attribute value", style = pair.fqn and "default" or "muted", padding_left = 1 })
end

local function pair_row(f, i, pair, h)
  UI.frame(h, "Attribute value", U.bind(value_text, pair))
  UI.button_box(
    h,
    "Choose…",
    U.bind(
      ValuePicker.open,
      U.bind(value_picked, pair),
      "Choose Attribute Value",
      "Enter or double-click chooses the value."
    )
  )
  UI.frame(h, "Action", U.bind(action_picker, pair), { width = 24 })
  UI.button_box(h, "Remove", U.bind(remove, f, i))
end

local function footer(f, h)
  h:button({ label = "+ Action and Attribute Value", on_click = U.bind(add, f) })
end

local function content(f, p)
  p:input({
    border = true,
    title = "Value",
    value = f.value,
    placeholder = "prod",
    autofocus = true,
    margin_top = 1,
    on_change = U.bind(set_text, f),
  })
  p:label({ text = HINT, style = "muted", padding_left = 1, margin_top = 1 })
  for i, pair in ipairs(f.pairs) do
    p:hstack({ height = 3, gap = 1, render = U.bind(pair_row, f, i, pair) })
  end
  p:hstack({ height = 1, padding_left = 1, render = U.bind(footer, f) })
end

local function saved(tab, f, err)
  f.busy = false
  f.err = err
  if err then
    S.redraw()
    return
  end
  ttt.notify((f.v and "Saved" or "Created") .. " value " .. U.trim(f.value))
  Router.back(tab)
  Store.reload_values()
  UI.load(Store.resources, true)
end

local function submit(tab, f)
  if f.busy then
    return
  end
  local value = U.trim(f.value)
  local grants = {}
  for i, pair in ipairs(f.pairs) do
    if not pair.action_name or not pair.value_id then
      f.err = "Choose an attribute value and an action in pair " .. i
      S.redraw()
      return
    end
    grants[i] = { actionName = pair.action_name, attributeValueId = pair.value_id }
  end
  if value == "" then
    f.err = "Value is required"
    S.redraw()
    return
  end
  local path, req
  if f.v then
    path = SVC.RR .. "UpdateRegisteredResourceValue"
    req = { id = f.v.id, value = value, actionAttributeValues = grants }
  else
    path = SVC.RR .. "CreateRegisteredResourceValue"
    req = { resourceId = f.r.id, value = value, actionAttributeValues = grants }
  end
  f.busy, f.err = true, nil
  S.redraw()
  Api.call(path, req, U.bind(saved, tab, f))
end

local function buttons(tab, f, h)
  h:button({ label = "Cancel", on_click = U.bind(Router.back, tab) })
  h:button({ label = f.v and "Save" or "Create", disabled = f.busy, on_click = U.bind(submit, tab, f) })
end

local function render(tab, f, p)
  p:scrollview({ render = U.bind(content, f) })
  local text, style = "", "muted"
  if f.err then
    text, style = "✕ " .. f.err, "danger"
  elseif f.busy then
    text = "Saving…"
  end
  p:label({ text = text, style = style, padding_left = 1 })
  p:hstack({ height = 1, gap = 1, align = "right", render = U.bind(buttons, tab, f) })
end

local function form_state(r, v)
  local f = { r = r, v = v, value = v and v.value or "", pairs = {} }
  for i, aav in ipairs(v and v.actionAttributeValues or {}) do
    f.pairs[i] = {
      action_name = aav.action and aav.action.name,
      fqn = aav.attributeValue and aav.attributeValue.fqn,
      value_id = aav.attributeValue and aav.attributeValue.id,
    }
  end
  return f
end

function M.open(tab, r, v)
  if not r then
    ttt.notify("Select a resource first", "warning")
    return
  end
  local f = form_state(r, v)
  Router.push(tab, {
    title = (v and ("Edit " .. v.value) or "New Value") .. " · " .. r.name,
    render = U.bind(render, tab, f),
  })
end

return M
