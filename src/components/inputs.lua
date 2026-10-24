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

-- on_search replaces the reload, for client lists that refilter themselves.
function M.search(h, lv, placeholder, on_search)
  lv.on_search = on_search
  lv.search_later = lv.search_later
    or ttt.debounce(250, function()
      lv.offset = 0
      if lv.on_search then
        lv.on_search()
        S.redraw()
      else
        List.load(lv)
      end
    end)
  h:input({
    placeholder = placeholder or "Search…",
    prefix = "⌕ ",
    value = lv.search,
    on_change = function(text)
      lv.search = text
      lv.search_later()
    end,
  })
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
    on_menu = function(command)
      local o = options[tonumber(command)]
      if o then
        on_pick(o.value)
      end
    end,
  })
end

function M.with_all(label, options)
  local out = { { label = label, value = "" } }
  for _, o in ipairs(options) do
    out[#out + 1] = o
  end
  return out
end

function M.filter(h, lv, field, options)
  M.dropdown(h, options, lv[field] or "", function(value)
    lv[field] = value
    lv.offset = 0
    List.load(lv)
  end)
end

function M.state_filter(h, lv)
  M.filter(h, lv, "state", M.STATES)
end

function M.namespace_filter(h, lv)
  M.filter(h, lv, "namespace", M.with_all("All namespaces", S.namespaces))
end

function M.refresh_button(h, lv, also)
  h:button({
    label = "Refresh",
    on_click = function()
      List.load(lv, true)
      if also then
        also()
      end
    end,
  })
end

return M
