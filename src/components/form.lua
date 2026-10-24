local U = require("core.util")
local S = require("core.state")
local Layout = require("components.layout")
local Inputs = require("components.inputs")

-- Forms from a field spec: { key, label, kind = "enum"|"multiline"|"readonly",
-- options, value, placeholder, password, required, rows, show(vals) }.
local M = {}

function M.field_options(f)
  if type(f.options) == "function" then
    return f.options()
  end
  return f.options or {}
end

function M.new_form(spec)
  local form = { spec = spec, vals = {}, err = nil, busy = false }
  for _, f in ipairs(spec.fields) do
    local v = f.value
    if v == nil and f.options then
      local options = M.field_options(f)
      if options[1] then
        v = options[1].value
      end
    end
    form.vals[f.key] = v or ""
  end
  function form.submit()
    if form.busy then
      return
    end
    for _, f in ipairs(spec.fields) do
      local shown = not f.show or f.show(form.vals)
      if shown and f.required and U.trim(form.vals[f.key]) == "" then
        form.err = f.label .. " is required"
        S.redraw()
        return
      end
    end
    form.busy = true
    form.err = nil
    S.redraw()
    spec.on_submit(form.vals, function(err)
      form.busy = false
      form.err = err
      if not err and spec.on_done then
        spec.on_done()
      end
      S.redraw()
    end)
  end
  return form
end

function M.form_height(form)
  local h = 2
  for _, f in ipairs(form.spec.fields) do
    if not f.show or f.show(form.vals) then
      if f.kind == "multiline" then
        h = h + (f.rows or 6) + 2
      else
        h = h + 3
      end
    end
  end
  return h
end

local function render_field(p, form, f, first)
  if f.kind == "enum" then
    local options = M.field_options(f)
    Layout.frame(p, f.label, function(b)
      Inputs.dropdown(b, options, form.vals[f.key], function(value)
        form.vals[f.key] = value
        S.redraw()
      end)
    end)
  elseif f.kind == "readonly" then
    p:label({ text = f.label .. ": " .. tostring(form.vals[f.key]), style = "muted", border = true })
  else
    local multiline = f.kind == "multiline"
    p:input({
      border = true,
      title = f.label,
      value = form.vals[f.key],
      placeholder = f.placeholder,
      password = f.password,
      multiline = multiline,
      min_rows = multiline and (f.rows or 6) or nil,
      max_rows = multiline and (f.rows or 6) or nil,
      autofocus = first,
      on_change = function(text)
        form.vals[f.key] = text
      end,
      on_submit = function()
        form.submit()
      end,
    })
  end
end

function M.render_form(p, form, on_cancel)
  for i, f in ipairs(form.spec.fields) do
    if not f.show or f.show(form.vals) then
      render_field(p, form, f, i == 1)
    end
  end
  local text, style = "", "muted"
  if form.err then
    text, style = "✕ " .. form.err, "danger"
  elseif form.busy then
    text = "Saving…"
  end
  p:label({ text = text, style = style, padding_left = 1 })
  p:hstack({
    height = 1,
    gap = 1,
    align = "right",
    render = function(h)
      h:button({ label = "Cancel", on_click = on_cancel })
      h:button({ label = form.spec.submit or "Save", disabled = form.busy, on_click = form.submit })
    end,
  })
end

return M
