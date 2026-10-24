local SVC = require("core.services")
local UI = require("components")

local M = {}

M.RULES = {
  { label = "Any of", value = "ATTRIBUTE_RULE_TYPE_ENUM_ANY_OF" },
  { label = "All of", value = "ATTRIBUTE_RULE_TYPE_ENUM_ALL_OF" },
  { label = "Hierarchy", value = "ATTRIBUTE_RULE_TYPE_ENUM_HIERARCHY" },
}

M.VALUE_STATES = {
  { label = "Any state", value = "" },
  { label = "Active", value = "active" },
  { label = "Inactive", value = "inactive" },
}

local function request(lv)
  local req = { state = lv.state }
  if lv.namespace and lv.namespace ~= "" then
    req.namespace = lv.namespace
  end
  return req
end

local function extract(data)
  return data.attributes
end

function M.filter_values(values, lv)
  local term = (lv.search or ""):lower()
  local state = lv.vstate or ""
  local out = {}
  for _, v in ipairs(values or {}) do
    local active = v.active ~= false
    local keep = (state == "" or (state == "active") == active)
      and (term == "" or (v.value or ""):lower():find(term, 1, true))
    if keep then
      out[#out + 1] = v
    end
  end
  return out
end

-- Keeps M.values on the attribute selected in M.attributes.
function M.values_follow()
  local a = UI.selected(M.attributes)
  if M.values.attr ~= a then
    M.values.attr = a
    M.values.offset = 0
    M.values.sel = 1
  end
  M.values.all = M.filter_values(a and a.values, M.values)
  UI.slice(M.values)
end

M.attributes = UI.list("attributes", {
  method = SVC.ATTR .. "ListAttributes",
  search = true,
  request = request,
  extract = extract,
  on_loaded = M.values_follow,
})

M.values = UI.list("values", { client = true })

function M.namespace_list(ns_id)
  local lv = UI.sub_list("ns-attrs:" .. ns_id, {
    method = SVC.ATTR .. "ListAttributes",
    search = true,
    request = request,
    extract = extract,
  })
  lv.namespace = ns_id
  return lv
end

function M.attribute_values(a)
  return UI.sub_list("attr-values:" .. a.id, { client = true })
end

-- Refilters an attribute's own values list, for its Values tab.
function M.refilter(a, lv)
  lv.all = M.filter_values(a.values, lv)
  UI.slice(lv)
end

-- Selects a newly created value when its attribute is the one on screen.
function M.add_value(a, value)
  a.values = a.values or {}
  a.values[#a.values + 1] = value
  if M.values.attr == a then
    M.values.all = M.filter_values(a.values, M.values)
    M.values.offset = UI.last_page_offset(#M.values.all)
    M.values.sel = #M.values.all - M.values.offset
    UI.slice(M.values)
  end
end

return M
