local json = require("ttt.json")

local U = {}

function U.urlencode(s)
  local out = {}
  s = tostring(s)
  for i = 1, #s do
    local c = s:sub(i, i)
    if c:find("^[%w%-%._~]$") then
      out[#out + 1] = c
    else
      out[#out + 1] = string.format("%%%02X", string.byte(c))
    end
  end
  return table.concat(out)
end

function U.form(t)
  local parts = {}
  for k, v in pairs(t) do
    parts[#parts + 1] = U.urlencode(k) .. "=" .. U.urlencode(v)
  end
  return table.concat(parts, "&")
end

-- ttt.json encodes an empty table as an array, which protobuf rejects for a map.
function U.encode(t)
  if next(t) == nil then
    return "{}"
  end
  local s = json.encode(t)
  s = s:gsub('"labels":%[%]', '"labels":{}')
  return s
end

function U.trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

function U.split(s, sep)
  local out, start = {}, 1
  s = s or ""
  while true do
    local i = s:find(sep, start, true)
    local part = U.trim(i and s:sub(start, i - 1) or s:sub(start))
    if part ~= "" then
      out[#out + 1] = part
    end
    if not i then
      break
    end
    start = i + #sep
  end
  return out
end

function U.date(ts)
  if type(ts) ~= "string" or #ts < 16 then
    return ""
  end
  return ts:sub(1, 10) .. " " .. ts:sub(12, 16)
end

function U.human(v, prefix)
  if type(v) ~= "string" or v == "" then
    return ""
  end
  if v:sub(1, #prefix) == prefix then
    v = v:sub(#prefix + 1)
  end
  v = v:gsub("_", " ")
  v = v:lower()
  return v:sub(1, 1):upper() .. v:sub(2)
end

function U.alg(v)
  if type(v) ~= "string" then
    return ""
  end
  v = v:gsub("^ALGORITHM_", "")
  v = v:gsub("_", " ")
  return v
end

function U.active(v)
  if v == false then
    return "Inactive"
  end
  return "Active"
end

function U.labels(md)
  local labels = md and md.labels
  if type(labels) ~= "table" then
    return ""
  end
  local keys = {}
  for k in pairs(labels) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = k .. "=" .. tostring(labels[k])
  end
  return table.concat(parts, ", ")
end

function U.parse_labels(s)
  local labels = {}
  for _, pair in ipairs(U.split(s, ",")) do
    local i = pair:find("=", 1, true)
    if i then
      local k = U.trim(pair:sub(1, i - 1))
      if k ~= "" then
        labels[k] = U.trim(pair:sub(i + 1))
      end
    end
  end
  return labels
end

function U.host(uri)
  if type(uri) ~= "string" then
    return ""
  end
  local h = uri:gsub("^%a+://", "")
  return h
end

function U.option_label(options, value)
  for _, o in ipairs(options) do
    if o.value == value then
      return o.label
    end
  end
  return "Select…"
end

function U.created(x)
  return U.date(x.metadata and x.metadata.createdAt)
end

function U.updated(x)
  return U.date(x.metadata and x.metadata.updatedAt)
end

function U.rule(a)
  return U.human(a.rule, "ATTRIBUTE_RULE_TYPE_ENUM_")
end

function U.inactive_style(x)
  return x.active == false and "muted" or "default"
end

return U
