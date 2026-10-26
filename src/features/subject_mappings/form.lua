local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Conditions = require("shared.conditions")
local ValuePicker = require("shared.value_picker")
local NamespaceActions = require("shared.namespace_actions")
local ConditionSets = require("features.condition_sets.store")
local ConditionSetPicker = require("features.condition_sets.picker")
local Store = require("features.subject_mappings.store")

-- Creating and editing a subject mapping: the attribute value, its actions and
-- an existing or new condition set.
local M = {}

local MODES = {
  { label = "Use an existing set", value = "existing" },
  { label = "Create a new set", value = "new" },
}

local PER_ROW = 5

local function set(f, key, value)
  f[key] = value
  S.redraw()
end

local function toggle(f, name, checked)
  f.chosen[name] = checked or nil
end

-- The actions of the chosen value's namespace, or nil while they load.
local function action_names(f)
  return NamespaceActions.names(NamespaceActions.namespace_id(f.value_fqn))
end

local function value_picked(f, fqn, id)
  f.value_fqn, f.value_id = fqn, id
  S.redraw()
end

local function value_text(f, b)
  b:label({
    text = f.value_fqn or "Choose an attribute value",
    style = f.value_fqn and "default" or "muted",
    padding_left = 1,
  })
end

local function value_row(f, h)
  UI.frame(h, "Attribute value", U.bind(value_text, f))
  if not f.sm then
    UI.button_box(
      h,
      "Choose…",
      U.bind(
        ValuePicker.open,
        U.bind(value_picked, f),
        "Choose Attribute Value",
        "Enter or double-click chooses the value."
      ),
      false,
      "bracket"
    )
  end
end

local function checkbox_row(f, names, first, h)
  for i = first, math.min(first + PER_ROW - 1, #names) do
    UI.checkbox(h, names[i], f.chosen[names[i]] == true, U.bind(toggle, f, names[i]))
  end
end

local function actions_body(f, b)
  local names, err = action_names(f)
  if not f.value_fqn then
    b:label({ text = "Choose an attribute value to see its namespace's actions", style = "muted", padding_left = 1 })
  elseif err then
    b:label({ text = "✕ " .. err, style = "danger", padding_left = 1 })
  elseif not names then
    b:label({ text = "Loading actions…", style = "muted", padding_left = 1 })
  else
    for first = 1, #names, PER_ROW do
      b:hstack({ height = 1, gap = 2, render = U.bind(checkbox_row, f, names, first) })
    end
  end
end

local function namespace_picker(f, b)
  UI.dropdown(b, UI.with_all("No namespace", S.namespaces), f.ns, U.bind(set, f, "ns"))
end

local function mode_picker(f, b)
  UI.dropdown(b, MODES, f.mode, U.bind(set, f, "mode"))
end

local function scs_text(f, b)
  local text = f.scs and Conditions.summary(f.scs) or "Choose a condition set"
  b:label({ text = text, style = f.scs and "default" or "muted", padding_left = 1 })
end

local function scs_row(f, h)
  if not f.sm then
    UI.frame(h, "Namespace", U.bind(namespace_picker, f), { width = 32 })
  end
  UI.frame(h, "Condition set", U.bind(mode_picker, f), { width = 26 })
  if f.mode == "existing" then
    UI.frame(h, "Selected", U.bind(scs_text, f))
    UI.button_box(h, "Choose…", U.bind(ConditionSetPicker.open, U.bind(set, f, "scs")), false, "bracket")
  else
    h:label({ text = "" })
  end
end

local function before(f, p)
  p:hstack({ height = 3, gap = 1, margin_top = 1, render = U.bind(value_row, f) })
  local names = action_names(f)
  local rows = names and math.max(math.ceil(#names / PER_ROW), 1) or 1
  UI.frame(p, "Actions", U.bind(actions_body, f), { height = rows + 2 })
  p:hstack({ height = 3, gap = 1, render = U.bind(scs_row, f) })
end

local function new_sets_shown(f)
  return f.mode == "new"
end

local function chosen_actions(f)
  local out = {}
  for _, name in ipairs(action_names(f) or {}) do
    if f.chosen[name] then
      out[#out + 1] = { name = name }
    end
  end
  return out
end

local function refetched(sm, err, data)
  if not err and data.subjectMapping then
    for k, v in pairs(data.subjectMapping) do
      sm[k] = v
    end
    S.redraw()
  end
end

local function saved(tab, f, done, err)
  done(err)
  if err then
    return
  end
  ttt.notify((f.sm and "Saved" or "Created") .. " subject mapping for " .. (f.value_fqn or ""))
  Router.close_form(tab, f.key)
  UI.load(Store.list, true)
  UI.load(ConditionSets.list, true)
  Api.refresh_counts()
  if f.sm then
    Api.call(SVC.SM .. "GetSubjectMapping", { id = f.sm.id }, U.bind(refetched, f.sm))
  end
end

local function update(tab, f, actions, done, scs_id)
  local req = { id = f.sm.id, subjectConditionSetId = scs_id, actions = actions }
  Api.call(SVC.SM .. "UpdateSubjectMapping", req, U.bind(saved, tab, f, done))
end

local function scs_created(tab, f, actions, done, err, data)
  if err then
    return done(err)
  end
  update(tab, f, actions, done, data.subjectConditionSet.id)
end

local function namespace_id(f)
  if f.sm then
    return f.sm.namespace and f.sm.namespace.id or ""
  end
  return f.ns
end

local function submit(tab, f, subject_sets, done)
  local actions = chosen_actions(f)
  if not f.value_id then
    return done("Choose an attribute value")
  elseif #actions == 0 then
    return done("Choose at least one action")
  elseif f.mode == "existing" and not f.scs then
    return done("Choose a condition set")
  end
  local ns = namespace_id(f)
  if f.sm and f.mode == "new" then
    local req = { subjectConditionSet = { subjectSets = subject_sets } }
    if ns ~= "" then
      req.namespaceId = ns
    end
    Api.call(SVC.SM .. "CreateSubjectConditionSet", req, U.bind(scs_created, tab, f, actions, done))
  elseif f.sm then
    update(tab, f, actions, done, f.scs.id)
  else
    local req = { attributeValueId = f.value_id, actions = actions }
    if f.mode == "new" then
      req.newSubjectConditionSet = { subjectSets = subject_sets }
    else
      req.existingSubjectConditionSetId = f.scs.id
    end
    if ns ~= "" then
      req.namespaceId = ns
    end
    Api.call(SVC.SM .. "CreateSubjectMapping", req, U.bind(saved, tab, f, done))
  end
end

local function form_state(sm)
  local f = { sm = sm, chosen = {}, ns = Store.list.namespace or "", mode = sm and "existing" or "new" }
  if sm then
    f.value_fqn = Store.fqn(sm)
    f.value_id = sm.attributeValue and sm.attributeValue.id
    f.scs = sm.subjectConditionSet
    for _, a in ipairs(sm.actions or {}) do
      f.chosen[a.name] = true
    end
  end
  return f
end

function M.open(tab, sm)
  local f = form_state(sm)
  f.key = sm and ("sm:edit:" .. sm.id) or "sm:new"
  local b = Conditions.builder({
    submit = sm and "Save" or "Create",
    on_cancel = U.bind(Router.close_form, tab, f.key),
    before = U.bind(before, f),
    show_sets = U.bind(new_sets_shown, f),
    on_save = U.bind(submit, tab, f),
  })
  Router.open_form(tab, f.key, {
    title = sm and "Edit Subject Mapping" or "New Subject Mapping",
    render = U.bind(Conditions.render_builder, b),
  })
end

return M
