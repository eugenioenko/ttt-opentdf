local U = require("core.util")
local S = require("core.state")
local List = require("components.list")
local Layout = require("components.layout")

local M = {}

local OPEN = "open"
local ACTIVATE = "__activate"

local function select_row(lv, opts, i)
  lv.sel = i
  if opts.on_move then
    opts.on_move(lv.items[i])
  end
end

local function activate_row(lv, opts, i)
  lv.sel = i
  if opts.on_open and lv.items[i] then
    opts.on_open(lv.items[i])
  end
end

local function row_command(lv, opts, cmd, i)
  if cmd == ACTIVATE then
    activate_row(lv, opts, i)
    return
  end
  lv.sel = i
  if opts.on_command then
    opts.on_command(cmd, lv.items[i])
  end
end

local function change_page(lv, opts, offset)
  lv.offset = offset
  lv.sel = 1
  List.load(lv)
  if opts.on_page then
    opts.on_page()
  end
end

local function pager(lv, opts, h)
  h:pager({ offset = lv.offset, limit = S.page_size, total = lv.total, on_change = U.bind(change_page, lv, opts) })
end

local function framed(lv, opts, b)
  M.table(b, lv, opts)
end

local function find_open(menu)
  for _, e in ipairs(menu) do
    if e.command == OPEN then
      return e
    end
  end
end

local function menu_rest(menu)
  local rest = {}
  for _, e in ipairs(menu) do
    local extra_separator = e.separator and (#rest == 0 or rest[#rest].separator)
    if e.command ~= OPEN and not extra_separator then
      rest[#rest + 1] = e
    end
  end
  if #rest > 0 and rest[#rest].separator then
    rest[#rest] = nil
  end
  return rest
end

-- The Open link only activates rows in tables built with M.table.
function M.actions_column(menu, open_label)
  local actions = {}
  local open = menu and find_open(menu)
  if open or open_label then
    actions[1] = { label = open and open.label or open_label, command = ACTIVATE }
  end
  local rest = menu and menu_rest(menu) or {}
  if #rest == 1 and #actions == 0 then
    actions[1] = { label = rest[1].label, command = rest[1].command }
  elseif #rest > 0 then
    actions[#actions + 1] = { menu = rest }
  end
  if #actions == 0 then
    return nil
  end
  return { label = "", actions = actions }
end

local function columns(opts)
  local open_label = opts.open_label
  if not open_label and not opts.menu and opts.on_open then
    open_label = "Open"
  end
  local col = M.actions_column(opts.menu, open_label)
  if not col then
    return opts.columns
  end
  local cols = {}
  for i, c in ipairs(opts.columns) do
    cols[i] = c
  end
  cols[#cols + 1] = col
  return cols
end

-- A list view as a table with a pager. The widget sequence stays the same
-- whatever the list holds, so reconciliation keeps the table focused while
-- pages load.
function M.table(p, lv, opts)
  if opts.frame then
    local title = opts.frame
    opts.frame = nil
    Layout.frame(p, title, U.bind(framed, lv, opts), opts.frame_opts)
    return
  end
  local rows, styles = {}, {}
  for i, item in ipairs(lv.items) do
    rows[i] = opts.row(item)
    styles[i] = opts.style and opts.style(item) or "default"
  end
  p:table({
    inset = 1,
    columns = columns(opts),
    rows = rows,
    row_styles = styles,
    selected = lv.sel,
    loading = lv.loading,
    empty = List.empty_text(lv, opts.noun or "items", opts.empty),
    on_select = U.bind(select_row, lv, opts),
    on_activate = U.bind(activate_row, lv, opts),
    key_commands = opts.keys,
    node_menu = opts.menu,
    on_command = U.bind(row_command, lv, opts),
  })
  p:divider()
  p:hstack({ height = 1, align = "center", render = U.bind(pager, lv, opts) })
  if lv.err then
    p:label({ text = "✕ " .. lv.err, style = "danger", padding_left = 1 })
  end
end

return M
