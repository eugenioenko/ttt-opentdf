local U = require("core.util")
local Api = require("core.api")
local S = require("core.state")

-- A list view model: one page of items from the platform, or a client-side
-- slice of `all` when spec.client is set.
local M = {}

function M.list(name, spec)
  local lv = {
    spec = spec,
    offset = 0,
    total = 0,
    items = {},
    all = nil,
    loading = false,
    loaded = false,
    err = nil,
    sel = 1,
    search = "",
    state = "ACTIVE_STATE_ENUM_ACTIVE",
    gen = 0,
  }
  S.lists[name] = lv
  return lv
end

function M.sub_list(key, spec)
  return S.lists[key] or M.list(key, spec)
end

local function loaded(lv, gen, keep, err, data)
  if gen ~= lv.gen then
    return
  end
  lv.loading = false
  lv.loaded = true
  if err then
    lv.err = err
    lv.items = {}
    S.redraw()
    return
  end
  lv.err = nil
  lv.items = lv.spec.extract(data) or {}
  lv.total = Api.total(data)
  if lv.total == 0 then
    lv.total = lv.offset + #lv.items
  end
  if not keep then
    lv.sel = 1
  end
  if lv.sel > #lv.items then
    lv.sel = math.max(#lv.items, 1)
  end
  if lv.spec.on_loaded then
    lv.spec.on_loaded(lv)
  end
  S.redraw()
end

function M.load(lv, keep)
  local spec = lv.spec
  if spec.client then
    M.slice(lv)
    S.redraw()
    return
  end
  lv.loading = true
  lv.gen = lv.gen + 1
  local req = spec.request and spec.request(lv) or {}
  req.pagination = { limit = S.page_size, offset = lv.offset }
  if spec.search and lv.search ~= "" then
    req.search = { term = lv.search }
  end
  Api.call(spec.method, req, U.bind(loaded, lv, lv.gen, keep))
end

function M.slice(lv)
  local all = lv.all or {}
  local page = S.page_size
  lv.total = #all
  if lv.offset >= lv.total then
    lv.offset = math.max(0, math.floor((lv.total - 1) / page) * page)
  end
  local items = {}
  for i = lv.offset + 1, math.min(lv.offset + page, lv.total) do
    items[#items + 1] = all[i]
  end
  lv.items = items
  lv.loaded = true
  if lv.sel > #items then
    lv.sel = math.max(#items, 1)
  end
end

function M.last_page_offset(count)
  local page = S.page_size
  return math.max(0, math.floor((count - 1) / page) * page)
end

function M.ensure(lv)
  if not lv.loaded and not lv.loading and S.status == "ok" then
    M.load(lv)
  end
end

function M.selected(lv)
  return lv.items[lv.sel]
end

function M.empty_text(lv, noun, empty)
  if lv.err then
    return "Couldn't load " .. noun
  end
  if lv.search ~= "" then
    return "No " .. noun .. " match “" .. lv.search .. "”"
  end
  return empty or ("No " .. noun .. " yet")
end

return M
