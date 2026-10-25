local U = require("core.util")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Store = require("features.subject_mappings.store")
local Form = require("features.subject_mappings.form")

local M = {}

local function deleted(sm)
  Router.close_page("sm:" .. sm.id)
  UI.load(Store.list, true)
  Api.refresh_counts()
end

local function open_condition_set(tab, sm)
  if sm.subjectConditionSet then
    require("features.condition_sets.commands").run(tab, "open", sm.subjectConditionSet)
  end
end

function M.run(tab, cmd, sm)
  if cmd == "new" then
    Form.open(tab, nil)
  elseif not sm then
    return
  elseif cmd == "open" then
    Router.show(tab, "sm:" .. sm.id, require("features.subject_mappings.detail_page").page(sm))
  elseif cmd == "edit" then
    Form.open(tab, sm)
  elseif cmd == "conditions" then
    open_condition_set(tab, sm)
  elseif cmd == "labels" then
    Policy.labels_dialog("subject mapping", sm, SVC.SM .. "UpdateSubjectMapping")
  elseif cmd == "delete" then
    UI.confirm(
      "Delete the subject mapping for " .. Store.fqn(sm) .. "?",
      SVC.SM .. "DeleteSubjectMapping",
      { id = sm.id },
      "Deleted subject mapping",
      U.bind(deleted, sm)
    )
  end
end

return M
