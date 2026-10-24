local U = require("core.util")
local S = require("core.state")
local UI = require("components")

-- Pieces shared by the namespace, attribute and value screens.
local M = {}

M.LABELS_HINT = "owner=security, env=dev"

local function labels_saved(item, labels, after)
  item.metadata = item.metadata or {}
  item.metadata.labels = labels
  if after then
    after()
  end
end

local function save_labels(item, path, after, v, done)
  local labels = U.parse_labels(v.labels)
  local req = { id = item.id, metadata = { labels = labels }, metadataUpdateBehavior = "METADATA_UPDATE_ENUM_REPLACE" }
  UI.save(path, req, done, U.bind(labels_saved, item, labels, after))
end

function M.labels_dialog(what, item, path, after)
  UI.dialog({
    title = "Edit Labels · " .. what,
    submit = "Save",
    fields = {
      { key = "labels", label = "Labels", value = U.labels(item.metadata), placeholder = M.LABELS_HINT },
    },
    on_submit = U.bind(save_labels, item, path, after),
  })
end

-- Labels and Deactivate buttons for a detail page's title row; command gets
-- (cmd, item).
function M.actions(h, item, command)
  h:button({ label = "Labels", on_click = U.bind(command, "labels", item) })
  if item.active ~= false then
    h:button({ label = "Deactivate", on_click = U.bind(command, "deactivate", item) })
  end
end

local function namespaces()
  return S.namespaces
end

function M.namespace_field(ns)
  if (not ns or ns == "") and S.namespaces[1] then
    ns = S.namespaces[1].value
  end
  return { key = "namespace", label = "Namespace", kind = "enum", value = ns, options = namespaces }
end

return M
