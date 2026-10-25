local U = require("core.util")
local UI = require("components")
local Store = require("features.resources.store")
local Commands = require("features.resources.commands")

-- The values of one resource: shared by the Registered Resources page and a
-- resource's Values tab.
local M = {}

local COLUMNS = { { label = "Value", width = 24 }, { label = "Actions on attribute values" } }

local KEYS = { n = "new", e = "edit", l = "labels", d = "delete" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "New Value", command = "new" },
  { label = "Edit", command = "edit" },
  { label = "Edit Labels", command = "labels" },
  { label = "Delete", command = "delete" },
}

local function row(v)
  return { v.value or "", Store.grants(v) }
end

function M.table(p, tab, r, lv, frame)
  UI.table(p, lv, {
    frame = frame,
    noun = "values",
    empty = r and "No values yet" or "Select a resource",
    columns = COLUMNS,
    row = row,
    on_open = U.bind(Commands.value, tab, r, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(Commands.value, tab, r),
  })
end

return M
