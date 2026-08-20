#!/usr/bin/env python3
import re, sys
from pathlib import Path
MODE = sys.argv[1]
PLUGIN_DIR = Path(sys.argv[2]).resolve()
INPUT = Path.home() / ".config/hypr/input.lua"
BEGIN = "-- BEGIN IO.GITHUB.DGORAN.OMAGESTURES"
END = "-- END IO.GITHUB.DGORAN.OMAGESTURES"
INPUT.parent.mkdir(parents=True, exist_ok=True)
text = INPUT.read_text() if INPUT.exists() else ""
text = re.sub(r"\n?" + re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "\n", text, flags=re.S)
text = re.sub(r"\n?-- BEGIN CHATGPT TRACKPAD SNAP GESTURES.*?-- END CHATGPT TRACKPAD SNAP GESTURES\n?", "\n", text, flags=re.S)
text = re.sub(r"^[ \t]*-- Mac-style trackpad gesture: 3-finger horizontal swipe changes workspace[ \t]*\n?", "", text, flags=re.M)
text = re.sub(r'^[ \t]*hl\.gesture\(\{\s*fingers\s*=\s*3,\s*direction\s*=\s*"horizontal",\s*action\s*=\s*"workspace"\s*\}\)[ \t]*\n?', "", text, flags=re.M)
if MODE == "enable":
    helper = str(PLUGIN_DIR / "snap.py").replace("\\", "\\\\").replace('"', '\\"')
    block = f'''{BEGIN}
-- Managed automatically by io.github.dgoran.omagestures
local omarchy_window_snap_helper = "{helper}"

hl.gesture({{ fingers = 3, direction = "left", action = function() hl.exec_cmd("python3 " .. omarchy_window_snap_helper .. " left") end }})
hl.gesture({{ fingers = 3, direction = "right", action = function() hl.exec_cmd("python3 " .. omarchy_window_snap_helper .. " right") end }})
hl.gesture({{ fingers = 3, direction = "up", action = function() hl.exec_cmd("python3 " .. omarchy_window_snap_helper .. " up") end }})
hl.gesture({{ fingers = 3, direction = "down", action = function() hl.exec_cmd("python3 " .. omarchy_window_snap_helper .. " down") end }})
{END}
'''
    text = text.rstrip() + "\n\n" + block
INPUT.write_text(text)
