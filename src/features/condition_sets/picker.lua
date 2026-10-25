local ttt = require("ttt")
local U = require("core.util")
local UI = require("components")
local Conditions = require("shared.conditions")
local Store = require("features.condition_sets.store")

local M = {}

local COLUMNS = { { label = "Conditions" }, { label = "Namespace", width = 20 }, { label = "ID", width = 8 } }

local function row(scs)
  return { Conditions.summary(scs), Store.namespace(scs), Store.short_id(scs) }
end

local function choose(on_pick, scs)
  ttt.close_dialog()
  on_pick(scs)
end

local function body(lv, on_pick, p)
  UI.search(p, lv, "Search labels…")
  UI.table(p, lv, {
    frame = "Subject condition sets",
    noun = "condition sets",
    columns = COLUMNS,
    row = row,
    on_open = U.bind(choose, on_pick),
  })
  p:label({ text = "Enter or double-click chooses the condition set.", style = "muted" })
end

function M.open(on_pick)
  local lv = UI.list("scs-picker", Store.SPEC)
  UI.load(lv)
  UI.open_dialog("Choose Condition Set", 110, 26, U.bind(body, lv, on_pick))
end

return M
