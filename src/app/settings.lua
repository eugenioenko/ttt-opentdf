local storage = require("ttt.storage")
local S = require("core.state")
local UI = require("components")

local M = {}

M.PAGE_SIZES = {
  { label = "10 per page", value = "10" },
  { label = "20 per page", value = "20" },
  { label = "50 per page", value = "50" },
  { label = "100 per page", value = "100" },
}

local function save(v, done)
  local n = tonumber(v.page_size) or S.page_size
  if n ~= S.page_size then
    S.page_size = n
    S.settings.page_size = n
    storage.set("settings", S.settings)
    S.reset_lists()
  end
  done()
end

function M.dialog()
  UI.dialog({
    title = "OpenTDF Settings",
    width = 50,
    fields = {
      { key = "page_size", label = "Page size", kind = "enum", options = M.PAGE_SIZES, value = tostring(S.page_size) },
    },
    on_submit = save,
  })
end

return M
