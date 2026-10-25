local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Conditions = require("shared.conditions")
local Store = require("features.condition_sets.store")

local M = {}

local function reload()
  UI.load(Store.list, true)
  Api.refresh_counts()
end

local function set_namespace(b, value)
  b.ns = value
  S.redraw()
end

local function namespace_picker(b, h)
  UI.dropdown(h, UI.with_all("No namespace", S.namespaces), b.ns, U.bind(set_namespace, b))
end

local function namespace_row(b, h)
  UI.frame(h, "Namespace", U.bind(namespace_picker, b), { width = 40 })
  h:label({ text = "" })
end

local function before(b, p)
  p:hstack({ height = 3, margin_top = 1, render = U.bind(namespace_row, b) })
end

local function created(tab, data)
  ttt.notify("Created condition set " .. Store.short_id(data.subjectConditionSet or {}))
  Router.back(tab)
  reload()
end

-- A builder save: an error stays in the builder, success runs after.
local function saved(done, after, err, data)
  done(err)
  if not err then
    after(data)
  end
end

local function create(tab, b, subject_sets, done)
  local req = { subjectConditionSet = { subjectSets = subject_sets } }
  if b.ns ~= "" then
    req.namespaceId = b.ns
  end
  Api.call(SVC.SM .. "CreateSubjectConditionSet", req, U.bind(saved, done, U.bind(created, tab)))
end

function M.new(tab, ns)
  local b = Conditions.builder({ submit = "Create", on_cancel = U.bind(Router.back, tab) })
  b.ns = ns or Store.list.namespace or ""
  b.opts.before = U.bind(before, b)
  b.opts.on_save = U.bind(create, tab, b)
  Router.push(tab, { title = "New Condition Set", render = U.bind(Conditions.render_builder, b) })
end

local function updated(tab, scs, subject_sets)
  scs.subjectSets = subject_sets
  ttt.notify("Saved condition set " .. Store.short_id(scs))
  Router.back(tab)
  UI.load(Store.list, true)
end

local function update(tab, scs, subject_sets, done)
  local req = { id = scs.id, subjectSets = subject_sets }
  Api.call(SVC.SM .. "UpdateSubjectConditionSet", req, U.bind(saved, done, U.bind(updated, tab, scs, subject_sets)))
end

function M.edit(tab, scs)
  local b = Conditions.builder({ scs = scs, submit = "Save", on_cancel = U.bind(Router.back, tab) })
  b.opts.on_save = U.bind(update, tab, scs)
  Router.push(tab, { title = "Edit Conditions", render = U.bind(Conditions.render_builder, b) })
end

local function deleted(scs)
  Router.close_page("scs:" .. scs.id)
  reload()
end

function M.run(tab, cmd, scs)
  if cmd == "new" then
    M.new(tab)
  elseif not scs then
    return
  elseif cmd == "open" then
    Router.show(tab, "scs:" .. scs.id, require("features.condition_sets.detail_page").page(scs))
  elseif cmd == "edit" then
    M.edit(tab, scs)
  elseif cmd == "labels" then
    Policy.labels_dialog("condition set", scs, SVC.SM .. "UpdateSubjectConditionSet")
  elseif cmd == "delete" then
    UI.confirm(
      "Delete condition set " .. Store.short_id(scs) .. "? Subject mappings that use it must be deleted first.",
      SVC.SM .. "DeleteSubjectConditionSet",
      { id = scs.id },
      "Deleted condition set " .. Store.short_id(scs),
      U.bind(deleted, scs)
    )
  end
end

return M
