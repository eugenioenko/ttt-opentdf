local M = {}

local function merge(into, opts)
  for k, v in pairs(opts or {}) do
    into[k] = v
  end
  return into
end

function M.frame(p, title, render, opts)
  p:box(merge({ border = true, title = title, render = render }, opts))
end

function M.toolbar(p, render, margin_top)
  p:hstack({ height = 1, gap = 1, margin_top = margin_top == nil and 1 or margin_top, render = render })
end

function M.checkbox(h, label, checked, on_change, opts)
  h:box(merge({
    width = #label + 5,
    render = function(b)
      b:checkbox({ label = label, checked = checked, on_change = on_change })
    end,
  }, opts))
end

-- A button aligned with bordered inputs in the same row.
function M.button_box(h, label, on_click, disabled)
  h:box({
    padding_top = 1,
    width = #label + 2,
    render = function(b)
      b:button({ label = label, on_click = on_click, disabled = disabled })
    end,
  })
end

function M.kv(entries)
  local out = { padding_left = 1, margin_top = 1 }
  for _, e in ipairs(entries) do
    out[#out + 1] = { key = e[1], value = e[2] or "" }
  end
  return out
end

return M
