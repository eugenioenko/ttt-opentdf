local ttt = require("ttt")
local net = require("ttt.net")
local json = require("ttt.json")
local storage = require("ttt.storage")

local PAGE = 50

local SVC = {
  NS = "policy.namespaces.NamespaceService/",
  ATTR = "policy.attributes.AttributesService/",
  KAS = "policy.kasregistry.KeyAccessServerRegistryService/",
  ACT = "policy.actions.ActionService/",
  KM = "policy.keymanagement.KeyManagementService/",
}

local U, Api, S, UI, V = {}, {}, {}, {}, {}

-- Utilities ------------------------------------------------------------------

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

function U.option_entries(options, value)
  local entries = {}
  for i, o in ipairs(options) do
    entries[i] = { label = o.label, command = o.value, checked = o.value == value }
  end
  return entries
end

-- State ----------------------------------------------------------------------

S.conn = storage.get("connection") or {}
S.conn.url = S.conn.url or "http://localhost:8080"
S.conn.client_id = S.conn.client_id or "opentdf"
S.conn.client_secret = S.conn.client_secret or ""
S.settings = storage.get("settings") or {}
PAGE = tonumber(S.settings.page_size) or PAGE
S.status = "idle"
S.message = ""
S.token = nil
S.token_exp = 0
S.token_endpoint = nil
S.counts = {}
S.namespaces = {}
S.providers = {}
S.base = nil
S.panels = {}

function S.redraw()
  for _, p in pairs(S.panels) do
    pcall(function()
      p:redraw()
    end)
    return
  end
end

function S.configured()
  return S.conn.client_secret ~= "" and S.conn.url ~= ""
end

-- API ------------------------------------------------------------------------

function Api.reset()
  S.token = nil
  S.token_exp = 0
  S.token_endpoint = nil
end

function Api.decode(body)
  if type(body) ~= "string" or body == "" then
    return {}
  end
  local data = json.decode(body)
  if type(data) ~= "table" then
    return {}
  end
  return data
end

function Api.discover(cb)
  if S.token_endpoint then
    return cb(nil)
  end
  net.get_async(S.conn.url .. "/.well-known/opentdf-configuration", function(resp)
    if resp.error then
      return cb(resp.error)
    end
    if resp.status ~= 200 then
      return cb("well-known configuration returned HTTP " .. resp.status)
    end
    local cfg = Api.decode(resp.body)
    if not cfg.idp or not cfg.idp.token_endpoint then
      return cb("the platform does not advertise a token endpoint")
    end
    S.token_endpoint = cfg.idp.token_endpoint
    cb(nil)
  end)
end

function Api.token(cb)
  if S.token and os.time() < S.token_exp - 30 then
    return cb(nil, S.token)
  end
  Api.discover(function(err)
    if err then
      return cb(err)
    end
    net.post_async(S.token_endpoint, {
      headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
      body = U.form({
        grant_type = "client_credentials",
        client_id = S.conn.client_id,
        client_secret = S.conn.client_secret,
      }),
    }, function(resp)
      if resp.error then
        return cb(resp.error)
      end
      local data = Api.decode(resp.body)
      if resp.status ~= 200 or not data.access_token then
        return cb(data.error_description or data.error or ("token request returned HTTP " .. resp.status))
      end
      S.token = data.access_token
      S.token_exp = os.time() + (data.expires_in or 300)
      cb(nil, S.token)
    end)
  end)
end

function Api.call(path, req, cb)
  Api.token(function(err, token)
    if err then
      return cb(err)
    end
    net.post_async(S.conn.url .. "/" .. path, {
      headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. token },
      body = U.encode(req or {}),
    }, function(resp)
      if resp.error then
        return cb(resp.error)
      end
      local data = Api.decode(resp.body)
      if resp.status == 401 then
        S.token = nil
      end
      if resp.status ~= 200 then
        return cb(data.message or ("HTTP " .. resp.status))
      end
      cb(nil, data)
    end)
  end)
end

function Api.total(data)
  return (data.pagination and data.pagination.total) or 0
end

function Api.count(key, path, req)
  req = req or {}
  req.pagination = { limit = 1 }
  Api.call(path, req, function(err, data)
    if not err then
      S.counts[key] = Api.total(data)
      S.redraw()
    end
  end)
end

function Api.refresh_counts()
  Api.count("namespaces", SVC.NS .. "ListNamespaces")
  Api.count("attributes", SVC.ATTR .. "ListAttributes")
  Api.count("actions", SVC.ACT .. "ListActions")
  Api.count("kas", SVC.KAS .. "ListKeyAccessServers")
  Api.count("keys", SVC.KAS .. "ListKeys")
end

function Api.load_pickers()
  Api.call(SVC.NS .. "ListNamespaces", { pagination = { limit = 1000 } }, function(err, data)
    if err then
      return
    end
    local list = {}
    for _, n in ipairs(data.namespaces or {}) do
      list[#list + 1] = { label = n.name, value = n.id }
    end
    table.sort(list, function(a, b)
      return a.label < b.label
    end)
    S.namespaces = list
    S.redraw()
  end)
  Api.call(SVC.KM .. "ListProviderConfigs", { pagination = { limit = 1000 } }, function(err, data)
    if err then
      return
    end
    local list = {}
    for _, pc in ipairs(data.providerConfigs or {}) do
      list[#list + 1] = { label = pc.name .. "  (" .. (pc.manager or "") .. ")", value = pc.id }
    end
    S.providers = list
  end)
  Api.load_base_key()
end

function Api.load_base_key()
  Api.call(SVC.KAS .. "GetBaseKey", {}, function(err, data)
    if err then
      return
    end
    local bk = data.baseKey
    if bk and bk.publicKey and bk.publicKey.kid then
      S.base = { kas_id = bk.kasId, kid = bk.publicKey.kid }
    else
      S.base = nil
    end
    S.redraw()
  end)
end

function Api.connect(cb)
  S.status = "connecting"
  S.message = ""
  Api.reset()
  S.redraw()
  Api.call(SVC.NS .. "ListNamespaces", { pagination = { limit = 1 } }, function(err, data)
    if err then
      S.status = "error"
      S.message = err
      S.redraw()
      if cb then
        cb(err)
      end
      return
    end
    S.status = "ok"
    S.counts.namespaces = Api.total(data)
    Api.refresh_counts()
    Api.load_pickers()
    for _, lv in pairs(V.lists or {}) do
      lv.loaded = false
    end
    S.redraw()
    if cb then
      cb(nil)
    end
  end)
end

-- Lists ----------------------------------------------------------------------

V.lists = {}

function UI.list(name, spec)
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
  V.lists[name] = lv
  return lv
end

function UI.load(lv, keep)
  local spec = lv.spec
  if spec.client then
    UI.slice(lv)
    S.redraw()
    return
  end
  lv.loading = true
  lv.gen = lv.gen + 1
  local gen = lv.gen
  local req = spec.request and spec.request(lv) or {}
  req.pagination = { limit = PAGE, offset = lv.offset }
  if spec.search and lv.search ~= "" then
    req.search = { term = lv.search }
  end
  Api.call(spec.method, req, function(err, data)
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
    lv.items = spec.extract(data) or {}
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
    if spec.on_loaded then
      spec.on_loaded(lv)
    end
    S.redraw()
  end)
end

function UI.slice(lv)
  local all = lv.all or {}
  lv.total = #all
  if lv.offset >= lv.total then
    lv.offset = math.max(0, math.floor((lv.total - 1) / PAGE) * PAGE)
  end
  local items = {}
  for i = lv.offset + 1, math.min(lv.offset + PAGE, lv.total) do
    items[#items + 1] = all[i]
  end
  lv.items = items
  lv.loaded = true
  if lv.sel > #items then
    lv.sel = math.max(#items, 1)
  end
end

function UI.ensure(lv)
  if not lv.loaded and not lv.loading and S.status == "ok" then
    UI.load(lv)
  end
end

function UI.selected(lv)
  return lv.items[lv.sel]
end

function UI.empty_text(lv, noun, empty)
  if lv.err then
    return "Couldn't load " .. noun
  end
  if lv.search ~= "" then
    return "No " .. noun .. " match “" .. lv.search .. "”"
  end
  return empty or ("No " .. noun .. " yet")
end

-- The widget sequence stays the same whatever the list holds, so reconciliation
-- keeps the table focused while pages load.
function UI.table(p, lv, opts)
  if opts.frame then
    local title = opts.frame
    opts.frame = nil
    UI.frame(p, title, function(b)
      UI.table(b, lv, opts)
    end, opts.frame_opts)
    return
  end
  local rows, styles = {}, {}
  for i, item in ipairs(lv.items) do
    rows[i] = opts.row(item)
    styles[i] = opts.style and opts.style(item) or "default"
  end
  p:table({
    inset = 1,
    columns = opts.columns,
    rows = rows,
    row_styles = styles,
    selected = lv.sel,
    loading = lv.loading,
    empty = UI.empty_text(lv, opts.noun or "items", opts.empty),
    on_select = function(i)
      lv.sel = i
      if opts.on_move then
        opts.on_move(lv.items[i])
      end
    end,
    on_activate = function(i)
      lv.sel = i
      if opts.on_open and lv.items[i] then
        opts.on_open(lv.items[i])
      end
    end,
    key_commands = opts.keys,
    node_menu = opts.menu,
    on_command = function(cmd, i)
      lv.sel = i
      if opts.on_command then
        opts.on_command(cmd, lv.items[i])
      end
    end,
  })
  p:divider()
  p:hstack({
    height = 1,
    align = "center",
    render = function(h)
      h:pager({
        offset = lv.offset,
        limit = PAGE,
        total = lv.total,
        on_change = function(offset)
          lv.offset = offset
          lv.sel = 1
          UI.load(lv)
          if opts.on_page then
            opts.on_page()
          end
        end,
      })
    end,
  })
  if lv.err then
    p:label({ text = "✕ " .. lv.err, style = "danger", padding_left = 1 })
  end
end

function UI.frame(p, title, render, opts)
  local box = { border = true, title = title, render = render }
  for k, v in pairs(opts or {}) do
    box[k] = v
  end
  p:box(box)
end

-- on_search replaces the reload, for client lists that refilter themselves.
function UI.search(h, lv, placeholder, on_search)
  lv.on_search = on_search
  lv.search_later = lv.search_later
    or ttt.debounce(250, function()
      lv.offset = 0
      if lv.on_search then
        lv.on_search()
        S.redraw()
      else
        UI.load(lv)
      end
    end)
  h:input({
    placeholder = placeholder or "Search…",
    prefix = "⌕ ",
    value = lv.search,
    on_change = function(text)
      lv.search = text
      lv.search_later()
    end,
  })
end

function UI.checkbox(h, label, checked, on_change, opts)
  local box = {
    width = #label + 5,
    render = function(b)
      b:checkbox({ label = label, checked = checked, on_change = on_change })
    end,
  }
  for k, v in pairs(opts or {}) do
    box[k] = v
  end
  h:box(box)
end

function UI.button_box(h, label, on_click, disabled)
  h:box({
    padding_top = 1,
    width = #label + 2,
    render = function(b)
      b:button({ label = label, on_click = on_click, disabled = disabled })
    end,
  })
end

function UI.dropdown(h, options, value, on_pick)
  h:dropdown({
    label = U.option_label(options, value) .. " ▾",
    entries = U.option_entries(options, value),
    on_menu = on_pick,
  })
end

function UI.filter(h, lv, field, options)
  UI.dropdown(h, options, lv[field] or "", function(value)
    lv[field] = value
    lv.offset = 0
    UI.load(lv)
  end)
end

function UI.refresh_button(h, lv, also)
  h:button({
    label = "Refresh",
    on_click = function()
      UI.load(lv, true)
      if also then
        also()
      end
    end,
  })
end

function UI.toolbar(p, render, margin_top)
  p:hstack({ height = 1, gap = 1, margin_top = margin_top == nil and 1 or margin_top, render = render })
end

UI.STATES = {
  { label = "Active", value = "ACTIVE_STATE_ENUM_ACTIVE" },
  { label = "Inactive", value = "ACTIVE_STATE_ENUM_INACTIVE" },
  { label = "Any state", value = "ACTIVE_STATE_ENUM_ANY" },
}

function UI.with_all(label, options)
  local out = { { label = label, value = "" } }
  for _, o in ipairs(options) do
    out[#out + 1] = o
  end
  return out
end

function UI.state_filter(h, lv)
  UI.filter(h, lv, "state", UI.STATES)
end

function UI.namespace_filter(h, lv)
  UI.filter(h, lv, "namespace", UI.with_all("All namespaces", S.namespaces))
end

-- Forms ----------------------------------------------------------------------

function UI.new_form(spec)
  local form = { spec = spec, vals = {}, err = nil, busy = false }
  for _, f in ipairs(spec.fields) do
    local v = f.value
    if v == nil and f.options then
      local options = UI.field_options(f)
      if options[1] then
        v = options[1].value
      end
    end
    form.vals[f.key] = v or ""
  end
  function form.submit()
    if form.busy then
      return
    end
    for _, f in ipairs(spec.fields) do
      local shown = not f.show or f.show(form.vals)
      if shown and f.required and U.trim(form.vals[f.key]) == "" then
        form.err = f.label .. " is required"
        S.redraw()
        return
      end
    end
    form.busy = true
    form.err = nil
    S.redraw()
    spec.on_submit(form.vals, function(err)
      form.busy = false
      form.err = err
      if not err and spec.on_done then
        spec.on_done()
      end
      S.redraw()
    end)
  end
  return form
end

function UI.field_options(f)
  if type(f.options) == "function" then
    return f.options()
  end
  return f.options or {}
end

function UI.form_height(form)
  local h = 3
  for _, f in ipairs(form.spec.fields) do
    if not f.show or f.show(form.vals) then
      if f.kind == "multiline" then
        h = h + (f.rows or 6) + 2
      else
        h = h + 3
      end
    end
  end
  return h
end

function UI.render_form(p, form, on_cancel)
  for i, f in ipairs(form.spec.fields) do
    if not f.show or f.show(form.vals) then
      if f.kind == "enum" then
        local options = UI.field_options(f)
        UI.frame(p, f.label, function(b)
          UI.dropdown(b, options, form.vals[f.key], function(value)
            form.vals[f.key] = value
            S.redraw()
          end)
        end)
      elseif f.kind == "readonly" then
        p:label({ text = f.label .. ": " .. tostring(form.vals[f.key]), style = "muted", border = true })
      else
        local multiline = f.kind == "multiline"
        p:input({
          border = true,
          title = f.label,
          value = form.vals[f.key],
          placeholder = f.placeholder,
          password = f.password,
          multiline = multiline,
          min_rows = multiline and (f.rows or 6) or nil,
          max_rows = multiline and (f.rows or 6) or nil,
          autofocus = i == 1,
          on_change = function(text)
            form.vals[f.key] = text
          end,
          on_submit = function()
            form.submit()
          end,
        })
      end
    end
  end
  local text, style = "", "muted"
  if form.err then
    text, style = "✕ " .. form.err, "danger"
  elseif form.busy then
    text = "Saving…"
  end
  p:label({ text = text, style = style, padding_left = 1 })
  p:hstack({
    height = 1,
    gap = 1,
    align = "right",
    render = function(h)
      h:button({ label = "Cancel", on_click = on_cancel })
      h:button({ label = form.spec.submit or "Save", disabled = form.busy, on_click = form.submit })
    end,
  })
end

function UI.open_dialog(title, width, height, render)
  ttt.open_dialog({
    title = title,
    width = width,
    height = height,
    render = function(p)
      S.panels.dialog = p
      render(p)
    end,
    on_close = function()
      S.panels.dialog = nil
    end,
  })
end

function UI.dialog(spec)
  local form = UI.new_form(spec)
  spec.on_done = ttt.close_dialog
  UI.open_dialog(spec.title, spec.width or 64, UI.form_height(form), function(p)
    UI.render_form(p, form, ttt.close_dialog)
  end)
end

-- Form submits: an error stays in the form, success runs after and closes it.
function UI.save(path, req, done, after)
  Api.call(path, req, function(err, data)
    if err then
      return done(err)
    end
    if after then
      after(data)
    end
    done()
  end)
end

function UI.confirm(message, path, req, done_message, after)
  ttt.confirm(message, function()
    Api.call(path, req, function(err)
      if err then
        ttt.notify(err, "error")
        return
      end
      if done_message then
        ttt.notify(done_message)
      end
      if after then
        after()
      end
      S.redraw()
    end)
  end)
end

function UI.not_connected(p)
  local text = "Not connected."
  if S.status == "connecting" then
    text = "Connecting to " .. S.conn.url .. "…"
  elseif S.status == "error" then
    text = "✕ " .. S.message
  elseif not S.configured() then
    text = "Not configured. Set the platform URL and client credentials first."
  end
  p:label({ text = text, style = S.status == "error" and "danger" or "muted", margin_top = 1, padding_left = 1 })
  p:hstack({
    height = 1,
    gap = 1,
    margin_top = 1,
    padding_left = 1,
    render = function(h)
      h:button({ label = "Connection…", on_click = V.connection_dialog })
      if S.configured() then
        h:button({
          label = "Retry",
          on_click = function()
            Api.connect()
          end,
        })
      end
    end,
  })
end

-- Tabs -----------------------------------------------------------------------

V.tabs = {}
V.NAV = {
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
V.titles = {}
for _, section in ipairs(V.NAV) do
  for _, item in ipairs(section.items) do
    V.titles[item.id] = item.label
  end
end

function V.push(tab, page)
  tab.stack[#tab.stack + 1] = page
  S.redraw()
end

function V.back(tab)
  if #tab.stack > 1 then
    tab.stack[#tab.stack] = nil
    S.redraw()
  end
end

function V.reset(tab)
  while #tab.stack > 1 do
    tab.stack[#tab.stack] = nil
  end
end

function V.open(id)
  local tab = V.tabs[id]
  if not tab then
    tab = { id = id, stack = { V.roots[id]() } }
    V.tabs[id] = tab
  end
  ttt.open_tab({
    id = id,
    title = V.titles[id],
    render = function(p)
      S.panels[id] = p
      V.render(tab, p)
    end,
    on_event = function(ev)
      if ev.type == "key" and ev.key == "Backspace" and not ev.mod then
        V.back(tab)
      end
    end,
  })
  return tab
end

function Api.ensure_connected()
  if S.status == "idle" and S.configured() then
    Api.connect()
  end
end

function V.render(tab, p)
  Api.ensure_connected()
  if S.status ~= "ok" then
    UI.not_connected(p)
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
            V.back(tab)
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

-- Namespaces -----------------------------------------------------------------

V.ns = UI.list("namespaces", {
  method = SVC.NS .. "ListNamespaces",
  search = true,
  request = function(lv)
    return { state = lv.state }
  end,
  extract = function(data)
    return data.namespaces
  end,
})

function V.ns_root()
  return {
    title = "Namespaces",
    actions = function(h)
      h:button({ label = "New", on_click = V.ns_new })
      UI.refresh_button(h, V.ns)
    end,
    render = function(p, tab)
      local lv = V.ns
      UI.ensure(lv)
      UI.toolbar(p, function(h)
        UI.search(h, lv, "Search namespaces…")
        UI.state_filter(h, lv)
      end)
      UI.table(p, lv, {
        frame = "Namespaces",
        noun = "namespaces",
        columns = {
          { label = "Name" },
          { label = "Status", width = 9 },
          { label = "Labels" },
          { label = "Created", width = 16 },
        },
        row = function(n)
          return { n.name, U.active(n.active), U.labels(n.metadata), U.created(n) }
        end,
        style = U.inactive_style,
        on_open = function(n)
          V.push(tab, V.ns_detail(n))
        end,
        keys = { n = "new", e = "labels", d = "deactivate", a = "attributes", c = "actions" },
        menu = {
          { label = "Open", command = "open" },
          { label = "Edit Labels", command = "labels" },
          { label = "Deactivate", command = "deactivate" },
          { separator = true },
          { label = "Show Attributes", command = "attributes" },
          { label = "Show Actions", command = "actions" },
        },
        on_command = function(cmd, n)
          V.ns_command(tab, cmd, n)
        end,
      })
    end,
  }
end

function V.ns_command(tab, cmd, n)
  if cmd == "new" then
    V.ns_new()
  elseif not n then
    return
  elseif cmd == "open" then
    V.push(tab, V.ns_detail(n))
  elseif cmd == "labels" then
    V.labels_dialog("Namespace " .. n.name, n, SVC.NS .. "UpdateNamespace", function()
      UI.load(V.ns, true)
    end)
  elseif cmd == "deactivate" then
    UI.confirm(
      "Deactivate namespace " .. n.name .. "? Its attributes and values are deactivated too.",
      SVC.NS .. "DeactivateNamespace",
      { id = n.id },
      "Deactivated " .. n.name,
      function()
        n.active = false
        UI.load(V.ns, true)
        Api.refresh_counts()
      end
    )
  elseif cmd == "attributes" then
    V.open_for_namespace("attributes", V.attr, n.id)
  elseif cmd == "actions" then
    V.open_for_namespace("actions", V.act, n.id)
  end
end

function V.ns_new()
  UI.dialog({
    title = "New Namespace",
    submit = "Create",
    fields = {
      { key = "name", label = "Name", placeholder = "example.com", required = true },
      { key = "labels", label = "Labels", placeholder = "owner=security, env=dev" },
    },
    on_submit = function(v, done)
      local req = { name = U.trim(v.name) }
      local labels = U.parse_labels(v.labels)
      if next(labels) then
        req.metadata = { labels = labels }
      end
      UI.save(SVC.NS .. "CreateNamespace", req, done, function()
        ttt.notify("Created namespace " .. req.name)
        UI.load(V.ns, true)
        Api.refresh_counts()
        Api.load_pickers()
      end)
    end,
  })
end

function V.labels_dialog(what, item, path, after)
  UI.dialog({
    title = "Edit Labels · " .. what,
    submit = "Save",
    fields = {
      { key = "labels", label = "Labels", value = U.labels(item.metadata), placeholder = "owner=security, env=dev" },
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

function V.policy_actions(h, item, command)
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

function V.kv(entries)
  local out = { padding_left = 1, margin_top = 1 }
  for _, e in ipairs(entries) do
    out[#out + 1] = { key = e[1], value = e[2] or "" }
  end
  return out
end

function V.tab_strip(p, page, items)
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

function V.sub_list(key, spec)
  return V.lists[key] or UI.list(key, spec)
end

function V.ns_detail(n)
  local page = { title = n.name }
  local attrs = V.sub_list("ns-attrs:" .. n.id, {
    method = SVC.ATTR .. "ListAttributes",
    search = true,
    request = function(lv)
      return { namespace = n.id, state = lv.state }
    end,
    extract = function(data)
      return data.attributes
    end,
  })
  local acts = V.sub_list("ns-actions:" .. n.id, {
    method = SVC.ACT .. "ListActions",
    request = function()
      return { namespaceId = n.id }
    end,
    extract = V.act.spec.extract,
  })
  page.actions = function(h, tab)
    if page.tab == "attributes" then
      h:button({
        label = "New",
        on_click = function()
          V.attr_new(n.id, function()
            UI.load(attrs, true)
          end)
        end,
      })
      UI.refresh_button(h, attrs)
    elseif page.tab == "actions" then
      h:button({
        label = "New",
        on_click = function()
          V.act_new(n.id, function()
            UI.load(acts, true)
          end)
        end,
      })
      UI.refresh_button(h, acts)
    else
      V.policy_actions(h, n, function(cmd)
        V.ns_command(tab, cmd, n)
      end)
    end
  end
  page.render = function(p, tab)
    local current = V.tab_strip(p, page, {
      { id = "details", label = "Details" },
      { id = "attributes", label = "Attributes" },
      { id = "actions", label = "Actions" },
    })
    if current == "attributes" then
      UI.ensure(attrs)
      UI.toolbar(p, function(h)
        UI.search(h, attrs, "Search attributes in " .. n.name .. "…")
        UI.state_filter(h, attrs)
      end)
      UI.table(p, attrs, {
        frame = "Attributes",
        noun = "attributes",
        columns = {
          { label = "Name" },
          { label = "Rule", width = 9 },
          { label = "Values", width = 6, align = "right" },
          { label = "Status", width = 9 },
        },
        row = function(a)
          return { a.name, U.rule(a), tostring(#(a.values or {})), U.active(a.active) }
        end,
        style = U.inactive_style,
        on_open = function(a)
          V.push(tab, V.attr_detail(a))
        end,
      })
      return
    end
    if current == "actions" then
      UI.ensure(acts)
      UI.table(p, acts, {
        frame = "Actions",
        frame_opts = { margin_top = 1 },
        noun = "actions",
        columns = { { label = "Name" }, { label = "Type", width = 9 }, { label = "Created", width = 16 } },
        row = function(a)
          return { a.name, a.kind, U.created(a) }
        end,
        style = function(a)
          return a.kind == "Standard" and "muted" or "default"
        end,
        on_open = function(a)
          V.act_command(tab, "rename", a)
        end,
      })
      return
    end
    p:keyvalue(V.kv({
      { "Name", n.name },
      { "FQN", n.fqn },
      { "Status", U.active(n.active) },
      { "Labels", U.labels(n.metadata) },
      { "ID", n.id },
      { "Created", U.created(n) },
      { "Updated", U.updated(n) },
    }))
  end
  return page
end

-- Attributes and values ------------------------------------------------------

V.RULES = {
  { label = "Any of", value = "ATTRIBUTE_RULE_TYPE_ENUM_ANY_OF" },
  { label = "All of", value = "ATTRIBUTE_RULE_TYPE_ENUM_ALL_OF" },
  { label = "Hierarchy", value = "ATTRIBUTE_RULE_TYPE_ENUM_HIERARCHY" },
}

V.attr = UI.list("attributes", {
  method = SVC.ATTR .. "ListAttributes",
  search = true,
  request = function(lv)
    local req = { state = lv.state }
    if lv.namespace and lv.namespace ~= "" then
      req.namespace = lv.namespace
    end
    return req
  end,
  extract = function(data)
    return data.attributes
  end,
  on_loaded = function()
    V.values_follow()
  end,
})

V.values = UI.list("values", { client = true })

V.VALUE_STATES = {
  { label = "Any state", value = "" },
  { label = "Active", value = "active" },
  { label = "Inactive", value = "inactive" },
}

function V.filter_values(values, lv)
  local term = (lv.search or ""):lower()
  local state = lv.vstate or ""
  local out = {}
  for _, v in ipairs(values or {}) do
    local active = v.active ~= false
    local keep = (state == "" or (state == "active") == active)
      and (term == "" or (v.value or ""):lower():find(term, 1, true))
    if keep then
      out[#out + 1] = v
    end
  end
  return out
end

function V.values_follow()
  local a = UI.selected(V.attr)
  if V.values.attr ~= a then
    V.values.attr = a
    V.values.offset = 0
    V.values.sel = 1
  end
  V.values.all = V.filter_values(a and a.values, V.values)
  UI.slice(V.values)
end

function V.values_filters(p, lv, refilter, margin_top)
  UI.toolbar(p, function(h)
    UI.search(h, lv, "Filter values…", refilter)
    UI.dropdown(h, V.VALUE_STATES, lv.vstate or "", function(value)
      lv.vstate = value
      lv.offset = 0
      refilter()
      S.redraw()
    end)
  end, margin_top or 0)
end

function V.open_for_namespace(id, lv, ns_id)
  lv.namespace = ns_id
  lv.offset = 0
  lv.loaded = false
  V.reset(V.open(id))
  S.redraw()
end

function V.attr_root()
  return {
    title = "Attributes",
    actions = function(h)
      h:button({
        label = "New",
        on_click = function()
          V.attr_new()
        end,
      })
      UI.refresh_button(h, V.attr)
    end,
    render = function(p, tab)
      local lv = V.attr
      UI.ensure(lv)
      local w = p:size()
      local left = math.max(36, math.floor(w * 0.5))
      local a = UI.selected(lv)
      p:hstack({
        height = 1,
        margin_top = 1,
        render = function(h)
          h:box({
            width = left,
            padding_right = 1,
            render = function(b)
              UI.toolbar(b, function(t)
                UI.search(t, lv, "Search attributes…")
                UI.namespace_filter(t, lv)
                UI.state_filter(t, lv)
              end, 0)
            end,
          })
          h:box({
            render = function(b)
              V.values_filters(b, V.values, V.values_follow)
            end,
          })
        end,
      })
      p:hstack({
        render = function(h)
          UI.frame(h, "Attributes", function(b)
            UI.table(b, lv, {
              noun = "attributes",
              columns = {
                { label = "Attribute" },
                { label = "Rule", width = 9 },
                { label = "Values", width = 6, align = "right" },
              },
              row = function(item)
                local ns = item.namespace and item.namespace.name or ""
                return { ns .. "/" .. item.name, U.rule(item), tostring(#(item.values or {})) }
              end,
              style = U.inactive_style,
              on_move = function()
                V.values_follow()
              end,
              on_page = V.values_follow,
              on_open = function(item)
                V.push(tab, V.attr_detail(item))
              end,
              keys = { n = "new", v = "value", d = "deactivate", e = "labels" },
              menu = {
                { label = "Open", command = "open" },
                { label = "New Value", command = "value" },
                { label = "Edit Labels", command = "labels" },
                { label = "Deactivate", command = "deactivate" },
              },
              on_command = function(cmd, item)
                V.attr_command(tab, cmd, item)
              end,
            })
          end, { width = left })
          UI.frame(h, a and ("Values · " .. a.fqn) or "Values", function(b)
            V.values_table(b, tab, a, V.values)
          end)
        end,
      })
    end,
  }
end

function V.values_table(p, tab, a, lv, frame)
  UI.table(p, lv, {
    frame = frame,
    noun = "values",
    columns = {
      { label = "Value" },
      { label = "Status", width = 9 },
      { label = "FQN" },
    },
    row = function(v)
      return { v.value, U.active(v.active), v.fqn or "" }
    end,
    style = U.inactive_style,
    on_open = function(v)
      V.push(tab, V.value_detail(a, v))
    end,
    keys = { n = "new", d = "deactivate", e = "labels" },
    menu = {
      { label = "Open", command = "open" },
      { label = "New Value", command = "new" },
      { label = "Edit Labels", command = "labels" },
      { label = "Deactivate", command = "deactivate" },
    },
    on_command = function(cmd, v)
      V.value_command(tab, cmd, a, v)
    end,
  })
end

function V.attr_command(tab, cmd, a)
  if cmd == "new" then
    V.attr_new()
  elseif not a then
    return
  elseif cmd == "open" then
    V.push(tab, V.attr_detail(a))
  elseif cmd == "value" then
    V.value_new(a)
  elseif cmd == "labels" then
    V.labels_dialog("Attribute " .. a.name, a, SVC.ATTR .. "UpdateAttribute", function()
      UI.load(V.attr, true)
    end)
  elseif cmd == "deactivate" then
    UI.confirm(
      "Deactivate attribute " .. a.fqn .. "? Its values are deactivated too.",
      SVC.ATTR .. "DeactivateAttribute",
      { id = a.id },
      "Deactivated " .. a.name,
      function()
        a.active = false
        UI.load(V.attr, true)
      end
    )
  end
end

function V.value_command(tab, cmd, a, v)
  if not a then
    return
  end
  if cmd == "new" then
    V.value_new(a)
  elseif not v then
    return
  elseif cmd == "open" then
    V.push(tab, V.value_detail(a, v))
  elseif cmd == "labels" then
    V.labels_dialog("Value " .. v.value, v, SVC.ATTR .. "UpdateAttributeValue", nil)
  elseif cmd == "deactivate" then
    UI.confirm(
      "Deactivate value " .. v.fqn .. "?",
      SVC.ATTR .. "DeactivateAttributeValue",
      { id = v.id },
      "Deactivated " .. v.value,
      function()
        v.active = false
      end
    )
  end
end

function V.namespace_field(ns)
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

function V.attr_new(ns_override, after)
  UI.dialog({
    title = "New Attribute",
    submit = "Create",
    fields = {
      V.namespace_field(ns_override or V.attr.namespace),
      { key = "name", label = "Name", placeholder = "classification", required = true },
      { key = "rule", label = "Rule", kind = "enum", options = V.RULES },
      { key = "values", label = "Values", placeholder = "secret, confidential, public" },
    },
    on_submit = function(v, done)
      local req = { namespaceId = v.namespace, name = U.trim(v.name), rule = v.rule }
      local values = U.split(v.values, ",")
      if #values > 0 then
        req.values = values
      end
      UI.save(SVC.ATTR .. "CreateAttribute", req, done, function()
        ttt.notify("Created attribute " .. req.name)
        UI.load(V.attr, true)
        Api.refresh_counts()
        if after then
          after()
        end
      end)
    end,
  })
end

function V.value_new(a)
  UI.dialog({
    title = "New Value · " .. a.fqn,
    submit = "Create",
    fields = {
      { key = "value", label = "Value", placeholder = "confidential", required = true },
    },
    on_submit = function(v, done)
      UI.save(SVC.ATTR .. "CreateAttributeValue", { attributeId = a.id, value = U.trim(v.value) }, done, function(data)
        if data.value then
          a.values = a.values or {}
          a.values[#a.values + 1] = data.value
          if V.values.attr == a then
            V.values.all = V.filter_values(a.values, V.values)
            V.values.offset = math.max(0, math.floor((#V.values.all - 1) / PAGE) * PAGE)
            V.values.sel = #V.values.all - V.values.offset
            UI.slice(V.values)
          end
        end
        ttt.notify("Created value " .. U.trim(v.value))
      end)
    end,
  })
end

function V.attr_detail(a)
  local page = { title = a.fqn }
  local values = V.sub_list("attr-values:" .. a.id, { client = true })
  page.actions = function(h, tab)
    if page.tab == "values" then
      h:button({
        label = "New",
        on_click = function()
          V.value_new(a)
        end,
      })
    else
      V.policy_actions(h, a, function(cmd)
        V.attr_command(tab, cmd, a)
      end)
    end
  end
  page.render = function(p, tab)
    local current = V.tab_strip(p, page, {
      { id = "details", label = "Details" },
      { id = "values", label = "Values (" .. #(a.values or {}) .. ")" },
    })
    if current == "values" then
      local refilter = function()
        values.all = V.filter_values(a.values, values)
        UI.slice(values)
      end
      refilter()
      V.values_filters(p, values, refilter, 1)
      V.values_table(p, tab, a, values, "Values")
      return
    end
    p:keyvalue(V.kv({
      { "FQN", a.fqn },
      { "Namespace", a.namespace and a.namespace.name },
      { "Name", a.name },
      { "Rule", U.rule(a) },
      { "Status", U.active(a.active) },
      { "Values", tostring(#(a.values or {})) },
      { "Labels", U.labels(a.metadata) },
      { "ID", a.id },
      { "Created", U.created(a) },
      { "Updated", U.updated(a) },
    }))
  end
  return page
end

function V.value_detail(a, v)
  return {
    title = v.value,
    actions = function(h, tab)
      V.policy_actions(h, v, function(cmd)
        V.value_command(tab, cmd, a, v)
      end)
    end,
    render = function(p)
      p:keyvalue(V.kv({
        { "FQN", v.fqn },
        { "Attribute", a.fqn },
        { "Value", v.value },
        { "Status", U.active(v.active) },
        { "Labels", U.labels(v.metadata) },
        { "ID", v.id },
      }))
    end,
  }
end

-- Actions --------------------------------------------------------------------

V.act = UI.list("actions", {
  method = SVC.ACT .. "ListActions",
  request = function(lv)
    if lv.namespace and lv.namespace ~= "" then
      return { namespaceId = lv.namespace }
    end
    return {}
  end,
  extract = function(data)
    local out = {}
    for _, a in ipairs(data.actionsStandard or {}) do
      a.kind = "Standard"
      out[#out + 1] = a
    end
    for _, a in ipairs(data.actionsCustom or {}) do
      a.kind = "Custom"
      out[#out + 1] = a
    end
    return out
  end,
})

function V.act_root()
  return {
    title = "Actions",
    actions = function(h)
      h:button({
        label = "New",
        on_click = function()
          V.act_new()
        end,
      })
      UI.refresh_button(h, V.act)
    end,
    render = function(p, tab)
      local lv = V.act
      UI.ensure(lv)
      UI.toolbar(p, function(h)
        UI.namespace_filter(h, lv)
      end)
      UI.table(p, lv, {
        frame = "Actions",
        noun = "actions",
        columns = {
          { label = "Name" },
          { label = "Type", width = 9 },
          { label = "Namespace" },
          { label = "Created", width = 16 },
        },
        row = function(a)
          return { a.name, a.kind, a.namespace and a.namespace.name or "", U.created(a) }
        end,
        style = function(a)
          return a.kind == "Standard" and "muted" or "default"
        end,
        on_open = function(a)
          V.act_command(tab, "rename", a)
        end,
        keys = { n = "new", e = "rename", d = "delete" },
        menu = {
          { label = "Rename", command = "rename" },
          { label = "Delete", command = "delete" },
        },
        on_command = function(cmd, a)
          V.act_command(tab, cmd, a)
        end,
      })
    end,
  }
end

function V.act_command(_, cmd, a)
  if cmd == "new" then
    V.act_new()
  elseif not a then
    return
  elseif a.kind == "Standard" and (cmd == "rename" or cmd == "delete") then
    ttt.notify("Standard actions can't be changed", "warning")
  elseif cmd == "rename" then
    UI.dialog({
      title = "Rename Action",
      submit = "Save",
      fields = { { key = "name", label = "Name", value = a.name, required = true } },
      on_submit = function(v, done)
        UI.save(SVC.ACT .. "UpdateAction", { id = a.id, name = U.trim(v.name) }, done, function()
          a.name = U.trim(v.name)
        end)
      end,
    })
  elseif cmd == "delete" then
    UI.confirm(
      "Delete action " .. a.name .. "?",
      SVC.ACT .. "DeleteAction",
      { id = a.id },
      "Deleted " .. a.name,
      function()
        UI.load(V.act, true)
        Api.refresh_counts()
      end
    )
  end
end

function V.act_new(ns_override, after)
  UI.dialog({
    title = "New Action",
    submit = "Create",
    fields = {
      V.namespace_field(ns_override or V.act.namespace),
      { key = "name", label = "Name", placeholder = "approve", required = true },
    },
    on_submit = function(v, done)
      UI.save(SVC.ACT .. "CreateAction", { namespaceId = v.namespace, name = U.trim(v.name) }, done, function()
        ttt.notify("Created action " .. U.trim(v.name))
        UI.load(V.act, true)
        Api.refresh_counts()
        if after then
          after()
        end
      end)
    end,
  })
end

-- Key access servers and keys ------------------------------------------------

V.SOURCES = {
  { label = "Internal", value = "SOURCE_TYPE_INTERNAL" },
  { label = "External", value = "SOURCE_TYPE_EXTERNAL" },
  { label = "Unspecified", value = "SOURCE_TYPE_UNSPECIFIED" },
}

V.ALGS = {
  { label = "RSA 2048", value = "ALGORITHM_RSA_2048" },
  { label = "RSA 4096", value = "ALGORITHM_RSA_4096" },
  { label = "EC P-256", value = "ALGORITHM_EC_P256" },
  { label = "EC P-384", value = "ALGORITHM_EC_P384" },
  { label = "EC P-521", value = "ALGORITHM_EC_P521" },
}

V.MODES = {
  { label = "Public key only", value = "KEY_MODE_PUBLIC_KEY_ONLY" },
  { label = "Config root key (wrapped locally)", value = "KEY_MODE_CONFIG_ROOT_KEY" },
  { label = "Provider root key (wrapped by a provider)", value = "KEY_MODE_PROVIDER_ROOT_KEY" },
  { label = "Remote (key stays in the provider)", value = "KEY_MODE_REMOTE" },
}

V.ALL_KEYS = { all = true, name = "All keys" }

V.kas = UI.list("kas", {
  method = SVC.KAS .. "ListKeyAccessServers",
  search = true,
  extract = function(data)
    local out = { V.ALL_KEYS }
    for _, k in ipairs(data.keyAccessServers or {}) do
      out[#out + 1] = k
    end
    return out
  end,
  on_loaded = function()
    V.keys_follow(true)
  end,
})

function V.keys_request(lv, kas_id)
  local req = {}
  if kas_id then
    req.kasId = kas_id
  end
  if lv.alg and lv.alg ~= "" then
    req.keyAlgorithm = lv.alg
  end
  return req
end

V.keys = UI.list("keys", {
  method = SVC.KAS .. "ListKeys",
  search = true,
  request = function(lv)
    return V.keys_request(lv, lv.kas and not lv.kas.all and lv.kas.id or nil)
  end,
  extract = function(data)
    return data.kasKeys
  end,
})

V.keys_later, V.keys_cancel = ttt.debounce(150, function()
  UI.load(V.keys)
end)

function V.keys_follow(now)
  local k = UI.selected(V.kas)
  if V.keys.kas == k and V.keys.loaded then
    return
  end
  V.keys.kas = k
  V.keys.offset = 0
  V.keys.sel = 1
  if now then
    V.keys_cancel()
    UI.load(V.keys)
    return
  end
  V.keys.loading = true
  V.keys_later()
end

function V.can_be_base(kk)
  local key = kk and kk.key
  return key ~= nil
    and key.keyMode ~= "KEY_MODE_PUBLIC_KEY_ONLY"
    and key.keyStatus == "KEY_STATUS_ACTIVE"
    and not V.is_base(kk)
end

function V.is_base(kk)
  return S.base and kk.key and S.base.kid == kk.key.keyId and S.base.kas_id == kk.kasId
end

function V.kas_root()
  return {
    title = "KAS & Keys",
    actions = function(h)
      h:button({ label = "New", on_click = V.kas_new })
      UI.refresh_button(h, V.kas, Api.load_base_key)
    end,
    render = function(p, tab)
      local lv = V.kas
      UI.ensure(lv)
      UI.toolbar(p, function(h)
        UI.search(h, lv, "Search key access servers…")
      end)
      local w = p:size()
      local left = math.max(32, math.floor(w * 0.36))
      local k = UI.selected(lv)
      p:hstack({
        render = function(h)
          UI.frame(h, "Key Access Servers", function(b)
            UI.table(b, lv, {
              noun = "servers",
              columns = { { label = "Name" }, { label = "Keys", width = 5, align = "right" } },
              row = function(item)
                if item.all then
                  return { "All keys", tostring(S.counts.keys or "") }
                end
                return { item.name or U.host(item.uri), tostring(#(item.kasKeys or {})) }
              end,
              style = function(item)
                return item.all and "bold" or "default"
              end,
              on_move = function()
                V.keys_follow(false)
              end,
              on_page = function()
                V.keys_follow(true)
              end,
              on_open = function(item)
                if not item.all then
                  V.push(tab, V.kas_detail(item))
                end
              end,
              keys = { n = "new", e = "edit", d = "delete" },
              menu = {
                { label = "Open", command = "open" },
                { label = "Edit", command = "edit" },
                { label = "Delete", command = "delete" },
                { separator = true },
                { label = "New Key", command = "key" },
              },
              on_command = function(cmd, item)
                V.kas_command(tab, cmd, item)
              end,
            })
          end, { width = left })
          UI.frame(
            h,
            k and not k.all and ("Keys · " .. (k.name or U.host(k.uri))) or "Keys · all servers",
            function(b)
              V.keys_panel(b, tab, k)
            end
          )
        end,
      })
    end,
  }
end

function V.keys_panel(p, tab, kas, lv)
  lv = lv or V.keys
  UI.toolbar(p, function(h)
    V.keys_filters(h, lv)
    V.keys_actions(h, tab, kas, lv)
  end, 0)
  V.keys_table(p, tab, kas, lv)
end

function V.keys_filters(h, lv)
  UI.search(h, lv, "Search keys…")
  UI.filter(h, lv, "alg", UI.with_all("All algorithms", V.ALGS))
end

function V.keys_actions(h, tab, kas, lv)
  h:button({
    label = "New",
    on_click = function()
      V.key_form(tab, kas, nil)
    end,
  })
  h:button({
    label = "Rotate",
    on_click = function()
      V.key_command(tab, "rotate", UI.selected(lv))
    end,
  })
  h:button({
    label = "Set Base",
    disabled = not V.can_be_base(UI.selected(lv)),
    on_click = function()
      V.key_command(tab, "base", UI.selected(lv))
    end,
  })
end

function V.keys_table(p, tab, kas, lv)
  local all = not kas or kas.all
  local columns = {
    { label = "", width = 1 },
    { label = "Key ID" },
    { label = "Algorithm", width = 9 },
    { label = "Mode", width = 15 },
    { label = "Status", width = 8 },
  }
  if all then
    columns[#columns + 1] = { label = "KAS" }
  else
    columns[#columns + 1] = { label = "Created", width = 16 }
  end
  UI.table(p, lv, {
    noun = "keys",
    columns = columns,
    row = function(kk)
      local key = kk.key or {}
      local row = {
        V.is_base(kk) and "★" or "",
        key.keyId or "",
        U.alg(key.keyAlgorithm),
        U.human(key.keyMode, "KEY_MODE_"),
        U.human(key.keyStatus, "KEY_STATUS_"),
      }
      row[#row + 1] = all and U.host(kk.kasUri) or U.created(key)
      return row
    end,
    style = function(kk)
      local status = kk.key and kk.key.keyStatus
      return status == "KEY_STATUS_ACTIVE" and "default" or "muted"
    end,
    on_open = function(kk)
      V.push(tab, V.key_detail(kk))
    end,
    keys = { n = "new", r = "rotate", b = "base" },
    menu = {
      { label = "Open", command = "open" },
      { label = "Rotate…", command = "rotate" },
      { label = "Set as Base Key", command = "base" },
    },
    on_command = function(cmd, kk)
      if cmd == "new" then
        V.key_form(tab, kas, nil)
      else
        V.key_command(tab, cmd, kk)
      end
    end,
  })
end

function V.kas_command(tab, cmd, k)
  if cmd == "new" then
    V.kas_new()
  elseif not k or k.all then
    return
  elseif cmd == "open" then
    V.push(tab, V.kas_detail(k))
  elseif cmd == "edit" then
    V.kas_edit(k)
  elseif cmd == "key" then
    V.key_form(tab, k, nil)
  elseif cmd == "delete" then
    UI.confirm(
      "Delete key access server " .. (k.name or k.uri) .. "?",
      SVC.KAS .. "DeleteKeyAccessServer",
      { id = k.id },
      "Deleted " .. (k.name or k.uri),
      function()
        UI.load(V.kas, true)
        Api.refresh_counts()
      end
    )
  end
end

function V.kas_fields(k)
  k = k or {}
  return {
    { key = "name", label = "Name", value = k.name, placeholder = "kas-us-east-1" },
    { key = "uri", label = "URI", value = k.uri, placeholder = "https://kas.example.com", required = true },
    {
      key = "source",
      label = "Source",
      kind = "enum",
      options = V.SOURCES,
      value = k.sourceType or "SOURCE_TYPE_INTERNAL",
    },
  }
end

function V.kas_request(v, id)
  local req = { id = id, uri = U.trim(v.uri), sourceType = v.source }
  if U.trim(v.name) ~= "" then
    req.name = U.trim(v.name)
  end
  return req
end

function V.kas_new()
  UI.dialog({
    title = "New Key Access Server",
    submit = "Create",
    fields = V.kas_fields(nil),
    on_submit = function(v, done)
      local req = V.kas_request(v)
      UI.save(SVC.KAS .. "CreateKeyAccessServer", req, done, function()
        ttt.notify("Created key access server " .. (req.name or req.uri))
        UI.load(V.kas, true)
        Api.refresh_counts()
      end)
    end,
  })
end

function V.kas_edit(k)
  UI.dialog({
    title = "Edit Key Access Server",
    submit = "Save",
    fields = V.kas_fields(k),
    on_submit = function(v, done)
      local req = V.kas_request(v, k.id)
      UI.save(SVC.KAS .. "UpdateKeyAccessServer", req, done, function()
        k.name, k.uri, k.sourceType = req.name, req.uri, req.sourceType
      end)
    end,
  })
end

function V.kas_detail(k)
  local page = { title = k.name or U.host(k.uri) }
  local keys = V.sub_list("kas-keys:" .. k.id, {
    method = SVC.KAS .. "ListKeys",
    search = true,
    request = function(lv)
      return V.keys_request(lv, k.id)
    end,
    extract = V.keys.spec.extract,
  })
  page.actions = function(h, tab)
    if page.tab == "keys" then
      V.keys_actions(h, tab, k, keys)
      UI.refresh_button(h, keys)
      return
    end
    h:button({
      label = "New Key",
      on_click = function()
        V.key_form(tab, k, nil)
      end,
    })
    h:button({
      label = "Edit",
      on_click = function()
        V.kas_edit(k)
      end,
    })
    h:button({
      label = "Delete",
      on_click = function()
        V.kas_command(tab, "delete", k)
      end,
    })
  end
  page.render = function(p, tab)
    local current = V.tab_strip(p, page, {
      { id = "details", label = "Details" },
      { id = "keys", label = "Keys (" .. #(k.kasKeys or {}) .. ")" },
    })
    if current == "keys" then
      UI.ensure(keys)
      UI.toolbar(p, function(h)
        V.keys_filters(h, keys)
      end)
      UI.frame(p, "Keys", function(b)
        V.keys_table(b, tab, k, keys)
      end)
      return
    end
    p:keyvalue(V.kv({
      { "Name", k.name },
      { "URI", k.uri },
      { "Source", U.human(k.sourceType, "SOURCE_TYPE_") },
      { "Keys", tostring(#(k.kasKeys or {})) },
      { "ID", k.id },
      { "Created", U.created(k) },
      { "Updated", U.updated(k) },
    }))
  end
  return page
end

function V.key_command(tab, cmd, kk)
  if not kk or not kk.key then
    return
  end
  if cmd == "open" then
    V.push(tab, V.key_detail(kk))
  elseif cmd == "rotate" then
    V.key_form(tab, nil, kk)
  elseif cmd == "base" and not V.can_be_base(kk) then
    if kk.key.keyMode == "KEY_MODE_PUBLIC_KEY_ONLY" then
      ttt.notify(
        "A public-key-only key can't be the base key: the platform has no private key to decrypt with",
        "warning"
      )
    elseif V.is_base(kk) then
      ttt.notify(kk.key.keyId .. " is already the base key")
    else
      ttt.notify("Only an active key can be the base key", "warning")
    end
  elseif cmd == "base" then
    UI.confirm(
      "Make " .. kk.key.keyId .. " on " .. U.host(kk.kasUri) .. " the base key? New TDFs use it by default.",
      SVC.KAS .. "SetBaseKey",
      { id = kk.key.id },
      "Base key is now " .. kk.key.keyId,
      function()
        Api.load_base_key()
      end
    )
  end
end

function V.pem(kk)
  local ctx = kk.key and kk.key.publicKeyCtx
  if not ctx or not ctx.pem then
    return nil
  end
  return crypto.base64_decode(ctx.pem) or ctx.pem
end

function V.key_detail(kk)
  local key = kk.key or {}
  return {
    title = key.keyId or "key",
    actions = function(h, tab)
      h:button({
        label = "Rotate",
        on_click = function()
          V.key_command(tab, "rotate", kk)
        end,
      })
      if V.can_be_base(kk) then
        h:button({
          label = "Set Base",
          on_click = function()
            V.key_command(tab, "base", kk)
          end,
        })
      end
    end,
    render = function(p)
      p:keyvalue(V.kv({
        { "Key ID", key.keyId },
        { "KAS", kk.kasUri },
        { "Algorithm", U.alg(key.keyAlgorithm) },
        { "Mode", U.human(key.keyMode, "KEY_MODE_") },
        { "Status", U.human(key.keyStatus, "KEY_STATUS_") },
        { "Base key", V.is_base(kk) and "Yes" or "No" },
        { "Provider", key.providerConfig and key.providerConfig.name or "" },
        { "ID", key.id },
        { "Created", U.created(key) },
      }))
      local pem = V.pem(kk)
      if pem then
        p:markdown({ text = "**Public key**\n\n```\n" .. pem .. "\n```", margin_top = 1, padding_left = 1 })
      end
    end,
  }
end

function V.needs_private(vals)
  return vals.mode == "KEY_MODE_CONFIG_ROOT_KEY" or vals.mode == "KEY_MODE_PROVIDER_ROOT_KEY"
end

function V.needs_provider(vals)
  return vals.mode == "KEY_MODE_PROVIDER_ROOT_KEY" or vals.mode == "KEY_MODE_REMOTE"
end

-- Creating and rotating share one form: rotating sends the same fields as the
-- replacement key and the platform marks the old key as rotated.
function V.key_form(tab, kas, rotating)
  if not rotating and (not kas or kas.all) then
    ttt.notify("Select a key access server first", "warning")
    return
  end
  local old = rotating and rotating.key or {}
  local target = rotating and U.host(rotating.kasUri) or (kas.name or U.host(kas.uri))
  local form
  form = UI.new_form({
    submit = rotating and "Rotate" or "Create Key",
    fields = {
      { key = "key_id", label = "Key ID", required = true, placeholder = rotating and (old.keyId .. "-2") or "r1" },
      { key = "alg", label = "Algorithm", kind = "enum", options = V.ALGS, value = old.keyAlgorithm },
      { key = "mode", label = "Mode", kind = "enum", options = V.MODES, value = old.keyMode },
      {
        key = "pem",
        label = "Public key (PEM)",
        kind = "multiline",
        rows = 8,
        required = true,
        placeholder = "-----BEGIN PUBLIC KEY-----",
      },
      {
        key = "wrapped",
        label = "Wrapped private key (base64)",
        kind = "multiline",
        rows = 3,
        required = true,
        show = V.needs_private,
      },
      {
        key = "provider",
        label = "Provider config",
        kind = "enum",
        options = function()
          return S.providers
        end,
        show = V.needs_provider,
      },
    },
    on_submit = function(v, done)
      local key = {
        keyId = U.trim(v.key_id),
        keyMode = v.mode,
        publicKeyCtx = { pem = crypto.base64_encode(U.trim(v.pem) .. "\n") },
      }
      if V.needs_private(v) then
        key.privateKeyCtx = { keyId = U.trim(v.key_id), wrappedKey = U.trim(v.wrapped) }
      end
      if V.needs_provider(v) then
        key.providerConfigId = v.provider
      end
      local path, req
      if rotating then
        key.algorithm = v.alg
        path, req = SVC.KAS .. "RotateKey", { id = old.id, newKey = key }
      else
        key.keyAlgorithm = v.alg
        key.kasId = kas.id
        path, req = SVC.KAS .. "CreateKey", key
      end
      UI.save(path, req, done, function()
        ttt.notify((rotating and "Rotated to " or "Created key ") .. key.keyId)
        V.back(tab)
        for name, lv in pairs(V.lists) do
          if name == "keys" or name:find("^kas%-keys:") then
            lv.loaded = false
          end
        end
        UI.load(V.keys, true)
        UI.load(V.kas, true)
        Api.refresh_counts()
      end)
    end,
  })
  V.push(tab, {
    title = (rotating and ("Rotate " .. old.keyId) or "New Key") .. " · " .. target,
    render = function(p)
      local w = p:size()
      p:hstack({
        render = function(h)
          h:box({
            width = math.min(w, 96),
            padding_top = 1,
            render = function(b)
              UI.render_form(b, form, function()
                V.back(tab)
              end)
            end,
          })
        end,
      })
    end,
  })
end

-- Authorization (v2) ---------------------------------------------------------

SVC.AUTHZ = "authorization.v2.AuthorizationService/"

V.ENTITY_TYPES = {
  { label = "Client ID", value = "clientId" },
  { label = "Email", value = "emailAddress" },
  { label = "Username", value = "userName" },
  { label = "JWT", value = "jwt" },
  { label = "This connection's token", value = "request" },
}

V.ENTITY_HINTS = {
  clientId = "opentdf",
  emailAddress = "alice@example.com",
  userName = "alice",
  jwt = "eyJhbGciOi…",
  request = "uses the token of the configured client",
}

function V.new_entity()
  return { kind = "clientId", value = "opentdf" }
end

function V.entity_identifier(entity)
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

function V.entity_label(entity)
  if entity.kind == "request" then
    return "client " .. S.conn.client_id .. " (request token)"
  end
  if entity.kind == "jwt" then
    return "the pasted JWT"
  end
  return U.option_label(V.ENTITY_TYPES, entity.kind):lower() .. " " .. U.trim(entity.value)
end

function V.entity_fields(h, entity, on_submit)
  UI.frame(h, "Entity", function(b)
    UI.dropdown(b, V.ENTITY_TYPES, entity.kind, function(kind)
      if kind ~= entity.kind then
        entity.kind = kind
        entity.value = kind == "clientId" and S.conn.client_id or ""
      end
      S.redraw()
    end)
  end, { width = 28 })
  if entity.kind == "request" then
    UI.frame(h, "Value", function(b)
      b:label({ text = V.ENTITY_HINTS.request, style = "muted", padding_left = 1 })
    end)
  else
    h:input({
      border = true,
      title = U.option_label(V.ENTITY_TYPES, entity.kind),
      value = entity.value,
      placeholder = V.ENTITY_HINTS[entity.kind],
      on_change = function(text)
        entity.value = text
      end,
      on_submit = on_submit,
    })
  end
end

-- Entitlements

V.ent = {
  entity = V.new_entity(),
  comprehensive = true,
  busy = false,
  err = nil,
  ran = nil,
  list = UI.list("entitlements", { client = true }),
}

function V.missing_entity(st)
  if st.entity.kind ~= "request" and U.trim(st.entity.value) == "" then
    st.err = "Enter an entity first"
    S.redraw()
    return true
  end
  return false
end

function V.ent_run()
  local st = V.ent
  if V.missing_entity(st) then
    return
  end
  st.busy = true
  st.err = nil
  st.list.loading = true
  S.redraw()
  local label = V.entity_label(st.entity)
  Api.call(SVC.AUTHZ .. "GetEntitlements", {
    entityIdentifier = V.entity_identifier(st.entity),
    withComprehensiveHierarchy = st.comprehensive,
  }, function(err, data)
    st.busy = false
    st.list.loading = false
    if err then
      st.err = err
      st.list.all = {}
      UI.slice(st.list)
      S.redraw()
      return
    end
    local rows = {}
    local entities = data.entitlements or {}
    for _, ent in ipairs(entities) do
      for fqn, list in pairs(ent.actionsPerAttributeValueFqn or {}) do
        local names = {}
        for _, a in ipairs(list.actions or {}) do
          names[#names + 1] = a.name
        end
        table.sort(names)
        rows[#rows + 1] = { fqn = fqn, actions = table.concat(names, ", "), entity = ent.ephemeralId or "" }
      end
    end
    table.sort(rows, function(a, b)
      if a.fqn == b.fqn then
        return a.entity < b.entity
      end
      return a.fqn < b.fqn
    end)
    st.all = rows
    st.entities = #entities
    st.ran = label
    V.ent_filter()
    S.redraw()
  end)
end

function V.ent_filter()
  local st = V.ent
  local term = st.list.search:lower()
  local out = {}
  for _, r in ipairs(st.all or {}) do
    if term == "" or r.fqn:lower():find(term, 1, true) or r.actions:lower():find(term, 1, true) then
      out[#out + 1] = r
    end
  end
  st.list.all = out
  st.list.offset = 0
  st.list.sel = 1
  UI.slice(st.list)
end

function V.ent_root()
  return {
    title = "Entitlements",
    render = function(p)
      local st = V.ent
      p:hstack({
        height = 3,
        gap = 1,
        margin_top = 1,
        render = function(h)
          V.entity_fields(h, st.entity, V.ent_run)
          UI.checkbox(h, "Full hierarchy", st.comprehensive, function(v)
            st.comprehensive = v
          end, { padding_top = 1 })
          UI.button_box(h, st.busy and "Checking…" or "Get Entitlements", V.ent_run, st.busy)
        end,
      })
      local summary, style = "", "muted"
      if st.err then
        summary, style = "✕ " .. st.err, "danger"
      elseif st.ran then
        local n = #(st.all or {})
        summary = n .. " entitled value" .. (n == 1 and "" or "s") .. " for " .. st.ran
        if (st.entities or 0) > 1 then
          summary = summary .. " across " .. st.entities .. " entities"
        end
      end
      local w = p:size()
      p:hstack({
        height = 1,
        gap = 2,
        margin_top = 1,
        render = function(h)
          h:label({ text = summary, style = style, padding_left = 1, width = math.max(w - 44, 10) })
          UI.search(h, st.list, "Filter values or actions…", V.ent_filter)
        end,
      })
      local columns = { { label = "Attribute value" }, { label = "Actions", width = 28 } }
      if (st.entities or 0) > 1 then
        table.insert(columns, 1, { label = "Entity", width = 28 })
      end
      UI.table(p, st.list, {
        frame = "Entitlements",
        noun = "entitlements",
        empty = st.ran and "This entity isn't entitled to any attribute values"
          or "Choose an entity and press Get Entitlements",
        columns = columns,
        row = function(r)
          if (st.entities or 0) > 1 then
            return { r.entity, r.fqn, r.actions }
          end
          return { r.fqn, r.actions }
        end,
        on_open = function(r)
          V.dec.resources = { r.fqn }
          V.dec.entity = { kind = st.entity.kind, value = st.entity.value }
          V.open("decision")
        end,
      })
    end,
  }
end

-- Decision

V.dec = {
  entity = V.new_entity(),
  action = "read",
  resources = {},
  each = false,
  busy = false,
  err = nil,
  result = nil,
}

function V.dec_run()
  local st = V.dec
  if V.missing_entity(st) then
    return
  end
  if #st.resources == 0 then
    st.err = "Add at least one attribute value"
    S.redraw()
    return
  end
  st.busy = true
  st.err = nil
  S.redraw()
  local action = U.trim(st.action)
  if action == "" then
    action = "read"
  end
  local label = V.entity_label(st.entity)
  local done = function(err, decisions, obligations)
    st.busy = false
    if err then
      st.err = err
      st.result = nil
    else
      st.result = { entity = label, action = action, decisions = decisions, obligations = obligations or {} }
    end
    S.redraw()
  end
  if not st.each then
    local fqns = {}
    for i, f in ipairs(st.resources) do
      fqns[i] = f
    end
    Api.call(SVC.AUTHZ .. "GetDecision", {
      entityIdentifier = V.entity_identifier(st.entity),
      action = { name = action },
      resource = { ephemeralId = "resource", attributeValues = { fqns = fqns } },
    }, function(err, data)
      if err then
        return done(err)
      end
      local d = data.decision or {}
      done(
        nil,
        { { label = #fqns .. " value" .. (#fqns == 1 and "" or "s") .. " together", decision = d.decision } },
        d.requiredObligations
      )
    end)
    return
  end
  local resources = {}
  for i, f in ipairs(st.resources) do
    resources[i] = { ephemeralId = "r" .. i, attributeValues = { fqns = { f } } }
  end
  Api.call(SVC.AUTHZ .. "GetDecisionMultiResource", {
    entityIdentifier = V.entity_identifier(st.entity),
    action = { name = action },
    resources = resources,
  }, function(err, data)
    if err then
      return done(err)
    end
    local out, obligations = {}, {}
    for _, d in ipairs(data.resourceDecisions or {}) do
      local i = tonumber((d.ephemeralResourceId or ""):sub(2))
      out[#out + 1] = { label = st.resources[i] or d.ephemeralResourceId, decision = d.decision }
      for _, o in ipairs(d.requiredObligations or {}) do
        obligations[#obligations + 1] = o
      end
    end
    done(nil, out, obligations)
  end)
end

function V.verdict(decisions)
  local permit = #decisions > 0
  for _, d in ipairs(decisions) do
    if d.decision ~= "DECISION_PERMIT" then
      permit = false
    end
  end
  return permit
end

function V.value_picker(on_pick)
  local lv = UI.list("picker", { client = true })
  lv.search = V.picker_search or ""
  local gen = 0
  local function fetch()
    gen = gen + 1
    local mine = gen
    lv.loading = true
    local req = { pagination = { limit = 100 } }
    if lv.search ~= "" then
      req.search = { term = lv.search }
    end
    Api.call(SVC.ATTR .. "ListAttributes", req, function(err, data)
      if mine ~= gen then
        return
      end
      lv.loading = false
      lv.err = err
      local out = {}
      for _, a in ipairs((data and data.attributes) or {}) do
        for _, v in ipairs(a.values or {}) do
          out[#out + 1] = { fqn = v.fqn, rule = U.rule(a) }
        end
      end
      lv.all = out
      lv.offset = 0
      lv.sel = 1
      UI.slice(lv)
      S.redraw()
    end)
  end
  fetch()
  UI.open_dialog("Add Attribute Value", 96, 26, function(p)
    UI.search(p, lv, "Search attributes, e.g. acme or department…", function()
      V.picker_search = lv.search
      fetch()
    end)
    UI.table(p, lv, {
      frame = "Attribute values",
      noun = "values",
      empty = "No attribute values match",
      columns = { { label = "Attribute value" }, { label = "Rule", width = 9 } },
      row = function(r)
        return { r.fqn, r.rule }
      end,
      on_open = function(r)
        ttt.close_dialog()
        on_pick(r.fqn)
      end,
    })
    p:label({ text = "Enter or double-click adds the value.", style = "muted" })
  end)
end

function V.dec_root()
  return {
    title = "Decision",
    render = function(p)
      local st = V.dec
      p:hstack({
        height = 3,
        gap = 1,
        margin_top = 1,
        render = function(h)
          V.entity_fields(h, st.entity, V.dec_run)
          h:box({
            width = 18,
            render = function(b)
              b:input({
                border = true,
                title = "Action",
                value = st.action,
                placeholder = "read",
                on_change = function(text)
                  st.action = text
                end,
                on_submit = V.dec_run,
              })
            end,
          })
          UI.button_box(h, st.busy and "Deciding…" or "Get Decision", V.dec_run, st.busy)
        end,
      })
      p:hstack({
        height = 1,
        gap = 1,
        margin_top = 1,
        align = "right",
        render = function(h)
          h:button({
            label = "Add Value",
            on_click = function()
              V.value_picker(function(fqn)
                for _, f in ipairs(st.resources) do
                  if f == fqn then
                    return
                  end
                end
                st.resources[#st.resources + 1] = fqn
                S.redraw()
              end)
            end,
          })
          UI.checkbox(h, "Decide each value separately", st.each, function(v)
            st.each = v
          end)
        end,
      })
      local rows = {}
      for i, f in ipairs(st.resources) do
        rows[i] = { f }
      end
      UI.frame(p, "Resource attribute values", function(b)
        b:table({
          inset = 1,
          columns = { { label = "Attribute value FQN" } },
          rows = rows,
          empty = "Add the attribute values the resource carries",
          key_commands = { d = "remove", x = "remove" },
          node_menu = { { label = "Remove", command = "remove" } },
          on_command = function(cmd, i)
            if cmd == "remove" then
              table.remove(st.resources, i)
              S.redraw()
            end
          end,
        })
      end, { height = math.max(math.min(#rows, 8), 2) + 4 })
      local r = st.result
      if st.err then
        p:label({ text = "✕ " .. st.err, style = "danger", margin_top = 1, padding_left = 1 })
        return
      end
      if not r then
        p:label({
          text = "Pick an entity, an action and the resource's attribute values, then press Get Decision.",
          style = "muted",
          margin_top = 1,
          padding_left = 1,
        })
        return
      end
      local permit = V.verdict(r.decisions)
      local permitted = 0
      for _, d in ipairs(r.decisions) do
        if d.decision == "DECISION_PERMIT" then
          permitted = permitted + 1
        end
      end
      local detail = r.entity .. "  ·  " .. r.action
      if #r.decisions > 1 then
        detail = detail .. "  ·  " .. permitted .. " of " .. #r.decisions .. " permitted"
      end
      p:hstack({
        height = 3,
        gap = 1,
        margin_top = 1,
        render = function(h)
          h:label({
            text = permit and " ✓ PERMIT" or " ✕ DENY",
            style = permit and "success" or "danger",
            border = true,
            width = 14,
          })
          h:box({
            padding_top = 1,
            render = function(b)
              b:label({ text = detail, style = "muted" })
            end,
          })
        end,
      })
      local drows, dstyles = {}, {}
      for i, d in ipairs(r.decisions) do
        local ok = d.decision == "DECISION_PERMIT"
        drows[i] = { ok and "Permit" or "Deny", d.label }
        dstyles[i] = ok and "success" or "danger"
      end
      if #r.obligations > 0 then
        drows[#drows + 1] = { "", "" }
        for _, o in ipairs(r.obligations) do
          drows[#drows + 1] = { "Obligation", o }
          dstyles[#drows] = "warning"
        end
      end
      UI.frame(p, "Decisions", function(b)
        b:table({
          inset = 1,
          columns = { { label = "Decision", width = 10 }, { label = "Resource" } },
          rows = drows,
          row_styles = dstyles,
        })
      end, { margin_top = 1 })
    end,
  }
end

V.roots = {
  namespaces = V.ns_root,
  attributes = V.attr_root,
  actions = V.act_root,
  kas = V.kas_root,
  entitlements = V.ent_root,
  decision = V.dec_root,
}

-- Connection -----------------------------------------------------------------

function V.connection_dialog()
  UI.dialog({
    title = "OpenTDF Connection",
    submit = "Connect",
    width = 70,
    fields = {
      {
        key = "url",
        label = "Platform URL",
        value = S.conn.url,
        required = true,
        placeholder = "http://localhost:8080",
      },
      { key = "client_id", label = "Client ID", value = S.conn.client_id, required = true, placeholder = "opentdf" },
      {
        key = "client_secret",
        label = "Client secret",
        value = S.conn.client_secret,
        password = true,
        required = true,
      },
    },
    on_submit = function(v, done)
      local url = U.trim(v.url):gsub("/+$", "")
      S.conn = { url = url, client_id = U.trim(v.client_id), client_secret = v.client_secret }
      Api.connect(function(err)
        if err then
          return done(err)
        end
        storage.set("connection", S.conn)
        ttt.notify("Connected to " .. url)
        done()
      end)
    end,
  })
end

V.PAGE_SIZES = {
  { label = "10 per page", value = "10" },
  { label = "20 per page", value = "20" },
  { label = "50 per page", value = "50" },
  { label = "100 per page", value = "100" },
}

function V.settings_dialog()
  UI.dialog({
    title = "OpenTDF Settings",
    width = 50,
    fields = {
      { key = "page_size", label = "Page size", kind = "enum", options = V.PAGE_SIZES, value = tostring(PAGE) },
    },
    on_submit = function(v, done)
      local n = tonumber(v.page_size) or PAGE
      if n ~= PAGE then
        PAGE = n
        S.settings.page_size = n
        storage.set("settings", S.settings)
        for _, lv in pairs(V.lists) do
          lv.offset = 0
          lv.sel = 1
          lv.loaded = false
        end
      end
      done()
    end,
  })
end

-- Sidebar --------------------------------------------------------------------

function V.status_item()
  local host = U.host(S.conn.url)
  if S.status == "ok" then
    return { id = "conn", icon = "●", label = host .. " · " .. S.conn.client_id }
  elseif S.status == "connecting" then
    return { id = "conn", icon = "◌", label = "Connecting to " .. host .. "…", muted = true }
  elseif S.status == "error" then
    return { id = "conn", icon = "✕", label = host .. " · not connected", muted = true }
  end
  return { id = "conn", icon = "○", label = "Set up connection…", muted = true }
end

function V.badge(key)
  local n = S.counts[key]
  if S.status ~= "ok" or not n then
    return nil
  end
  return tostring(n)
end

function V.links(p, items)
  p:box({
    height = #items,
    render = function(b)
      b:list({
        items = items,
        inset = 1,
        badge_right = true,
        on_select = function(node)
          if node.id == "conn" then
            V.connection_dialog()
          else
            V.open(node.id)
          end
        end,
      })
    end,
  })
end

function V.nav_section(p, section)
  local muted = S.status ~= "ok"
  local items = {}
  for i, item in ipairs(section.items) do
    items[i] = { id = item.id, label = item.label, badge = item.count and V.badge(item.id), muted = muted }
  end
  p:label({ text = "• " .. section.title, style = "muted", margin_top = 1, padding_left = 1 })
  V.links(p, items)
end

function V.sidebar(p)
  S.panels.sidebar = p
  Api.ensure_connected()
  for _, section in ipairs(V.NAV) do
    V.nav_section(p, section)
  end
  p:box({ render = function() end })
  if S.status == "error" then
    p:label({ text = "✕ " .. S.message, style = "danger", padding_left = 1 })
  end
  p:divider()
  V.links(p, { V.status_item() })
end

function V.commands()
  local cmds = {
    { id = "opentdf.connection", title = "OpenTDF: Connection…", handler = V.connection_dialog },
    { id = "opentdf.settings", title = "OpenTDF: Settings…", handler = V.settings_dialog },
  }
  for _, section in ipairs(V.NAV) do
    for _, item in ipairs(section.items) do
      cmds[#cmds + 1] = {
        id = "opentdf." .. item.id,
        title = "OpenTDF: " .. item.label,
        handler = function()
          V.open(item.id)
        end,
      }
    end
  end
  return cmds
end

ttt.register({
  sidebar = {
    title = "OpenTDF",
    render = V.sidebar,
    actions = {
      { label = "Connection…", command = "connection" },
      { label = "Settings…", command = "settings" },
      { label = "Reconnect", command = "reconnect" },
      { label = "Refresh Counts", command = "counts" },
    },
    on_action = function(cmd)
      if cmd == "connection" then
        V.connection_dialog()
      elseif cmd == "settings" then
        V.settings_dialog()
      elseif cmd == "reconnect" then
        Api.connect()
      elseif cmd == "counts" then
        Api.refresh_counts()
      end
    end,
  },
  commands = V.commands(),
})
