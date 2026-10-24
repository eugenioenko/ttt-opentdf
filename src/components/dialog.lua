local ttt = require("ttt")
local U = require("core.util")
local Api = require("core.api")
local S = require("core.state")
local Form = require("components.form")

local M = {}

local function render_dialog(render, p)
  S.panels.dialog = p
  render(p)
end

local function forget_dialog()
  S.panels.dialog = nil
end

function M.open_dialog(title, width, height, render)
  ttt.open_dialog({
    title = title,
    width = width,
    height = height,
    render = U.bind(render_dialog, render),
    on_close = forget_dialog,
  })
end

local function form_body(form, p)
  Form.render_form(p, form, ttt.close_dialog)
end

function M.dialog(spec)
  local form = Form.new_form(spec)
  spec.on_done = ttt.close_dialog
  M.open_dialog(spec.title, spec.width or 64, Form.form_height(form), U.bind(form_body, form))
end

local function saved(done, after, err, data)
  if err then
    return done(err)
  end
  if after then
    after(data)
  end
  done()
end

-- Form submits: an error stays in the form, success runs after and closes it.
function M.save(path, req, done, after)
  Api.call(path, req, U.bind(saved, done, after))
end

local function confirmed(done_message, after, err)
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
end

function M.confirm(message, path, req, done_message, after)
  ttt.confirm(message, U.bind(Api.call, path, req, U.bind(confirmed, done_message, after)))
end

return M
