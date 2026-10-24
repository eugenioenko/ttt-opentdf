local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local UI = require("components")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")
local Keys = require("features.kas.keys_panel")

-- Key access servers on the left, the selected server's keys on the right.
local M = {}

local function servers_table(p, tab, lv)
  UI.table(p, lv, {
    noun = "servers",
    columns = { { label = "Name" }, { label = "Keys", width = 5, align = "right" } },
    row = function(item)
      if item.all then
        return { "All keys", tostring(S.counts.keys or "") }
      end
      return { item.name or U.host(item.uri), tostring(#(item.kasKeys or {})) }
    end,
    style = function(item)
      return item.all and "bold" or "default"
    end,
    on_move = function()
      Store.keys_follow(false)
    end,
    on_page = function()
      Store.keys_follow(true)
    end,
    on_open = function(item)
      Commands.server(tab, "open", item)
    end,
    keys = { n = "new", e = "edit", d = "delete" },
    menu = {
      { label = "Open", command = "open" },
      { label = "Edit", command = "edit" },
      { label = "Delete", command = "delete" },
      { separator = true },
      { label = "New Key", command = "key" },
    },
    on_command = function(cmd, item)
      Commands.server(tab, cmd, item)
    end,
  })
end

function M.page()
  return {
    title = "KAS & Keys",
    actions = function(h)
      h:button({ label = "New", on_click = Commands.new_server })
      UI.refresh_button(h, Store.servers, Api.load_base_key)
    end,
    render = function(p, tab)
      local lv = Store.servers
      UI.ensure(lv)
      UI.toolbar(p, function(h)
        UI.search(h, lv, "Search key access servers…")
      end)
      local w = p:size()
      local left = math.max(32, math.floor(w * 0.36))
      local k = UI.selected(lv)
      local keys_title = k and not k.all and ("Keys · " .. (k.name or U.host(k.uri))) or "Keys · all servers"
      p:hstack({
        render = function(h)
          UI.frame(h, "Key Access Servers", function(b)
            servers_table(b, tab, lv)
          end, { width = left })
          UI.frame(h, keys_title, function(b)
            Keys.render(b, tab, k, Store.keys)
          end)
        end,
      })
    end,
  }
end

return M
