local ttt = require("ttt")
local Api = require("core.api")
local S = require("core.state")
local Form = require("components.form")

local M = {}

function M.open_dialog(title, width, height, render)
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

function M.dialog(spec)
  local form = Form.new_form(spec)
  spec.on_done = ttt.close_dialog
  M.open_dialog(spec.title, spec.width or 64, Form.form_height(form), function(p)
    Form.render_form(p, form, ttt.close_dialog)
  end)
end

-- Form submits: an error stays in the form, success runs after and closes it.
function M.save(path, req, done, after)
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

function M.confirm(message, path, req, done_message, after)
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

return M
