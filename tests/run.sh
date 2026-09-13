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
local monitor = {
  x = 100, y = 50, width = 2000, height = 1000, scale = 2,
  reserved = { 10, 20, 30, 40 },
}
local active_window = { mapped = true, floating = true, fullscreen = 0, monitor = monitor }

os.time = function() return now end

hl = {
  dsp = { window = {} },
  get_active_window = function() return active_window end,
  gesture = function(spec) gestures[spec.direction] = spec.action end,
  dispatch = function(dispatcher) calls[#calls + 1] = dispatcher end,
}

hl.dsp.window.float = function(spec) return { kind = "float", spec = spec } end
hl.dsp.window.resize = function(spec) return { kind = "resize", spec = spec } end
hl.dsp.window.move = function(spec) return { kind = "move", spec = spec } end

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
gestures.left()
expect_geometry(115, 75, 470, 430, snapped_window)

local other_window = { mapped = true, floating = true, fullscreen = 0, monitor = monitor }
active_window = other_window
reset_calls()
gestures.up()
expect_geometry(115, 75, 470, 210, snapped_window)

reset_calls()
gestures.down()
assert(#calls == 0, "vertical follow-up must be single-use")

active_window = other_window
gestures.right()
reset_calls()
now = 131
gestures.down()
assert(#calls == 0, "vertical follow-up must expire after 30 seconds")

now = 200
gestures.right()
reset_calls()
now = 230
gestures.down()
expect_geometry(595, 295, 470, 210, other_window)

-- Only floating windows are snapped, and a rejected swipe disarms the pending
-- follow-up instead of leaving the previously snapped window targeted.
active_window = other_window
gestures.left()
active_window = { mapped = true, floating = false, fullscreen = 0, monitor = monitor }
reset_calls()
gestures.left()
assert(#calls == 0, "a tiled window must be left alone")
gestures.up()
assert(#calls == 0, "a rejected swipe must clear the armed follow-up")

active_window = other_window
gestures.left()
active_window = { mapped = true, floating = true, fullscreen = 2, monitor = monitor }
reset_calls()
gestures.left()
assert(#calls == 0, "a fullscreen window must be left alone")
gestures.up()
assert(#calls == 0, "a fullscreen window must not arm the vertical follow-up")

print("native gesture behavior: ok")
EOF

lua "$tmp/harness.lua"

export OMAGESTURES_CAPTURE="$tmp/disable.lua"
bash "$repo/activate.sh" disable

cat >"$tmp/disable-harness.lua" <<'EOF'
local removed = {}
hl = {
  gesture = function(spec)
    assert(spec.fingers == 3)
    assert(spec.action == "unset")
    removed[spec.direction] = true
  end,
}
_G.omagestures = { state = "old" }
assert(loadfile(os.getenv("OMAGESTURES_CAPTURE")))()
for _, direction in ipairs({ "left", "right", "up", "down" }) do
  assert(removed[direction], "missing removal for " .. direction)
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
GAP_INNER=16" ]] || { echo "settings round-trip failed"; exit 1; }
grep -q "local GAP_OUTER = 8 local GAP_INNER = 16" "$tmp/apply.lua" ||
  { echo "applied gaps did not reach the Lua prelude"; exit 1; }
if bash "$repo/activate.sh" apply 1 "x; rm -rf /" 5 2>/dev/null; then
  echo "non-numeric gap was accepted"; exit 1
fi
# Disabling in the widget must survive the reinstall that a config reload runs.
bash "$repo/activate.sh" apply 0 5 10
grep -q "_G.omagestures = nil" "$tmp/apply.lua" ||
  { echo "disabled state did not unregister on enable"; exit 1; }
bash "$repo/activate.sh" apply 1 5 10
echo "settings round-trip: ok"

bash -n "$repo/activate.sh"
jq -e . "$repo/manifest.json" >/dev/null
omarchy-plugin-validate "$repo"

echo "all tests passed"
