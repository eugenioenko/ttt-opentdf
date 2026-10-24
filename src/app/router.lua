local ttt = require("ttt")
local U = require("core.util")
local S = require("core.state")
local Api = require("core.api")
local Nav = require("app.nav")
local Connection = require("app.connection")

-- Every feature and every detail page gets its own editor tab. A tab holds a
-- stack of pages, { title, tab_title?, render(p, tab), actions(h, tab)?, tab? },
-- for steps like a form that return with ‹ Back. actions draw on the right of
-- the title row.
local M = {}

M.roots = {}
M.tabs = {}

function M.register(id, root)
  M.roots[id] = root
end

function M.push(tab, page)
  tab.stack[#tab.stack + 1] = page
  S.redraw()
end

function M.back(tab)
  if #tab.stack > 1 then
    tab.stack[#tab.stack] = nil
    S.redraw()
  end
end

function M.reset(tab)
  while #tab.stack > 1 do
    tab.stack[#tab.stack] = nil
  end
end

local function trail(tab)
  local crumbs = {}
  for _, title in ipairs(tab.context or {}) do
    crumbs[#crumbs + 1] = title
  end
  for _, page in ipairs(tab.stack) do
    crumbs[#crumbs + 1] = page.title
  end
  return crumbs
end

local function title_row(tab, h)
  local nested = #tab.stack > 1
  local page = tab.stack[#tab.stack]
  if nested then
    h:button({ label = "‹ Back", on_click = U.bind(M.back, tab) })
  end
  h:label({ text = table.concat(trail(tab), "  ›  "), style = "bold", padding_left = nested and 0 or 1 })
  if page.actions then
    page.actions(h, tab)
  end
end

local function render(tab, p)
  S.panels[tab.id] = p
  Api.ensure_connected()
  if S.status ~= "ok" then
    Connection.not_connected(p)
    return
  end
  p:hstack({ height = 1, gap = 1, render = U.bind(title_row, tab) })
  tab.stack[#tab.stack].render(p, tab)
end

local function on_event(tab, ev)
  if ev.type == "key" and ev.key == "Backspace" and not ev.mod then
    M.back(tab)
  end
end

local function forget(tab)
  S.panels[tab.id] = nil
  M.tabs[tab.id] = nil
end

-- ttt focuses an open tab with the same id and ignores the rest.
local function open_tab(tab, title)
  ttt.open_tab({
    id = tab.id,
    title = title,
    render = U.bind(render, tab),
    on_event = U.bind(on_event, tab),
    on_close = U.bind(forget, tab),
  })
end

-- Opens a feature's tab, or focuses it when it is already open.
function M.open(id)
  local tab = M.tabs[id]
  if not tab then
    tab = { id = id, stack = { M.roots[id]() } }
    M.tabs[id] = tab
  end
  open_tab(tab, Nav.titles[id])
  return tab
end

-- Opens a detail page in its own tab, keyed by what it shows, or focuses that
-- tab when it is already open. The title row keeps the trail it came from.
function M.show(from, key, page)
  local id = "page:" .. key
  local tab = M.tabs[id]
  if not tab then
    tab = { id = id, stack = { page }, context = from and trail(from) or {} }
    M.tabs[id] = tab
  end
  open_tab(tab, page.tab_title or page.title)
  return tab
end

function M.close_page(key)
  ttt.close_tab("page:" .. key)
end

-- Opens a feature's list filtered to one namespace.
function M.open_for_namespace(id, lv, ns_id)
  lv.namespace = ns_id
  lv.offset = 0
  lv.loaded = false
  M.reset(M.open(id))
  S.redraw()
end

local function select_tab(page, id)
  page.tab = id
  S.redraw()
end

-- Draws a page's tab strip and returns the active tab id.
function M.tab_strip(p, page, items)
  page.tab = page.tab or items[1].id
  p:tabs({ items = items, active = page.tab, margin_top = 1, on_change = U.bind(select_tab, page) })
  return page.tab
end

return M
