local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local SVC = require("core.services")
local Api = require("core.api")
local UI = require("components")

-- A dialog that searches attributes and lists their values, paged on the
-- client so each page shows values rather than attributes.
local M = {}

local COLUMNS = { { label = "Attribute value" }, { label = "Rule", width = 9 } }

local last_search = ""

local function fetched(lv, gen, err, data)
  if gen ~= lv.gen then
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
end

local function fetch(lv)
  lv.gen = lv.gen + 1
  lv.loading = true
  local req = { pagination = { limit = 100 } }
  if lv.search ~= "" then
    req.search = { term = lv.search }
  end
  Api.call(SVC.ATTR .. "ListAttributes", req, U.bind(fetched, lv, lv.gen))
end

local function search(lv)
  last_search = lv.search
  fetch(lv)
end

local function row(r)
  return { r.fqn, r.rule }
end

local function choose(on_pick, r)
  ttt.close_dialog()
  on_pick(r.fqn)
end

local function body(lv, on_pick, p)
  UI.search(p, lv, "Search attributes, e.g. acme or department…", U.bind(search, lv))
  UI.table(p, lv, {
    frame = "Attribute values",
    noun = "values",
    empty = "No attribute values match",
    columns = COLUMNS,
    row = row,
    on_open = U.bind(choose, on_pick),
  })
  p:label({ text = "Enter or double-click adds the value.", style = "muted" })
end

function M.open(on_pick)
  local lv = UI.list("picker", { client = true })
  lv.search = last_search
  fetch(lv)
  UI.open_dialog("Add Attribute Value", 96, 26, U.bind(body, lv, on_pick))
end

return M
