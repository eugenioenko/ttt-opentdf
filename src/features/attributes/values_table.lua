local U = require("core.util")
local S = require("core.state")
local UI = require("components")
local Store = require("features.attributes.store")
local Commands = require("features.attributes.commands")

-- The values of one attribute: shared by the Attributes page and an
-- attribute's Values tab.
local M = {}

local COLUMNS = {
  { label = "Value" },
  { label = "Status", width = 9 },
  { label = "FQN" },
}

local KEYS = { n = "new", d = "deactivate", e = "labels" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "New Value", command = "new" },
  { label = "Edit Labels", command = "labels" },
  { label = "Deactivate", command = "deactivate" },
}

local function row(v)
  return { v.value, U.active(v.active), v.fqn or "" }
end

local function set_state(lv, refilter, value)
  lv.vstate = value
  lv.offset = 0
  refilter()
  S.redraw()
end

local function filter_row(lv, refilter, h)
  UI.search(h, lv, "Filter values…", refilter)
  UI.dropdown(h, Store.VALUE_STATES, lv.vstate or "", U.bind(set_state, lv, refilter))
end

function M.filters(p, lv, refilter, margin_top)
  UI.toolbar(p, U.bind(filter_row, lv, refilter), margin_top or 0)
end

function M.table(p, tab, a, lv, frame)
  UI.table(p, lv, {
    frame = frame,
    noun = "values",
    columns = COLUMNS,
    row = row,
    style = U.inactive_style,
    on_open = U.bind(Commands.value, tab, a, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.value, tab, a),
  })
end

return M
