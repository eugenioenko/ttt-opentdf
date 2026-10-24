local U = require("core.util")
local S = require("core.state")
local List = require("components.list")
local Layout = require("components.layout")

local M = {}

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
    columns = opts.columns,
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
