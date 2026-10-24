local ttt = require("ttt")
local Api = require("core.api")
local Nav = require("app.nav")
local Router = require("app.router")
local Sidebar = require("app.sidebar")
local Connection = require("app.connection")
local Settings = require("app.settings")

for _, name in ipairs({ "namespaces", "attributes", "actions", "kas", "entitlements", "decision" }) do
  local feature = require("features." .. name)
  Router.register(feature.id, feature.root)
end

local function commands()
  local cmds = {
    { id = "opentdf.connection", title = "OpenTDF: Connection…", handler = Connection.dialog },
    { id = "opentdf.settings", title = "OpenTDF: Settings…", handler = Settings.dialog },
  }
  Nav.each(function(item)
    cmds[#cmds + 1] = {
      id = "opentdf." .. item.id,
      title = "OpenTDF: " .. item.label,
      handler = function()
        Router.open(item.id)
      end,
    }
  end)
  return cmds
end

local sidebar_actions = {
  connection = Connection.dialog,
  settings = Settings.dialog,
  reconnect = function()
    Api.connect()
  end,
  counts = Api.refresh_counts,
}

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
    on_action = function(cmd)
      local run = sidebar_actions[cmd]
      if run then
        run()
      end
    end,
  },
  commands = commands(),
})
