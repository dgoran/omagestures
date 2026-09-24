#!/usr/bin/env bash
set -euo pipefail

# Settings the bar widget writes and this script reads, so a Hyprland config
# reload (which reinstalls through "enable") keeps the chosen gaps.
config_file="${OMAGESTURES_CONFIG:-${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/omagestures.conf}"

enabled=1
gap_outer=5
gap_inner=10

# Read one key without sourcing the file, so a corrupted or hand-edited config
# cannot execute anything. Non-numeric or out-of-range values keep the default.
read_setting() {
  local key=$1 fallback=$2 value
  [[ -f $config_file ]] || { printf '%s' "$fallback"; return; }
  value=$(sed -n "s/^${key}=\\([0-9]\\{1,3\\}\\)$/\\1/p" "$config_file" | tail -n1)
  [[ -n $value && $value -le 200 ]] && printf '%s' "$value" || printf '%s' "$fallback"
}

load_settings() {
  enabled=$(read_setting ENABLED 1)
  gap_outer=$(read_setting GAP_OUTER 5)
  gap_inner=$(read_setting GAP_INNER 10)
}

write_settings() {
  mkdir -p "$(dirname "$config_file")"
  printf 'ENABLED=%s\nGAP_OUTER=%s\nGAP_INNER=%s\n' "$1" "$2" "$3" >"$config_file"
}

# mode is "register" or "unregister". snap is 1 or 0. Gaps are integers the
# caller already checked. Unregister drops every gesture this plugin owns.
# Register always installs the four-finger workspace gestures; the three-finger
# snap is included only while snap is 1, so the bar toggle can turn snapping
# off without taking workspace switching with it.
invoke() {
  local mode=$1 snap=$2
  hyprctl eval "local MODE = \"${mode}\" local SNAP = ${snap} local GAP_OUTER = ${gap_outer} local GAP_INNER = ${gap_inner}"'
local function unset(spec)
  local clear = { fingers = spec.fingers, direction = spec.direction, action = "unset" }
  if spec.mods ~= nil then clear.mods = spec.mods end
  if spec.scale ~= nil then clear.scale = spec.scale end
  pcall(hl.gesture, clear)
end

local snap_specs = {
  { fingers = 3, direction = "left" },
  { fingers = 3, direction = "right" },
  { fingers = 3, direction = "up" },
  { fingers = 3, direction = "down" },
}

-- SUPER + four fingers horizontal is the animated workspace swipe.
-- SUPER + four fingers up toggles Exposé.
-- Plain four-finger left and right step one numbered workspace. Discrete
-- directions, rather than one horizontal gesture, keep the mapping here
-- instead of on gestures.workspace_swipe_invert: left moves toward workspace 1.
local nav_specs = {
  { fingers = 4, direction = "horizontal", mods = "SUPER", scale = 1.3 },
  { fingers = 4, direction = "up", mods = "SUPER" },
  { fingers = 4, direction = "left" },
  { fingers = 4, direction = "right" },
}

-- Only a previous activation can leave gestures behind; unsetting a gesture
-- that was never registered is an error Hyprland reports back to hyprctl.
if _G.omagestures ~= nil then
  for _, spec in ipairs(snap_specs) do unset(spec) end
  for _, spec in ipairs(nav_specs) do unset(spec) end
end

if MODE == "unregister" then
  _G.omagestures = nil
  return
end

local WORKSPACE_FIRST, WORKSPACE_LAST = 1, 10

local function step_workspace(delta)
  local workspace = hl.get_active_workspace()
  local id = workspace and tonumber(workspace.id) or nil

  -- A special or named workspace sits outside the numbered run and has no
  -- neighbour to step to. Stepping stops at both ends of SUPER + 1..0
  -- instead of opening a workspace the keyboard cannot reach.
  if id == nil or id < WORKSPACE_FIRST or id > WORKSPACE_LAST then return end

  local target = math.min(WORKSPACE_LAST, math.max(WORKSPACE_FIRST, id + delta))
  if target == id then return end

  hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
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

  -- Inset the usable area first, then split what is left around the inner gap.
  -- A screen too small to hold its gaps still yields a window of a few pixels
  -- rather than a negative size Hyprland would reject.
  local avail_width = math.max(2, width - 2 * GAP_OUTER)
  local avail_height = math.max(2, height - 2 * GAP_OUTER)
  local split_width = math.max(2, avail_width - GAP_INNER)
  local split_height = math.max(2, avail_height - GAP_INNER)
  local left_width = math.max(2, math.floor(split_width / 2))
  local right_width = math.max(2, split_width - left_width)
  local top_height = math.max(2, math.floor(split_height / 2))
  local bottom_height = math.max(2, split_height - top_height)
  local x = (tonumber(monitor.x) or 0) + left + GAP_OUTER
  local y = (tonumber(monitor.y) or 0) + top + GAP_OUTER

  if side == "right" then x = x + left_width + GAP_INNER end
  if vertical == "down" then y = y + top_height + GAP_INNER end

  return x, y,
    side == "left" and left_width or right_width,
    vertical == nil and avail_height or (vertical == "up" and top_height or bottom_height)
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

if SNAP == 1 then
  hl.gesture({ fingers = 3, direction = "left", action = function() pcall(runtime.horizontal, "left") end })
  hl.gesture({ fingers = 3, direction = "right", action = function() pcall(runtime.horizontal, "right") end })
  hl.gesture({ fingers = 3, direction = "up", action = function() pcall(runtime.vertical, "up") end })
  hl.gesture({ fingers = 3, direction = "down", action = function() pcall(runtime.vertical, "down") end })
end

hl.gesture({ fingers = 4, direction = "horizontal", mods = "SUPER", scale = 1.3, action = "workspace" })
hl.gesture({
  fingers = 4,
  direction = "up",
  mods = "SUPER",
  action = function() pcall(hl.dispatch, hl.dsp.event("expose.window-overview:toggle")) end,
})
hl.gesture({ fingers = 4, direction = "left", action = function() pcall(step_workspace, -1) end })
hl.gesture({ fingers = 4, direction = "right", action = function() pcall(step_workspace, 1) end })
' >/dev/null || true
}

case "${1:-}" in
enable)
  load_settings
  # Snapping off has to survive a Hyprland config reload too, and a reload
  # comes back through this same path. Workspace gestures stay either way.
  if [[ $enabled == 0 ]]; then invoke register 0; else invoke register 1; fi
  ;;
disable)
  invoke unregister 0
  ;;
apply)
  # apply <enabled> <outer> <inner> -- what the bar widget calls when a
  # control changes: persist first, then reinstall from the stored values.
  [[ $# -eq 4 ]] || exit 2
  for value in "$2" "$3" "$4"; do
    [[ $value =~ ^[0-9]{1,3}$ && $value -le 200 ]] || exit 2
  done
  write_settings "$2" "$3" "$4"
  load_settings
  if [[ $enabled == 0 ]]; then invoke register 0; else invoke register 1; fi
  ;;
show)
  # The widget reads its initial state from here, so the config file stays the
  # single source of truth even when shell.json has no entry yet.
  load_settings
  printf 'ENABLED=%s\nGAP_OUTER=%s\nGAP_INNER=%s\n' "$enabled" "$gap_outer" "$gap_inner"
  ;;
*)
  exit 2
  ;;
esac
