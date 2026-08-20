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
export OMAGESTURES_CAPTURE="$tmp/enable.lua"
bash "$repo/activate.sh" enable

cat >"$tmp/harness.lua" <<'EOF'
local gestures = {}
local calls = {}
local now = 100
local active_window = {
  mapped = true,
  monitor = {
    x = 100, y = 50, width = 2000, height = 1000, scale = 2,
    reserved = { 10, 20, 30, 40 },
  },
}

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
local function expect_geometry(x, y, w, h, window)
  assert(#calls == 3, "expected float, resize, and move dispatches")
  assert(calls[1].kind == "float" and calls[1].spec.action == "set")
  assert(calls[2].kind == "resize")
  assert(calls[2].spec.x == w and calls[2].spec.y == h)
  assert(calls[2].spec.relative == false and calls[2].spec.window == window)
  assert(calls[3].kind == "move")
  assert(calls[3].spec.x == x and calls[3].spec.y == y)
  assert(calls[3].spec.relative == false and calls[3].spec.window == window)
end

local snapped_window = active_window
gestures.left()
expect_geometry(110, 70, 480, 440, snapped_window)

local other_window = { mapped = true, monitor = active_window.monitor }
active_window = other_window
reset_calls()
gestures.up()
expect_geometry(110, 70, 480, 220, snapped_window)

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
expect_geometry(590, 290, 480, 220, other_window)

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

bash -n "$repo/activate.sh"
jq -e . "$repo/manifest.json" >/dev/null
omarchy-plugin-validate "$repo"

echo "all tests passed"
