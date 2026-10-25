local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Conditions = require("shared.conditions")
local Store = require("features.condition_sets.store")
local Commands = require("features.condition_sets.commands")

local M = {}

local MAPPING_COLUMNS = {
  { label = "Attribute value" },
  { label = "Actions", width = 28 },
  { label = "Created", width = 16 },
}

local function mapping_row(sm)
  return { sm.attributeValue and sm.attributeValue.fqn or "", U.action_names(sm.actions), U.created(sm) }
end

local function mappings_loaded(lv, err, data)
  lv.loading = false
  lv.err = err
  lv.all = (data and data.associatedSubjectMappings) or {}
  UI.slice(lv)
  S.redraw()
end

local function load_mappings(scs, lv)
  lv.loading = true
  Api.call(SVC.SM .. "GetSubjectConditionSet", { id = scs.id }, U.bind(mappings_loaded, lv))
end

local function tabs(lv)
  local n = lv.loaded and (" (" .. #(lv.all or {}) .. ")") or ""
  return { { id = "details", label = "Details" }, { id = "mappings", label = "Subject Mappings" .. n } }
end

local function conditions_body(scs, b)
  Conditions.view(b, scs)
end

local function details(p, scs)
  p:keyvalue(UI.kv({
    { "Namespace", Store.namespace(scs) },
    { "Labels", U.labels(scs.metadata) },
    { "ID", scs.id },
    { "Created", U.created(scs) },
    { "Updated", U.updated(scs) },
  }))
  UI.frame(p, "Conditions", U.bind(conditions_body, scs), { margin_top = 1 })
end

local function open_mapping(tab, sm)
  require("features.subject_mappings.commands").run(tab, "open", sm)
end

local function mappings(p, tab, lv)
  UI.table(p, lv, {
    frame = "Subject mappings using this condition set",
    noun = "subject mappings",
    empty = "No subject mappings use this condition set",
    columns = MAPPING_COLUMNS,
    row = mapping_row,
    on_open = U.bind(open_mapping, tab),
    frame_opts = { margin_top = 1 },
  })
end

local function actions(scs, h, tab)
  h:button({ label = "Edit", on_click = U.bind(Commands.run, tab, "edit", scs) })
  h:button({ label = "Labels", on_click = U.bind(Commands.run, tab, "labels", scs) })
  h:button({ label = "Delete", on_click = U.bind(Commands.run, tab, "delete", scs) })
end

local function render(page, scs, lv, p, tab)
  if not lv.loaded and not lv.loading then
    load_mappings(scs, lv)
  end
  if Router.tab_strip(p, page, tabs(lv)) == "mappings" then
    mappings(p, tab, lv)
  else
    details(p, scs)
  end
end

function M.page(scs)
  local page = { title = "Condition set " .. Store.short_id(scs) }
  local lv = UI.sub_list("scs-mappings:" .. scs.id, { client = true })
  lv.loaded = false
  page.actions = U.bind(actions, scs)
  page.render = U.bind(render, page, scs, lv)
  return page
end

return M
