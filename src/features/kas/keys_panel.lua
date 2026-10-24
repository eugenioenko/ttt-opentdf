local U = require("core.util")
local UI = require("components")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")
local KeyForm = require("features.kas.key_form")

-- The keys of one server, or of every server when kas is nil or ALL_KEYS.
local M = {}

function M.filters(h, lv)
  UI.search(h, lv, "Search keys…")
  UI.filter(h, lv, "alg", UI.with_all("All algorithms", Store.ALGS))
end

function M.actions(h, tab, kas, lv)
  h:button({
    label = "New",
    on_click = function()
      KeyForm.open(tab, kas, nil)
    end,
  })
  h:button({
    label = "Rotate",
    on_click = function()
      Commands.key(tab, "rotate", UI.selected(lv))
    end,
  })
  h:button({
    label = "Set Base",
    disabled = not Store.can_be_base(UI.selected(lv)),
    on_click = function()
      Commands.key(tab, "base", UI.selected(lv))
    end,
  })
end

function M.table(p, tab, kas, lv)
  local all = not kas or kas.all
  local columns = {
    { label = "", width = 1 },
    { label = "Key ID" },
    { label = "Algorithm", width = 9 },
    { label = "Mode", width = 15 },
    { label = "Status", width = 8 },
  }
  if all then
    columns[#columns + 1] = { label = "KAS" }
  else
    columns[#columns + 1] = { label = "Created", width = 16 }
  end
  UI.table(p, lv, {
    noun = "keys",
    columns = columns,
    row = function(kk)
      local key = kk.key or {}
      return {
        Store.is_base(kk) and "★" or "",
        key.keyId or "",
        U.alg(key.keyAlgorithm),
        U.human(key.keyMode, "KEY_MODE_"),
        U.human(key.keyStatus, "KEY_STATUS_"),
        all and U.host(kk.kasUri) or U.created(key),
      }
    end,
    style = function(kk)
      local status = kk.key and kk.key.keyStatus
      return status == "KEY_STATUS_ACTIVE" and "default" or "muted"
    end,
    on_open = function(kk)
      Commands.key(tab, "open", kk)
    end,
    keys = { n = "new", r = "rotate", b = "base" },
    menu = {
      { label = "Open", command = "open" },
      { label = "Rotate…", command = "rotate" },
      { label = "Set as Base Key", command = "base" },
    },
    on_command = function(cmd, kk)
      if cmd == "new" then
        KeyForm.open(tab, kas, nil)
      else
        Commands.key(tab, cmd, kk)
      end
    end,
  })
end

-- Filters, actions and the table together, for the KAS & Keys page.
function M.render(p, tab, kas, lv)
  UI.toolbar(p, function(h)
    M.filters(h, lv)
    M.actions(h, tab, kas, lv)
  end, 0)
  M.table(p, tab, kas, lv)
end

return M
