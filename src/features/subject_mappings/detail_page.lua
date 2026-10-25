local U = require("core.util")
local UI = require("components")
local Conditions = require("shared.conditions")
local ConditionSets = require("features.condition_sets.store")
local Store = require("features.subject_mappings.store")
local Commands = require("features.subject_mappings.commands")

local M = {}

local function conditions_body(sm, b)
  Conditions.view(b, sm.subjectConditionSet)
end

local function render(sm, p)
  local scs = sm.subjectConditionSet or {}
  p:keyvalue(UI.kv({
    { "Attribute value", Store.fqn(sm) },
    { "Actions", U.action_names(sm.actions) },
    { "Namespace", Store.namespace(sm) },
    { "Condition set", scs.id and ConditionSets.short_id(scs) or "" },
    { "Labels", U.labels(sm.metadata) },
    { "ID", sm.id },
    { "Created", U.created(sm) },
    { "Updated", U.updated(sm) },
  }))
  UI.frame(p, "Conditions", U.bind(conditions_body, sm), { margin_top = 1 })
end

local function actions(sm, h, tab)
  h:button({ label = "Edit", on_click = U.bind(Commands.run, tab, "edit", sm) })
  h:button({ label = "Condition Set", on_click = U.bind(Commands.run, tab, "conditions", sm) })
  h:button({ label = "Labels", on_click = U.bind(Commands.run, tab, "labels", sm) })
  h:button({ label = "Delete", on_click = U.bind(Commands.run, tab, "delete", sm) })
end

function M.page(sm)
  local value = sm.attributeValue and sm.attributeValue.value or "mapping"
  return {
    title = Store.fqn(sm),
    tab_title = "Mapping · " .. value,
    actions = U.bind(actions, sm),
    render = U.bind(render, sm),
  }
end

return M
