local U = require("core.util")
local S = require("core.state")
local UI = require("components")

-- Pieces shared by the namespace, attribute and value screens.
local M = {}

M.LABELS_HINT = "owner=security, env=dev"

function M.labels_dialog(what, item, path, after)
  UI.dialog({
    title = "Edit Labels · " .. what,
    submit = "Save",
    fields = {
      { key = "labels", label = "Labels", value = U.labels(item.metadata), placeholder = M.LABELS_HINT },
    },
    on_submit = function(v, done)
      local labels = U.parse_labels(v.labels)
      UI.save(
        path,
        {
          id = item.id,
          metadata = { labels = labels },
          metadataUpdateBehavior = "METADATA_UPDATE_ENUM_REPLACE",
        },
        done,
        function()
          item.metadata = item.metadata or {}
          item.metadata.labels = labels
          if after then
            after()
          end
        end
      )
    end,
  })
end

-- Labels and Deactivate buttons for a detail page's title row.
function M.actions(h, item, command)
  h:button({
    label = "Labels",
    on_click = function()
      command("labels")
    end,
  })
  if item.active ~= false then
    h:button({
      label = "Deactivate",
      on_click = function()
        command("deactivate")
      end,
    })
  end
end

function M.namespace_field(ns)
  if (not ns or ns == "") and S.namespaces[1] then
    ns = S.namespaces[1].value
  end
  return {
    key = "namespace",
    label = "Namespace",
    kind = "enum",
    value = ns,
    options = function()
      return S.namespaces
    end,
  }
end

return M
