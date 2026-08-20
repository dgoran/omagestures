#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
plugin_dir="${2:-}"
helper="$plugin_dir/snap.py"

if [[ -z "$plugin_dir" || ! -f "$helper" ]]; then
  exit 1
fi

helper_lua=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$helper")

if [[ "$mode" == "enable" ]]; then
  code=$(cat <<EOF
hl.gesture({ fingers = 3, direction = "left", action = function() hl.exec_cmd("python3 " .. $helper_lua .. " left") end })
hl.gesture({ fingers = 3, direction = "right", action = function() hl.exec_cmd("python3 " .. $helper_lua .. " right") end })
hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("python3 " .. $helper_lua .. " up") end })
hl.gesture({ fingers = 3, direction = "down", action = function() hl.exec_cmd("python3 " .. $helper_lua .. " down") end })
EOF
)
  hyprctl eval "$code" >/dev/null
elif [[ "$mode" == "disable" ]]; then
  code=$(cat <<'EOF'
hl.gesture({ fingers = 3, direction = "left", action = "unset" })
hl.gesture({ fingers = 3, direction = "right", action = "unset" })
hl.gesture({ fingers = 3, direction = "up", action = "unset" })
hl.gesture({ fingers = 3, direction = "down", action = "unset" })
EOF
)
  hyprctl eval "$code" >/dev/null || true
else
  exit 2
fi
