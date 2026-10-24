local U = require("core.util")
local UI = require("components")
local Store = require("features.kas.store")
local Commands = require("features.kas.commands")
local KeyForm = require("features.kas.key_form")

-- The keys of one server, or of every server when kas is nil or ALL_KEYS.
local M = {}

local KEYS = { n = "new", r = "rotate", b = "base" }

local MENU = {
  { label = "Open", command = "open" },
  { label = "Rotate…", command = "rotate" },
  { label = "Set as Base Key", command = "base" },
}

local function columns(all)
  return {
    { label = "", width = 1 },
    { label = "Key ID" },
    { label = "Algorithm", width = 9 },
    { label = "Mode", width = 15 },
    { label = "Status", width = 8 },
    all and { label = "KAS" } or { label = "Created", width = 16 },
  }
end

local function row(all, kk)
  local key = kk.key or {}
  return {
    Store.is_base(kk) and "★" or "",
    key.keyId or "",
    U.alg(key.keyAlgorithm),
    U.human(key.keyMode, "KEY_MODE_"),
    U.human(key.keyStatus, "KEY_STATUS_"),
    all and U.host(kk.kasUri) or U.created(key),
  }
end

local function style(kk)
  local status = kk.key and kk.key.keyStatus
  return status == "KEY_STATUS_ACTIVE" and "default" or "muted"
end

local function key_command(tab, kas, cmd, kk)
  if cmd == "new" then
    KeyForm.open(tab, kas, nil)
  else
    Commands.key(tab, cmd, kk)
  end
end

local function on_selected(tab, cmd, lv)
  Commands.key(tab, cmd, UI.selected(lv))
end

function M.filters(h, lv)
  UI.search(h, lv, "Search keys…")
  UI.filter(h, lv, "alg", UI.with_all("All algorithms", Store.ALGS))
end

function M.actions(h, tab, kas, lv)
  h:button({ label = "New", on_click = U.bind(KeyForm.open, tab, kas, nil) })
  h:button({ label = "Rotate", on_click = U.bind(on_selected, tab, "rotate", lv) })
  h:button({
    label = "Set Base",
    disabled = not Store.can_be_base(UI.selected(lv)),
    on_click = U.bind(on_selected, tab, "base", lv),
  })
end

function M.table(p, tab, kas, lv)
  local all = not kas or kas.all
  UI.table(p, lv, {
    noun = "keys",
    columns = columns(all),
    row = U.bind(row, all),
    style = style,
    on_open = U.bind(Commands.key, tab, "open"),
    keys = KEYS,
    menu = MENU,
    on_command = U.bind(key_command, tab, kas),
  })
end

local function toolbar(tab, kas, lv, h)
  M.filters(h, lv)
  M.actions(h, tab, kas, lv)
end

-- Filters, actions and the table together, for the KAS & Keys page.
function M.render(p, tab, kas, lv)
  UI.toolbar(p, U.bind(toolbar, tab, kas, lv), 0)
  M.table(p, tab, kas, lv)
end

return M
