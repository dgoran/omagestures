#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
enable)
  hyprctl eval '
-- Only a previous activation can leave gestures behind; unsetting a gesture
-- that was never registered is an error Hyprland reports back to hyprctl.
if _G.omagestures ~= nil then
  for _, direction in ipairs({ "left", "right", "up", "down" }) do
    pcall(hl.gesture, { fingers = 3, direction = direction, action = "unset" })
  end
end

local runtime = { state = nil }
_G.omagestures = runtime

local function edge(reserved, name, index)
  if type(reserved) ~= "table" then return 0 end
  return tonumber(reserved[name] or reserved[index]) or 0
end

local function geometry(monitor, side, vertical)
  local scale = tonumber(monitor.scale) or 1
  if scale <= 0 then scale = 1 end

  local reserved = monitor.reserved
  local left = edge(reserved, "left", 1)
  local top = edge(reserved, "top", 2)
  local right = edge(reserved, "right", 3)
  local bottom = edge(reserved, "bottom", 4)
  local width = math.max(2, math.floor((tonumber(monitor.width) or 0) / scale + 0.5) - left - right)
  local height = math.max(2, math.floor((tonumber(monitor.height) or 0) / scale + 0.5) - top - bottom)
  local left_width = math.floor(width / 2)
  local right_width = width - left_width
  local top_height = math.floor(height / 2)
  local bottom_height = height - top_height
  local x = (tonumber(monitor.x) or 0) + left
  local y = (tonumber(monitor.y) or 0) + top

  if side == "right" then x = x + left_width end
  if vertical == "down" then y = y + top_height end

  return x, y,
    side == "left" and left_width or right_width,
    vertical == nil and height or (vertical == "up" and top_height or bottom_height)
end

local function snap(window, monitor, side, vertical)
  if window == nil or monitor == nil or window.mapped == false then return false end
  -- Snapping applies to floating windows only: a tiled window belongs to its
  -- layout, and a fullscreen window has no half to move to.
  if window.floating ~= true then return false end
  if (tonumber(window.fullscreen) or 0) ~= 0 then return false end
  local x, y, width, height = geometry(monitor, side, vertical)
  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false, window = window }))
  hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false, window = window }))
  return true
end

function runtime.horizontal(side)
  local window = hl.get_active_window()
  local monitor = window and window.monitor or nil
  if snap(window, monitor, side, nil) then
    runtime.state = { window = window, monitor = monitor, side = side, deadline = os.time() + 30 }
  else
    -- A rejected swipe must not leave an earlier window armed, or the next
    -- vertical swipe would corner a window the user has already left behind.
    runtime.state = nil
  end
end

function runtime.vertical(direction)
  local state = runtime.state
  runtime.state = nil
  if state == nil or os.time() > state.deadline then return end
  snap(state.window, state.monitor, state.side, direction)
end

hl.gesture({ fingers = 3, direction = "left", action = function() pcall(runtime.horizontal, "left") end })
hl.gesture({ fingers = 3, direction = "right", action = function() pcall(runtime.horizontal, "right") end })
hl.gesture({ fingers = 3, direction = "up", action = function() pcall(runtime.vertical, "up") end })
hl.gesture({ fingers = 3, direction = "down", action = function() pcall(runtime.vertical, "down") end })
' >/dev/null || true
  ;;
disable)
  hyprctl eval '
if _G.omagestures ~= nil then
  for _, direction in ipairs({ "left", "right", "up", "down" }) do
    pcall(hl.gesture, { fingers = 3, direction = direction, action = "unset" })
  end
end
_G.omagestures = nil
' >/dev/null || true
  ;;
*)
  exit 2
  ;;
esac
