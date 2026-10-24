local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")
local KeyForm = require("features.kas.key_form")
local Keys = require("features.kas.keys_panel")

local M = {}

function M.page(k)
  local page = { title = k.name or U.host(k.uri) }
  local keys = Store.server_keys(k)
  page.actions = function(h, tab)
    if page.tab == "keys" then
      Keys.actions(h, tab, k, keys)
      UI.refresh_button(h, keys)
      return
    end
    h:button({
      label = "New Key",
      on_click = function()
        KeyForm.open(tab, k, nil)
      end,
    })
    h:button({
      label = "Edit",
      on_click = function()
        Commands.edit_server(k)
      end,
    })
    h:button({
      label = "Delete",
      on_click = function()
        Commands.server(tab, "delete", k)
      end,
    })
  end
  page.render = function(p, tab)
    local current = Router.tab_strip(p, page, {
      { id = "details", label = "Details" },
      { id = "keys", label = "Keys (" .. #(k.kasKeys or {}) .. ")" },
    })
    if current == "keys" then
      UI.ensure(keys)
      UI.toolbar(p, function(h)
        Keys.filters(h, keys)
      end)
      UI.frame(p, "Keys", function(b)
        Keys.table(b, tab, k, keys)
      end)
      return
    end
    p:keyvalue(UI.kv({
      { "Name", k.name },
      { "URI", k.uri },
      { "Source", U.human(k.sourceType, "SOURCE_TYPE_") },
      { "Keys", tostring(#(k.kasKeys or {})) },
      { "ID", k.id },
      { "Created", U.created(k) },
      { "Updated", U.updated(k) },
    }))
  end
  return page
end

return M
