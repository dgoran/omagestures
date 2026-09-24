#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == eval && $# == 2 ]]
printf '%s' "$2" >"$OMAGESTURES_CAPTURE"
EOF
chmod +x "$tmp/bin/hyprctl"

export PATH="$tmp/bin:$PATH"
# Keep the suite off the real settings file, so a gap the user picked in the bar
# widget cannot change what the geometry assertions below expect.
export OMAGESTURES_CONFIG="$tmp/omagestures.conf"
export OMAGESTURES_CAPTURE="$tmp/enable.lua"
bash "$repo/activate.sh" enable

cat >"$tmp/harness.lua" <<'EOF'
local gestures = {}
local calls = {}
local now = 100
local workspace_id = 4
local monitor = {
  x = 100, y = 50, width = 2000, height = 1000, scale = 2,
  reserved = { 10, 20, 30, 40 },
}
local active_window = { mapped = true, floating = true, fullscreen = 0, monitor = monitor }

local function key(spec)
  local scale = spec.scale and string.format("%.1f", spec.scale) or ""
  return table.concat({ tostring(spec.fingers), spec.direction, spec.mods or "", scale }, ":")
end

os.time = function() return now end

hl = {
  dsp = { window = {} },
  get_active_window = function() return active_window end,
  get_active_workspace = function() return { id = workspace_id } end,
  gesture = function(spec)
    if spec.action == "unset" then gestures[key(spec)] = nil else gestures[key(spec)] = spec.action end
  end,
  dispatch = function(dispatcher) calls[#calls + 1] = dispatcher end,
  bind = function() end,
  unbind = function() end,
}

hl.dsp.window.float = function(spec) return { kind = "float", spec = spec } end
hl.dsp.window.resize = function(spec) return { kind = "resize", spec = spec } end
hl.dsp.window.move = function(spec) return { kind = "move", spec = spec } end
hl.dsp.focus = function(spec) return { kind = "focus", spec = spec } end
hl.dsp.event = function(name) return { kind = "event", name = name } end

local function fire(fingers, direction, mods, scale)
  local id = table.concat({
    tostring(fingers), direction, mods or "", scale and string.format("%.1f", scale) or "",
  }, ":")
  local action = gestures[id]
  assert(type(action) == "function", "missing gesture " .. id)
  action()
end

assert(loadfile(os.getenv("OMAGESTURES_CAPTURE")))()

local function reset_calls() calls = {} end
-- A floating window is snapped where it already is, so nothing floats it.
local function expect_geometry(x, y, w, h, window)
  assert(#calls == 2, "expected resize and move dispatches")
  assert(calls[1].kind == "resize")
  assert(calls[1].spec.x == w and calls[1].spec.y == h)
  assert(calls[1].spec.relative == false and calls[1].spec.window == window)
  assert(calls[2].kind == "move")
  assert(calls[2].spec.x == x and calls[2].spec.y == y)
  assert(calls[2].spec.relative == false and calls[2].spec.window == window)
end

local snapped_window = active_window
fire(3, "left")
expect_geometry(115, 75, 470, 430, snapped_window)

local other_window = { mapped = true, floating = true, fullscreen = 0, monitor = monitor }
active_window = other_window
reset_calls()
fire(3, "up")
expect_geometry(115, 75, 470, 210, snapped_window)

reset_calls()
fire(3, "down")
assert(#calls == 0, "vertical follow-up must be single-use")

active_window = other_window
fire(3, "right")
reset_calls()
now = 131
fire(3, "down")
assert(#calls == 0, "vertical follow-up must expire after 30 seconds")

now = 200
fire(3, "right")
reset_calls()
now = 230
fire(3, "down")
expect_geometry(595, 295, 470, 210, other_window)

-- Only floating windows are snapped, and a rejected swipe disarms the pending
-- follow-up instead of leaving the previously snapped window targeted.
active_window = other_window
fire(3, "left")
active_window = { mapped = true, floating = false, fullscreen = 0, monitor = monitor }
reset_calls()
fire(3, "left")
assert(#calls == 0, "a tiled window must be left alone")
fire(3, "up")
assert(#calls == 0, "a rejected swipe must clear the armed follow-up")

active_window = other_window
fire(3, "left")
active_window = { mapped = true, floating = true, fullscreen = 2, monitor = monitor }
reset_calls()
fire(3, "left")
assert(#calls == 0, "a fullscreen window must be left alone")
fire(3, "up")
assert(#calls == 0, "a fullscreen window must not arm the vertical follow-up")

assert(gestures["4:horizontal:SUPER:1.3"] == "workspace", "super swipe keeps the native workspace gesture")

reset_calls()
workspace_id = 4
fire(4, "left")
assert(#calls == 1 and calls[1].kind == "focus" and calls[1].spec.workspace == "3", "four-finger left steps toward workspace 1")

reset_calls()
fire(4, "right")
assert(#calls == 1 and calls[1].kind == "focus" and calls[1].spec.workspace == "5", "four-finger right steps toward workspace 10")

reset_calls()
workspace_id = 1
fire(4, "left")
assert(#calls == 0, "workspace stepping stops at 1")

reset_calls()
workspace_id = 10
fire(4, "right")
assert(#calls == 0, "workspace stepping stops at 10")

reset_calls()
workspace_id = "special:scratch"
fire(4, "left")
assert(#calls == 0, "a named workspace has no numbered neighbour")

reset_calls()
workspace_id = 11
fire(4, "right")
assert(#calls == 0, "a workspace outside 1..10 is left alone")

reset_calls()
fire(4, "up", "SUPER")
assert(#calls == 1 and calls[1].kind == "event" and calls[1].name == "expose.window-overview:toggle",
  "super plus four fingers up toggles Exposé")

-- A second install unsets the previous copies before registering again.
assert(loadfile(os.getenv("OMAGESTURES_CAPTURE")))()
reset_calls()
workspace_id = 4
fire(4, "left")
assert(calls[1].spec.workspace == "3", "reinstall keeps a single workspace step")

print("native gesture behavior: ok")
EOF

lua "$tmp/harness.lua"

export OMAGESTURES_CAPTURE="$tmp/disable.lua"
bash "$repo/activate.sh" disable

cat >"$tmp/disable-harness.lua" <<'EOF'
local removed = {}
local function key(spec)
  local scale = spec.scale and string.format("%.1f", spec.scale) or ""
  return table.concat({ tostring(spec.fingers), spec.direction, spec.mods or "", scale }, ":")
end
local unbound = false
hl = {
  gesture = function(spec)
    assert(spec.action == "unset")
    removed[key(spec)] = true
  end,
  unbind = function(key)
    assert(key == "mouse:274")
    unbound = true
  end,
}
_G.omagestures = { state = "old", tap = true }
assert(loadfile(os.getenv("OMAGESTURES_CAPTURE")))()
assert(unbound, "disable must release the three-finger tap")
local expected = {
  "3:left::", "3:right::", "3:up::", "3:down::",
  "4:horizontal:SUPER:1.3", "4:up:SUPER:", "4:left::", "4:right::",
}
for _, id in ipairs(expected) do
  assert(removed[id], "missing removal for " .. id)
end
assert(_G.omagestures == nil, "disable must clear runtime state")
print("gesture cleanup: ok")
EOF

lua "$tmp/disable-harness.lua"

# Settings round-trip: apply persists, show reports, and a bad value is refused
# before it can reach the Lua that gets evaluated inside Hyprland.
export OMAGESTURES_CAPTURE="$tmp/apply.lua"
bash "$repo/activate.sh" apply 1 8 16
[[ $(bash "$repo/activate.sh" show) == "ENABLED=1
GAP_OUTER=8
GAP_INNER=16
CORNERS=1
TAP_FLOAT=1
WORKSPACE_STEP=1
WORKSPACE_SWIPE=1
EXPOSE=1" ]] || { echo "settings round-trip failed"; exit 1; }
grep -q "local GAP_OUTER = 8 local GAP_INNER = 16" "$tmp/apply.lua" ||
  { echo "applied gaps did not reach the Lua prelude"; exit 1; }
if bash "$repo/activate.sh" apply 1 "x; rm -rf /" 5 2>/dev/null; then
  echo "non-numeric gap was accepted"; exit 1
fi
# Turning snapping off must drop the three-finger gestures and keep the
# four-finger workspace ones, including across the reinstall a config reload runs.
bash "$repo/activate.sh" apply 0 5 10
cat >"$tmp/snap-off.lua" <<'EOF'
local live = {}
local function key(spec)
  local scale = spec.scale and string.format("%.1f", spec.scale) or ""
  return table.concat({ tostring(spec.fingers), spec.direction, spec.mods or "", scale }, ":")
end
hl = {
  dsp = {
    window = { float = function(spec) return { kind = "float", spec = spec } end },
    focus = function() return {} end,
    event = function() return {} end,
  },
  get_active_window = function() return nil end,
  get_active_workspace = function() return { id = 1 } end,
  gesture = function(spec)
    if spec.action == "unset" then live[key(spec)] = nil else live[key(spec)] = spec.action end
  end,
  dispatch = function() end,
  bind = function() end,
  unbind = function() end,
}
_G.omagestures = { state = "armed" }
assert(loadfile(os.getenv("OMAGESTURES_CAPTURE")))()
assert(live["3:left::"] == nil, "snapping off must remove the three-finger gestures")
assert(live["4:horizontal:SUPER:1.3"] == "workspace", "snapping off must keep workspace swipe")
assert(type(live["4:left::"]) == "function", "snapping off must keep workspace stepping")
assert(_G.omagestures ~= nil and _G.omagestures.state == nil, "snapping off clears armed snap state")
print("snap toggle keeps workspace gestures: ok")
EOF
lua "$tmp/snap-off.lua"
bash "$repo/activate.sh" apply 1 5 10
# Each switch installs only its own gesture. Corners stay off while half snap
# stays on, and a tap that was previously installed is released.
bash "$repo/activate.sh" apply 1 5 10 0 0 0 1 0
cat >"$tmp/selective.lua" <<'EOF'
local live = {}
local unbound = false
local bound = false
local function key(spec)
  local scale = spec.scale and string.format("%.1f", spec.scale) or ""
  return table.concat({ tostring(spec.fingers), spec.direction, spec.mods or "", scale }, ":")
end
hl = {
  dsp = {
    window = { float = function(spec) return { kind = "float", spec = spec } end },
    focus = function() return {} end,
    event = function() return {} end,
  },
  get_active_window = function() return nil end,
  get_active_workspace = function() return { id = 1 } end,
  gesture = function(spec)
    if spec.action == "unset" then live[key(spec)] = nil else live[key(spec)] = spec.action end
  end,
  dispatch = function() end,
  bind = function(key) bound = key end,
  unbind = function(key) unbound = key end,
}
_G.omagestures = { tap = true }
assert(loadfile(os.getenv("OMAGESTURES_CAPTURE")))()
assert(type(live["3:left::"]) == "function", "half snap stays available")
assert(live["3:up::"] == nil, "corner follow-up can be switched off")
assert(live["4:left::"] == nil, "workspace stepping can be switched off")
assert(live["4:up:SUPER:"] == nil, "Exposé can be switched off")
assert(live["4:horizontal:SUPER:1.3"] == "workspace", "the Super swipe can stay on alone")
assert(unbound == "mouse:274", "switching the tap off releases the previous bind")
assert(bound == false, "a disabled tap is not installed again")
assert(_G.omagestures.tap == false, "the runtime remembers that the tap is off")
print("selective switches: ok")
EOF
lua "$tmp/selective.lua"
bash "$repo/activate.sh" apply 1 5 10 1 1 1 1 1
echo "settings round-trip: ok"

bash -n "$repo/activate.sh"
jq -e . "$repo/manifest.json" >/dev/null
omarchy-plugin-validate "$repo"

echo "all tests passed"
