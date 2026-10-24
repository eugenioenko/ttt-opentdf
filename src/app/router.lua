local ttt = require("ttt")
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

local function render(tab, p)
  Api.ensure_connected()
  if S.status ~= "ok" then
    Connection.not_connected(p)
    return
  end
  local crumbs = {}
  for _, title in ipairs(tab.context or {}) do
    crumbs[#crumbs + 1] = title
  end
  for _, page in ipairs(tab.stack) do
    crumbs[#crumbs + 1] = page.title
  end
  local page = tab.stack[#tab.stack]
  p:hstack({
    height = 1,
    gap = 1,
    render = function(h)
      if #tab.stack > 1 then
        h:button({
          label = "‹ Back",
          on_click = function()
            M.back(tab)
          end,
        })
      end
      h:label({ text = table.concat(crumbs, "  ›  "), style = "bold", padding_left = #tab.stack > 1 and 0 or 1 })
      if page.actions then
        page.actions(h, tab)
      end
    end,
  })
  page.render(p, tab)
end

-- ttt focuses an open tab with the same id and ignores the rest.
local function open_tab(tab, title)
  ttt.open_tab({
    id = tab.id,
    title = title,
    render = function(p)
      S.panels[tab.id] = p
      render(tab, p)
    end,
    on_event = function(ev)
      if ev.type == "key" and ev.key == "Backspace" and not ev.mod then
        M.back(tab)
      end
    end,
    on_close = function()
      S.panels[tab.id] = nil
      M.tabs[tab.id] = nil
    end,
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
  if tab then
    open_tab(tab, page.tab_title or page.title)
    return tab
  end
  local context = {}
  for _, title in ipairs(from and from.context or {}) do
    context[#context + 1] = title
  end
  for _, p in ipairs(from and from.stack or {}) do
    context[#context + 1] = p.title
  end
  tab = { id = id, stack = { page }, context = context }
  M.tabs[id] = tab
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

-- Draws a page's tab strip and returns the active tab id.
function M.tab_strip(p, page, items)
  page.tab = page.tab or items[1].id
  p:tabs({
    items = items,
    active = page.tab,
    margin_top = 1,
    on_change = function(id)
      page.tab = id
      S.redraw()
    end,
  })
  return page.tab
end

return M
