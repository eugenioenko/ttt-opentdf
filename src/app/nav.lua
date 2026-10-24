-- Sidebar sections, tab titles and commands all come from this table.
local M = {}

M.sections = {
  {
    title = "POLICY",
    items = {
      { id = "namespaces", label = "Namespaces", count = true },
      { id = "attributes", label = "Attributes", count = true },
      { id = "actions", label = "Actions", count = true },
    },
  },
  { title = "KEYS", items = { { id = "kas", label = "KAS & Keys", count = true } } },
  {
    title = "AUTHORIZATION",
    items = { { id = "entitlements", label = "Entitlements" }, { id = "decision", label = "Decision" } },
  },
}

M.titles = {}
for _, section in ipairs(M.sections) do
  for _, item in ipairs(section.items) do
    M.titles[item.id] = item.label
  end
end

function M.each(fn)
  for _, section in ipairs(M.sections) do
    for _, item in ipairs(section.items) do
      fn(item, section)
    end
  end
end

return M
