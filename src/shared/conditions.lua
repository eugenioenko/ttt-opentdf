local U = require("core.util")
local S = require("core.state")
local UI = require("components")

-- Subject condition sets: the subject sets of a condition set and the groups of
-- a subject set all have to match; a group's conditions join with AND or OR.
local M = {}

M.OPERATORS = {
  { label = "in", value = "SUBJECT_MAPPING_OPERATOR_ENUM_IN" },
  { label = "not in", value = "SUBJECT_MAPPING_OPERATOR_ENUM_NOT_IN" },
  { label = "contains", value = "SUBJECT_MAPPING_OPERATOR_ENUM_IN_CONTAINS" },
}

M.BOOLEANS = {
  { label = "All of (AND)", value = "CONDITION_BOOLEAN_TYPE_ENUM_AND" },
  { label = "Any of (OR)", value = "CONDITION_BOOLEAN_TYPE_ENUM_OR" },
}

M.HINT = "Every subject set and every group must match. Within a group, conditions join with AND or OR."

local function operator_text(op)
  for _, o in ipairs(M.OPERATORS) do
    if o.value == op then
      return o.label
    end
  end
  return U.human(op, "SUBJECT_MAPPING_OPERATOR_ENUM_"):lower()
end

local function is_or(g)
  return g.booleanOperator == "CONDITION_BOOLEAN_TYPE_ENUM_OR"
end

function M.condition_text(c)
  local values = table.concat(c.subjectExternalValues or {}, ", ")
  return (c.subjectExternalSelectorValue or "") .. " " .. operator_text(c.operator) .. " [" .. values .. "]"
end

local function group_text(g)
  local parts = {}
  for i, c in ipairs(g.conditions or {}) do
    parts[i] = M.condition_text(c)
  end
  return table.concat(parts, is_or(g) and " or " or " and ")
end

local function groups(scs)
  local out = {}
  for _, set in ipairs((scs and scs.subjectSets) or {}) do
    for _, g in ipairs(set.conditionGroups or {}) do
      out[#out + 1] = g
    end
  end
  return out
end

-- One line for a listing.
function M.summary(scs)
  local list = groups(scs)
  if #list == 1 then
    return group_text(list[1])
  end
  local parts = {}
  for i, g in ipairs(list) do
    parts[i] = "(" .. group_text(g) .. ")"
  end
  return table.concat(parts, " and ")
end

function M.counts(scs)
  local sets = (scs and scs.subjectSets) or {}
  return #sets, #groups(scs)
end

-- The nested sets, groups and conditions, one per line.
function M.view(p, scs)
  local sets = (scs and scs.subjectSets) or {}
  if #sets == 0 then
    p:label({ text = "No conditions", style = "muted", padding_left = 1 })
    return
  end
  for i, set in ipairs(sets) do
    p:label({ text = "Subject set " .. i, style = "bold", padding_left = 1, margin_top = 1 })
    for j, g in ipairs(set.conditionGroups or {}) do
      local join = is_or(g) and "any of" or "all of"
      p:label({ text = "Group " .. j .. " · " .. join, style = "muted", padding_left = 3 })
      for _, c in ipairs(g.conditions or {}) do
        p:label({ text = M.condition_text(c), padding_left = 5 })
      end
    end
  end
end

-- Builder state: sets of groups of conditions, with values as typed text.

local function new_condition(selector, values)
  return { selector = selector or "", operator = M.OPERATORS[1].value, values = values or "" }
end

local function new_group(selector, values)
  return { op = M.BOOLEANS[1].value, conditions = { new_condition(selector, values) } }
end

local function new_set(selector, values)
  return { groups = { new_group(selector, values) } }
end

local function editable(scs)
  local sets = {}
  for i, set in ipairs(scs.subjectSets or {}) do
    local gs = {}
    for j, g in ipairs(set.conditionGroups or {}) do
      local cs = {}
      for k, c in ipairs(g.conditions or {}) do
        cs[k] = {
          selector = c.subjectExternalSelectorValue or "",
          operator = c.operator or M.OPERATORS[1].value,
          values = table.concat(c.subjectExternalValues or {}, ", "),
        }
      end
      gs[j] = { op = g.booleanOperator or M.BOOLEANS[1].value, conditions = cs }
    end
    sets[i] = { groups = gs }
  end
  return sets
end

-- opts: { scs, submit, on_save(subject_sets, done), on_cancel, before(p)?,
-- show_sets()? }. When show_sets returns false only before draws, and on_save
-- gets nil.
function M.builder(opts)
  local sets = opts.scs and editable(opts.scs) or {}
  if #sets == 0 then
    sets = { new_set(".clientId", S.conn.client_id) }
  end
  return { sets = sets, opts = opts, err = nil, busy = false }
end

local function to_subject_sets(sets)
  local out = {}
  for i, set in ipairs(sets) do
    local gs = {}
    for j, g in ipairs(set.groups) do
      local cs = {}
      for k, c in ipairs(g.conditions) do
        local where = "set " .. i .. ", group " .. j .. ", condition " .. k
        if U.trim(c.selector) == "" then
          return nil, "Enter a selector in " .. where
        end
        local values = U.split(c.values, ",")
        if #values == 0 then
          return nil, "Enter at least one value in " .. where
        end
        cs[k] =
          { subjectExternalSelectorValue = U.trim(c.selector), operator = c.operator, subjectExternalValues = values }
      end
      gs[j] = { booleanOperator = g.op, conditions = cs }
    end
    out[i] = { conditionGroups = gs }
  end
  return out
end

local function finished(b, err)
  b.busy = false
  b.err = err
  S.redraw()
end

local function sets_shown(b)
  return not b.opts.show_sets or b.opts.show_sets()
end

local function save(b)
  if b.busy then
    return
  end
  local subject_sets, err
  if sets_shown(b) then
    subject_sets, err = to_subject_sets(b.sets)
    if not subject_sets then
      b.err = err
      S.redraw()
      return
    end
  end
  b.err = nil
  b.busy = true
  b.opts.on_save(subject_sets, U.bind(finished, b))
  S.redraw()
end

local function set_field(c, key, value)
  c[key] = value
end

local function pick(item, key, value)
  item[key] = value
  S.redraw()
end

local function remove(list, i)
  table.remove(list, i)
  S.redraw()
end

local function add(list, make)
  list[#list + 1] = make()
  S.redraw()
end

local function operator_picker(c, b)
  UI.dropdown(b, M.OPERATORS, c.operator, U.bind(pick, c, "operator"))
end

local function condition_row(g, k, c, h)
  h:input({
    border = true,
    title = "Selector",
    value = c.selector,
    placeholder = ".emailAddress",
    on_change = U.bind(set_field, c, "selector"),
  })
  UI.frame(h, "Operator", U.bind(operator_picker, c), { width = 14 })
  h:input({
    border = true,
    title = "Values, comma separated",
    value = c.values,
    placeholder = "alice@example.com, bob@example.com",
    on_change = U.bind(set_field, c, "values"),
  })
  UI.button_box(h, "Remove", U.bind(remove, g.conditions, k), #g.conditions == 1)
end

local function group_header(set, j, g, h)
  h:label({ text = "Match", style = "muted", width = 6 })
  UI.dropdown(h, M.BOOLEANS, g.op, U.bind(pick, g, "op"))
  h:label({ text = "" })
  h:button({ label = "Remove Group", disabled = #set.groups == 1, on_click = U.bind(remove, set.groups, j) })
end

local function group_footer(g, h)
  h:button({ label = "+ Condition", on_click = U.bind(add, g.conditions, new_condition) })
end

local function group_body(set, j, g, p)
  p:hstack({ height = 1, gap = 1, padding_left = 1, render = U.bind(group_header, set, j, g) })
  for k, c in ipairs(g.conditions) do
    p:hstack({ height = 3, gap = 1, render = U.bind(condition_row, g, k, c) })
  end
  p:hstack({ height = 1, padding_left = 1, render = U.bind(group_footer, g) })
end

local function set_header(b, i, set, h)
  h:label({ text = "Subject set " .. i, style = "bold" })
  h:button({ label = "Remove Set", disabled = #b.sets == 1, on_click = U.bind(remove, b.sets, i) })
end

local function set_footer(set, h)
  h:button({ label = "+ Group", on_click = U.bind(add, set.groups, new_group) })
end

local function sets_footer(b, h)
  h:button({ label = "+ Subject Set", on_click = U.bind(add, b.sets, new_set) })
end

local function buttons(b, h)
  h:button({ label = "Cancel", on_click = b.opts.on_cancel })
  h:button({ label = b.opts.submit or "Save", disabled = b.busy, on_click = U.bind(save, b) })
end

local function content(b, p)
  if b.opts.before then
    b.opts.before(p)
  end
  if not sets_shown(b) then
    return
  end
  p:label({ text = M.HINT, style = "muted", padding_left = 1, margin_top = 1 })
  for i, set in ipairs(b.sets) do
    p:hstack({ height = 1, gap = 1, margin_top = 1, padding_left = 1, render = U.bind(set_header, b, i, set) })
    for j, g in ipairs(set.groups) do
      UI.frame(p, "Group " .. j, U.bind(group_body, set, j, g), { margin_left = 2 })
    end
    p:hstack({ height = 1, padding_left = 3, render = U.bind(set_footer, set) })
  end
  p:hstack({ height = 1, margin_top = 1, padding_left = 1, render = U.bind(sets_footer, b) })
end

function M.render_builder(b, p)
  p:scrollview({ render = U.bind(content, b) })
  local text, style = "", "muted"
  if b.err then
    text, style = "✕ " .. b.err, "danger"
  elseif b.busy then
    text = "Saving…"
  end
  p:label({ text = text, style = style, padding_left = 1 })
  p:hstack({ height = 1, gap = 1, align = "right", render = U.bind(buttons, b) })
end

return M
