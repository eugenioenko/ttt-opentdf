local U = require("core.util")
local S = require("core.state")
local UI = require("components")
local Store = require("features.attributes.store")
local Commands = require("features.attributes.commands")

-- The values of one attribute: shared by the Attributes page and an
-- attribute's Values tab.
local M = {}

function M.filters(p, lv, refilter, margin_top)
  UI.toolbar(p, function(h)
    UI.search(h, lv, "Filter values…", refilter)
    UI.dropdown(h, Store.VALUE_STATES, lv.vstate or "", function(value)
      lv.vstate = value
      lv.offset = 0
      refilter()
      S.redraw()
    end)
  end, margin_top or 0)
end

function M.table(p, tab, a, lv, frame)
  UI.table(p, lv, {
    frame = frame,
    noun = "values",
    columns = {
      { label = "Value" },
      { label = "Status", width = 9 },
      { label = "FQN" },
    },
    row = function(v)
      return { v.value, U.active(v.active), v.fqn or "" }
    end,
    style = U.inactive_style,
    on_open = function(v)
      Commands.value(tab, "open", a, v)
    end,
    keys = { n = "new", d = "deactivate", e = "labels" },
    menu = {
      { label = "Open", command = "open" },
      { label = "New Value", command = "new" },
      { label = "Edit Labels", command = "labels" },
      { label = "Deactivate", command = "deactivate" },
    },
    on_command = function(cmd, v)
      Commands.value(tab, cmd, a, v)
    end,
  })
end

return M
