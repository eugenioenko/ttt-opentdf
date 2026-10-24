local UI = require("components")
local Router = require("app.router")
local Entity = require("shared.entity")
local Store = require("features.entitlements.store")
local Decision = require("features.decision")

local M = {}

function M.page()
  return {
    title = "Entitlements",
    render = function(p)
      local st = Store.state
      local many = (st.entities or 0) > 1
      p:hstack({
        height = 3,
        gap = 1,
        margin_top = 1,
        render = function(h)
          Entity.fields(h, st.entity, Store.run)
          UI.checkbox(h, "Full hierarchy", st.comprehensive, function(v)
            st.comprehensive = v
          end, { padding_top = 1 })
          UI.button_box(h, st.busy and "Checking…" or "Get Entitlements", Store.run, st.busy)
        end,
      })
      local summary, style = Store.summary()
      local w = p:size()
      p:hstack({
        height = 1,
        gap = 2,
        margin_top = 1,
        render = function(h)
          h:label({ text = summary, style = style, padding_left = 1, width = math.max(w - 44, 10) })
          UI.search(h, st.list, "Filter values or actions…", Store.filter)
        end,
      })
      local columns = { { label = "Attribute value" }, { label = "Actions", width = 28 } }
      if many then
        table.insert(columns, 1, { label = "Entity", width = 28 })
      end
      UI.table(p, st.list, {
        frame = "Entitlements",
        noun = "entitlements",
        empty = st.ran and "This entity isn't entitled to any attribute values"
          or "Choose an entity and press Get Entitlements",
        columns = columns,
        row = function(r)
          if many then
            return { r.entity, r.fqn, r.actions }
          end
          return { r.fqn, r.actions }
        end,
        on_open = function(r)
          Decision.store.prefill(st.entity, r.fqn)
          Router.open(Decision.id)
        end,
      })
    end,
  }
end

return M
