local storage = require("ttt.storage")
local U = require("core.util")

local M = {}
M.items = storage.get("connections") or {}
M.active_id = storage.get("active_connection")

function M.persist()
  storage.set("connections", M.items)
  storage.set("active_connection", M.active_id)
end

local legacy = storage.get("connection")
if legacy then
  if #M.items == 0 then
    legacy.id = "1"
    legacy.name = U.host(legacy.url)
    M.items[1] = legacy
    M.active_id = legacy.id
    M.persist()
  end
  storage.remove("connection")
end

function M.find(id)
  for i, item in ipairs(M.items) do
    if item.id == id then
      return item, i
    end
  end
end

function M.credentials(item, secret)
  return {
    url = item.url,
    client_id = item.client_id,
    client_secret = secret or item.client_secret or "",
  }
end

function M.save(id, values)
  local item, index = M.find(id)
  if not item then
    local n = 1
    while M.find(tostring(n)) do
      n = n + 1
    end
    id, index = tostring(n), #M.items + 1
  end
  item = {
    id = id,
    name = U.trim(values.name),
    url = U.trim(values.url):gsub("/+$", ""),
    client_id = U.trim(values.client_id),
  }
  if values.remember_secret then
    item.client_secret = values.client_secret
  end
  M.items[index] = item
  M.persist()
  return item
end

function M.delete(id)
  local _, index = M.find(id)
  if not index then
    return
  end
  table.remove(M.items, index)
  if M.active_id == id then
    M.active_id = nil
  end
  M.persist()
end

return M
