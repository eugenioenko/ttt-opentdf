local S = require("core.state")
local UI = require("components")
local Entity = require("shared.entity")
local Store = require("features.decision.store")
local Picker = require("features.decision.value_picker")

local M = {}

local function request_form(p, st)
  p:hstack({
    height = 3,
    gap = 1,
    margin_top = 1,
    render = function(h)
      Entity.fields(h, st.entity, Store.run)
      h:box({
        width = 18,
        render = function(b)
          b:input({
            border = true,
            title = "Action",
            value = st.action,
            placeholder = "read",
            on_change = function(text)
              st.action = text
            end,
            on_submit = Store.run,
          })
        end,
      })
      UI.button_box(h, st.busy and "Deciding…" or "Get Decision", Store.run, st.busy)
    end,
  })
  p:hstack({
    height = 1,
    gap = 1,
    margin_top = 1,
    align = "right",
    render = function(h)
      h:button({
        label = "Add Value",
        on_click = function()
          Picker.open(Store.add_resource)
        end,
      })
      UI.checkbox(h, "Decide each value separately", st.each, function(v)
        st.each = v
      end)
    end,
  })
end

local function resources_table(p, st)
  local rows = {}
  for i, f in ipairs(st.resources) do
    rows[i] = { f }
  end
  UI.frame(p, "Resource attribute values", function(b)
    b:table({
      inset = 1,
      columns = { { label = "Attribute value FQN" } },
      rows = rows,
      empty = "Add the attribute values the resource carries",
      key_commands = { d = "remove", x = "remove" },
      node_menu = { { label = "Remove", command = "remove" } },
      on_command = function(cmd, i)
        if cmd == "remove" then
          table.remove(st.resources, i)
          S.redraw()
        end
      end,
    })
  end, { height = math.max(math.min(#rows, 8), 2) + 4 })
end

local function result(p, r)
  local permitted = Store.permitted(r.decisions)
  local permit = #r.decisions > 0 and permitted == #r.decisions
  local detail = r.entity .. "  ·  " .. r.action
  if #r.decisions > 1 then
    detail = detail .. "  ·  " .. permitted .. " of " .. #r.decisions .. " permitted"
  end
  p:hstack({
    height = 3,
    gap = 1,
    margin_top = 1,
    render = function(h)
      h:label({
        text = permit and " ✓ PERMIT" or " ✕ DENY",
        style = permit and "success" or "danger",
        border = true,
        width = 14,
      })
      h:box({
        padding_top = 1,
        render = function(b)
          b:label({ text = detail, style = "muted" })
        end,
      })
    end,
  })
  local rows, styles = {}, {}
  for i, d in ipairs(r.decisions) do
    local ok = d.decision == "DECISION_PERMIT"
    rows[i] = { ok and "Permit" or "Deny", d.label }
    styles[i] = ok and "success" or "danger"
  end
  if #r.obligations > 0 then
    rows[#rows + 1] = { "", "" }
    for _, o in ipairs(r.obligations) do
      rows[#rows + 1] = { "Obligation", o }
      styles[#rows] = "warning"
    end
  end
  UI.frame(p, "Decisions", function(b)
    b:table({
      inset = 1,
      columns = { { label = "Decision", width = 10 }, { label = "Resource" } },
      rows = rows,
      row_styles = styles,
    })
  end, { margin_top = 1 })
end

function M.page()
  return {
    title = "Decision",
    render = function(p)
      local st = Store.state
      request_form(p, st)
      resources_table(p, st)
      if st.err then
        p:label({ text = "✕ " .. st.err, style = "danger", margin_top = 1, padding_left = 1 })
      elseif not st.result then
        p:label({
          text = "Pick an entity, an action and the resource's attribute values, then press Get Decision.",
          style = "muted",
          margin_top = 1,
          padding_left = 1,
        })
      else
        result(p, st.result)
      end
    end,
  }
end

return M
