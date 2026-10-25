local ttt = require("ttt")
local U = require("core.util")
local Api = require("core.api")
local Nav = require("app.nav")
local Router = require("app.router")
local Sidebar = require("app.sidebar")
local Connection = require("app.connection")
local Settings = require("app.settings")

for _, name in ipairs({
  "namespaces",
  "attributes",
  "actions",
  "resources",
  "subject_mappings",
  "condition_sets",
  "kas",
  "entitlements",
  "decision",
}) do
  local feature = require("features." .. name)
  Router.register(feature.id, feature.root)
end

local function commands()
  local cmds = {
    { id = "opentdf.connection", title = "OpenTDF: Connection…", handler = Connection.dialog },
    { id = "opentdf.settings", title = "OpenTDF: Settings…", handler = Settings.dialog },
  }
  Nav.each(function(item)
    cmds[#cmds + 1] =
      { id = "opentdf." .. item.id, title = "OpenTDF: " .. item.label, handler = U.bind(Router.open, item.id) }
  end)
  return cmds
end

local sidebar_actions = {
  connection = Connection.dialog,
  settings = Settings.dialog,
  reconnect = Api.connect,
  counts = Api.refresh_counts,
}

local function on_action(cmd)
  local run = sidebar_actions[cmd]
  if run then
    run()
  end
end

ttt.register({
  sidebar = {
    title = "OpenTDF",
    render = Sidebar.render,
    actions = {
      { label = "Connection…", command = "connection" },
      { label = "Settings…", command = "settings" },
      { label = "Reconnect", command = "reconnect" },
      { label = "Refresh Counts", command = "counts" },
    },
    on_action = on_action,
  },
  commands = commands(),
})
