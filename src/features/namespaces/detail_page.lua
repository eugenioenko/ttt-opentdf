local U = require("core.util")
local UI = require("components")
local Router = require("app.router")
local Policy = require("shared.policy")
local Commands = require("features.namespaces.commands")
local Attributes = require("features.attributes")
local Actions = require("features.actions")

local M = {}

local function attributes_tab(p, tab, n, attrs)
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
      Router.push(tab, Attributes.detail_page.page(a))
    end,
  })
end

local function actions_tab(p, acts)
  UI.ensure(acts)
  UI.table(p, acts, {
    frame = "Actions",
    frame_opts = { margin_top = 1 },
    noun = "actions",
    columns = { { label = "Name" }, { label = "Type", width = 9 }, { label = "Created", width = 16 } },
    row = function(a)
      return { a.name, a.kind, U.created(a) }
    end,
    style = Actions.store.style,
    on_open = function(a)
      Actions.commands.run("rename", a)
    end,
  })
end

function M.page(n)
  local page = { title = n.name }
  local attrs = Attributes.store.namespace_list(n.id)
  local acts = Actions.store.namespace_list(n.id)
  page.actions = function(h, tab)
    if page.tab == "attributes" then
      h:button({
        label = "New",
        on_click = function()
          Attributes.commands.new_attribute(n.id, function()
            UI.load(attrs, true)
          end)
        end,
      })
      UI.refresh_button(h, attrs)
    elseif page.tab == "actions" then
      h:button({
        label = "New",
        on_click = function()
          Actions.commands.new(n.id, function()
            UI.load(acts, true)
          end)
        end,
      })
      UI.refresh_button(h, acts)
    else
      Policy.actions(h, n, function(cmd)
        Commands.run(tab, cmd, n)
      end)
    end
  end
  page.render = function(p, tab)
    local current = Router.tab_strip(p, page, {
      { id = "details", label = "Details" },
      { id = "attributes", label = "Attributes" },
      { id = "actions", label = "Actions" },
    })
    if current == "attributes" then
      attributes_tab(p, tab, n, attrs)
    elseif current == "actions" then
      actions_tab(p, acts)
    else
      p:keyvalue(UI.kv({
        { "Name", n.name },
        { "FQN", n.fqn },
        { "Status", U.active(n.active) },
        { "Labels", U.labels(n.metadata) },
        { "ID", n.id },
        { "Created", U.created(n) },
        { "Updated", U.updated(n) },
      }))
    end
  end
  return page
end

return M
