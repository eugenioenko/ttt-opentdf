local U = require("core.util")
local UI = require("components")
local Store = require("features.attributes.store")
local Commands = require("features.attributes.commands")
local Values = require("features.attributes.values_table")

-- Attributes on the left, the selected attribute's values on the right.
local M = {}

local function filters(p, lv, left)
  p:hstack({
    height = 1,
    margin_top = 1,
    render = function(h)
      h:box({
        width = left,
        padding_right = 1,
        render = function(b)
          UI.toolbar(b, function(t)
            UI.search(t, lv, "Search attributes…")
            UI.namespace_filter(t, lv)
            UI.state_filter(t, lv)
          end, 0)
        end,
      })
      h:box({
        render = function(b)
          Values.filters(b, Store.values, Store.values_follow)
        end,
      })
    end,
  })
end

local function attributes_table(p, tab, lv)
  UI.table(p, lv, {
    noun = "attributes",
    columns = {
      { label = "Attribute" },
      { label = "Rule", width = 9 },
      { label = "Values", width = 6, align = "right" },
    },
    row = function(item)
      local ns = item.namespace and item.namespace.name or ""
      return { ns .. "/" .. item.name, U.rule(item), tostring(#(item.values or {})) }
    end,
    style = U.inactive_style,
    on_move = Store.values_follow,
    on_page = Store.values_follow,
    on_open = function(item)
      Commands.attribute(tab, "open", item)
    end,
    keys = { n = "new", v = "value", d = "deactivate", e = "labels" },
    menu = {
      { label = "Open", command = "open" },
      { label = "New Value", command = "value" },
      { label = "Edit Labels", command = "labels" },
      { label = "Deactivate", command = "deactivate" },
    },
    on_command = function(cmd, item)
      Commands.attribute(tab, cmd, item)
    end,
  })
end

function M.page()
  return {
    title = "Attributes",
    actions = function(h)
      h:button({
        label = "New",
        on_click = function()
          Commands.new_attribute()
        end,
      })
      UI.refresh_button(h, Store.attributes)
    end,
    render = function(p, tab)
      local lv = Store.attributes
      UI.ensure(lv)
      local w = p:size()
      local left = math.max(36, math.floor(w * 0.5))
      local a = UI.selected(lv)
      filters(p, lv, left)
      p:hstack({
        render = function(h)
          UI.frame(h, "Attributes", function(b)
            attributes_table(b, tab, lv)
          end, { width = left })
          UI.frame(h, a and ("Values · " .. a.fqn) or "Values", function(b)
            Values.table(b, tab, a, Store.values)
          end)
        end,
      })
    end,
  }
end

return M
