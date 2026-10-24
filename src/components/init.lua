-- The component library as one table, so callers write UI.table, UI.frame, …
local UI = {}

for _, name in ipairs({ "list", "layout", "inputs", "table", "form", "dialog" }) do
  for k, v in pairs(require("components." .. name)) do
    assert(UI[k] == nil, "components: " .. k .. " is defined twice")
    UI[k] = v
  end
end

return UI
