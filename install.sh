#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/dgoran/omagestures/main"
INSTALL_DIR="$HOME/.local/share/omagestures"
INPUT="$HOME/.config/hypr/input.lua"
BACKUP="$INPUT.omagestures-backup-$(date +%Y%m%d-%H%M%S)"
BEGIN='-- BEGIN IO.GITHUB.DGORAN.OMAGESTURES'
END='-- END IO.GITHUB.DGORAN.OMAGESTURES'

mkdir -p "$INSTALL_DIR" "$(dirname "$INPUT")"
curl -fsSL "$REPO_RAW/snap.py" -o "$INSTALL_DIR/snap.py"
chmod +x "$INSTALL_DIR/snap.py"
touch "$INPUT"
cp "$INPUT" "$BACKUP"

python3 - "$INPUT" "$INSTALL_DIR/snap.py" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); helper=sys.argv[2]
s=p.read_text()
begin='-- BEGIN IO.GITHUB.DGORAN.OMAGESTURES'; end='-- END IO.GITHUB.DGORAN.OMAGESTURES'
s=re.sub(r'\n?'+re.escape(begin)+r'.*?'+re.escape(end)+r'\n?', '\n', s, flags=re.S)
helper=helper.replace('\\','\\\\').replace('"','\\"')
block=f'''{begin}
-- Managed by OmaGestures. Hyprland-native; Quickshell is not involved.
local omagestures_helper = "{helper}"
hl.gesture({{ fingers = 3, direction = "left", action = function() hl.exec_cmd("python3 " .. omagestures_helper .. " left") end }})
hl.gesture({{ fingers = 3, direction = "right", action = function() hl.exec_cmd("python3 " .. omagestures_helper .. " right") end }})
hl.gesture({{ fingers = 3, direction = "up", action = function() hl.exec_cmd("python3 " .. omagestures_helper .. " up") end }})
hl.gesture({{ fingers = 3, direction = "down", action = function() hl.exec_cmd("python3 " .. omagestures_helper .. " down") end }})
{end}
'''
p.write_text(s.rstrip()+'\n\n'+block)
PY

echo "OmaGestures files installed. Backup: $BACKUP"
echo "Checking Hyprland config before reload..."
if ERR="$(hyprctl configerrors 2>&1)" && [[ -z "$ERR" ]]; then
  hyprctl reload
  echo "OmaGestures installed."
else
  cp "$BACKUP" "$INPUT"
  echo "Hyprland reported config errors; restored backup." >&2
  echo "$ERR" >&2
  exit 1
fi
