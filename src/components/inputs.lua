local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local List = require("components.list")

local M = {}

M.STATES = {
  { label = "Active", value = "ACTIVE_STATE_ENUM_ACTIVE" },
  { label = "Inactive", value = "ACTIVE_STATE_ENUM_INACTIVE" },
  { label = "Any state", value = "ACTIVE_STATE_ENUM_ANY" },
}

local function run_search(lv)
  lv.offset = 0
  if lv.on_search then
    lv.on_search()
    S.redraw()
  else
    List.load(lv)
  end
end

local function set_search(lv, text)
  lv.search = text
  lv.search_later()
end

-- on_search replaces the reload, for client lists that refilter themselves.
function M.search(h, lv, placeholder, on_search)
  lv.on_search = on_search
  lv.search_later = lv.search_later or ttt.debounce(250, U.bind(run_search, lv))
  h:input({
    placeholder = placeholder or "Search…",
    prefix = "⌕ ",
    value = lv.search,
    on_change = U.bind(set_search, lv),
  })
end

local function pick(options, on_pick, command)
  local o = options[tonumber(command)]
  if o then
    on_pick(o.value)
  end
end

-- Menu commands are option positions: ttt ignores menu entries whose command is
-- empty, and "All …" options use "" as their value.
function M.dropdown(h, options, value, on_pick)
  local entries = {}
  for i, o in ipairs(options) do
    entries[i] = { label = o.label, command = tostring(i), checked = o.value == value }
  end
  h:dropdown({
    label = U.option_label(options, value) .. " ▾",
    entries = entries,
    on_menu = U.bind(pick, options, on_pick),
  })
end

function M.with_all(label, options)
  local out = { { label = label, value = "" } }
  for _, o in ipairs(options) do
    out[#out + 1] = o
  end
  return out
end

local function set_filter(lv, field, value)
  lv[field] = value
  lv.offset = 0
  List.load(lv)
end

function M.filter(h, lv, field, options)
  M.dropdown(h, options, lv[field] or "", U.bind(set_filter, lv, field))
end

function M.state_filter(h, lv)
  M.filter(h, lv, "state", M.STATES)
end

function M.namespace_filter(h, lv)
  M.filter(h, lv, "namespace", M.with_all("All namespaces", S.namespaces))
end

local function refresh(lv, also)
  List.load(lv, true)
  if also then
    also()
  end
end

function M.refresh_button(h, lv, also)
  h:button({ label = "Refresh", on_click = U.bind(refresh, lv, also) })
end

return M
