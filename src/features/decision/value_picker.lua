local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")

-- A dialog that searches attributes and lists their values, paged on the
-- client so each page shows values rather than attributes.
local M = {}

local last_search = ""

function M.open(on_pick)
  local lv = UI.list("picker", { client = true })
  lv.search = last_search
  local gen = 0
  local function fetch()
    gen = gen + 1
    local mine = gen
    lv.loading = true
    local req = { pagination = { limit = 100 } }
    if lv.search ~= "" then
      req.search = { term = lv.search }
    end
    Api.call(SVC.ATTR .. "ListAttributes", req, function(err, data)
      if mine ~= gen then
        return
      end
      lv.loading = false
      lv.err = err
      local out = {}
      for _, a in ipairs((data and data.attributes) or {}) do
        for _, v in ipairs(a.values or {}) do
          out[#out + 1] = { fqn = v.fqn, rule = U.rule(a) }
        end
      end
      lv.all = out
      lv.offset = 0
      lv.sel = 1
      UI.slice(lv)
      S.redraw()
    end)
  end
  fetch()
  UI.open_dialog("Add Attribute Value", 96, 26, function(p)
    UI.search(p, lv, "Search attributes, e.g. acme or department…", function()
      last_search = lv.search
      fetch()
    end)
    UI.table(p, lv, {
      frame = "Attribute values",
      noun = "values",
      empty = "No attribute values match",
      columns = { { label = "Attribute value" }, { label = "Rule", width = 9 } },
      row = function(r)
        return { r.fqn, r.rule }
      end,
      on_open = function(r)
        ttt.close_dialog()
        on_pick(r.fqn)
      end,
    })
    p:label({ text = "Enter or double-click adds the value.", style = "muted" })
  end)
end

return M
