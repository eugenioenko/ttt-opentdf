local U = require("core.util")
local S = require("core.state")
local UI = require("components")

-- The entity picker and request shape shared by Entitlements and Decision.
local M = {}

M.TYPES = {
  { label = "Client ID", value = "clientId" },
  { label = "Email", value = "emailAddress" },
  { label = "Username", value = "userName" },
  { label = "JWT", value = "jwt" },
  { label = "This connection's token", value = "request" },
}

M.HINTS = {
  clientId = "opentdf",
  emailAddress = "alice@example.com",
  userName = "alice",
  jwt = "eyJhbGciOi…",
  request = "uses the token of the configured client",
}

function M.new()
  return { kind = "clientId", value = "opentdf" }
end

function M.identifier(entity)
  if entity.kind == "request" then
    return { withRequestToken = true }
  end
  local value = U.trim(entity.value)
  if entity.kind == "jwt" then
    return { token = { ephemeralId = "jwt", jwt = value } }
  end
  local e = { ephemeralId = "entity", category = "CATEGORY_SUBJECT" }
  e[entity.kind] = value
  return { entityChain = { ephemeralId = "chain", entities = { e } } }
end

function M.label(entity)
  if entity.kind == "request" then
    return "client " .. S.conn.client_id .. " (request token)"
  end
  if entity.kind == "jwt" then
    return "the pasted JWT"
  end
  return U.option_label(M.TYPES, entity.kind):lower() .. " " .. U.trim(entity.value)
end

-- Sets st.err and returns true when st.entity has no value to send.
function M.missing(st)
  if st.entity.kind ~= "request" and U.trim(st.entity.value) == "" then
    st.err = "Enter an entity first"
    S.redraw()
    return true
  end
  return false
end

function M.fields(h, entity, on_submit)
  UI.frame(h, "Entity", function(b)
    UI.dropdown(b, M.TYPES, entity.kind, function(kind)
      if kind ~= entity.kind then
        entity.kind = kind
        entity.value = kind == "clientId" and S.conn.client_id or ""
      end
      S.redraw()
    end)
  end, { width = 28 })
  if entity.kind == "request" then
    UI.frame(h, "Value", function(b)
      b:label({ text = M.HINTS.request, style = "muted", padding_left = 1 })
    end)
  else
    h:input({
      border = true,
      title = U.option_label(M.TYPES, entity.kind),
      value = entity.value,
      placeholder = M.HINTS[entity.kind],
      on_change = function(text)
        entity.value = text
      end,
      on_submit = on_submit,
    })
  end
end

return M
