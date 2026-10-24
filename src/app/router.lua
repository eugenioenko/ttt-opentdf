local ttt = require("ttt")
local S = require("core.state")
local Api = require("core.api")
local Nav = require("app.nav")
local Connection = require("app.connection")

-- One editor tab per feature. Each tab holds a stack of pages:
-- { title, render(p, tab), actions(h, tab)?, tab? }. actions draw on the
-- right of the title row.
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
  for i, page in ipairs(tab.stack) do
    crumbs[i] = page.title
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

function M.open(id)
  local tab = M.tabs[id]
  if not tab then
    tab = { id = id, stack = { M.roots[id]() } }
    M.tabs[id] = tab
  end
  ttt.open_tab({
    id = id,
    title = Nav.titles[id],
    render = function(p)
      S.panels[id] = p
      render(tab, p)
    end,
    on_event = function(ev)
      if ev.type == "key" and ev.key == "Backspace" and not ev.mod then
        M.back(tab)
      end
    end,
  })
  return tab
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
